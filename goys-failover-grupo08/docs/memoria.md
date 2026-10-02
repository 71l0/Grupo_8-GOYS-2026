# Memoria del Laboratorio — Failover Routing

**Grupo:** 8
**Materia:** Gestión Operativa y Seguridad en Redes (GOYS)
**Fecha de entrega:** viernes 23/10/2026

## Integrantes y roles

| Integrante | Rol |
|-----------|-----|
| **Todos los miembros del grupo** | R1 — Líder / Edge-WAN |
| Jano Stratakis | R2 — Proveedores |
| Ulises Mateo Bucchino | R3 — Core |
| Valentín Garzaniti | R4 — Distribución |
| Sofia Raggi | R5 — Hosts / QA / Operación |

---

## 1.1 Correccion del Diagrama
#### Corrección del diagrama

Diagrama analizado: "Enterprise Network Design (Cisco)", el que vimos en clase. Le encontramos 5 defectos. Esta tabla va en la sección 1.1 de la memoria.

| # | Defecto detectado | Corrección aplicada | Justificación |
|:-:|-------------------|---------------------|---------------|
| 1 | Hay un solo firewall (ASA 5506-X) entre el edge y el core, sin par HA. Es un punto único de falla. | En el lab no hay firewall aparte, el filtrado lo hace EDGE. Dejamos documentado que en una red real tienen que ser dos firewalls en failover (activo/standby). | Los ISR y los ISP están duplicados, pero todo el tráfico pasa por un único ASA. Si se cae, se corta la salida igual y la redundancia de arriba no sirve de nada. En el lab pasa algo parecido con EDGE, que también es uno solo; en producción irían dos. |
| 2 | Subredes repetidas entre sitios: las VLAN 10 y 20 están en el Site 1 y en el Site 2, y la 192.168.10.0/24 aparece dos veces. | Plan de direccionamiento sin solapamientos: cada enlace y cada LAN con su propia red (ver IPAM en [`memoria.md`](../memoria.md)). | Si la misma red está en dos lugares, al interconectar los sitios el router no sabe a cuál mandar el paquete. OSPF y BGP la anuncian desde dos puntos y el tráfico termina en el sitio equivocado o se pierde. |
| 3 | Entre C1 y C2 (los dos Nexus del core) no hay enlace. | Agregamos el enlace CORE-1 ↔ CORE-2 y corre OSPF área 0 sobre él. | Si se corta EDGE ↔ CORE-1, CORE-1 se queda sin camino directo hacia arriba y el tráfico tiene que bajar a distribución para volver a subir por CORE-2. Con el enlace core-core pasa directo al otro core y OSPF tiene una ruta alternativa corta. |
| 4 | HSRP en el core (VLAN 10, 20 y 30 en los Nexus 9300). Es un diseño "collapsed": el core hace también de gateway de los usuarios. | El gateway pasa a distribución con VRRP entre DIST-1 y DIST-2. El core queda solo para rutear (tránsito puro). | El core tiene que hacer una sola cosa y hacerla rápido. Si además es gateway, un problema de una LAN (ARP, broadcast, cambio de master) termina afectando al equipo del que depende toda la red. En distribución el problema queda en esa capa. Usamos VRRP y no HSRP porque VRRP es estándar (RFC 5798) y HSRP es de Cisco (RFC 2281); en MikroTik no existe HSRP. |
| 5 | El iBGP con route reflector está mal ubicado: la sesión aparece entre las interfaces outside del ASA, atravesando el firewall. | Sin iBGP y sin route reflector. BGP corre solo en EDGE (AS 65000), como eBGP hacia ISP-1 (AS 65001) e ISP-2 (AS 65002). Adentro se usa OSPF. | Un route reflector sirve cuando hay muchos routers iBGP en el mismo AS y no querés hacer full-mesh. Acá hay un solo router de borde, no hay nada que reflejar. Además, si el RR existiera tendría que estar en los routers de borde, no del otro lado del firewall. BGP queda para hablar con los proveedores y OSPF para adentro. |

### Otras cosas que vimos

En el análisis también aparecen problemas que no son de ruteo: no hay QoS para voz, no hay VLAN de gestión y faltan protecciones de capa 2 (port-security, DHCP snooping, DAI, root guard). No los corregimos porque el lab se centra en el failover de ruteo (VRRP, OSPF y BGP), pero los anotamos.

### Topología corregida

