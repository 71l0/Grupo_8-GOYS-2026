# Grupo 8 — Failover Routing: la red que no se cae

Repositorio del **Grupo 8** de la materia **Gestión Operativa y Seguridad en Redes (GOYS) 2026** — UTN FR La Plata. El laboratorio **Failover Routing** vive en la raíz del repo (decisión tomada para evaluar el repositorio como una unidad); el warm-up de VRRP queda en [`goys-vrrp-grupo08/`](goys-vrrp-grupo08).

---

## 📌 Información general

| Campo | Descripción |
|---|---|
| **Materia** | Gestión Operativa y Seguridad en Redes (GOYS) |
| **Año académico** | 2026 |
| **Grupo** | 8 · Comisión S51 |
| **Repositorio** | `Grupo_8-GOYS-2026` |
| **Simulador** | GNS3 · MikroTik CHR (RouterOS 7) |
| **Vencimiento final** | viernes 23 de octubre de 2026 |

---

## 👥 Integrantes y roles

**Dueño único por rol** (rotación obligatoria R1 ↔ R2 en F4):

| Integrante | Legajo | Rol principal | Rol de respaldo |
|------------|:------:|---------------|-----------------|
| **Ulises Mateo Bucchino** | 33326 | **R1 — Líder / Edge-WAN** | R3 — Core |
| **Jano Stratakis** | 30765 | **R2 — Proveedores** | R3 — Core |
| **Valentín Garzaniti** | 32547 | **R4 — Distribución** | R2 — Proveedores |
| **Sofía Belén Raggi** | 31532 | **R5 — Hosts / QA / Operación** | R4 — Distribución |

| Rol | Responsabilidad principal |
|-----|---------------------------|
| **R1 — Líder / Edge-WAN** | EDGE: eBGP ×2, redistribución, BGP MD5, firewall |
| **R2 — Proveedores** | ISP-1/ISP-2: default-originate, eBGP, hardening |
| **R3 — Core** | CORE-1/CORE-2: OSPF, enlace core–core, OSPF MD5 |
| **R4 — Distribución** | DIST-1/DIST-2: VRRP (auth), OSPF, gateways |
| **R5 — Hosts / QA / Ops** | Hosts, ejecuta los drills, dueño del backlog + change log + backups + runbooks |

---

## 🎯 Objetivo del repositorio

Centralizar, documentar y versionar el diseño, la implementación, la **operación** y el **aseguramiento** del laboratorio de failover routing, con evidencia verificable (capturas, backups y change log) y trazabilidad por autor en el historial de git.

---

## 📚 Actividades

| Actividad / Proyecto | Descripción | Estado |
|---|---|---|
| [Failover Routing (raíz)](.) | Failover Routing: la red que no se cae | En progreso (F0–F3 hechas) |
| [`goys-vrrp-grupo08/`](goys-vrrp-grupo08) | Laboratorio VRRP — Redundancia de primer salto | Completado |
| `goys-proyecto_integrador-grupo08` | Proyecto Integrador + Feria de Redes | Pendiente |

---

## 🌐 Resumen del laboratorio

Diseño, implementación, **operación** y **aseguramiento** de una red empresarial jerárquica de 5 capas con:

- **Redundancia de primer salto:** VRRP (2 grupos, 10 y 20, con load-sharing).
- **Redundancia de IGP:** OSPF área 0 con autenticación MD5.
- **Redundancia de proveedor:** eBGP multi-homing (AS 65000 ↔ AS 65001 / AS 65002) con TCP-MD5.

La red debe sobrevivir a fallas de enlace y de nodo. No alcanza con que ande: tiene que estar **bien diseñada, bien operada y bien asegurada**.

### Topología (5 capas)

```
[ INTERNET ]       ISP-1 (AS 65001)      ISP-2 (AS 65002)      eBGP
[ EDGE ]                 EDGE (AS 65000)                       eBGP multi-homing + OSPF
[ CORE ]           CORE-1 ─── core-core ─── CORE-2             OSPF área 0 (tránsito puro)
[ DISTRIBUTION ]     DIST-1               DIST-2               VRRP (FHRP) + OSPF
[ ACCESS ]         switch + hosts       switch + hosts         USERS / SERVERS
```

