# Configuraciones de red

## Propósito

Esta carpeta almacena las configuraciones de los dispositivos que forman parte de la topología de failover del grupo 08.

## Estado

Se cargaron las configuraciones finales de F3 (los 7 routers), tomadas del respaldo `backups/2026-10-11_F3_BASE/`. `/export` no incluye claves: OSPF MD5, BGP TCP-MD5 y VRRP auth se cargan por separado (política en `docs/memoria.md`, sección 1.3.4).

| Router | Archivo |
|--------|---------|
| EDGE | `edge.rsc` |
| ISP-1 | `isp1.rsc` |
| ISP-2 | `isp2.rsc` |
| CORE-1 | `core1.rsc` |
| CORE-2 | `core2.rsc` |
| DIST-1 | `dist1.rsc` |
| DIST-2 | `dist2.rsc` |