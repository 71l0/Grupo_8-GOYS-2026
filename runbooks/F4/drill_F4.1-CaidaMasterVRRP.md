# Runbook F4 · Drill 1 — Caída del master VRRP

| Campo | Valor |
|-------|-------|
| **Épica** | F4 — Drills + monitoreo |
| **Vence** | martes 20/10 |
| **Tipo** | Drill de failover de redundancia de primer salto (VRRP) |
| **Roles** | R4 (ejecuta el drill sobre DIST-1/DIST-2), R5 (mide, verifica y evidencia) |
| **Fecha de ejecución** | 17/10/2026 |
| **Estado** | cerrado (failover verificado, 1 paquete perdido) |
| **Dependencia** | ⚠️ Requiere **F2 cerrado**: VRRP vrid 10/20 operativo con auth (DIST-1 master del grupo 10, DIST-2 master del 20). |

> **Escenario:** DIST-1 es el **master del VRID 10** (grupo `vrrp-users`, prioridad 150) y backup del 20; DIST-2 es el backup del 10 (prioridad 100) y master del 20. Se simula la caída del master del gateway USERS.

---

## 1. Objetivo

Comprobar que, ante la caída del nodo master del grupo VRRP USERS, **DIST-2 asume el gateway virtual automáticamente** y los hosts de la LAN USERS mantienen la conectividad con pérdida mínima.

## 2. Prerrequisitos

- Estado baseline verificado: `/interface vrrp print` en DIST-1 (`vrrp-users` flag `M`, prioridad 150) y en DIST-2 (`vrrp-users` flag `B`, prioridad 100).
- Ping continuo corriendo desde PC-USER: `ping 1.1.1.1` (loopback de ISP-1, destino a través de toda la red).
- Auth VRRP (`<VRRP_KEY>`) configurada igual en ambos DIST (si no coincide, DIST-2 no acepta los anuncios — ver §5.3 de la memoria).

## 3. Detección (cómo se detectaría en operación)

1. En DIST-1: `/interface vrrp print` → el grupo `vrrp-users` (vrid 10) está en `M` (master) con prioridad 150.
2. Señal de falla esperada al caer DIST-1: en el backup desaparecen los anuncios del master y el grupo pasa de `B` a `M`; el host ve pérdida de los primeros paquetes al gateway.

## 4. Respuesta (inyección de la falla)

En DIST-1 se deshabilita el grupo VRRP USERS (equivale funcionalmente a la caída del servicio de gateway en ese nodo):

```routeros
[admin@DIST-1] > /interface vrrp disable [find vrid=10]
```

**Verificación durante la falla:**

- DIST-1: `vrrp-users` queda con flag `X` (disabled); `vrrp-servers` sigue `B` (no se ve afectado).
- DIST-2: `vrrp-users` **deja de ser backup y asume el rol de master** del VRID 10 (la VIP `192.168.10.3` migra a DIST-2).
- PC-USER: el ping continuo a `1.1.1.1` sigue respondiendo tras la ventana de convergencia.

## 5. Recuperación

```routeros
[admin@DIST-1] > /interface vrrp enable [find vrid=10]
```

Al volver a habilitarse, DIST-1 recupera el master del VRID 10 (prioridad 150 > 100) y DIST-2 vuelve al rol `B` (backup). El ping continuo no se interrumpe en la vuelta a normalidad.

## 6. Resultado y tiempo medido

| Métrica | Valor |
|---|---|
| Paquetes transmitidos / recibidos (ping continuo a `1.1.1.1`) | 60 / 59 |
| Pérdida | **1 %** (1 paquete) |
| RTT min/avg/max | 6.835 / 66.276 / 955.861 ms |
| **Tiempo de failover estimado** | **≈ 1 s** (un solo paquete perdido, acorde al `interval=1s` de VRRP) |
| Impacto en el usuario | Un único timeout de ICMP; sin cortes de sesión |

## 7. Post-mortem

- **¿Por qué funcionó?** El grupo VRRP estaba correctamente parametrizado con prioridades distintas (150/100) y **auth simple compartida**: DIST-2 aceptó los anuncios del master y al dejar de recibirlos por `dead-interval` asumió la VIP sin intervención manual. La load-sharing (cada DIST master de un grupo) limitó el impacto al 50 % de las LANs: SERVERS no se vio afectada.
- **Aprendizajes:** conviene monitorear el estado master/backup (SNMP, §8 de la memoria) porque una caída del master es casi imperceptible para el usuario y nadie la reportaría; el preempt por prioridad garantiza el rebalanceo al volver el nodo original.

## 8. Evidencia

- Estado baseline y deshabilitación/habilitación del VRID 10 en DIST-1: [Drill1-CaidaMasterVRRP-A.png](../capturas/F4/Drill1-CaidaMasterVRRP-A.png)
- Reacción de DIST-2 (backup → master → backup): [Drill1-CaidaMasterVRRP-B.png](../capturas/F4/Drill1-CaidaMasterVRRP-B.png)
- Ping continuo desde PC-USER: [Drill1-CaidaMasterVRRP-C.png](../capturas/F4/Drill1-CaidaMasterVRRP-C.png)
- Estadísticas del ping (60 paquetes, 1 % de pérdida): [Drill1-CaidaMasterVRRP-D.png](../capturas/F4/Drill1-CaidaMasterVRRP-D.png)

## 9. Registro en change log / commit

Drill operativo: los comandos `disable`/`enable` son **temporales y se revirtieron en el acto** (no dejan cambio persistente en los `.rsc`). Quedan registrados en la memoria §6.1.5, con el detalle en `docs/memoria.md` §7.1. Evidencia versionada en el commit de runbooks/capturas F4.