Así queda la red después de aplicar las correcciones. Las direcciones IP no van acá, están en el IPAM ([`memoria.md`](../memoria.md)).

```
[ INTERNET ]        ISP-1 (AS 65001)               ISP-2 (AS 65002)
                           \                             /
                            \ eBGP                 eBGP /
                             \                         /
[ EDGE ]                        EDGE (AS 65000)
                        eBGP x2 + OSPF + filtrado de borde        <- correcciones 1 y 5
                             /                         \
                            / OSPF                OSPF  \
                           /                             \
[ CORE ]               CORE-1 ------- core-core ------- CORE-2    <- corrección 3
                         |    \                       /    |
                         |     \                     /     |
                         |      \___________________/      |
                         |       ___________________       |
                         |      /                   \      |
                         |     /                     \     |
[ DISTRIBUTION ]       DIST-1                         DIST-2      <- corrección 4
                   VRRP 10 master                 VRRP 10 backup
                   VRRP 20 backup                 VRRP 20 master
                         |     \                     /     |
                         |      \___________________/      |
                         |       ___________________       |
                         |      /                   \      |
                         |     /                     \     |
[ ACCESS ]         SW-ACC-USERS                   SW-ACC-SERVERS
                         |                               |
                      PC-USER                        PC-SERVER
```

Las líneas cruzadas son:
- Entre core y distribución: cada DIST está conectado a los dos core (DIST-1 a CORE-2 y DIST-2 a CORE-1).
- Entre distribución y acceso: cada DIST está conectado a los dos switches, porque VRRP necesita que los dos routers estén en la misma LAN.

### Enlaces

| # | Enlace | Capa |
|:-:|--------|------|
| 1 | ISP-1 ↔ EDGE | Internet / Edge |
| 2 | ISP-2 ↔ EDGE | Internet / Edge |
| 3 | EDGE ↔ CORE-1 | Edge / Core |
| 4 | EDGE ↔ CORE-2 | Edge / Core |
| 5 | CORE-1 ↔ CORE-2 | Core (el que faltaba) |
| 6 | CORE-1 ↔ DIST-1 | Core / Distribución |
| 7 | CORE-1 ↔ DIST-2 | Core / Distribución |
| 8 | CORE-2 ↔ DIST-1 | Core / Distribución |
| 9 | CORE-2 ↔ DIST-2 | Core / Distribución |
| 10 | DIST-1 ↔ SW-ACC-USERS | Distribución / Acceso |
| 11 | DIST-2 ↔ SW-ACC-USERS | Distribución / Acceso |
| 12 | DIST-1 ↔ SW-ACC-SERVERS | Distribución / Acceso |
| 13 | DIST-2 ↔ SW-ACC-SERVERS | Distribución / Acceso |
| 14 | SW-ACC-USERS ↔ PC-USER | Acceso |
| 15 | SW-ACC-SERVERS ↔ PC-SERVER | Acceso |

En total son 11 nodos (7 routers, 2 switches y 2 hosts) y 15 enlaces, lo mismo que dice la consigna. En F1 lo comparamos con el proyecto de GNS3.

### Qué cambió con respecto al original

| Original | Corregido |
|----------|-----------|
| Un solo ASA como firewall | Filtrado en EDGE; en producción, dos firewalls en failover |
| Redes repetidas entre sitios | Cada red es única (ver IPAM en [`memoria.md`](../memoria.md)) |
| C1 y C2 sin enlace entre sí | Enlace CORE-1 ↔ CORE-2 |
| HSRP en el core | VRRP en DIST-1 / DIST-2, el core solo rutea |
| iBGP con route reflector a través del ASA | eBGP solo en EDGE, sin RR, OSPF adentro |
---
## 1.2 IPAM / direccionamiento

### 1.2.1 Criterios definidos

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

### 1.2.2 Criterio de direccionamiento

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

### 1.2.3 Tabla de direccionamiento de ENLACES

#### Enlaces de Capa 3 con subred `/30`.

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

#### Enlaces de Capa 2

Los enlaces entre los routers de distribución y los switches de acceso son trunks de Capa 2. Por lo tanto, no se asigna una dirección IP directamente al enlace físico.

