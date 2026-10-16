# GOYS — Failover Routing: la red que no se cae

- **Materia:** Gestión Operativa y Seguridad en Redes (GOYS) — UTN FR La Plata	
- **Grupo:** `08`
- **Simulador:** GNS3 · MikroTik CHR (RouterOS 7)
- **Vencimiento final:** viernes 23 de octubre de 2026

---

## Integrantes y roles

| Integrante | Rol |
|-----------|-----|
| **Todos los miembros del grupo** | R1 — Líder / Edge-WAN |
| Jano Stratakis | R2 — Proveedores |
| Ulises Mateo Bucchino | R3 — Core |
| Valentín Garzaniti | R4 — Distribución |
| Sofia Raggi | R5 — Hosts / QA / Operación |

---

## Resumen del laboratorio

Diseño, implementación, **operación** y **aseguramiento** de una red empresarial jerárquica de 5 capas con:

- **Redundancia de primer salto:** VRRP (2 grupos, 10 y 20, con load-sharing).
- **Redundancia de IGP:** OSPF área 0 con autenticación MD5.
- **Redundancia de proveedor:** eBGP multi-homing (AS 65000 ↔ AS 65001 / AS 65002) con TCP-MD5.

La red debe sobrevivir a fallas de enlace y de nodo. No alcanza con que ande: tiene que estar **bien diseñado, bien operado y bien asegurado**.

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

## Cronograma

| Epic | Contenido | Vence |
|:----:|-----------|:-----:|
| F0 | Diseño + políticas + repo | vie 2/10 |
| F1 | Topología + hardening + backup | vie 9/10 |
| F2 | VRRP + OSPF | vie 16/10 |
| F3 | BGP + firewall | vie 16/10 |
| F4 | Drills + monitoreo | mar 20/10 |
| F5 | Memoria + defensa | vie 23/10 |

> **Regla de oro:** F0 antes que cualquier CLI. Sin aprobación del docente no se toca un nodo.

---

## Estructura del repositorio

```
goys-failover-<grupo>/
├── README.md          # este archivo
├── backlog.md         # tareas con estado
├── docs/
│   ├── memoria.md     # plantilla de documentación completada
│   └── diagramas/     # topología y diagramas de diseño
├── configs/           # .rsc finales por router
├── backups/           # /export de cada router (por fecha)
├── runbooks/          # un .md por drill
└── capturas/          # screenshots organizados por drill
```

---

## Convenciones de trabajo

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

Ejemplos:

```
feat(configs): agrego VRRP vrid10 en DIST-1
fix(ospf): corrijo auth-key en CORE-2
docs(memoria): completo drill 1 — VRRP
ops(backup): backup post-F2
```

### Reglas

- Un commit por cambio lógico (nada de commits "todo junto").
- Cada rol commitea su parte (trazabilidad por autor).
- `main` siempre funciona: lo roto se arregla antes de mergear.
- El change log de la memoria (sección 6.1) debe reflejar los commits del repo.
- **No commitear claves reales:** en `configs/` y `backups/` usar placeholders o sanitizar secretos antes de subir (a confirmar con el docente).
- "Done" = criterio de aceptación cumplido, no "más o menos".

---

## Enlaces

- Backlog: [`backlog.md`](backlog.md)
- Memoria: [`docs/memoria.md`](docs/memoria.md)
- Diagramas: [`docs/diagramas/`](docs/diagramas/)
- Runbooks: [`runbooks/`](runbooks/)

## Rúbrica (sobre 100)

| Criterio | Peso |
|----------|:----:|
| Funcionalidad técnica (redes + failover) | 30% |
| Seguridad en redes | 20% |
| Gestión operativa | 20% |
| Corrección del diseño + conceptos | 15% |
| Defensa oral | 15% |
