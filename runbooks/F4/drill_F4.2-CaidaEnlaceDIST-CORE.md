# Runbook F4 · Drill 2 — Caída de un enlace DIST ↔ CORE

| Campo | Valor |
|-------|-------|
| **Épica** | F4 — Drills + monitoreo |
| **Vence** | martes 20/10 |
| **Tipo** | Drill de failover de redundancia de IGP (OSPF, camino interno) |
| **Roles** | R3 (ejecuta sobre CORE-1), R5 (mide, verifica y evidencia) |
| **Fecha de ejecución** | 17/10/2026 |
| **Estado** | cerrado (sin pérdida de paquetes) |
| **Dependencia** | ⚠️ Requiere **F2 cerrado**: OSPF FULL en el área 0, con doble enlace CORE↔DIST y ECMP en las tablas. |

> **Escenario:** DIST-1 y DIST-2 están conectadas a ambos CORE (2 enlaces por DIST). Se corta el enlace **CORE-1 ↔ DIST-1** (`ether11` en CORE-1) y el tráfico debe reencaminarse por CORE-2.

---

## 1. Objetivo

Comprobar que, ante la caída de un enlace acceso-core, **OSPF reconverge por el enlace paralelo** y el tráfico de las LANs no se pierde.

## 2. Prerrequisitos

- Estado baseline verificado: adyacencias FULL y tablas con ECMP (múltiples gateways OSPF por destino).
- Ping continuo corriendo desde PC-USER: `ping 1.1.1.1`.
- Snapshot y backup F4 tomados (`backups/2026-10-17_F4_BASE/`).

## 3. Detección (cómo se detectaría en operación)

1. En CORE-1: `/routing ospf neighbor print` → vecinos `6.6.6.6` (DIST-1) y `7.7.7.7` (DIST-2) en `Full` por `ether11`/`ether12`.
2. Señal de falla esperada: la adyacencia hacia el vecino del enlace caído desaparece y las rutas con esa gateway se retiran de la tabla (se mantiene la alternativa ECMP).

## 4. Respuesta (inyección de la falla)

En CORE-1 se deshabilita la interfaz del enlace hacia DIST-1:

```routeros
[admin@CORE-1] > /interface disable ether11
```

**Verificación durante la falla:**

- CORE-1: `ether11` queda `X` (disabled); las adyacencias por `ether9` (EDGE), `ether10` (CORE-2) y `ether12` (DIST-2) siguen `Full`.
- CORE-2: `/ip route print where ospf` → las rutas a las LANs y a los loopbacks siguen presentes por ECMP (dos gateways por destino), sin rutas colgadas.
- PC-USER: el ping continuo a `1.1.1.1` sigue respondiendo sin interrupción.

## 5. Recuperación

```routeros
[admin@CORE-1] > /interface enable ether11
```

Al restituir la interfaz, OSPF reconstruye la adyacencia con DIST-1 y **vuelve el ECMP** (las tablas de CORE-2 muestran de nuevo las dos gateways para cada destino).

## 6. Resultado y tiempo medido

| Métrica | Valor |
|---|---|
| Paquetes transmitidos / recibidos (ping continuo a `1.1.1.1`) | 29 / 29 |
| Pérdida | **0 %** |
| RTT min/avg/max | 9.690 / 140.527 / 622.378 ms |
| **Tiempo de failover** | **< 1 s** (ningún paquete perdido; la conmutación por ECMP fue anterior al siguiente eco ICMP) |
| Impacto en el usuario | Ninguno detectable |

## 7. Post-mortem

- **¿Por qué funcionó?** El diseño tiene **doble enlace CORE↔DIST por cada DIST**, y OSPF mantuvo rutas alternativas ya instaladas (ECMP) en las tablas. Al morir el enlace, el vecino se eliminó y el tráfico usó la gateway restante sin esperar recálculos largos.
- **Aprendizajes:** los picos de RTT (hasta 622 ms) corresponden al arranque del ping en GNS3, no al failover; para medir más finamente conviene usar `ping with-interval` o iperf. El ECMP es la "redundancia silenciosa": no hace falta protocolo adicional si el IGP ya tiene dos caminos vivos.

## 8. Evidencia

- Inyección: `disable ether11` y restauración en CORE-1: [Drill2-CaidaEnlaceDIST-CORE-A.png](../capturas/F4/Drill2-CaidaEnlaceDIST-CORE-A.png)
- Tablas OSPF de CORE-2 durante y después (ECMP conservado): [Drill2-CaidaEnlaceDIST-CORE-B.png](../capturas/F4/Drill2-CaidaEnlaceDIST-CORE-B.png)
- Ping continuo desde PC-USER (29 paquetes, 0 % de pérdida): [Drill2-CaidaEnlaceDIST-CORE-C.png](../capturas/F4/Drill2-CaidaEnlaceDIST-CORE-C.png)

## 9. Registro en change log / commit

Drill operativo: `disable`/`enable` temporal de una interfaz, **revertido en el acto** (sin cambio persistente en los `.rsc`). Registrado en la memoria §6.1.5; detalle en `docs/memoria.md` §7.2.
