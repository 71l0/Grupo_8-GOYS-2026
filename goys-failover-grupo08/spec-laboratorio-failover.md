# Consigna — Laboratorio Grupal: "Failover Routing — la red que no se cae"

**Materia:** Gestión Operativa y Seguridad en Redes (GOYS) — UTN FR La Plata
**Modalidad:** Grupal (5 integrantes) · trabajo asincrónico en sus laptops (GNS3)
**Simulador:** GNS3 · MikroTik CHR (RouterOS 7)
**🗓️ Vencimiento final: viernes 23 de octubre de 2026**

> **Regla de oro:** primero el diseño, después el CLI. En F0 entregan el plan y recién con la aprobación del docente tocan un nodo. **No alcanza con que ande: tiene que estar bien diseñado, bien operado y bien asegurado.**

---

## 1. Objetivo

Diseñar, implementar, **operar** y **asegurar** una red empresarial jerárquica de 5 capas con redundancia de primer salto (VRRP), de IGP (OSPF) y de proveedor (BGP multi-homing), capaz de sobrevivir a fallas de enlace y de nodo.

## 2. Contexto: el diagrama a corregir

En clase analizamos el diagrama viral "Enterprise Network Design (Cisco)". Tiene **5 defectos** que este lab corrige:

| # | Defecto del original | Corrección en el lab |
|:-:|----------------------|----------------------|
| 1 | Firewall sin par HA (SPOF) | Se documenta por qué en producción van dos en failover |
| 2 | Subredes solapadas entre sitios | Direccionamiento limpio y sin overlap (obligatorio en F0) |
| 3 | **Sin enlace core–core** | **Lo agregamos** (CORE-1↔CORE-2) |
| 4 | **HSRP en el core** (diseño "collapsed") | **Lo movemos a distribución** (VRRP), core = tránsito puro |
| 5 | iBGP RR mal ubicado | eBGP correcto en el edge, sin RR |

## 3. Competencias evaluadas

| Dimensión | Qué se evalúa |
|-----------|---------------|
| **Redes** | Topología de 5 capas, VRRP + OSPF + BGP, y las 5 experiencias de failover |
| **Seguridad** | Hardening, autenticación del plano de control (OSPF MD5, BGP TCP-MD5, VRRP auth), firewall/ACL |
| **Operación** | Gestión de cambios (change log + git), backup probado, monitoreo, runbooks y drills de incidente |

## 4. Topología (5 capas)

```
[ INTERNET ]     ISP-1 (AS 65001)      ISP-2 (AS 65002)      eBGP
[ EDGE ]              EDGE (AS 65000)                        eBGP multi-homing + OSPF
[ CORE ]         CORE-1 ─── core-core ─── CORE-2             OSPF área 0 (tránsito puro)
[ DISTRIBUTION ]   DIST-1               DIST-2               VRRP (FHRP) + OSPF
[ ACCESS ]       switch + hosts        switch + hosts        USERS / SERVERS
```

**11 nodos · 15 enlaces · 7 routers CHR.** (Proyecto GNS3 provisto: `topologia_failover_routing`.)

## 5. Roles (5 integrantes)

| Rol | Responsabilidad principal |
|-----|---------------------------|
| **R1 — Líder / Edge-WAN** | EDGE: eBGP ×2, redistribución, BGP MD5, firewall |
| **R2 — Proveedores** | ISP-1/ISP-2: default-originate, eBGP, hardening |
| **R3 — Core** | CORE-1/CORE-2: OSPF, core–core, OSPF MD5 |
| **R4 — Distribución** | DIST-1/DIST-2: VRRP (auth), OSPF, gateways |
| **R5 — Hosts / QA / Ops** | Hosts, ejecuta los drills, **dueño del backlog + change log + backups + runbooks** |

> Cada rol opera y asegura su parte. Rotación obligatoria en la fase 4 (R1↔R2).

---

## 6. Backlog del laboratorio (epics)

> Esto es el **qué**. Ustedes lo convierten en su **backlog** (el *cómo*): rompen cada *feature* en tareas accionables y las trackean. Ver sección 7.

### Epic F0 — Diseño y gestión de cambio · *vence vie 2/10*

| Feature | Criterio de aceptación |
|---------|------------------------|
| IPAM / direccionamiento | Tabla completa (enlaces + LANs + VRRP + router-ids), **sin solapamiento** |
| Corrección del diagrama | ≥ 3 defectos documentados, cada uno con su corrección y justificación |
| Política de seguridad | Usuarios/privilegios, servicios a deshabilitar y claves de auth definidos |
| Política de operación | Formato de change log + política de backup definidos |
| Repositorio git | Estructura creada (README + backlog.md + carpetas) + commits iniciales |

### Epic F1 — Topología + hardening + backup · *vence vie 9/10*

| Feature | Criterio de aceptación |
|---------|------------------------|
| Despliegue | 7 CHR + 2 switches + 2 hosts levantados y cableados según el diagrama |
| IPs de enlace + loopbacks | Ping entre vecinos directos OK |
| Snapshot BASE | Tomado y documentado |
| Hardening | Password admin + usuario `monitor` + servicios apagados en los 7 routers |
| Backup inicial | `/export` de cada router versionado en el repo |

### Epic F2 — VRRP + OSPF · *vence vie 16/10*

| Feature | Criterio de aceptación |
|---------|------------------------|
| VRRP | 2 grupos (10/20) operativos con load-sharing (DIST-1 master 10, DIST-2 master 20), **con auth** |
| OSPF área 0 | Adyacencias FULL edge↔core↔dist (incluido core–core), **con MD5** |
| Verificación L3 | Ping intra-LAN + gateway virtual responde |

### Epic F3 — BGP + firewall · *vence vie 16/10*

