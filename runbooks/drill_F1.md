# Runbook F1 — Topología + hardening + backup

| Campo | Valor |
|-------|-------|
| **Épica** | F1 — Topología + hardening + backup |
| **Vence** | viernes 9/10 |
| **Tipo** | Procedimiento de despliegue y aseguramiento |
| **Roles** | R1 (Edge-WAN), R2 (ISP-1/ISP-2), R3 (CORE-1/CORE-2), R4 (DIST-1/DIST-2), R5 (despliegue/snapshot/evidencia) |
| **Estado** | cerrado (backups en `backups/2026-10-08_F1_BASE/`) |
| **Dependencia** | ⚠️ Requiere **F0 aprobado** (IPAM, seguridad, operación de la memoria). |

> **Alcance:** 7 routers MikroTik CHR (RouterOS 7) + 2 switches + 2 hosts = **11 nodos, 15 enlaces**.

---

## 1. Objetivo

Levantar la topología física, aplicar el direccionamiento, **endurecer** cada router y tomar el **Snapshot BASE** con respaldo versionado.

**Criterio de aceptación (del backlog):**
- 7 CHR + 2 switches + 2 hosts levantados y cableados según el diagrama.
- Ping entre vecinos directos OK.
- Snapshot BASE tomado y documentado.
- Hardening: password admin + usuario `monitor` + servicios apagados en los 7 routers.
- `/export` de cada router versionado en el repo.

---

## 2. Prerrequisitos

- Proyecto GNS3.
- Imagen MikroTik CHR RouterOS 7.
- Cableado de los 15 enlaces verificado contra el diagrama (R1).
- Tabla IPAM de memoria §1.2 a mano.
- Canal privado con las claves reales (`<ADMIN_PASS>`, `<MONITOR_PASS>`).

---

## 3. Procedimiento

### F1.1 · Despliegue

1. Importar el proyecto GNS3 en todas las laptops (R5).
2. Verificar el cableado de los 15 enlaces contra el diagrama (R1).
3. Levantar los nodos y confirmar acceso por consola (R5).

**Mapa de nodos:** ISP-1, ISP-2, EDGE, CORE-1, CORE-2, DIST-1, DIST-2, SW-ACC-USERS, SW-ACC-SERVERS, PC-USER, PC-SERVER.

---

### F1.2 · IPs de enlace + loopbacks

Aplicar por router según la tabla. Usar el nombre de interfaz real del cableado en GNS3 en lugar de `<iface-…>`.

**ISP-1** (AS 65001 · Router-ID `1.1.1.1`)
```routeros
/ip address add address=10.255.0.2/30 interface=<iface-ISP1-EDGE>   # enlace 1
/ip address add address=1.1.1.1/32    interface=loopback            # Router-ID
```

**ISP-2** (AS 65002 · Router-ID `2.2.2.2`)
```routeros
/ip address add address=10.255.0.6/30 interface=<iface-ISP2-EDGE>   # enlace 2
/ip address add address=2.2.2.2/32    interface=loopback
```

**EDGE** (AS 65000 · Router-ID `3.3.3.3`)
```routeros
/ip address add address=10.255.0.1/30  interface=<iface-EDGE-ISP1>  # enlace 1
/ip address add address=10.255.0.5/30  interface=<iface-EDGE-ISP2>  # enlace 2
/ip address add address=10.255.0.9/30  interface=<iface-EDGE-CORE1> # enlace 3
/ip address add address=10.255.0.13/30 interface=<iface-EDGE-CORE2> # enlace 4
/ip address add address=3.3.3.3/32     interface=loopback
```

**CORE-1** (Router-ID `4.4.4.4`)
```routeros
/ip address add address=10.255.0.10/30 interface=<iface-CORE1-EDGE>  # enlace 3
/ip address add address=10.255.0.17/30 interface=<iface-CORE1-CORE2> # enlace 5 (core-core)
/ip address add address=10.255.0.21/30 interface=<iface-CORE1-DIST1> # enlace 6
/ip address add address=10.255.0.25/30 interface=<iface-CORE1-DIST2> # enlace 7
/ip address add address=4.4.4.4/32     interface=loopback
```

**CORE-2** (Router-ID `5.5.5.5`)
```routeros
/ip address add address=10.255.0.14/30 interface=<iface-CORE2-EDGE>  # enlace 4
/ip address add address=10.255.0.18/30 interface=<iface-CORE2-CORE1> # enlace 5 (core-core)
/ip address add address=10.255.0.29/30 interface=<iface-CORE2-DIST1> # enlace 8
/ip address add address=10.255.0.33/30 interface=<iface-CORE2-DIST2> # enlace 9
/ip address add address=5.5.5.5/32     interface=loopback
```

**Hosts**

| Host | IP | Gateway virtual VRRP |
|---|---|---|
| PC-USER | `192.168.10.100/24` | `192.168.10.1` |
| PC-SERVER | `192.168.20.100/24` | `192.168.20.1` |

**DIST-1** (Router-ID `6.6.6.6`)
```routeros
/ip address add address=10.255.0.22/30 interface=<iface-DIST1-CORE1> # enlace 6
/ip address add address=10.255.0.30/30 interface=<iface-DIST1-CORE2> # enlace 8
# VLAN USERS (10) y SERVERS (20) sobre el trunk hacia los switches
/interface bridge add name=bridge-lan
/interface bridge port add bridge=bridge-lan interface=<iface-DIST1-SW-USERS>
/interface bridge port add bridge=bridge-lan interface=<iface-DIST1-SW-SERVERS>
/interface vlan add interface=bridge-lan vlan-id=10 name=vlan-users
/interface vlan add interface=bridge-lan vlan-id=20 name=vlan-servers
/ip address add address=192.168.10.2/24 interface=vlan-users   # gateway físico USERS
/ip address add address=192.168.20.2/24 interface=vlan-servers # gateway físico SERVERS
/ip address add address=6.6.6.6/32     interface=loopback
```

