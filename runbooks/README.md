# Runbooks operativos

## Propósito

Esta carpeta contiene procedimientos operativos reproducibles para ejecutar, verificar y recuperar los escenarios de failover del laboratorio.

## Estado

`drill_F0.md`, `drill_F1.md`, `drill_F2.md` y `drill_F3.md` cerrados y ejecutados (un runbook por fase, con su evidencia en `capturas/`). La prueba de restore del F1 quedó registrada en `docs/memoria.md` §2.5.1.

**F4 — un runbook por drill de failover, con la estructura detección → respuesta → recuperación, post-mortem y tiempo medido:**

| Drill | Runbook | Resultado |
|:-----:|---------|-----------|
| 1 | `drill_F4-CaidaMasterVRRP.md` | Failover VRRP: 1 paquete perdido (≈1 s) |
| 2 | `drill_F4-CaidaEnlaceDIST-CORE.md` | Enlace DIST–CORE: 0 % de pérdida (ECMP) |
| 3 | `drill_F4-CaidaEnlaceCORE-CORE.md` | Enlace core–core: 0 % de pérdida |
| 4 | `drill_F4-CaidaDeISP-1.md` | Caída ISP-1: salida por ISP-2, 6 % de pérdida |
| 5 | `drill_F4-FallaCombinada.md` | Doble falla: salida sobrevive, 24 % acotado |

Consolidado de los drills (tabla resumen + post-mortems) en `docs/memoria.md` §7; monitoreo SNMP en §8.