| Feature | Criterio de aceptación |
|---------|------------------------|
| eBGP multi-homing | 2 sesiones established (EDGE↔ISP-1, EDGE↔ISP-2), **con TCP-MD5** |
| Redistribución | OSPF→BGP: las LANs se anuncian a los ISP |
| Salida a "Internet" | Host alcanza el loopback del ISP |
| Firewall edge | Filtro de entrada + plano de gestión protegido |

### Epic F4 — Drills + monitoreo · *vence mar 20/10*

| Feature | Criterio de aceptación |
|---------|------------------------|
| 5 drills de failover | Cada uno con runbook (detección→respuesta→recuperación) + post-mortem + tiempo medido |
| Monitoreo | SNMP/chequeos habilitados y documentados |
| Verificación de seguridad | Adyacencia/sesión con clave incorrecta **FALLA** (documentado) |

### Epic F5 — Memoria + defensa · *vence vie 23/10*

| Feature | Criterio de aceptación |
|---------|------------------------|
| Memoria | Plantilla de documentación completa (todas las secciones) |
| Backlog cerrado | Todas las tareas en "done" |
| Defensa oral | Cada integrante explica su parte **y** una parte ajena |

---

## 7. Cómo armar tu propio backlog

1. **Epic** = objetivo (F0–F5 de arriba). Son 6 epics, uno por fase.
2. **Feature** = entregable con criterio de aceptación (las filas de las tablas).
3. **Tarea** = paso accionable. Rompan cada feature en **2–4 tareas** con un dueño (rol).

**Ejemplo** — la feature "VRRP" (Epic F2) se rompe en:
- `[R4] configurar VRRP vrid 10 en DIST-1 (master)`
- `[R4] configurar VRRP vrid 20 en DIST-2 (master)`
- `[R5] verificar master/backup con /interface vrrp print`
- `[R4] activar auth simple en ambos grupos`

4. **Tracking:** mantengan `backlog.md` en el repo con el estado de cada tarea:

```markdown
## Epic F2 — VRRP + OSPF
- [x] configurar VRRP vrid 10 en DIST-1 (R4)
- [ ] configurar VRRP vrid 20 en DIST-2 (R4)
- [ ] verificar master/backup (R5)
```

> Regla: **"done" = criterio de aceptación cumplido**, no "más o menos". Si una tarea no pasa su criterio, sigue abierta.

---

## 8. Cronograma

| Epic | Contenido | Vence |
|:----:|-----------|:-----:|
| F0 | Diseño + políticas + repo | **vie 2/10** |
| F1 | Topología + hardening + backup | **vie 9/10** |
| F2 | VRRP + OSPF | **vie 16/10** |
| F3 | BGP + firewall | **vie 16/10** |
| F4 | Drills + monitoreo | **mar 20/10** |
| F5 | Memoria + defensa | **vie 23/10** |

---

## 9. Formato de entrega — repositorio git del grupo

### 9.1 Estructura del repositorio

```
goys-failover-<grupo>/
├── README.md          # integrantes, roles, resumen del lab
├── backlog.md         # backlog: tareas con estado (pendiente / en curso / hecho)
├── docs/
│   ├── memoria.md     # la plantilla de documentación completada
│   └── diagramas/     # topología, diagramas de diseño
├── configs/           # .rsc finales por router
├── backups/           # /export de cada router (por fecha)
├── runbooks/          # un .md por drill
└── capturas/          # screenshots organizados por drill
```

### 9.2 Convención de commits (Conventional Commits)

```
tipo(alcance): descripción breve
```

| Tipo | Cuándo se usa |
|------|---------------|
| `feat` | Agregan algo nuevo (una config, una feature) |
| `fix` | Corrigen algo roto |
| `docs` | Documentación (memoria, diagramas, runbooks) |
| `ops` | Operación (backup, change log) |
| `chore` | Mantenimiento (estructura, .gitignore) |

**Ejemplos:**
```
feat(configs): agrego VRRP vrid10 en DIST-1
fix(ospf): corrijo auth-key en CORE-2
docs(memoria): completo drill 1 — VRRP
ops(backup): backup post-F2
```

### 9.3 Reglas

- **Un commit por cambio lógico.** Nada de commits "todo junto".
- **Cada rol commitea su parte** (trazabilidad por autor en el historial).
- **`main` siempre funciona:** los cambios rotos se arreglan antes de mergear.
- El **change log** de la memoria (sección 6.1) debe **reflejar los commits** del repo.
- Repo visible para el docente (fork del repo base o repo nuevo del grupo, a definir en clase).

---

## 10. Rúbrica (sobre 100)

| Criterio | Peso |
|----------|:----:|
| Funcionalidad técnica (redes + failover) | 30% |
| Seguridad en redes | 20% |
| Gestión operativa | 20% |
| Corrección del diseño + conceptos | 15% |
| Defensa oral (saber) | 15% |

---

## 11. Recursos

- **Guía de referencia** (configs, gotchas, recursos): `laboratorio-failover-routing.md`
- **Lab VRRP** (warm-up): `laboratorio-vrrp.md`
- **Presentación** (teoría + "Profundizar"): `presentacion-failover-routing.html`
- **Plantilla de documentación**: `template-documentacion-failover.md`
- **Plantilla de backlog**: `template-backlog.md` (copiar a `backlog.md` en el repo del grupo)
- **Lecturas/videos**: Halabi, Doyle & Carroll, Stallings, Google SRE Book; RFC 5798, 2328, 4271, 2385, 5925, 5709; videos VRRP/HSRP (NetWorks, Arawi).

---

## 12. Regla de oro

> **F0 antes que cualquier CLI.** Antes de encender un nodo: tabla de direccionamiento + política de seguridad + formato del change log. El docente aprueba; sin eso, no se toca un nodo.