| # | Enlace | Tipo | VLAN | IP host | Modo |
|---:|---|---|---|---|---|
| 10 | DIST-1 ↔ SW-ACC-USERS | Trunk L2 | USERS | - | 802.1Q |
| 11 | DIST-2 ↔ SW-ACC-USERS | Trunk L2 | USERS | - | 802.1Q |
| 12 | DIST-1 ↔ SW-ACC-SERVERS | Trunk L2 | SERVERS | - | 802.1Q |
| 13 | DIST-2 ↔ SW-ACC-SERVERS | Trunk L2 | SERVERS | - | 802.1Q |
| 14 | SW-ACC-USERS ↔ PC-USER | Access L2 | USERS | `192.168.10.100/24` | Access |
| 15 | SW-ACC-SERVERS ↔ PC-SERVER | Access L2 | SERVERS | `192.168.20.100/24`| Access | 

#### VLAN y segmentos LAN

| VLAN | Nombre | Subred | Gateway virtual VRRP | Host |
|---:|---|---|---|---|
| 10 | USERS | `192.168.10.0/24` | `192.168.10.1` | PC-USER |
| 20 | SERVERS | `192.168.20.0/24` | `192.168.20.1` | PC-SERVER |

### 1.2.4 LAN USERS

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

#### VRRP — USERS

| Parámetro | Valor |
|---|---|
| VRID | `10` |
| IP virtual | `192.168.10.1` |
| Master | DIST-1 |
| Priority DIST-1 | `150` |
| Priority DIST-2 | `100` |
| Authentication | VRRP authentication — clave compartida |

Clave autenticacion: definida como secreto compartido entre DIST-1 y DIST-2.

### 1.2.5 LAN SERVERS

**Red:** `192.168.20.0/24`

| Dispositivo / función | Dirección |
|---|---|
| Gateway virtual VRRP | `192.168.20.1` |
| DIST-1 | `192.168.20.2` |
| DIST-2 | `192.168.20.3` |
| PC-SERVER | `192.168.20.100` |
| Máscara | `255.255.255.0` |
| Gateway PC-SERVER | `192.168.20.1` |

#### VRRP — SERVERS

| Parámetro | Valor |
|---|---|
| VRID | `20` |
| IP virtual | `192.168.20.1` |
| Master | DIST-2 |
| Priority DIST-1 | `100` |
| Priority DIST-2 | `150` |
| Authentication | VRRP authentication — clave compartida |

Clave autenticacion: definida como secreto compartido entre DIST-1 y DIST-2.

### 1.2.6 Loopbacks y Router-ID

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

### 1.2.7 Resumen de redes
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

### 1.2.8 Verificación de solapamiento

El direccionamiento utiliza bloques separados:

| Bloque | Uso |
|---|---|
| `10.255.0.0/30` – `10.255.0.32/30` | Enlaces L3 |
| `192.168.10.0/24` | VLAN 10 USERS |
| `192.168.20.0/24` | VLAN 20 SERVERS |
| `1.1.1.1/32` – `7.7.7.7/32` | Router-ID / Loopbacks |

No se deben utilizar subredes repetidas entre enlaces, LANs o loopbacks.

Los enlaces L2 no poseen una subred IP propia. Las direcciones IP pertenecen a las VLAN/LAN transportadas por dichos enlaces.

## 1.3 Política de seguridad

Alcance: los **7 routers CHR** (ISP-1, ISP-2, EDGE, CORE-1, CORE-2, DIST-1, DIST-2), RouterOS 7.

Principio rector: **mínimo privilegio y mínima superficie de ataque**. Cada usuario tiene solo los permisos que necesita, cada servicio que no se usa se apaga, y todo protocolo de control (OSPF, BGP, VRRP) se autentica para que ningún equipo no autorizado pueda inyectar rutas o tomar el gateway.

### 1.3.1 Usuarios y privilegios

| Usuario | Grupo | Permisos | Uso |
|---------|-------|----------|-----|
| `admin` | `full` | Total | Configuración. Password obligatoria, distinta de la de fábrica (vacía) |
| `monitor` | `monitor` (custom) | Solo lectura: `read`, `test`, `ssh`, `winbox` | Consultas de estado, verificación de drills, monitoreo |

Reglas:

- **Password de `admin`**: mínimo 12 caracteres. CHR viene con `admin` sin password, por eso es lo primero que se configura al levantar cada router.
- **`monitor` no puede** escribir config, reiniciar, cambiar passwords, ver datos sensibles (`!sensitive`) ni usar `ftp`, `telnet`, `web`, `api` o `sniff`.
- No se crean más usuarios con grupo `full`.

