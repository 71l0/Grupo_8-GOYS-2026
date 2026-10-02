# F0 — Diseño y gestión de cambio

## 0. Criterios definidos

- 7 routers MikroTik CHR.
- 2 switches.
- 2 hosts.
- 15 enlaces.
- AS EDGE: `65000`.
- ISP-1: `65001`.
- ISP-2: `65002`.
- CORE con OSPF área 0.
- CORE-1 Router-ID: `4.4.4.4`.
- CORE-2 Router-ID: `5.5.5.5`.
- VRRP:
  - VRID `10` → USERS → prioridad `150` en DIST-1.
  - VRID `20` → SERVERS → prioridad `150` en DIST-2.
- PC-USER: `192.168.10.100/24`, gateway `192.168.10.1`.
- PC-SERVER: `192.168.20.100/24`, gateway `192.168.20.1`.

## 1. Criterio de direccionamiento

| Elemento | Criterio |
|---|---|
| Enlaces punto a punto | `/30` |
| LAN USERS | `192.168.10.0/24` |
| LAN SERVERS | `192.168.20.0/24` |
| Loopbacks / Router-ID | `/32` |
| Red de infraestructura | `10.255.0.0/16` |
| VRRP USERS | VRID `10` |
| VRRP SERVERS | VRID `20` |
| Solapamiento de subredes | No permitido |

## 2. Tabla de direccionamiento de ENLACES

### Enlaces de Capa 3 con subred `/30`.

| # | Enlace | Subred | Extremo A (IP) | Extremo B (IP) |
|---:|---|---|---|---|
| 1 | ISP-1 ↔ EDGE | `10.255.0.0/30` | ISP-1 (`10.255.0.2`) | EDGE (`10.255.0.1`) |
| 2 | ISP-2 ↔ EDGE | `10.255.0.4/30` | ISP-2 (`10.255.0.6`) | EDGE (`10.255.0.5`) |
| 3 | EDGE ↔ CORE-1 | `10.255.0.8/30` | EDGE (`10.255.0.9`) | CORE-1 (`10.255.0.10`) |
| 4 | EDGE ↔ CORE-2 | `10.255.0.12/30` | EDGE (`10.255.0.13`) | CORE-2 (`10.255.0.14`) |
| 5 | CORE-1 ↔ CORE-2 | `10.255.0.16/30` | CORE-1 (`10.255.0.17`) | CORE-2 (`10.255.0.18`) |
| 6 | CORE-1 ↔ DIST-1 | `10.255.0.20/30` | CORE-1 (`10.255.0.21`) | DIST-1 (`10.255.0.22`) |
| 7 | CORE-1 ↔ DIST-2 | `10.255.0.24/30` | CORE-1 (`10.255.0.25`) | DIST-2 (`10.255.0.26`) |
| 8 | CORE-2 ↔ DIST-1 | `10.255.0.28/30` | CORE-2 (`10.255.0.29`) | DIST-1 (`10.255.0.30`) |
| 9 | CORE-2 ↔ DIST-2 | `10.255.0.32/30` | CORE-2 (`10.255.0.33`) | DIST-2 (`10.255.0.34`) |

### Enlaces de Capa 2

Los enlaces entre los routers de distribución y los switches de acceso son trunks de Capa 2. Por lo tanto, no se asigna una dirección IP directamente al enlace físico.

| # | Enlace | Tipo | VLAN | IP host | Modo |
|---:|---|---|---|---|---|
| 10 | DIST-1 ↔ SW-ACC-USERS | Trunk L2 | USERS | - | 802.1Q |
| 11 | DIST-2 ↔ SW-ACC-USERS | Trunk L2 | USERS | - | 802.1Q |
| 12 | DIST-1 ↔ SW-ACC-SERVERS | Trunk L2 | SERVERS | - | 802.1Q |
| 13 | DIST-2 ↔ SW-ACC-SERVERS | Trunk L2 | SERVERS | - | 802.1Q |
| 14 | SW-ACC-USERS ↔ PC-USER | Access L2 | USERS | `192.168.10.100/24` | Access |
| 15 | SW-ACC-SERVERS ↔ PC-SERVER | Access L2 | SERVERS | `192.168.20.100/24`| Access | 

### VLAN y segmentos LAN

| VLAN | Nombre | Subred | Gateway virtual VRRP | Host |
|---:|---|---|---|---|
| 10 | USERS | `192.168.10.0/24` | `192.168.10.1` | PC-USER |
| 20 | SERVERS | `192.168.20.0/24` | `192.168.20.1` | PC-SERVER |

## 3. LAN USERS

**VLAN:** ` 10 - USERS `
**Red:** `192.168.10.0/24`
**VRID** `10` 

| Dispositivo / función | Dirección |
|---|---|
| Gateway virtual VRRP | `192.168.10.1` |
| DIST-1 | `192.168.10.2` |
| DIST-2 | `192.168.10.3` |
| PC-USER | `192.168.10.100` |
| Máscara | `255.255.255.0` |
| Gateway PC-USER | `192.168.10.1` |

### VRRP — USERS

| Parámetro | Valor |
|---|---|
| VRID | `10` |
| IP virtual | `192.168.10.1` |
| Master | DIST-1 |
| Priority DIST-1 | `150` |
| Priority DIST-2 | `100` |
| Authentication | VRRP authentication — clave compartida |

Clave autenticacion: definida como secreto compartido entre DIST-1 y DIST-2.

