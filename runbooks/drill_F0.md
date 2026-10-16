# Runbook F0 — Diseño y gestión de cambio

| Campo | Valor |
|-------|-------|
| **Épica** | F0 — Diseño y gestión de cambio |
| **Vence** | viernes 2/10 |
| **Tipo** | Procedimiento de diseño y control de cambios |
| **Roles** | R1 (líder/Edge-WAN), R2 (proveedores), R3 (core), R4 (distribución), R5 (hosts/QA/operación) |
| **Estado** | cerrado (documentado en [`docs/memoria.md`](../docs/memoria.md)) |
| **Gate** | ⚠️ El docente debe **aprobar F0 antes de tocar cualquier nodo**. Sin aprobación no se ejecuta ningún cambio en el laboratorio. |

---

## 1. Objetivo

Definir y dejar documentado el **diseño de referencia** de la red y las **políticas** que gobiernan su operación, de modo que las fases de implementación (F1 en adelante) sean reproducibles, auditables y reversibles.

**Criterio de aceptación (del backlog):**
- IPAM completo y sin solapamiento.
- ≥ 3 defectos del diagrama original documentados, cada uno con corrección y justificación.
- Política de seguridad (usuarios, servicios, claves) definida.
- Política de operación (change log + backup) definida.
- Estructura del repo git creada con commits iniciales de cada integrante.

---

## 2. Prerrequisitos

- Acceso de escritura al repo del grupo (`Grupo_8-GOYS-2026`, raíz del laboratorio failover).
- Diagrama/consigna original del laboratorio.
- Canal privado del grupo para compartir claves reales (no van al repo).
- Conocimiento de la topología de 5 capas y de los protocolos del lab (VRRP, OSPF, eBGP).

---

## 3. Procedimiento

### F0.1 · IPAM / direccionamiento

Definir el plan de direccionamiento completo (enlaces + LANs + VRRP + loopbacks) sin solapamiento.

**Criterios de direccionamiento adoptados:**

| Elemento | Criterio |
|---|---|
| Enlaces punto a punto | `/30` |
| LAN USERS (VLAN 10) | `192.168.10.0/24` |
| LAN SERVERS (VLAN 20) | `192.168.20.0/24` |
| Loopbacks / Router-ID | `/32` |
| Red de infraestructura | `10.255.0.0/16` |
| Solapamiento de subredes | No permitido |

**Parámetros globales:** AS EDGE `65000` · ISP-1 `65001` · ISP-2 `65002` · OSPF área 0 · CORE-1 Router-ID `4.4.4.4` · CORE-2 Router-ID `5.5.5.5` · VRID 10 (USERS, prioridad 150 en DIST-1) · VRID 20 (SERVERS, prioridad 150 en DIST-2).

**Verificación de no solapamiento** (reproducible): confirmar que cada uso cae en un bloque separado.

| Bloque | Uso |
|---|---|
| `10.255.0.0/30` – `10.255.0.32/30` | Enlaces L3 |
| `192.168.10.0/24` | VLAN 10 USERS |
| `192.168.20.0/24` | VLAN 20 SERVERS |
| `1.1.1.1/32` – `7.7.7.7/32` | Router-ID / Loopbacks |

**Salida:** tabla IPAM publicada en [`docs/memoria.md`](../docs/memoria.md).

---

### F0.2 · Corrección del diagrama

Documentar los defectos del diagrama original, con corrección y justificación (mínimo 3; se hicieron 5).

| # | Defecto detectado | Corrección aplicada | Justificación |
|:-:|---|---|---|
| 1 | Firewall (ASA) único sin par HA (SPOF) | Filtrado en EDGE; en producción dos firewalls en failover | Todo el tráfico pasa por un solo equipo; si cae, se corta la salida |
| 2 | Subredes solapadas entre sitios (VLAN 10/20 y `192.168.10.0/24` repetidas) | IPAM único, sin overlap (§F0.1) | Una red en dos lugares → el router no sabe a dónde mandar el paquete |
| 3 | Sin enlace CORE-1 ↔ CORE-2 | Se agrega enlace core–core con OSPF área 0 | Da ruta alternativa corta si cae EDGE ↔ CORE-1 |
| 4 | HSRP en el core (diseño *collapsed*) | VRRP en distribución (DIST-1/DIST-2); core = tránsito puro | El core debe hacer una sola cosa; VRRP es estándar (RFC 5798) y MikroTik no tiene HSRP |
| 5 | iBGP con route reflector mal ubicado (a través del ASA) | eBGP solo en EDGE, sin RR; OSPF adentro | El filtrado perimetral no debe atravesarse con sesiones de control |