```routeros
/user set admin password=<ADMIN_PASS>
/user group add name=monitor policy=read,test,ssh,winbox,!local,!telnet,!ftp,!reboot,!write,!policy,!password,!web,!sniff,!sensitive,!api,!romon,!rest-api
/user add name=monitor group=monitor password=<MONITOR_PASS>
```

### 1.3.2 Servicios a deshabilitar

#### 1.3.2.1 Servicios de gestión (`/ip service`)

| Servicio | Puerto | Decisión | Motivo |
|----------|:------:|:--------:|--------|
| telnet | 23 | Apagar | Texto plano, credenciales visibles en la red |
| ftp | 21 | Apagar | Texto plano; no se usa |
| www | 80 | Apagar | WebFig sin cifrar; no se usa |
| www-ssl | 443 | Apagar | No se usa |
| api | 8728 | Apagar | No se usa |
| api-ssl | 8729 | Apagar | No se usa |
| ssh | 22 | Mantener | Gestión cifrada |
| winbox | 8291 | Mantener | Gestión GUI |

SSH y Winbox se restringen a redes internas en F3, con el firewall del EDGE.

```routeros
/ip service disable telnet,ftp,www,www-ssl,api,api-ssl
/ip ssh set strong-crypto=yes
```

#### 1.3.2.2 Otros servicios y descubrimiento

| Servicio | Decisión | Motivo |
|----------|:--------:|--------|
| Neighbor discovery (MNDP/CDP/LLDP) | Apagar | Revela identidad, modelo y versión a cualquier vecino |
| MAC-Telnet / MAC-Winbox | Apagar | Acceso de capa 2 que no pasa por el firewall IP |
| Bandwidth test server | Apagar | Se puede usar para saturar el router |
| DNS remoto | Apagar | Evita que el router sea resolver abierto |
| Proxy / SOCKS / UPnP | Apagar | No se usan |
| IP Cloud (DDNS) | Apagar | No se usa; hace conexiones salientes |
| SNMP | Apagado hasta F4 | Se habilita en F4 para monitoreo, solo lectura y con community propia (no `public`) |

