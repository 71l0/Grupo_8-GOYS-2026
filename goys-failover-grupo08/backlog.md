# Backlog — GOYS Failover Routing

**Grupo:** `08`

**Regla:** "hecho" = criterio de aceptación cumplido. Si no pasa su criterio, sigue abierta.
Formato de tarea: `- [ ] descripción (Rol)`

| Epic | Vence | Estado |
|:----:|:-----:|:------:|
| F0 — Diseño y gestión de cambio | vie 2/10 | pendiente |
| F1 — Topología + hardening + backup | vie 9/10 | pendiente |
| F2 — VRRP + OSPF | vie 16/10 | pendiente |
| F3 — BGP + firewall | vie 16/10 | pendiente |
| F4 — Drills + monitoreo | mar 20/10 | pendiente |
| F5 — Memoria + defensa | vie 23/10 | pendiente |

---

## Epic F0 — Diseño y gestión de cambio · vence vie 2/10

> **Gate:** el docente debe aprobar F0 antes de tocar cualquier nodo.

### Feature: IPAM / direccionamiento
*Criterio: tabla completa (enlaces + LANs + VRRP + router-ids), sin solapamiento.*
- [ x ] Definir plan de direccionamiento de enlaces punto a punto (R1)
- [ x ] Definir LANs USERS/SERVERS, VIPs VRRP y gateways virtuales (R4)
- [ x ] Definir loopbacks / router-ids de los 7 routers y rangos de ISP (R3)
- [ x ] Revisar que no haya solapamientos y publicar la tabla en `docs/memoria.md` (R5)

### Feature: Corrección del diagrama
*Criterio: ≥ 3 defectos documentados, cada uno con corrección y justificación.*
- [ x ] Documentar defecto 1 (firewall sin HA) y defecto 5 (iBGP RR) (R1)
- [ x ] Documentar defectos 3 (core–core) y 4 (HSRP en core → VRRP en dist) (R3)
- [ x ] Documentar defecto 2 (solapamiento) y dibujar diagrama corregido en `docs/diagramas/` (R5)

### Feature: Política de seguridad
*Criterio: usuarios/privilegios, servicios a deshabilitar y claves de auth definidos.*
- [x] Definir usuarios y privilegios (admin, `monitor` read-only) (R2)
- [x] Listar servicios a deshabilitar en los 7 routers (R1)
- [x] Definir esquema de claves OSPF MD5, BGP TCP-MD5 y VRRP auth (R3/R4)
- [x] Redactar la política en `docs/memoria.md` (R5)

### Feature: Política de operación
*Criterio: formato de change log + política de backup definidos.*
- [ x ] Definir formato del change log (fecha, rol, nodo, cambio, commit, rollback) (R5)
- [ x ] Definir política de backup (cuándo, qué, dónde, cómo se prueba la restauración) (R5)

### Feature: Repositorio git
*Criterio: estructura creada (README + backlog.md + carpetas) + commits iniciales.*
- [ x ] Crear repo (fork o nuevo) y dar acceso al docente (R5)
- [ x ] Crear estructura de carpetas, README.md y backlog.md (R5)
- [ x ] Primer commit de cada integrante (trazabilidad por autor) (R1–R5)

---

## Epic F1 — Topología + hardening + backup · vence vie 9/10

### Feature: Despliegue
*Criterio: 7 CHR + 2 switches + 2 hosts levantados y cableados según el diagrama.*
- [ ] Importar proyecto GNS3 `topologia_failover_routing` en todas las laptops (R5)
- [ ] Verificar cableado de los 15 enlaces contra el diagrama (R1)
- [ ] Levantar nodos y confirmar acceso por consola (R5)

### Feature: IPs de enlace + loopbacks
*Criterio: ping entre vecinos directos OK.*
- [ ] Configurar IPs de enlace y loopback en EDGE, ISP-1, ISP-2 (R1/R2)
- [ ] Configurar IPs de enlace y loopback en CORE-1, CORE-2 (R3)
- [ ] Configurar IPs de enlace, LANs y loopback en DIST-1, DIST-2 (R4)
- [ ] Verificar ping entre vecinos directos y capturar evidencia (R5)

### Feature: Snapshot BASE
*Criterio: tomado y documentado.*
- [ ] Tomar snapshot BASE de todos los nodos (R5)
- [ ] Documentar el snapshot en el change log (R5)

### Feature: Hardening
*Criterio: password admin + usuario `monitor` + servicios apagados en los 7 routers.*
- [ ] Hardening de EDGE (R1)
- [ ] Hardening de ISP-1 e ISP-2 (R2)
- [ ] Hardening de CORE-1 y CORE-2 (R3)
- [ ] Hardening de DIST-1 y DIST-2 (R4)

### Feature: Backup inicial
*Criterio: `/export` de cada router versionado en el repo.*
- [ ] Exportar `/export` de los 7 routers a `backups/` (cada rol el suyo)
- [ ] Commit `ops(backup): backup post-F1` y registro en change log (R5)

---

## Epic F2 — VRRP + OSPF · vence vie 16/10

### Feature: VRRP
*Criterio: 2 grupos (10/20) operativos con load-sharing (DIST-1 master 10, DIST-2 master 20), con auth.*
- [ ] Configurar VRRP vrid 10 en DIST-1 (master) y DIST-2 (backup) (R4)
- [ ] Configurar VRRP vrid 20 en DIST-2 (master) y DIST-1 (backup) (R4)
- [ ] Activar auth en ambos grupos (R4)
- [ ] Verificar master/backup con `/interface vrrp print` (R5)

