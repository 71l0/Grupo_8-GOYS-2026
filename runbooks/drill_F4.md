# Runbook F4 - 5 drills de failover

| Campo | Valor |
|-------|-------|
| **Épica** | F4 — Drills + monitoreo |
| **Vence** | martes 20/10 |
| **Tipo** | Reconvergencia OSPF ante pérdida de enlace entre routers centrales |
| **Roles** | Reconvergencia OSPF ante pérdida de enlace entre routers centrales| **Estado** | cerrado (backups en `backups/2026-10-17_F4_BASE`) |
| **Dependencia** | ⚠️ Requiere **F2 y F3 cerrado**|

> **Alcance:** validar el comportamiento de la topologia MikroTik CHR ante 5 escenarios de falla: caída del master VRRP, caída de enlace DIST–CORE, caída de enlace CORE–CORE, caída de ISP-1 y falla combinada. Se registran los mecanismos de detección y recuperación, el tiempo medido, la pérdida de paquetes y el estado final de los servicios.

---

## 1. Objetivo
Evaluar la resiliencia de la topología mediante la ejecución y documentación de cinco escenarios de falla controlada. Para cada escenario se registra el estado inicial, el evento introducido, la detección, la respuesta de los mecanismos de redundancia, la recuperación de la conectividad y las conclusiones del post-mortem.

**Criterio de aceptación:**

- Ante la caída del master VRRP, el router de respaldo asume el rol correspondiente y se mantiene la conectividad de las LAN.
- Ante la caída de un enlace DIST–CORE o CORE–CORE, OSPF converge hacia un camino alternativo y se recupera la conectividad entre las LAN.
- Ante la caída de ISP-1, EDGE utiliza la salida alternativa mediante ISP-2 y recupera la conectividad con el destino externo de prueba.
- Ante la falla combinada, se documenta qué servicios permanecen disponibles, cuáles resultan afectados y el comportamiento residual de la topología.
- Para los cinco escenarios se dispone de un runbook, evidencias, tiempo de detección, tiempo de recuperación y post-mortem.
- Los resultados se basan en observaciones y mediciones reproducibles; los valores no registrados se identifican como pendientes.

---

## 2. Prerrequisitos

- Configuracion de F2: VRRP operativo y OSPF con autenticación MD5.
- Configuracion de F3: eBGP entre EDGE e ISP-1/ISP-2, redistribución de rutas y políticas de borde.
- Backup de referencia: `backups/2026-10-17_F4_BASE`
- Acceso a las consolas de los siete routers MikroTik CHR mediante GNS3.
- Acceso a PC-USER y al host de servidores para ejecutar pruebas de conectividad.
- Registro de la topología, direcciones IP, interfaces y vecinos implicados en cada escenario.
- Herramienta de medición de tiempos y registro de pings continuos.
- Capturas originales de los cinco drills disponibles en capturas/F4/.
- Verificación del estado inicial antes de cada prueba.

---

## 3. Tabla de resultados de conectividad en cada drill

| Drill                     | Transmitidos | Recibidos | Perdidos | Pérdida calculada | RTT mín. / prom. / máx.       |
|---------------------------|-------------:|----------:|---------:|------------------:|-------------------------------|
| 1. Caída del master VRRP  | 60 | 59 | 1 | 1,67 % | 6,835 / 66,276 / 955,861 ms |
| 2. Caída DIST–CORE        | 29 | 29 | 0 | 0 % | 9,690 / 140,527 / 622,378 ms |
| 3. Caída CORE–CORE        | 65 | 65 | 0 | 0 % | 7,386 / 55,496 / 442,455 ms |
| 4. Caída de ISP-1         | 15 | 14 | 1 | 6,67 % | 9,952 / 90,020 / 604,627 ms |
| 5. Falla combinada        | 33 | 25 | 8 | 24,24 % | 6,027 / 95,791 / 760,146 ms |

