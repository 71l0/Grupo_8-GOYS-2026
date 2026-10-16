# Runbook F3 — BGP + firewall

| Campo | Valor |
|-------|-------|
| **Épica** | F3 — BGP + firewall |
| **Vence** | viernes 16/10 |
| **Tipo** | Procedimiento de redundancia de proveedor y aseguramiento del borde |
| **Roles** | R1 (EDGE: eBGP, redistribución, firewall), R2 (ISP-1/ISP-2: eBGP y default-originate), R5 (verificación y evidencia) |
| **Estado** | cerrado (backups en `backups/2026-10-11_F3_BASE/`) |
| **Dependencia** | ⚠️ Requiere **F2 cerrado** (OSPF FULL en el dominio interno). |

> **Alcance:** EDGE + ISP-1 (AS 65001) + ISP-2 (AS 65002). El dominio interno (CORE/DIST) no cambia en esta fase.

---

## 1. Objetivo

Implementar **eBGP multi-homing** con TCP-MD5 hacia los dos proveedores, anunciar las LANs internas hacia los ISP con filtros, habilitar la salida a "Internet" y **asegurar el borde** con firewall (input/forward) y NAT.

**Criterio de aceptación (del backlog):**
- 2 sesiones eBGP established (EDGE↔ISP-1, EDGE↔ISP-2), **con TCP-MD5**.
- OSPF→BGP redistribuido: las LANs se anuncian a los ISP.
- Host interno alcanza el loopback del ISP.
- Filtro de entrada + plano de gestión protegido en EDGE.

---

## 2. Prerrequisitos

- F2 cerrado: OSPF FULL y `<OSPF_MD5_KEY>` activa.
- Claves del canal privado: `<BGP_KEY_ISP1>` y `<BGP_KEY_ISP2>` (TCP-MD5, una por enlace). No se commitean.
- IPs de enlace WAN: EDGE `10.255.0.1/30` ↔ ISP-1 `10.255.0.2/30`; EDGE `10.255.0.5/30` ↔ ISP-2 `10.255.0.6/30`.

---

## 3. Procedimiento

### F3.1 · eBGP multi-homing con TCP-MD5

**EDGE** (AS 65000, router-id `3.3.3.3`):

```routeros
/routing bgp instance add as=65000 name=default router-id=3.3.3.3
/routing bgp template  add name=ebgp-peers hold-time=1m30s keepalive-time=30s routing-table=main
/routing bgp connection
add name=bgp-isp1 instance=default local.role=ebgp templates=ebgp-peers \
    remote.address=10.255.0.2/32 remote.as=65001 tcp-md5-key=<BGP_KEY_ISP1>
add name=bgp-isp2 instance=default local.role=ebgp templates=ebgp-peers \
    remote.address=10.255.0.6/32 remote.as=65002 tcp-md5-key=<BGP_KEY_ISP2>
```

**ISP-1** (AS 65001) — y análogo en ISP-2 (AS 65002, vecino `10.255.0.1/32`):

```routeros
/routing bgp instance add as=65001 name=default router-id=1.1.1.1
/routing bgp template  add name=ebgp-edge routing-table=main
/routing bgp connection
add name=bgp-edge instance=default local.role=ebgp templates=ebgp-edge \
    remote.address=10.255.0.1/32 remote.as=65000 tcp-md5-key=<BGP_KEY_ISP1> \
    output.redistribute=connected
```

### F3.2 · Redistribución OSPF → BGP con filtro

En EDGE, las dos conexiones redistribuyen OSPF y salen por una cadena que **solo anuncia las LANs internas**:

```routeros
/routing bgp connection set [find name=bgp-isp1,bgp-isp2] output.redistribute=ospf output.filter-chain=bgp-out-filter
/routing filter rule add chain=bgp-out-filter rule="if (dst in 192.168.0.0/16) { accept }"
```

### F3.3 · Salida a "Internet" y NAT

La default hacia el dominio la origina el propio EDGE en OSPF (los ISP no anuncian default por BGP):

```routeros
/routing ospf instance set [find name=ospf-instance-1] originate-default=always
/ip firewall nat
add action=masquerade chain=srcnat comment="NAT hacia ISP-1" out-interface=ether9
add action=masquerade chain=srcnat comment="NAT hacia ISP-2" out-interface=ether10
```