**11 nodos · 15 enlaces · 7 routers CHR.** Proyecto GNS3: `topologia_failover_routing`.

### Defectos del diagrama original y su corrección

| # | Defecto | Corrección |
|:-:|---------|------------|
| 1 | Firewall sin par HA (SPOF) | Se documenta por qué en producción van dos en failover |
| 2 | Subredes solapadas entre sitios | Direccionamiento limpio, sin overlap (IPAM en F0) |
| 3 | Sin enlace core–core | Se agrega CORE-1 ↔ CORE-2 |
| 4 | HSRP en el core (collapsed) | VRRP en distribución; core = tránsito puro |
| 5 | iBGP RR mal ubicado | eBGP correcto en el edge, sin RR |

---

## 📅 Cronograma

| Epic | Contenido | Vence | Estado |
|:----:|-----------|:-----:|:------:|
| F0 | Diseño + políticas + repo | vie 2/10 | Completada |
| F1 | Topología + hardening + backup | vie 9/10 | Completada |
| F2 | VRRP + OSPF | vie 16/10 | Completada |
| F3 | BGP + firewall | vie 16/10 | Completada |
| F4 | Drills + monitoreo | mar 20/10 | Pendiente |
| F5 | Memoria + defensa | vie 23/10 | Pendiente |

> **Regla de oro:** F0 antes que cualquier CLI. Sin aprobación del docente no se toca un nodo.

---

## 🗂️ Estructura del repositorio

```
Grupo_8-GOYS-2026/            # raíz = laboratorio failover
├── README.md                 # este archivo
├── backlog.md                # tareas con estado
├── docs/
│   ├── memoria.md            # plantilla de documentación completada
│   └── diagramas/            # topología y diagramas de diseño
├── configs/                  # .rsc finales por router
├── backups/                  # /export de cada router (por fecha)
├── runbooks/                 # un .md por drill / fase
├── capturas/                 # screenshots organizados por fase
└── goys-vrrp-grupo08/        # laboratorio VRRP (warm-up)
```

---

## 🛠️ Convenciones de trabajo

### Commits (Conventional Commits)

```
tipo(alcance): descripción breve
```

| Tipo | Uso |
|------|-----|
| `feat` | Algo nuevo (config, feature) |
| `fix` | Corrección de algo roto |
| `docs` | Memoria, diagramas, runbooks |
| `ops` | Backup, change log |
| `chore` | Estructura, .gitignore |

### Reglas

- Un commit por cambio lógico (nada de commits "todo junto").
- Cada rol commitea su parte (trazabilidad por autor) **con un único email por persona**.
- `main` siempre funciona: lo roto se arregla antes de mergear.
- El change log de la memoria (sección 6.1) debe reflejar los commits del repo.
- **No commitear claves reales:** en `configs/` y `backups/` usar placeholders o sanitizar secretos antes de subir (a confirmar con el docente).
- "Done" = criterio de aceptación cumplido, no "más o menos".

---

## 🔗 Enlaces

- Backlog: [`backlog.md`](backlog.md)
- Memoria: [`docs/memoria.md`](docs/memoria.md)
- Diagramas: [`docs/diagramas/`](docs/diagramas/)
- Runbooks: [`runbooks/`](runbooks/)
- Backups: [`backups/`](backups/)
- Capturas: [`capturas/`](capturas/)
- Configs finales: [`configs/`](configs/)

---

## 📊 Rúbrica (sobre 100)

| Criterio | Peso |
|----------|:----:|
| Funcionalidad técnica (redes + failover) | 30% |
| Seguridad en redes | 20% |
| Gestión operativa | 20% |
| Corrección del diseño + conceptos | 15% |
| Defensa oral | 15% |

---

**Grupo 8 — GOYS 2026**
*Gestión Operativa y Seguridad en Redes · Repositorio académico del laboratorio Failover Routing.*