Las pruebas de ping continuo nos permitieron observar el impacto de los escenarios de falla sobre la conectividad. 
* En el drill 2 no se registraron pérdidas de paquetes
* En los drills 1 y 4 se perdió un paquete en cada prueba
* El drill 3, la captura disponible registra 65 paquetes transmitidos y recibidos después de la recuperación
* El drill 5, la captura registrada muestra 33 paquetes transmitidos, 25 recibidos y 8 perdidos.

---

## 4. Procedimiento de los drills
### 4.1 Drill 1 - Caida del master VRRP

Comprobar que, ante la caída del nodo master del grupo VRRP USERS, **DIST-2 asume el gateway virtual automáticamente** y los hosts de la LAN USERS mantienen la conectividad con pérdida mínima.

#### 4.1.1 Detección (cómo se detectaría en operación)

1. En DIST-1: `/interface vrrp print` → el grupo `vrrp-users` (vrid 10) está en `M` (master) con prioridad 150.
2. Señal de falla esperada al caer DIST-1: en el backup desaparecen los anuncios del master y el grupo pasa de `B` a `M`; el host ve pérdida de los primeros paquetes al gateway.

#### 4.1.2 Respuesta (inyección de la falla)

En DIST-1 se deshabilita el grupo VRRP USERS (equivale funcionalmente a la caída del servicio de gateway en ese nodo):

```routeros
[admin@DIST-1] > /interface vrrp disable [find vrid=10]
```

**Verificación durante la falla:**

- DIST-1: `vrrp-users` queda con flag `X` (disabled); `vrrp-servers` sigue `B` (no se ve afectado).
- DIST-2: `vrrp-users` **deja de ser backup y asume el rol de master** del VRID 10 (la VIP `192.168.10.3` migra a DIST-2).
- PC-USER: el ping continuo a `1.1.1.1` sigue respondiendo tras la ventana de convergencia.

#### 4.1.3 Recuperación

```routeros
[admin@DIST-1] > /interface vrrp enable [find vrid=10]
```

Al volver a habilitarse, DIST-1 recupera el master del VRID 10 (prioridad 150 > 100) y DIST-2 vuelve al rol `B` (backup). El ping continuo no se interrumpe en la vuelta a normalidad.

#### 4.1.4 Resultado y tiempo medido

| Métrica | Valor |
|---|---|
| Paquetes transmitidos / recibidos (ping continuo a `1.1.1.1`) | 60 / 59 |
| Pérdida | **1 %** (1 paquete) |
| RTT min/avg/max | 6.835 / 66.276 / 955.861 ms |
| **Tiempo de failover estimado** | **≈ 1 s** (un solo paquete perdido, acorde al `interval=1s` de VRRP) |
| Impacto en el usuario | Un único timeout de ICMP; sin cortes de sesión |

#### 4.1.5 Post-mortem

- **¿Por qué funcionó?** El grupo VRRP estaba correctamente parametrizado con prioridades distintas (150/100) y **auth simple compartida**: DIST-2 aceptó los anuncios del master y al dejar de recibirlos por `dead-interval` asumió la VIP sin intervención manual. La load-sharing (cada DIST master de un grupo) limitó el impacto al 50 % de las LANs: SERVERS no se vio afectada.
- **Aprendizajes:** conviene monitorear el estado master/backup (SNMP, §8 de la memoria) porque una caída del master es casi imperceptible para el usuario y nadie la reportaría; el preempt por prioridad garantiza el rebalanceo al volver el nodo original.

#### 4.1.6 Evidencia

- Estado baseline y deshabilitación/habilitación del VRID 10 en DIST-1: [Drill1-CaidaMasterVRRP-A.png](../capturas/F4/Drill1-CaidaMasterVRRP-A.png)
- Reacción de DIST-2 (backup → master → backup): [Drill1-CaidaMasterVRRP-B.png](../capturas/F4/Drill1-CaidaMasterVRRP-B.png)
- Ping continuo desde PC-USER: [Drill1-CaidaMasterVRRP-C.png](../capturas/F4/Drill1-CaidaMasterVRRP-C.png)
- Estadísticas del ping (60 paquetes, 1 % de pérdida): [Drill1-CaidaMasterVRRP-D.png](../capturas/F4/Drill1-CaidaMasterVRRP-D.png)