### Feature: OSPF área 0
*Criterio: adyacencias FULL edge↔core↔dist (incluido core–core), con MD5.*
- [ ] Configurar OSPF en CORE-1 y CORE-2, incluido el enlace core–core (R3)
- [ ] Configurar OSPF en DIST-1 y DIST-2 (R4)
- [ ] Configurar OSPF en EDGE hacia el core (R1)
- [ ] Activar MD5 en todas las interfaces OSPF (R3)
- [ ] Verificar adyacencias FULL con `/routing ospf neighbor print` (R5)

### Feature: Verificación L3
*Criterio: ping intra-LAN + gateway virtual responde.*
- [ ] Ping host ↔ gateway virtual en ambas LANs (R5)
- [ ] Ping entre hosts de distintas LANs (R5)
- [ ] Backup post-F2 y registro en change log (R5)

---

## Epic F3 — BGP + firewall · vence vie 16/10

### Feature: eBGP multi-homing
*Criterio: 2 sesiones established (EDGE↔ISP-1, EDGE↔ISP-2), con TCP-MD5.*
- [ ] Configurar eBGP en EDGE hacia ISP-1 y ISP-2 con TCP-MD5 (R1)
- [ ] Configurar eBGP en ISP-1 e ISP-2 con TCP-MD5 y default-originate (R2)
- [ ] Verificar ambas sesiones en estado established (R5)

### Feature: Redistribución
*Criterio: OSPF→BGP, las LANs se anuncian a los ISP.*
- [ ] Redistribuir OSPF→BGP en EDGE con filtros (R1)
- [ ] Verificar que las LANs aparecen en la tabla de ISP-1 e ISP-2 (R2)

### Feature: Salida a "Internet"
*Criterio: host alcanza el loopback del ISP.*
- [ ] Verificar default route recibida por EDGE y propagada por OSPF (R1/R3)
- [ ] Ping desde un host al loopback de cada ISP (R5)

### Feature: Firewall edge
*Criterio: filtro de entrada + plano de gestión protegido.*
- [ ] Reglas de entrada (input/forward) en EDGE, con `established,related` y drop por defecto (R1)
- [ ] Restringir acceso de gestión (SSH/Winbox) a origen permitido (R1)
- [ ] Probar reglas y capturar evidencia (R5)

---

## Epic F4 — Drills + monitoreo · vence mar 20/10

> **Rotación R1 ↔ R2 en esta fase.**

### Feature: 5 drills de failover
*Criterio: cada uno con runbook (detección→respuesta→recuperación) + post-mortem + tiempo medido.*
> Confirmar con la guía `laboratorio-failover-routing.md` cuáles son los 5 drills. Propuesta de partida:
- [ ] Drill 1 — Caída del master VRRP (R4 ejecuta, R5 mide)
- [ ] Drill 2 — Caída de un enlace dist–core (R3 ejecuta, R5 mide)
- [ ] Drill 3 — Caída de un nodo CORE / enlace core–core (R3 ejecuta, R5 mide)
- [ ] Drill 4 — Caída de un ISP (R1 ejecuta, R5 mide)
- [ ] Drill 5 — Falla combinada o del segundo ISP (R2 ejecuta, R5 mide)
- [ ] Escribir un runbook por drill en `runbooks/` (R5)
- [ ] Escribir post-mortem y tiempos medidos de cada drill en `docs/memoria.md` (R5)
- [ ] Capturas organizadas por drill en `capturas/` (R5)

### Feature: Monitoreo
*Criterio: SNMP/chequeos habilitados y documentados.*
- [ ] Habilitar SNMP (v3 si es posible) con usuario de solo lectura en los 7 routers (R1–R4)
- [ ] Definir y documentar chequeos (vecinos OSPF, sesiones BGP, estado VRRP) (R5)

### Feature: Verificación de seguridad
*Criterio: adyacencia/sesión con clave incorrecta FALLA (documentado).*
- [ ] Probar OSPF con clave MD5 incorrecta y capturar evidencia (R3)
- [ ] Probar BGP con clave TCP-MD5 incorrecta y capturar evidencia (R1/R2)
- [ ] Probar VRRP con auth incorrecta y capturar evidencia (R4)
- [ ] Documentar resultados en la memoria (R5)

---

## Epic F5 — Memoria + defensa · vence vie 23/10

### Feature: Memoria
*Criterio: plantilla de documentación completa (todas las secciones).*
- [ ] Completar secciones de diseño, IPAM y políticas (R1)
- [ ] Completar sección de proveedores / BGP (R2)
- [ ] Completar sección de core / OSPF (R3)
- [ ] Completar sección de distribución / VRRP (R4)
- [ ] Consolidar change log (coincidente con commits), drills y revisión final (R5)

### Feature: Backlog cerrado
*Criterio: todas las tareas en "done".*
- [ ] Revisar todo el backlog contra criterios de aceptación (R5)
- [ ] Backup final en `backups/` y configs finales `.rsc` en `configs/` (R1–R5)

### Feature: Defensa oral
*Criterio: cada integrante explica su parte y una parte ajena.*
- [ ] Armar guía de defensa por rol (R1–R5)
- [ ] Ensayo cruzado: cada uno explica la parte de otro rol (R1–R5)