```routeros
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

> ⚠️ Si alguien gestiona por **Winbox vía MAC** dentro de GNS3, apagar MAC-Winbox lo deja afuera. Conectarse por IP (Winbox o SSH) o por la consola de GNS3, que no se ve afectada.

### 1.3.3 Claves de autenticación del plano de control

#### 1.3.3.1 Resumen

| Protocolo | Mecanismo | Dónde | Alcance de la clave | Responsable |
|-----------|-----------|-------|---------------------|-------------|
| OSPF | MD5 (key-id 1) | EDGE, CORE-1, CORE-2, DIST-1, DIST-2 | Una clave para todo el área 0 | R3 (con R1 y R4) |
| BGP | TCP-MD5 (RFC 2385) | EDGE ↔ ISP-1, EDGE ↔ ISP-2 | Una clave **distinta por sesión** | R1 + R2 |
| VRRP | Simple (VRRPv2) | DIST-1 ↔ DIST-2 | Una clave **por grupo** (vrid 10 y vrid 20) | R4 |

Criterio:

- **OSPF**: una sola clave en el área es suficiente porque todos los routers pertenecen al mismo dominio administrativo.
- **BGP**: cada sesión es una relación con otra organización (cada ISP). Si la clave de un proveedor se filtra, la sesión con el otro sigue protegida.
- **VRRP**: una clave por grupo, para que un error de configuración en un grupo no afecte al otro.

#### 1.3.3.2 Convención de claves

| Clave | Identificador | Requisito |
|-------|---------------|-----------|
| `<OSPF_KEY>` | OSPF área 0 | Hasta 16 caracteres (límite de MD5 en OSPF) |
| `<BGP_KEY_ISP1>` | Sesión EDGE ↔ ISP-1 | ≥ 12 caracteres |
| `<BGP_KEY_ISP2>` | Sesión EDGE ↔ ISP-2 | ≥ 12 caracteres, distinta de la de ISP-1 |
| `<VRRP_KEY_10>` | VRRP vrid 10 (USERS) | **Máximo 8 caracteres** (límite de VRRPv2) |
| `<VRRP_KEY_20>` | VRRP vrid 20 (SERVERS) | Máximo 8 caracteres |

**Las claves reales no se commitean al repo.** En los `.rsc` y en la memoria se usan los placeholders de la tabla. Las claves reales se comparten por un canal privado del grupo y se le pasan al docente si las pide.

#### 1.3.3.3 Configuración de referencia

**OSPF MD5:** se aplica en el interface-template de cada router OSPF.

```routeros
/routing ospf interface-template set [find] auth=md5 auth-id=1 auth-key=<OSPF_KEY>
```

**BGP TCP-MD5:** en EDGE y en el ISP correspondiente, con la misma clave en ambos extremos.

```routeros
# EDGE
/routing bgp connection set [find name=to-isp1] tcp-md5-key=<BGP_KEY_ISP1>
/routing bgp connection set [find name=to-isp2] tcp-md5-key=<BGP_KEY_ISP2>
```

**VRRP auth:** en DIST-1 y DIST-2.

```routeros
/interface vrrp set [find vrid=10] version=2 authentication=simple password=<VRRP_KEY_10>
/interface vrrp set [find vrid=20] version=2 authentication=simple password=<VRRP_KEY_20>
```

> ⚠️ **VRRPv3 (RFC 5798), que es el default de RouterOS 7, no soporta autenticación.** El RFC la eliminó porque una clave simple viaja en texto plano y no aporta seguridad real. Para cumplir la consigna se usa **VRRPv2 (RFC 3768) con auth simple**. Conviene saberlo para la defensa: la auth simple de VRRP evita errores de configuración (un router mal configurado que se suma al grupo), pero no frena a un atacante que capture el tráfico.

### 1.3.4 Relación con backups

- `/export` en RouterOS 7 **oculta los datos sensibles por defecto**: passwords y claves no aparecen. Por eso los `/export` del directorio `backups/` se pueden versionar sin filtrar claves.
- Al restaurar desde un `/export` hay que **volver a cargar las claves** a mano.
- Los archivos binarios de `/system backup save` sí contienen las claves. Se generan **siempre con password** (`/system backup save password=<BACKUP_PASS>`) y solo entonces se versionan en `backups/`, según la política de operación (sección 1.4 de la memoria). Un `.backup` sin password no se commitea.
- `<BACKUP_PASS>` sigue la misma regla que las demás claves: no se commitea y se comparte por el canal privado del grupo.

### 1.3.5 Verificación (F1 y F4)

| Control | Cómo se verifica | Resultado esperado |
|---------|------------------|--------------------|
| Password admin | Login sin password | Rechazado |
| Usuario `monitor` | Login como `monitor` + `/system identity set name=x` | Lee config, **no** puede escribir |
| Servicios | `/ip service print` | Solo `ssh` y `winbox` habilitados |
| OSPF MD5 | Cambiar `auth-key` en un vecino | Adyacencia cae (no llega a FULL) |
| BGP TCP-MD5 | Cambiar `tcp-md5-key` en un extremo | Sesión no llega a established |
| VRRP auth | Cambiar `password` en DIST-2 | Los dos routers no se reconocen: ambos pasan a master (comportamiento a documentar) |

Las tres últimas son la **prueba obligatoria de clave incorrecta** del Epic F4 y se documentan con captura en la sección 5 de la memoria.

---

## 1.4 Política de operación

- **Formato del change log** (convención de commits): 
  se utilizará la convención "Conventional Commits" para el repositorio con la estructura: `tipo(alcance): descripción breve`. Los tipos permitidos estrictamente son: `feat` (nueva config/feature), `fix` (correcciones), `docs` (memoria/runbooks), `ops` (backups/change log), y `chore` (mantenimiento estructural). 
  Asimismo, en la sección 6.1 de esta memoria, el Change Log reflejará las intervenciones en los nodos detallando: Fecha, Rol responsable, Cambio realizado (nodo afectado y descripción), Motivo del cambio (commit asociado) y Cómo se revierte (procedimiento de rollback).

- **Política de backup** (cuándo y cómo): 
  - **Cuándo:** se tomará un backup inicial (Snapshot BASE) de todos los equipos en la Fase 1. Posteriormente, se realizarán backups al finalizar cada hito o antes de aplicar un cambio crítico.
  - **Qué y Cómo:** para cada router MikroTik CHR, se extraerá la configuración ejecutando los comandos `/export` (para tener la configuración legible) y `/system backup save` (para el binario completo).
  - **Dónde:** estos archivos serán versionados por fecha y almacenados en el repositorio del grupo dentro de la carpeta `backups/`.
  - **Restauración:** se documentará evidencia probando el *restore* del archivo `.backup` en un nodo para garantizar que la recuperación sea viable ante incidentes.
