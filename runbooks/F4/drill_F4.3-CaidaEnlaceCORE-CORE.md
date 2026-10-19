# Runbook F4 · Drill 3 — Caída del enlace CORE-1 ↔ CORE-2 (core–core)

| Campo | Valor |
|-------|-------|
| **Épica** | F4 — Drills + monitoreo |
| **Vence** | martes 20/10 |
| **Tipo** | Drill de failover de redundancia de IGP (enlace core–core, defecto #3 corregido) |
| **Roles** | R3 (ejecuta sobre CORE-1), R5 (mide, verifica y evidencia) |
| **Fecha de ejecución** | 17/10/2026 |
| **Estado** | cerrado (sin pérdida de paquetes; ECMP restituido al recuperar) |
| **Dependencia** | ⚠️ Requiere **F2 cerrado** (OSPF FULL, incluido el enlace core–core) y **F3 cerrado** (ruta por defecto vía OSPF). |

> **Escenario:** CORE-1 y CORE-2 están unidos por el enlace core–core (`ether10` en CORE-1). Se corta ese enlace: el dominio interno pierde el camino directo entre cores y debe seguir funcionando por los caminos alternativos (EDGE↔CORE y CORE↔DIST).

---

## 1. Objetivo

Comprobar que la caída del enlace **core–core** (el defecto #3 del diagrama original, agregado en este lab) no parte la red: OSPF reconverge y cada nodo alcanza al resto por los enlaces restantes.

## 2. Prerrequisitos

- Adyacencia FULL CORE-1 ↔ CORE-2 visible en `/routing ospf neighbor print`.
- Ping continuo corriendo desde PC-USER: `ping 1.1.1.1`.
- Backup F4 disponible (`backups/2026-10-17_F4_BASE/`).

## 3. Detección (cómo se detectaría en operación)

1. En CORE-1: `/routing ospf neighbor print` → vecino `5.5.5.5` (CORE-2) en `Full` por `ether10`, junto a EDGE (`3.3.3.3`), DIST-1 (`6.6.6.6`) y DIST-2 (`7.7.7.7`).
2. Señal de falla esperada: el vecino `5.5.5.5` desaparece de la lista y las rutas aprendidas únicamente por CORE-2 se retiran.

## 4. Respuesta (inyección de la falla)

En CORE-1 se deshabilita la interfaz del enlace core–core:

```routeros
[admin@CORE-1] > /interface disable ether10
```

**Verificación durante la falla:**

- CORE-1: `/routing ospf neighbor print` → quedan los vecinos `3.3.3.3` (EDGE, `Full`), `6.6.6.6` (DIST-1) y `7.7.7.7` (DIST-2); el vecino CORE-2 (`5.5.5.5`) desapareció. Las adyacencias restantes pasan transitoriamente por `ExStart`/`Init` al reorganizarse el área y vuelven a `Full`.
- EDGE y DIST: `/ip route print where ospf` → cada destino alcanzable mantiene camino por los enlaces vivos; las LANs siguen presentes.
- PC-USER: el ping continuo a `1.1.1.1` sigue respondiendo sin interrupción.

## 5. Recuperación

```routeros
[admin@CORE-1] > /interface enable ether10
```

Al restituir el enlace, CORE-1 y CORE-2 reconstruyen la adyacencia (`5.5.5.5` vuelve a `Full`) y **se restaura el ECMP completo** en EDGE y en las DIST (cada destino con dos gateways otra vez).

## 6. Resultado y tiempo medido

| Métrica | Valor |
|---|---|
| Paquetes transmitidos / recibidos durante la caída (ping a `1.1.1.1`) | 29 / 29 |
| Pérdida durante la caída | **0 %** |
| RTT durante la caída (min/avg/max) | 9.690 / 140.527 / 622.378 ms |
| Verificación tras la recuperación | 65 / 65 paquetes, **0 %** de pérdida (min/avg/max = 7.386 / 55.496 / 442.455 ms) |
| **Tiempo de failover** | **< 1 s** (conmutación transparente al siguiente eco ICMP) |
| Impacto en el usuario | Ninguno detectable |

## 7. Post-mortem

- **¿Por qué funcionó?** El enlace core–core es un refuerzo, no un punto único: aunque se corte, el área 0 tiene **múltiples entradas a cada capa** (EDGE↔ambos CORE, ambos CORE↔ambas DIST). OSPF eliminó el vecino muerto y el tráfico siguió por los caminos ECMP ya calculados. Se valida así la corrección del defecto #3: el lab no depende del core–core para funcionar, pero al existir acorta los caminos y da ECMP.
- **Aprendizajes:** al reabrir el enlace las adyacencias vecinas (DIST) también transitaron por `ExStart`/`Init` por los LSA refresh; es esperable y no indica problema. Medir la recuperación con ping continuo da evidencia cuantitativa simple para el post-mortem.

## 8. Evidencia

- Inyección y vecinos OSPF de CORE-1 durante la caída (vecino 5.5.5.5 ausente) y restauración: [Drill3-CaidaEnlaceCORE-CORE-A.png](../capturas/F4/Drill3-CaidaEnlaceCORE-CORE-A.png), [Drill3-CaidaEnlaceCORE-CORE-B.png](../capturas/F4/Drill3-CaidaEnlaceCORE-CORE-B.png)
- Ping continuo desde PC-USER durante la caída: [Drill3-CaidaEnlaceCORE-CORE-C.png](../capturas/F4/Drill3-CaidaEnlaceCORE-CORE-C.png)
- Tablas OSPF de EDGE y DIST tras la recuperación (ECMP completo): [Drill3-CaidaEnlaceCORE-CORE-D.png](../capturas/F4/Drill3-CaidaEnlaceCORE-CORE-D.png), [Drill3-CaidaEnlaceCORE-CORE-E.png](../capturas/F4/Drill3-CaidaEnlaceCORE-CORE-E.png)

## 9. Registro en change log / commit

Drill operativo: `disable`/`enable` temporal del enlace core–core, **revertido en el acto** (sin cambio persistente en los `.rsc`). Registrado en la memoria §6.1.5; detalle en `docs/memoria.md` §7.3.