### F3.4 · Firewall en EDGE

Lista WAN + reglas (estado real en `backups/2026-10-11_F3_BASE/edge.rsc`, memoria §4.4):

```routeros
/interface list add name=WAN
/interface list member
add interface=ether9 list=WAN
add interface=ether10 list=WAN
/ip firewall filter
add action=accept chain=input    comment="establecido/relacionado" connection-state=established,related
add action=accept chain=input    comment="Permitir OSPF" protocol=ospf
add action=accept chain=input    comment="ICMP de gestion" protocol=icmp
add action=drop    chain=input    comment="Bloquear desde WAN ISP-1" in-interface=ether9
add action=drop    chain=input    comment="Bloquear desde WAN ISP-2" in-interface=ether10
add action=accept chain=input    comment="SSH/Winbox desde LAN interna" protocol=tcp dst-port=22,8291 in-interface-list=!WAN
add action=accept chain=forward comment="establecido/relacionado" connection-state=established,related
add action=accept chain=forward comment="Salida de LANs" src-address=192.168.0.0/16
add action=drop    chain=forward comment="Invalidos" connection-state=invalid
add action=drop    chain=forward comment="Entrante no solicitado ISP-1" in-interface=ether9 connection-nat-state=!dstnat
add action=drop    chain=forward comment="Entrante no solicitado ISP-2" in-interface=ether10 connection-nat-state=!dstnat
```

> Observaciones de revisión abiertas (memoria §4.4.5): `input` no termina con drop general (el cierre lo hacen las reglas de WAN), hay una regla `established,related` duplicada en `forward` y no hay accept explícito de TCP 179.

---

## 4. Verificación

| Qué | Cómo | Resultado esperado |
|---|---|---|
| Sesiones BGP | `/routing bgp session print` (en EDGE) | `bgp-isp1` y `bgp-isp2` con flag `E` (established) |
| TCP-MD5 | cambiar `tcp-md5-key` en un extremo | La sesión **no** llega a established (probado: memoria §5.1) |
| Anuncios | `/ip route print` en ISP-1 e ISP-2 | `192.168.10.0/24` y `192.168.20.0/24` como rutas BGP vía `10.255.0.1` |
| Default interna | `/ip route print` en CORE-1/DIST-1 | `0.0.0.0/0` aprendida por OSPF (dist 110; DIST con 2 caminos ECMP) |
| Salida | ping desde PC-USER a `1.1.1.1` y `2.2.2.2` | 0 % de pérdida, TTL 61 |
| Firewall | `/ip firewall filter print` + pruebas | 12 reglas activas sin marca `X`; el tráfico permitido sigue pasando y el management WAN externo queda bloqueado (memoria §4.4.4) |

## 5. Evidencia

- BGP: `capturas/F3/configuracionBGP-{EDGE,ISP1,ISP2}.png`, `estadoFinalEDGE_A.png`, `estadoFinalISP-1.png`, `estadoFinalISP-2.png`.
- Clave incorrecta: `wrongPasswordTCP-MD5{,-2,-3}.png` (memoria §5.1).
- Filtros/NAT/firewall: `cadenaDeFiltros.png`, `firewallFilter-EDGE.png`, `estadoFinalEDGE_C.png`.
- Salida: `estadoFinalEDGE_B.png`, `estadoFinalCORE1.png`, `estadoFinalDIST1.png`, `verificacionFinalPingueoALoopbacksDesdePC-USER.png`.
- Snapshot BASE F3: `snapshot_base_f3.png`.

## 6. Rollback / recuperación

Volver al estado F2: restaurar los `.rsc` de `backups/2026-10-11_F2_BASE/` en EDGE, ISP-1 e ISP-2, o quitar por CLI:

```routeros
/routing bgp connection remove [find]
/routing filter rule remove [find chain=bgp-out-filter]
/routing ospf instance set [find name=ospf-instance-1] originate-default=never
/ip firewall filter remove [find]
/ip firewall nat remove [find]
# Si EDGE queda sin acceso por red, operar por la consola de GNS3
```

## 7. Registro en change log / commit

Cierre de F3 en memoria §6.1.3, con commit `ops`:

```
ops(backup): agrega respaldos rsc, evidencias de conectividad y tablas de ruteo F3.
```
(Commit `4cc7d15`.)