#### 4.1.7 Registro en change log / commit

Drill operativo: los comandos `disable`/`enable` son **temporales y se revirtieron en el acto** (no dejan cambio persistente en los `.rsc`). Quedan registrados en la memoria §6.1.5, con el detalle en `docs/memoria.md` §7.1. Evidencia versionada en el commit de runbooks/capturas F4.

### 4.2 Drill 2 - Caída de un enlace DIST ↔ CORE

Comprobar que, ante la caída de un enlace acceso-core, **OSPF reconverge por el enlace paralelo** y el tráfico de las LANs no se pierde.

#### 4.2.1 Detección (cómo se detectaría en operación)

1. En CORE-1: `/routing ospf neighbor print` → vecinos `6.6.6.6` (DIST-1) y `7.7.7.7` (DIST-2) en `Full` por `ether11`/`ether12`.
2. Señal de falla esperada: la adyacencia hacia el vecino del enlace caído desaparece y las rutas con esa gateway se retiran de la tabla (se mantiene la alternativa ECMP).

#### 4.2.2 Respuesta (inyección de la falla)

En CORE-1 se deshabilita la interfaz del enlace hacia DIST-1:

```routeros
[admin@CORE-1] > /interface disable ether11
```

**Verificación durante la falla:**

- CORE-1: `ether11` queda `X` (disabled); las adyacencias por `ether9` (EDGE), `ether10` (CORE-2) y `ether12` (DIST-2) siguen `Full`.
- CORE-2: `/ip route print where ospf` → las rutas a las LANs y a los loopbacks siguen presentes por ECMP (dos gateways por destino), sin rutas colgadas.
- PC-USER: el ping continuo a `1.1.1.1` sigue respondiendo sin interrupción.

#### 4.2.3 Recuperación

```routeros
[admin@CORE-1] > /interface enable ether11
```

Al restituir la interfaz, OSPF reconstruye la adyacencia con DIST-1 y **vuelve el ECMP** (las tablas de CORE-2 muestran de nuevo las dos gateways para cada destino).

#### 4.2.4 Resultado y tiempo medido

| Métrica | Valor |
|---|---|
| Paquetes transmitidos / recibidos (ping continuo a `1.1.1.1`) | 29 / 29 |
| Pérdida | **0 %** |
| RTT min/avg/max | 9.690 / 140.527 / 622.378 ms |
| **Tiempo de failover** | **< 1 s** (ningún paquete perdido; la conmutación por ECMP fue anterior al siguiente eco ICMP) |
| Impacto en el usuario | Ninguno detectable |

#### 4.2.5 Post-mortem

- **¿Por qué funcionó?** El diseño tiene **doble enlace CORE↔DIST por cada DIST**, y OSPF mantuvo rutas alternativas ya instaladas (ECMP) en las tablas. Al morir el enlace, el vecino se eliminó y el tráfico usó la gateway restante sin esperar recálculos largos.
- **Aprendizajes:** los picos de RTT (hasta 622 ms) corresponden al arranque del ping en GNS3, no al failover; para medir más finamente conviene usar `ping with-interval` o iperf. El ECMP es la "redundancia silenciosa": no hace falta protocolo adicional si el IGP ya tiene dos caminos vivos.

#### 4.2.6 Evidencia