## 4. LAN SERVERS

**Red:** `192.168.20.0/24`

| Dispositivo / función | Dirección |
|---|---|
| Gateway virtual VRRP | `192.168.20.1` |
| DIST-1 | `192.168.20.2` |
| DIST-2 | `192.168.20.3` |
| PC-SERVER | `192.168.20.100` |
| Máscara | `255.255.255.0` |
| Gateway PC-SERVER | `192.168.20.1` |

### VRRP — SERVERS

| Parámetro | Valor |
|---|---|
| VRID | `20` |
| IP virtual | `192.168.20.1` |
| Master | DIST-2 |
| Priority DIST-1 | `100` |
| Priority DIST-2 | `150` |
| Authentication | VRRP authentication — clave compartida |

Clave autenticacion: definida como secreto compartido entre DIST-1 y DIST-2.

## 5. Loopbacks y Router-ID

| Nodo | Rol | Loopback | Router-ID |
|---|---|---|---|
| ISP-1 | Provider | `1.1.1.1/32` | `1.1.1.1` |
| ISP-2 | Provider | `2.2.2.2/32` | `2.2.2.2` |
| EDGE | Edge-WAN | `3.3.3.3/32` | `3.3.3.3` |
| CORE-1 | Core | `4.4.4.4/32` | `4.4.4.4` |
| CORE-2 | Core | `5.5.5.5/32` | `5.5.5.5` |
| DIST-1 | Distribution | `6.6.6.6/32` | `6.6.6.6` |
| DIST-2 | Distribution | `7.7.7.7/32` | `7.7.7.7` |

> Los Router-ID de CORE-1 y CORE-2 están definidos por el diagrama.

## 6. Resumen de redes
| Uso             | Red/VLAN          | Máscara           | Tipo       |
| --------------- | ----------------- | ----------------- | ---------- |
| ISP-1 ↔ EDGE    | `10.255.0.0/30`   | `255.255.255.252` | L3 P2P     |
| ISP-2 ↔ EDGE    | `10.255.0.4/30`   | `255.255.255.252` | L3 P2P     |
| EDGE ↔ CORE-1   | `10.255.0.8/30`   | `255.255.255.252` | L3 P2P     |
| EDGE ↔ CORE-2   | `10.255.0.12/30`  | `255.255.255.252` | L3 P2P     |
| CORE-1 ↔ CORE-2 | `10.255.0.16/30`  | `255.255.255.252` | L3 P2P     |
| CORE-1 ↔ DIST-1 | `10.255.0.20/30`  | `255.255.255.252` | L3 P2P     |
| CORE-1 ↔ DIST-2 | `10.255.0.24/30`  | `255.255.255.252` | L3 P2P     |
| CORE-2 ↔ DIST-1 | `10.255.0.28/30`  | `255.255.255.252` | L3 P2P     |
| CORE-2 ↔ DIST-2 | `10.255.0.32/30`  | `255.255.255.252` | L3 P2P     |
| VLAN 10 USERS   | `192.168.10.0/24` | `255.255.255.0`   | LAN / VRRP |
| VLAN 20 SERVERS | `192.168.20.0/24` | `255.255.255.0`   | LAN / VRRP |
| Loopbacks       | 7 × `/32`         | `255.255.255.255` | Router-ID  |



## 7. Verificación de solapamiento

El direccionamiento utiliza bloques separados:

| Bloque | Uso |
|---|---|
| `10.255.0.0/30` – `10.255.0.32/30` | Enlaces L3 |
| `192.168.10.0/24` | VLAN 10 USERS |
| `192.168.20.0/24` | VLAN 20 SERVERS |
| `1.1.1.1/32` – `7.7.7.7/32` | Router-ID / Loopbacks |


No se deben utilizar subredes repetidas entre enlaces, LANs o loopbacks.

Los enlaces L2 no poseen una subred IP propia. Las direcciones IP pertenecen a las VLAN/LAN transportadas por dichos enlaces.

---

### 1.4 Política de operación

- **Formato del change log** (convención de commits): 
  se utilizará la convención "Conventional Commits" para el repositorio con la estructura: `tipo(alcance): descripción breve`. Los tipos permitidos estrictamente son: `feat` (nueva config/feature), `fix` (correcciones), `docs` (memoria/runbooks), `ops` (backups/change log), y `chore` (mantenimiento estructural). 
  Asimismo, en la sección 6.1 de esta memoria, el Change Log reflejará las intervenciones en los nodos detallando: Fecha, Rol responsable, Cambio realizado (nodo afectado y descripción), Motivo del cambio (commit asociado) y Cómo se revierte (procedimiento de rollback).

- **Política de backup** (cuándo y cómo): 
  - **Cuándo:** se tomará un backup inicial (Snapshot BASE) de todos los equipos en la Fase 1. Posteriormente, se realizarán backups al finalizar cada hito o antes de aplicar un cambio crítico.
  - **Qué y Cómo:** para cada router MikroTik CHR, se extraerá la configuración ejecutando los comandos `/export` (para tener la configuración legible) y `/system backup save` (para el binario completo).
  - **Dónde:** estos archivos serán versionados por fecha y almacenados en el repositorio del grupo dentro de la carpeta `backups/`.
  - **Restauración:** se documentará evidencia probando el *restore* del archivo `.backup` en un nodo para garantizar que la recuperación sea viable ante incidentes.