**Salida:** diagrama corregido en `docs/diagramas/` y tabla en memoria.

---

### F0.3 · Política de seguridad

Principio rector: **mínimo privilegio y mínima superficie de ataque**.

**Usuarios y privilegios:**

| Usuario | Grupo | Permisos | Uso |
|---|---|---|---|
| `admin` | `full` | Total | Configuración (password obligatoria, distinta de la de fábrica) |
| `monitor` | `monitor` (custom) | `read`, `test`, `ssh`, `winbox` | Consultas de estado, verificación, monitoreo |

**Claves del plano de control (placeholders, no se commitean):**

| Protocolo | Mecanismo | Dónde | Responsable |
|---|---|---|---|
| OSPF | MD5 (key-id 1) | EDGE, CORE-1/2, DIST-1/2 (área 0) | R3 |
| BGP | TCP-MD5 (RFC 2385) | EDGE ↔ ISP-1, EDGE ↔ ISP-2 (una clave por sesión) | R1 + R2 |
| VRRP | Simple (VRRPv2) | DIST-1 ↔ DIST-2 (una clave por vrid) | R4 |

> ⚠️ VRRPv3 (default en RouterOS 7) no soporta autenticación; se usa **VRRPv2** para cumplir la consigna. Las claves reales (`<OSPF_KEY>`, `<BGP_KEY_ISP1/2>`, `<VRRP_KEY_10/20>`, `<ADMIN_PASS>`, `<MONITOR_PASS>`) se comparten por canal privado.

**Salida:** política redactada en memoria §1.3.

---

### F0.4 · Política de operación

**Formato del change log** (Conventional Commits `tipo(alcance): descripción`): `feat`, `fix`, `docs`, `ops`, `chore`. Cada intervención se registra en memoria §6.1 con: **Fecha · Rol · Nodo · Cambio · Commit · Rollback**.

**Política de backup:**
- **Cuándo:** snapshot BASE de todos los equipos en F1; luego backups al cerrar cada hito o antes de un cambio crítico.
- **Qué/Cómo:** `/export` (legible) + `/system backup save` (binario, siempre con password).
- **Dónde:** `backups/` versionado por fecha.
- **Restauración:** documentar evidencia del *restore* en un nodo.

---

### F0.5 · Repositorio git

- Crear repo y dar acceso al docente (R5).
- Estructura de carpetas + `README.md` + `backlog.md`.
- Primer commit de cada integrante (trazabilidad por autor).
- Reglas: un commit por cambio lógico; `main` siempre funciona; no commitear claves reales.

---

## 4. Verificación

| Control | Cómo se verifica | Resultado esperado |
|---|---|---|
| IPAM sin solapamiento | Revisar bloques de §F0.1 | Ningún uso cae en dos lugares |
| Defectos documentados | Contar filas de §F0.2 | ≥ 3 con corrección y justificación (se hicieron 5) |
| Políticas definidas | Presencia de §F0.3 y §F0.4 en memoria | Usuarios, servicios, claves, change log y backup definidos |
| Repo | `git log` | Commit inicial de R1–R5 |

## 5. Evidencia

- Tabla IPAM: memoria §1.2.
- Diagrama corregido: `docs/diagramas/`.

## 6. Rollback

F0 no modifica nodos (es diseño). Si hay que revertir una decisión de diseño, se corrige el documento y se registra en el change log **antes** de impactar en la implementación.

## 7. Registro en change log / commit

Al cerrar F0, commit tipo `docs`:

```
docs(memoria): defino IPAM, corrección de diagrama y políticas F0.
```
