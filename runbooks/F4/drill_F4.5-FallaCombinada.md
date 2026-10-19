# Runbook F4 · Drill 5 — Falla combinada (ISP-1 + enlace EDGE ↔ CORE-1)

| Campo | Valor |
|-------|-------|
| **Épica** | F4 — Drills + monitoreo |
| **Vence** | martes 20/10 |
| **Tipo** | Drill de failover combinado (proveedor + enlace interno) |
| **Roles** | R1 (rol rotado; ejecuta), R5 (mide, verifica y evidencia) |
| **Fecha de ejecución** | 17/10/2026 |
| **Estado** | cerrado (salida sobrevive por ISP-2 vía CORE-2, con pérdida acotada a la convergencia) |
| **Dependencia** | ⚠️ Requiere **F3 cerrado** y los drills 2–4 previos. Combina la caída de ISP-1 (drill 4) con la del enlace EDGE↔CORE-1. |

> **Escenario:** fallan **a la vez** la sesión eBGP con ISP-1 y el enlace EDGE ↔ CORE-1 (`ether11` en EDGE). El dominio interno solo puede salir por CORE-2 → EDGE → ISP-2. Es el caso límite: dos fallas simultáneas, de capas distintas (proveedor + backbone).

---

## 1. Objetivo

Comprobar que la red **sobrevive a una doble falla**: los hosts siguen alcanzando el destino "público" `8.8.8.8/32` por el único camino restante (CORE-2 → EDGE → ISP-2), y el tráfico interno no se parte.

## 2. Prerrequisitos

- Ambas sesiones eBGP established y ruta dual a `8.8.8.8/32` (como en el drill 4).
- Ping continuo corriendo desde PC-USER: `ping 8.8.8.8`.
- Backup F4 disponible (`backups/2026-10-17_F4_BASE/`).

## 3. Detección (cómo se detectaría en operación)

1. En EDGE: `/routing bgp session print` (sesiones) e `/routing ospf neighbor print` en CORE-1 (adyacencias internas).
2. Señal de falla esperada: sesión `bgp-isp1-1` sin `E` **y** adyacencia del enlace caído eliminada; las tablas internas deben converger todas hacia CORE-2 como única salida al EDGE.

## 4. Respuesta (inyección de la falla)

Se inyectan las dos fallas en EDGE (BGP con ISP-1 e interfaz hacia CORE-1):

```routeros
[admin@EDGE] > /routing bgp connection disable [find name=bgp-isp1]
[admin@EDGE] > /interface disable ether11
```

**Verificación durante la falla:**

- EDGE: `bgp-isp1` con flag `X`; `ether11` `X`; la sesión `bgp-isp2-1` sigue `established`.
- `/ip route print` en EDGE: las rutas internas (LANs, loopbacks CORE/DIST) quedan **todas vía `10.255.0.14%ether12`** (CORE-2, único enlace interno vivo); `8.8.8.8/32` y `2.2.2.2/32` siguen activas **vía `10.255.0.6`** (ISP-2); la ruta a `1.1.1.1/32` (loopback ISP-1) **desaparece** (esperado: su único anunciante era ISP-1).
- PC-USER: el ping a `8.8.8.8` sigue respondiendo tras la convergencia doble; el `traceroute` confirma el camino: `192.168.10.2` (DIST-1) → `10.255.0.33` → `10.255.0.13` (CORE-2 → EDGE) → `8.8.8.8`.

## 5. Recuperación

```routeros
[admin@EDGE] > /routing bgp connection enable [find name=bgp-isp1]
[admin@EDGE] > /interface enable ether11
```

Al restituir ambas, vuelve la sesión con ISP-1 (rutas dual-homed reinstaladas) y la adyacencia OSPF del enlace EDGE↔CORE-1 (ECMP interno restaurado).

## 6. Resultado y tiempo medido

| Métrica | Valor |
|---|---|
| Paquetes transmitidos / recibidos (ping a `8.8.8.8` durante la doble falla) | 33 / 25 |
| Pérdida | **24 %** (8 paquetes, concentrados en la ventana de convergencia doble) |
| RTT min/avg/max | 6.027 / 95.791 / 760.146 ms |
| **Tiempo de degradación** | **≈ 8 s** acumulados (24 % × 33 s de ping continuo), luego tráfico estable por ISP-2 |
| Verificación de camino | `traceroute 8.8.8.8`: vía DIST-1 → CORE-2 → EDGE → ISP-2 (4 saltos) |
| Impacto en el usuario | Pérdida acotada a la convergencia doble; la conectividad **no se pierde** |

## 7. Post-mortem

- **¿Por qué funcionó?** Cada capa absorbió su falla con su mecanismo: BGP multi-homing mantuvo la salida por ISP-2 y OSPF reencaminó el dominio interno por CORE-2. Aunque el escenario es doble, **las dos fallas son independientes entre sí** (no comparten nodo), y el diseño de malla entre capas garantiza al menos un camino host→Internet.
- **Aprendizajes:** la pérdida (24 %) fue mayor que en drills individuales porque convergen **dos protocolos a la vez** (BGP retira rutas mientras OSPF reorganiza el área 0) y los primeros paquetes se pierden en ambas ventanas. En producción se la reduciría con BFD en las sesiones BGP, timers OSPF más agresivos en enlaces críticos y/o ECMP más ancho. También se validó que un destino sin anunciante vivo (loopback `1.1.1.1` de ISP-1) desaparezca limpiamente de la tabla en vez de blackholear.

## 8. Evidencia

- Estado baseline en EDGE (conexiones, sesiones y tabla completa): [Drill5-FallaCombinada-A.png](../capturas/F4/Drill5-FallaCombinada-A.png), [Drill5-FallaCombinada-B.png](../capturas/F4/Drill5-FallaCombinada-B.png)
- Inyección de la doble falla y tabla convergida (todo por CORE-2/ISP-2): [Drill5-FallaCombinada-C.png](../capturas/F4/Drill5-FallaCombinada-C.png)
- Ping + traceroute desde PC-USER (24 % de pérdida acotada, camino verificado): [Drill5-FallaCombinada-D.png](../capturas/F4/Drill5-FallaCombinada-D.png)

## 9. Registro en change log / commit

Drill operativo: `disable`/`enable` temporal de la conexión BGP y de `ether11`, **revertidos en el acto** (sin cambio persistente en los `.rsc`). Registrado en la memoria §6.1.5; detalle en `docs/memoria.md` §7.5.
