# Runbook F4 · Drill 4 — Caída de ISP-1 (multi-homing BGP)

| Campo | Valor |
|-------|-------|
| **Épica** | F4 — Drills + monitoreo |
| **Vence** | martes 20/10 |
| **Tipo** | Drill de failover de redundancia de proveedor (eBGP multi-homing) |
| **Roles** | R2 (rol rotado; ejecuta, simulando al operador de proveedores), R5 (mide, verifica y evidencia) |
| **Fecha de ejecución** | 17/10/2026 |
| **Estado** | cerrado (salida a Internet por ISP-2 con pérdida acotada) |
| **Dependencia** | ⚠️ Requiere **F3 cerrado**: 2 sesiones eBGP established con TCP-MD5 y salida a "Internet". |

> **Escenario:** EDGE tiene dos sesiones eBGP (`bgp-isp1` con AS 65001 y `bgp-isp2` con AS 65002). Para simular un destino "público" alcanzable por ambos proveedores, **ISP-1 e ISP-2 anuncian la misma loopback `8.8.8.8/32`** (servicio en Internet). Se corta la sesión con ISP-1 y la salida debe seguir por ISP-2.

---

## 1. Objetivo

Comprobar que, ante la caída de la sesión eBGP con ISP-1, **EDGE retira las rutas aprendidas de ISP-1 y la salida a "Internet" sigue activa por ISP-2**, con pérdida mínima.

## 2. Prerrequisitos

- Ambas sesiones `established`: `/routing bgp session print` en EDGE (flags `E`).
- Ruta dual-homed verificada: `/ip route print where dst-address=8.8.8.8/32` en EDGE → `DAb` vía `10.255.0.2` (ISP-1, activa) y `Db` vía `10.255.0.6` (ISP-2, respaldo), ambas distancia 20.
- Ambas loopbacks `8.8.8.8/32` configuradas en los `lo` de ISP-1 e ISP-2 (previo al drill).
- Ping continuo corriendo desde PC-USER: `ping 8.8.8.8`.

## 3. Detección (cómo se detectaría en operación)

1. En EDGE: `/routing bgp session print` → ambas sesiones con flag `E` (established), `prefix-count` > 0.
2. Señal de falla esperada: la sesión `bgp-isp1-1` pierde el flag `E` (o desaparece de la lista de established) y sus prefijos dejan de estar en `ip route print`; SNMP/monitoreo alertaría por sesión caída (§8 de la memoria).

## 4. Respuesta (inyección de la falla)

Se deshabilita la conexión de BGP con ISP-1 en EDGE (equivale a la caída de la sesión):

```routeros
[admin@EDGE] > /routing bgp connection disable [find name=bgp-isp1]
```

**Verificación durante la falla:**

- EDGE: `bgp-isp1` queda con flag `X` (disabled); `bgp-isp2-1` **sigue `established`** y hasta aumenta su `prefix-count` (absorbe el tráfico).
- Ruta: `/ip route print where dst-address=8.8.8.8/32` → desaparece la vía `10.255.0.2` (ISP-1) y **la ruta vía `10.255.0.6` (ISP-2) queda activa**.
- PC-USER: el ping a `8.8.8.8` sigue respondiendo (la salida no se corta).

## 5. Recuperación

```routeros
[admin@EDGE] > /routing bgp connection enable [find name=bgp-isp1]
```

Al reactivarse la conexión, la sesión `bgp-isp1-1` vuelve a `established` y se reinstalan ambas rutas BGP a `8.8.8.8/32` (vuelven a compartir ECMP a los dos ISPs).

## 6. Resultado y tiempo medido

| Métrica | Valor |
|---|---|
| Paquetes transmitidos / recibidos (ping a `8.8.8.8` durante la caída) | 15 / 14 |
| Pérdida | **6 %** (1 paquete) |
| RTT min/avg/max | 9.952 / 90.020 / 604.627 ms |
| **Tiempo de failover estimado** | **≈ 1 s** (un solo paquete perdido; el retiro de la ruta BGP fue inmediato al bajar la sesión) |
| Impacto en el usuario | Un único timeout de ICMP; sin cortes de sesión sostenidas |

## 7. Post-mortem

- **¿Por qué funcionó?** El multi-homing con dos sesiones eBGP **independientes** (una por proveedor) y rutas de igual distancia (20) permite que, al bajar `bgp-isp1`, la ruta vía ISP-2 pase a ser la única activa al instante. El NAT masquerade y el firewall del EDGE no requieren ajustes: solo cambia la ruta de salida. La redistribución OSPF→BGP con filtro sigue anunciando las LANs por la sesión viva.
- **Aprendizajes:** el `disable` de la conexión simula la caída de forma limpia y reversible; en una caída real (enlace/telco) la sesión moriría por `hold-time` (1m30s), lo que alargaría el failover — en producción se acortaría con **BFD** o timers más agresivos. Monitorear `prefix-count` y `uptime` de las sesiones permite alertar la degradación antes que el usuario.

## 8. Evidencia

- Loopbacks `8.8.8.8/32` agregadas en ISP-1 e ISP-2 (servicio "Internet" simulado): [Drill4-CaidaDeISP-1-A.png](../capturas/F4/Drill4-CaidaDeISP-1-A.png), [Drill4-CaidaDeISP-1-B.png](../capturas/F4/Drill4-CaidaDeISP-1-B.png)
- Estado baseline en EDGE (ambas sesiones established, ruta dual a 8.8.8.8/32): [Drill4-CaidaDeISP-1-C.png](../capturas/F4/Drill4-CaidaDeISP-1-C.png)
- Inyección (`disable bgp-isp1`), tabla con salida por ISP-2 y restauración: [Drill4-CaidaDeISP-1-D.png](../capturas/F4/Drill4-CaidaDeISP-1-D.png)
- Ping desde PC-USER a 8.8.8.8 (15 paquetes, 6 % de pérdida): [Drill4-CaidaDeISP-1-E.png](../capturas/F4/Drill4-CaidaDeISP-1-E.png)

> **Nota de contexto:** la loopback `8.8.8.8/32` representa un servicio público alcanzable vía ambos ISPs; fue un agregado de diseño pensado justamente para poder medir la salida a "Internet" durante los drills de caída de proveedor.

## 9. Registro en change log / commit

- **Cambio de config persistente (previo al drill):** ISP-1 e ISP-2 agregan `8.8.8.8/32` en su loopback (registrado en la memoria §6.1.5; versionado en `backups/2026-10-17_F4_BASE/`).
- **Drill:** `disable`/`enable` temporal de la conexión BGP, **revertido en el acto**. Detalle en `docs/memoria.md` §7.4.
