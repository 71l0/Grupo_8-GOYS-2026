# Runbook F2 — VRRP + OSPF

| Campo | Valor |
|-------|-------|
| **Épica** | F2 — VRRP + OSPF |
| **Vence** | viernes 16/10 |
| **Tipo** | Procedimiento de implementación de redundancia de primer salto e IGP |
| **Roles** | R4 (DIST-1/DIST-2: VLANs, VRRP y OSPF), R3 (CORE-1/CORE-2: OSPF), R1 (EDGE: OSPF), R5 (verificación y evidencia) |
| **Estado** | cerrado (backups en `backups/2026-10-11_F2_BASE/`) |
| **Dependencia** | ⚠️ Requiere **F1 cerrado** (topología, IPs, hardening y backup BASE). |

> **Alcance:** 5 routers de ruteo (EDGE, CORE-1, CORE-2, DIST-1, DIST-2). ISP-1 e ISP-2 quedan fuera de OSPF (se conectan por eBGP en F3).

---

## 1. Objetivo

Implementar la redundancia de **primer salto** (VRRP con load-sharing en distribución) y la **redundancia de IGP** (OSPF área 0 con autenticación MD5 en el dominio interno), y verificar la conectividad de capa 3 de punta a punta.

**Criterio de aceptación (del backlog):**
- 2 grupos VRRP (10 y 20) operativos con load-sharing (DIST-1 master 10, DIST-2 master 20), **con auth**.
- Adyacencias OSPF FULL edge↔core↔dist (incluido core–core), **con MD5**.
- Verificación L3: ping intra-LAN + gateway virtual responde.

---

## 2. Prerrequisitos

- F1 cerrado: IPs de enlace, LANs y loopbacks according al IPAM (memoria §1.2), hardening aplicado y `backups/2026-10-08_F1_BASE/` versionado.
- Claves del canal privado: `<VRRP_PASS>` (auth simple VRRP) y `<OSPF_MD5_KEY>` (auth-id 1). **No se commitean**: `/export` las oculta.
- En DIST-1 y DIST-2: `ether11` trunkeado hacia SW-USERS (VLAN 10) y `ether12` hacia SW-SERVERS (VLAN 20).

---

## 3. Procedimiento

### F2.1 · VLANs + VRRP en distribución

**DIST-1** (master USERS / backup SERVERS):

```routeros
/interface vlan
add interface=ether11 name=vlan10 vlan-id=10
add interface=ether12 name=vlan20 vlan-id=20
/interface vrrp
add interface=vlan10 name=vrrp-users  vrid=10 version=2 priority=150 authentication=simple
add interface=vlan20 name=vrrp-servers vrid=20 version=2 authentication=simple
/ip address
add address=192.168.10.1 interface=vrrp-users    # gateway virtual USERS
add address=192.168.20.1 interface=vrrp-servers  # gateway virtual SERVERS
```

**DIST-2** (misma estructura, roles invertidos):

```routeros
/interface vlan
add interface=ether11 name=vlan10 vlan-id=10
add interface=ether12 name=vlan20 vlan-id=20
/interface vrrp
add interface=vlan10 name=vrrp-users  vrid=10 version=2 authentication=simple            # backup (prioridad por defecto)
add interface=vlan20 name=vrrp-servers vrid=20 version=2 priority=150 authentication=simple  # master SERVERS
/ip address
add address=192.168.10.1 interface=vrrp-users
add address=192.168.20.1 interface=vrrp-servers
```

> `version=2` (VRRPv2, RFC 5798). Las IPs físicas de las VLAN (`192.168.10.2/3`, `.20.2/3`) ya vienen de F1. La contraseña simple no aparece en `/export`; recargarla a mano tras cualquier restore desde `.rsc`.

### F2.2 · OSPF área 0 en los 5 routers

Misma estructura en todos: instancia + área backbone + interface-template con MD5.

| Router | Router-ID | Interfaces en OSPF |
|---|---|---|
| EDGE | `3.3.3.3` | `ether11,ether12,lo` |
| CORE-1 | `4.4.4.4` | `ether9,ether10,ether11,ether12,lo` |
| CORE-2 | `5.5.5.5` | `ether9,ether10,ether11,ether12,lo` |
| DIST-1 | `6.6.6.6` | `ether9,ether10,vlan10,vlan20,lo` |
| DIST-2 | `7.7.7.7` | `ether9,ether10,vlan10,vlan20,lo` |

```routeros
/routing ospf instance add name=ospf-instance-1 router-id=<R-ID>
/routing ospf area       add instance=ospf-instance-1 name=backbone-area
/routing ospf interface-template add area=backbone-area auth=md5 auth-id=1 interfaces=<ver tabla>
```

> EDGE **no** incluye `ether9`/`ether10` (enlaces WAN hacia los ISP): esa frontera es de BGP (F3). El enlace core–core (`ether10` en CORE-1 y CORE-2) sí participa.

### F2.3 · Autenticación MD5

`auth=md5 auth-id=1` queda en cada interface-template (visible en los `.rsc`); la `<OSPF_MD5_KEY>` no se exporta. Cualquier vecino con clave distinta no llega a FULL (prueba de clave incorrecta pendiente para F4, memoria §5).

---

## 4. Verificación

| Qué | Cómo | Resultado esperado |
|---|---|---|
| Roles VRRP | `/interface vrrp print` | DIST-1: `vrrp-users` **M**, `vrrp-servers` **B**; DIST-2: inverso |
| Adyacencias | `/routing ospf neighbor print` | Todas en estado `Full`: EDGE↔CORE-1/2, CORE-1↔CORE-2, CORE↔DIST (EDGE 2 vecinos, CORE-1/CORE-2 4 cada uno, DIST 2 cada uno) |
| Tabla de ruteo | `/ip route print` | Loopbacks `/32` y LANs `192.168.10.0/20.0/24` aprendidas por OSPF (dist 110) |
| Gateway virtual | ping desde PC-USER a `192.168.10.1` y desde PC-SERVER a `192.168.20.1` | 0 % de pérdida |
| Intra-LAN | ping PC-USER ↔ PC-SERVER | 0 % de pérdida (memoria §3.3) |

## 5. Evidencia

- VRRP: `capturas/F2/configVRRP-DIST1.png`, `configVRRP-DIST2.png`.
- OSPF: `configOSPF-{EDGE,CORE1,CORE2,DIST1,DIST2}.png`, `verificacionOSPF-*.png`, `verificacionTablaDeRuteo-{EDGE,CORE1,CORE2}.png`.
- L3: `pingGatewayVirtualDesdePC-USER.png`, `pingGatewayVirtualDesdePC-SERVER.png`, `pingPC-USER-PC-SERVER.png`.
- Snapshot BASE F2: `snapshot_base_f2.png`.

## 6. Rollback / recuperación

Volver al estado F1: restaurar los `.rsc` de `backups/2026-10-08_F1_BASE/` (EDGE, CORE-1, CORE-2, DIST-1, DIST-2) o quitar la configuración por CLI:

```routeros
/interface vrrp remove [find]
/routing ospf interface-template remove [find]
/routing ospf area remove [find]
/routing ospf instance remove [find]
# Si se restauró desde /export: recargar a mano las claves OSPF/VRRP (el /export las oculta)
```

## 7. Registro en change log / commit

Cierre de F2 en memoria §6.1.2, con commit `ops`:

```
ops(backup): agrega respaldos rsc, evidencias de conectividad y tablas de ruteo F2.
```
(Commit `e1f5757`.)