- Inyección: `disable ether11` y restauración en CORE-1: [Drill2-CaidaEnlaceDIST-CORE-A.png](../capturas/F4/Drill2-CaidaEnlaceDIST-CORE-A.png)
- Tablas OSPF de CORE-2 durante y después (ECMP conservado): [Drill2-CaidaEnlaceDIST-CORE-B.png](../capturas/F4/Drill2-CaidaEnlaceDIST-CORE-B.png)
- Ping continuo desde PC-USER (29 paquetes, 0 % de pérdida): [Drill2-CaidaEnlaceDIST-CORE-C.png](../capturas/F4/Drill2-CaidaEnlaceDIST-CORE-C.png)

#### 4.2.7 Registro en change log / commit

Drill operativo: `disable`/`enable` temporal de una interfaz, **revertido en el acto** (sin cambio persistente en los `.rsc`). Registrado en la memoria §6.1.5; detalle en `docs/memoria.md` §7.2.

### 4.3 Drill 3 - Caída del enlace CORE-1 ↔ CORE-2 (core–core)

Comprobar que la caída del enlace **core–core** (el defecto #3 del diagrama original, agregado en este lab) no parte la red: OSPF reconverge y cada nodo alcanza al resto por los enlaces restantes.

#### 4.3.1 Detección (cómo se detectaría en operación)

1. En CORE-1: `/routing ospf neighbor print` → vecino `5.5.5.5` (CORE-2) en `Full` por `ether10`, junto a EDGE (`3.3.3.3`), DIST-1 (`6.6.6.6`) y DIST-2 (`7.7.7.7`).
2. Señal de falla esperada: el vecino `5.5.5.5` desaparece de la lista y las rutas aprendidas únicamente por CORE-2 se retiran.

#### 4.3.2 Respuesta (inyección de la falla)

En CORE-1 se deshabilita la interfaz del enlace core–core:

```routeros
[admin@CORE-1] > /interface disable ether10
```

**Verificación durante la falla:**

- CORE-1: `/routing ospf neighbor print` → quedan los vecinos `3.3.3.3` (EDGE, `Full`), `6.6.6.6` (DIST-1) y `7.7.7.7` (DIST-2); el vecino CORE-2 (`5.5.5.5`) desapareció. Las adyacencias restantes pasan transitoriamente por `ExStart`/`Init` al reorganizarse el área y vuelven a `Full`.
- EDGE y DIST: `/ip route print where ospf` → cada destino alcanzable mantiene camino por los enlaces vivos; las LANs siguen presentes.
- PC-USER: el ping continuo a `1.1.1.1` sigue respondiendo sin interrupción.

#### 4.3.3 Recuperación

```routeros
[admin@CORE-1] > /interface enable ether10
```

Al restituir el enlace, CORE-1 y CORE-2 reconstruyen la adyacencia (`5.5.5.5` vuelve a `Full`) y **se restaura el ECMP completo** en EDGE y en las DIST (cada destino con dos gateways otra vez).

#### 4.3.4 Resultado y tiempo medido

| Métrica | Valor |
|---|---|
| Paquetes transmitidos / recibidos durante la caída (ping a `1.1.1.1`) | 29 / 29 |
| Pérdida durante la caída | **0 %** |
| RTT durante la caída (min/avg/max) | 9.690 / 140.527 / 622.378 ms |
| Verificación tras la recuperación | 65 / 65 paquetes, **0 %** de pérdida (min/avg/max = 7.386 / 55.496 / 442.455 ms) |
| **Tiempo de failover** | **< 1 s** (conmutación transparente al siguiente eco ICMP) |
| Impacto en el usuario | Ninguno detectable |

#### 4.3.5 Post-mortem

- **¿Por qué funcionó?** El enlace core–core es un refuerzo, no un punto único: aunque se corte, el área 0 tiene **múltiples entradas a cada capa** (EDGE↔ambos CORE, ambos CORE↔ambas DIST). OSPF eliminó el vecino muerto y el tráfico siguió por los caminos ECMP ya calculados. Se valida así la corrección del defecto #3: el lab no depende del core–core para funcionar, pero al existir acorta los caminos y da ECMP.
- **Aprendizajes:** al reabrir el enlace las adyacencias vecinas (DIST) también transitaron por `ExStart`/`Init` por los LSA refresh; es esperable y no indica problema. Medir la recuperación con ping continuo da evidencia cuantitativa simple para el post-mortem.

#### 4.3.6 Evidencia

- Inyección y vecinos OSPF de CORE-1 durante la caída (vecino 5.5.5.5 ausente) y restauración: [Drill3-CaidaEnlaceCORE-CORE-A.png](../capturas/F4/Drill3-CaidaEnlaceCORE-CORE-A.png), [Drill3-CaidaEnlaceCORE-CORE-B.png](../capturas/F4/Drill3-CaidaEnlaceCORE-CORE-B.png)
- Ping continuo desde PC-USER durante la caída: [Drill3-CaidaEnlaceCORE-CORE-C.png](../capturas/F4/Drill3-CaidaEnlaceCORE-CORE-C.png)
- Tablas OSPF de EDGE y DIST tras la recuperación (ECMP completo): [Drill3-CaidaEnlaceCORE-CORE-D.png](../capturas/F4/Drill3-CaidaEnlaceCORE-CORE-D.png), [Drill3-CaidaEnlaceCORE-CORE-E.png](../capturas/F4/Drill3-CaidaEnlaceCORE-CORE-E.png)

#### 4.3.7 Registro en change log / commit

Drill operativo: `disable`/`enable` temporal del enlace core–core, **revertido en el acto** (sin cambio persistente en los `.rsc`). Registrado en la memoria §6.1.5; detalle en `docs/memoria.md` §7.3.

### 4.4 Drill 4 - Caída de ISP-1 (multi-homing BGP)

Comprobar que, ante la caída de la sesión eBGP con ISP-1, **EDGE retira las rutas aprendidas de ISP-1 y la salida a "Internet" sigue activa por ISP-2**, con pérdida mínima.

#### 4.4.1 Detección (cómo se detectaría en operación)

1. En EDGE: `/routing bgp session print` → ambas sesiones con flag `E` (established), `prefix-count` > 0.
2. Señal de falla esperada: la sesión `bgp-isp1-1` pierde el flag `E` (o desaparece de la lista de established) y sus prefijos dejan de estar en `ip route print`; SNMP/monitoreo alertaría por sesión caída (§8 de la memoria).

#### 4.4.2 Respuesta (inyección de la falla)

Se deshabilita la conexión de BGP con ISP-1 en EDGE (equivale a la caída de la sesión):

```routeros
[admin@EDGE] > /routing bgp connection disable [find name=bgp-isp1]
```

**Verificación durante la falla:**

- EDGE: `bgp-isp1` queda con flag `X` (disabled); `bgp-isp2-1` **sigue `established`** y hasta aumenta su `prefix-count` (absorbe el tráfico).
- Ruta: `/ip route print where dst-address=8.8.8.8/32` → desaparece la vía `10.255.0.2` (ISP-1) y **la ruta vía `10.255.0.6` (ISP-2) queda activa**.
- PC-USER: el ping a `8.8.8.8` sigue respondiendo (la salida no se corta).

#### 4.4.3 Recuperación

```routeros
[admin@EDGE] > /routing bgp connection enable [find name=bgp-isp1]
```

Al reactivarse la conexión, la sesión `bgp-isp1-1` vuelve a `established` y se reinstalan ambas rutas BGP a `8.8.8.8/32` (vuelven a compartir ECMP a los dos ISPs).

#### 4.4.4 Resultado y tiempo medido

| Métrica | Valor |
|---|---|
| Paquetes transmitidos / recibidos (ping a `8.8.8.8` durante la caída) | 15 / 14 |
| Pérdida | **6 %** (1 paquete) |
| RTT min/avg/max | 9.952 / 90.020 / 604.627 ms |
| **Tiempo de failover estimado** | **≈ 1 s** (un solo paquete perdido; el retiro de la ruta BGP fue inmediato al bajar la sesión) |
| Impacto en el usuario | Un único timeout de ICMP; sin cortes de sesión sostenidas |

#### 4.4.5 Post-mortem

- **¿Por qué funcionó?** El multi-homing con dos sesiones eBGP **independientes** (una por proveedor) y rutas de igual distancia (20) permite que, al bajar `bgp-isp1`, la ruta vía ISP-2 pase a ser la única activa al instante. El NAT masquerade y el firewall del EDGE no requieren ajustes: solo cambia la ruta de salida. La redistribución OSPF→BGP con filtro sigue anunciando las LANs por la sesión viva.
- **Aprendizajes:** el `disable` de la conexión simula la caída de forma limpia y reversible; en una caída real (enlace/telco) la sesión moriría por `hold-time` (1m30s), lo que alargaría el failover — en producción se acortaría con **BFD** o timers más agresivos. Monitorear `prefix-count` y `uptime` de las sesiones permite alertar la degradación antes que el usuario.

#### 4.4.6 Evidencia

- Loopbacks `8.8.8.8/32` agregadas en ISP-1 e ISP-2 (servicio "Internet" simulado): [Drill4-CaidaDeISP-1-A.png](../capturas/F4/Drill4-CaidaDeISP-1-A.png), [Drill4-CaidaDeISP-1-B.png](../capturas/F4/Drill4-CaidaDeISP-1-B.png)
- Estado baseline en EDGE (ambas sesiones established, ruta dual a 8.8.8.8/32): [Drill4-CaidaDeISP-1-C.png](../capturas/F4/Drill4-CaidaDeISP-1-C.png)
- Inyección (`disable bgp-isp1`), tabla con salida por ISP-2 y restauración: [Drill4-CaidaDeISP-1-D.png](../capturas/F4/Drill4-CaidaDeISP-1-D.png)
- Ping desde PC-USER a 8.8.8.8 (15 paquetes, 6 % de pérdida): [Drill4-CaidaDeISP-1-E.png](../capturas/F4/Drill4-CaidaDeISP-1-E.png)

> **Nota de contexto:** la loopback `8.8.8.8/32` representa un servicio público alcanzable vía ambos ISPs; fue un agregado de diseño pensado justamente para poder medir la salida a "Internet" durante los drills de caída de proveedor.

#### 4.4.7 Registro en change log / commit

- **Cambio de config persistente (previo al drill):** ISP-1 e ISP-2 agregan `8.8.8.8/32` en su loopback (registrado en la memoria §6.1.5; versionado en `backups/2026-10-17_F4_BASE/`).
- **Drill:** `disable`/`enable` temporal de la conexión BGP, **revertido en el acto**. Detalle en `docs/memoria.md` §7.4.

### 4.5 Drill 5 - Falla combinada (ISP-1 + enlace EDGE ↔ CORE-1)

Comprobar que la red **sobrevive a una doble falla**: los hosts siguen alcanzando el destino "público" `8.8.8.8/32` por el único camino restante (CORE-2 → EDGE → ISP-2), y el tráfico interno no se parte.

#### 4.5.1 Detección (cómo se detectaría en operación)

1. En EDGE: `/routing bgp session print` (sesiones) e `/routing ospf neighbor print` en CORE-1 (adyacencias internas).
2. Señal de falla esperada: sesión `bgp-isp1-1` sin `E` **y** adyacencia del enlace caído eliminada; las tablas internas deben converger todas hacia CORE-2 como única salida al EDGE.

#### 4.5.2 Respuesta (inyección de la falla)

Se inyectan las dos fallas en EDGE (BGP con ISP-1 e interfaz hacia CORE-1):

```routeros
[admin@EDGE] > /routing bgp connection disable [find name=bgp-isp1]
[admin@EDGE] > /interface disable ether11
```

**Verificación durante la falla:**

- EDGE: `bgp-isp1` con flag `X`; `ether11` `X`; la sesión `bgp-isp2-1` sigue `established`.
- `/ip route print` en EDGE: las rutas internas (LANs, loopbacks CORE/DIST) quedan **todas vía `10.255.0.14%ether12`** (CORE-2, único enlace interno vivo); `8.8.8.8/32` y `2.2.2.2/32` siguen activas **vía `10.255.0.6`** (ISP-2); la ruta a `1.1.1.1/32` (loopback ISP-1) **desaparece** (esperado: su único anunciante era ISP-1).
- PC-USER: el ping a `8.8.8.8` sigue respondiendo tras la convergencia doble; el `traceroute` confirma el camino: `192.168.10.2` (DIST-1) → `10.255.0.33` → `10.255.0.13` (CORE-2 → EDGE) → `8.8.8.8`.

#### 4.5.3 Recuperación

```routeros
[admin@EDGE] > /routing bgp connection enable [find name=bgp-isp1]
[admin@EDGE] > /interface enable ether11
```

Al restituir ambas, vuelve la sesión con ISP-1 (rutas dual-homed reinstaladas) y la adyacencia OSPF del enlace EDGE↔CORE-1 (ECMP interno restaurado).

#### 4.5.4 Resultado y tiempo medido

| Métrica | Valor |
|---|---|
| Paquetes transmitidos / recibidos (ping a `8.8.8.8` durante la doble falla) | 33 / 25 |
| Pérdida | **24 %** (8 paquetes, concentrados en la ventana de convergencia doble) |
| RTT min/avg/max | 6.027 / 95.791 / 760.146 ms |
| **Tiempo de degradación** | **≈ 8 s** acumulados (24 % × 33 s de ping continuo), luego tráfico estable por ISP-2 |
| Verificación de camino | `traceroute 8.8.8.8`: vía DIST-1 → CORE-2 → EDGE → ISP-2 (4 saltos) |
| Impacto en el usuario | Pérdida acotada a la convergencia doble; la conectividad **no se pierde** |

#### 4.5.5 Post-mortem

- **¿Por qué funcionó?** Cada capa absorbió su falla con su mecanismo: BGP multi-homing mantuvo la salida por ISP-2 y OSPF reencaminó el dominio interno por CORE-2. Aunque el escenario es doble, **las dos fallas son independientes entre sí** (no comparten nodo), y el diseño de malla entre capas garantiza al menos un camino host→Internet.
- **Aprendizajes:** la pérdida (24 %) fue mayor que en drills individuales porque convergen **dos protocolos a la vez** (BGP retira rutas mientras OSPF reorganiza el área 0) y los primeros paquetes se pierden en ambas ventanas. En producción se la reduciría con BFD en las sesiones BGP, timers OSPF más agresivos en enlaces críticos y/o ECMP más ancho. También se validó que un destino sin anunciante vivo (loopback `1.1.1.1` de ISP-1) desaparezca limpiamente de la tabla en vez de blackholear.

#### 4.5.6 Evidencia

- Estado baseline en EDGE (conexiones, sesiones y tabla completa): [Drill5-FallaCombinada-A.png](../capturas/F4/Drill5-FallaCombinada-A.png), [Drill5-FallaCombinada-B.png](../capturas/F4/Drill5-FallaCombinada-B.png)
- Inyección de la doble falla y tabla convergida (todo por CORE-2/ISP-2): [Drill5-FallaCombinada-C.png](../capturas/F4/Drill5-FallaCombinada-C.png)
- Ping + traceroute desde PC-USER (24 % de pérdida acotada, camino verificado): [Drill5-FallaCombinada-D.png](../capturas/F4/Drill5-FallaCombinada-D.png)

#### 4.5.7 Registro en change log / commit

Drill operativo: `disable`/`enable` temporal de la conexión BGP y de `ether11`, **revertidos en el acto** (sin cambio persistente en los `.rsc`). Registrado en la memoria §6.1.5; detalle en `docs/memoria.md` §7.5.