**DIST-2** (Router-ID `7.7.7.7`)
```routeros
/ip address add address=10.255.0.26/30 interface=<iface-DIST2-CORE1> # enlace 7
/ip address add address=10.255.0.34/30 interface=<iface-DIST2-CORE2> # enlace 9
/interface bridge add name=bridge-lan
/interface bridge port add bridge=bridge-lan interface=<iface-DIST2-SW-USERS>
/interface bridge port add bridge=bridge-lan interface=<iface-DIST2-SW-SERVERS>
/interface vlan add interface=bridge-lan vlan-id=10 name=vlan-users
/interface vlan add interface=bridge-lan vlan-id=20 name=vlan-servers
/ip address add address=192.168.10.3/24 interface=vlan-users   # gateway físico USERS
/ip address add address=192.168.20.3/24 interface=vlan-servers # gateway físico SERVERS
/ip address add address=7.7.7.7/32     interface=loopback
```

---

### F1.3 · Hardening (los 7 routers)

Aplicar la misma configuración en ISP-1, ISP-2, EDGE, CORE-1, CORE-2, DIST-1, DIST-2.

```routeros
# 1) Password de admin (obligatorio; CHR viene sin password) y usuario monitor read-only
/user set admin password=<ADMIN_PASS>
/user group add name=monitor policy=read,test,ssh,winbox,!local,!telnet,!ftp,!reboot,!write,!policy,!password,!web,!sniff,!sensitive,!api,!romon,!rest-api
/user add name=monitor group=monitor password=<MONITOR_PASS>

# 2) Apagar servicios de gestión innecesarios y fortalecer SSH
/ip service disable telnet,ftp,www,www-ssl,api,api-ssl
/ip ssh set strong-crypto=yes

# 3) Reducir superficie: descubrimiento, acceso por MAC, bandwidth, DNS/proxy/socks/upnp/cloud
/ip neighbor discovery-settings set discover-interface-list=none
/tool mac-server set allowed-interface-list=none
/tool mac-server mac-winbox set allowed-interface-list=none
/tool bandwidth-server set enabled=no
/ip dns set allow-remote-requests=no
/ip proxy set enabled=no
/ip socks set enabled=no
/ip upnp set enabled=no
/ip cloud set ddns-enabled=no update-time=no
```

> ⚠️ Si se gestiona por **Winbox vía MAC** dentro de GNS3, apagar MAC-Winbox lo bloquea. Conectarse por IP (SSH/Winbox) o por la consola de GNS3. **SNMP queda apagado hasta F4.**

---

### F1.4 · Snapshot BASE + Backup

Para cada uno de los 7 routers:

```routeros
/export file=f1-base-<router>
/system backup save name=f1-base-<router> password=<BACKUP_PASS>
```

Versionar en `backups/2026-10-08_F1_BASE/`:

| Router | Archivo `.rsc` |
|---|---|
| EDGE | `edge.rsc` |
| ISP-1 | `isp1.rsc` |
| ISP-2 | `isp2.rsc` |
| CORE-1 | `core1.rsc` |
| CORE-2 | `core2.rsc` |
| DIST-1 | `dist1.rsc` |
| DIST-2 | `dist2.rsc` |

**Probar el *restore*** en un nodo con el `.backup` para confirmar que la recuperación es viable, y capturar la evidencia. ✅ Hecho el 16/10 en ISP-1 con `F3_BASE.backup` (memoria §2.5.1).

---

## 4. Verificación

**Conectividad entre vecinos directos** (`/ping`). Registro PING (memoria §2.2.10):

| ID | Origen | Destino |
|---|---|---|
| PING-01 | DIST2 | CORE1 · CORE2 · PC-SERVER · DIST1 |
| PING-02 | DIST1 | CORE1 · CORE2 · PC-USER · DIST2 |
| PING-03 | PC-USER | DIST1 |
| PING-04 | PC-SERVER | DIST2 |
| PING-05 | CORE2 | EDGE · CORE1 · DIST1 · DIST2 |
| PING-06 | CORE1 | EDGE · CORE2 · DIST1 · DIST2 |
| PING-07 | ISP-1 | EDGE |
| PING-08 | ISP-2 | EDGE |
| PING-09 | EDGE | ISP1 · ISP2 · CORE1 · CORE2 |

**Controles de seguridad** (memoria §1.3.5):

| Control | Cómo se verifica | Resultado esperado |
|---|---|---|
| Password admin | Login sin password | Rechazado |
| Usuario `monitor` | Login + intento de escribir | Lee, **no** escribe |
| Servicios | `/ip service print` | Solo `ssh` y `winbox` habilitados |

## 5. Evidencia

- Config y estado por nodo: `capturas/F1/config-<NODO>.png`.
- Conectividad: `capturas/F1/pruebaConectividad*.png`.
- Hardening: `capturas/F1/hardeningSeguridad.png`.
- Snapshot/backup: `capturas/F1/snapshot_base_f1.png`, `capturas/F1/exportYBackupPorRouter.png`.

## 6. Rollback / recuperación

Restaurar desde el Snapshot BASE (GNS3) o cargar el `.rsc`/`.backup`:

```routeros
/system backup load name=f1-base-<router> password=<BACKUP_PASS>
# Si se restauró desde /export, recargar a mano las claves (el /export las oculta)
```

## 7. Registro en change log / commit

Cerrar F1 con un commit `ops`:

```
ops(backup): agrega respaldos rsc, evidencias de conectividad y hardening F1.
```