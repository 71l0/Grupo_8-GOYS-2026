# Topología corregida

Así queda la red después de aplicar las correcciones. Las direcciones IP no van acá, están en el IPAM.

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
[ ACCESS ]           SW-USERS                       SW-SERVERS
                         |                               |
                      PC-USER                           SRV
```

Las líneas cruzadas son:
- Entre core y distribución: cada DIST está conectado a los dos core (DIST-1 a CORE-2 y DIST-2 a CORE-1).
- Entre distribución y acceso: cada DIST está conectado a los dos switches, porque VRRP necesita que los dos routers estén en la misma LAN.

## Enlaces

| # | Enlace | Capa |
|:-:|--------|------|
| 1 | ISP-1 ↔ EDGE | Internet / Edge |
| 2 | ISP-2 ↔ EDGE | Internet / Edge |
| 3 | EDGE ↔ CORE-1 | Edge / Core |
| 4 | EDGE ↔ CORE-2 | Edge / Core |
| 5 | CORE-1 ↔ CORE-2 | Core (el que faltaba) |
| 6 | CORE-1 ↔ DIST-1 | Core / Distribución |
| 7 | CORE-2 ↔ DIST-1 | Core / Distribución |
| 8 | CORE-1 ↔ DIST-2 | Core / Distribución |
| 9 | CORE-2 ↔ DIST-2 | Core / Distribución |
| 10 | DIST-1 ↔ SW-USERS | Distribución / Acceso |
| 11 | DIST-2 ↔ SW-USERS | Distribución / Acceso |
| 12 | DIST-1 ↔ SW-SERVERS | Distribución / Acceso |
| 13 | DIST-2 ↔ SW-SERVERS | Distribución / Acceso |
| 14 | SW-USERS ↔ PC-USER | Acceso |
| 15 | SW-SERVERS ↔ SRV | Acceso |

En total son 11 nodos (7 routers, 2 switches y 2 hosts) y 15 enlaces, lo mismo que dice la consigna. En F1 lo comparamos con el proyecto de GNS3.

## Qué cambió con respecto al original

| Original | Corregido |
|----------|-----------|
| Un solo ASA como firewall | Filtrado en EDGE; en producción, dos firewalls en failover |
| Redes repetidas entre sitios | Cada red es única (ver IPAM) |
| C1 y C2 sin enlace entre sí | Enlace CORE-1 ↔ CORE-2 |
| HSRP en el core | VRRP en DIST-1 / DIST-2, el core solo rutea |
| iBGP con route reflector a través del ASA | eBGP solo en EDGE, sin RR, OSPF adentro |
