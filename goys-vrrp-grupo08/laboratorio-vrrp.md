# 🧪 Laboratorio VRRP — Redundancia de primer salto (paso a paso)

**Asignatura:** Gestión Operativa y Seguridad en Redes (GOYS) — UTN FR La Plata
**Simulador:** GNS3 · **MikroTik CHR (RouterOS 7)** · hosts Alpine
**Proyecto GNS3:** [`labs/portable/vrrp-mikrotik.gns3project`](../../labs/portable/vrrp-mikrotik.gns3project) (portable, con `chr-7.16.img` embebida)
**Inspirado en:** [Router Redundancy — VRRP Mikrotik (Step by Step)](https://youtu.be/h_r9FtR8ZUk) · Arawi Network Consulting

> Este lab es la **Capa 1 del mapa de failover** (FHRP) en estado puro, aislada del resto: dos routers, un gateway virtual, y la prueba de que "se cae el gateway y nadie se entera".

---

## 1. Objetivos y competencias

Al terminar, el alumno será capaz de:

1. **Configurar** VRRP entre dos routers MikroTik (VRID, prioridad, IP virtual).
2. **Explicar** el rol de la IP virtual y por qué el host no cambia su gateway.
3. **Verificar** el failover: matar el master y comprobar que el backup toma el gateway.
4. **Entender** la limitación: VRRP cubre la caída del gateway, no la del *uplink*.

---

## 2. Topología

```
        [ INTERNET ]  ← cloud GNS3 (da IP por DHCP + NAT)
              │
          Switch1 (WAN)
        ┌─────┴─────┐
   R1.ether1    R2.ether1        ← DHCP client + masquerade
   ┌────────┐   ┌────────┐
   │  R1    │   │  R2    │       ← VRRP VRID 100
   │ master │   │ backup │
   └────────┘   └────────┘
        │  ether2   │
        └─────┬─────┘
          Switch2 (LAN 10.1.2.0/24)
        ┌─────┼─────┬─────┐
    Alpine-1 Alpine-2  WinBox
```

| Nodo | Dispositivo GNS3 | Rol |
|------|------------------|-----|
| INTERNET | Cloud (NAT) | Da WAN por DHCP a R1 y R2 |
| R1 | CHR (`chr-7.16.img`) | Router — **master** VRRP |
| R2 | CHR (`chr-7.16.img`) | Router — **backup** VRRP |
| Switch1 / Switch2 | ethernet_switch | WAN / LAN |
| Alpine-1, Alpine-2 | Docker `alpine:latest` | Hosts de prueba |
| WinBox | Docker `gns3/mikrotik-winbox` | Gestión GUI (opcional) |

---

## 3. Plan de direccionamiento

| Dispositivo | Interfaz | IP | Nota |
|-------------|----------|-----|------|
| R1 | ether1 (WAN) | **DHCP** (cloud) | + masquerade |
| R1 | ether2 (LAN) | 10.1.2.1/24 | |
| R1 | vrrp1 | **10.1.2.254/32** | VRID 100 · priority **200** (master) |
| R2 | ether1 (WAN) | **DHCP** (cloud) | + masquerade |
| R2 | ether2 (LAN) | 10.1.2.2/24 | |
| R2 | vrrp1 | **10.1.2.254/32** | VRID 100 · priority **100** (backup) |
| Alpine-1 | eth0 | 10.1.2.100/24 | gateway 10.1.2.254 |
| Alpine-2 | eth0 | 10.1.2.101/24 | gateway 10.1.2.254 |

> La IP virtual `10.1.2.254` es el **default gateway** de los hosts. Los hosts **nunca** apuntan a `.1` ni a `.2`.

---

## 4. Configuración (RouterOS 7)

### 4.1 R1 (master)

```routeros
/system identity set name=R1

# WAN — ether1 (cloud, DHCP)
/ip dhcp-client add interface=ether1 disabled=no

# LAN — ether2 (segmento VRRP)
/ip address add address=10.1.2.1/24 interface=ether2

# VRRP — VRID 100, priority 200 (master)
/interface vrrp add interface=ether2 vrid=100 priority=200
/ip address add address=10.1.2.254/32 interface=vrrp1

# NAT — masquerade LAN → WAN (Internet)
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade
```

### 4.2 R2 (backup)

```routeros
/system identity set name=R2

# WAN — ether1 (cloud, DHCP)
/ip dhcp-client add interface=ether1 disabled=no

# LAN — ether2 (segmento VRRP)
/ip address add address=10.1.2.2/24 interface=ether2

# VRRP — VRID 100, priority 100 (backup)
/interface vrrp add interface=ether2 vrid=100 priority=100
/ip address add address=10.1.2.254/32 interface=vrrp1

# NAT — masquerade LAN → WAN (Internet)
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade
```

### 4.3 Hosts (Alpine)

```bash
# AlpineLinux-1
ip addr add 10.1.2.100/24 dev eth0
ip route add default via 10.1.2.254
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# AlpineLinux-2
ip addr add 10.1.2.101/24 dev eth0
ip route add default via 10.1.2.254
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

---

## 5. Verificación y test de failover

### 5.1 Verificar estado

```routeros
# En R1 y R2: el WAN levantó por DHCP
/ip dhcp-client print      → status=bound
/ip address print          → WAN (ether1) + LAN (ether2) + vrrp1

# Quién es master
/interface vrrp print      → R1 flag "RM" (running+master) · R2 flag "B" (backup)
```

### 5.2 Conectividad e Internet

```bash
# En Alpine-1
ping 10.1.2.1               # llega al router R1 (IP real)
ping 10.1.2.254             # llega al gateway VIRTUAL
ping 8.8.8.8                # sale a Internet (por R1, master)
traceroute 8.8.8.8          # ves el salto 10.1.2.254
```

### 5.3 El failover (el momento clave)

```bash
# En Alpine-1: ping 8.8.8.8 CONTINUO
```

```routeros
# En R1: tirar abajo el enlace LAN
/interface disable ether2
```

- R2 pasa a **master** (`/interface vrrp print` en R2 → `RM`).
- El ping **sigue respondiendo** (< 3 s): ahora el tráfico sale por R2.

```routeros
# En R1: volver
/interface enable ether2
```

- R1 retoma master (preemption `yes`, porque 200 > 100).

---

## 6. ¿Qué está pasando realmente?

- La **MAC virtual** es `00:00:5E:00:01:64` (VRID 100 = 0x64). R1 y R2 responden a **la misma** IP+MAC virtual.
- El host manda al gateway `10.1.2.254`; quién responde (R1 o R2) le es **transparente**.
- Por eso el host **no se entera** de la falla: cambia quién responde, no el gateway.

---

## 7. ⚠️ El gotcha que hay que llevarse

VRRP **solo** failoverea cuando cae el **enlace LAN** (ether2). Si cae el **WAN de R1** (ether1) pero su LAN sigue vivo:

- R1 **sigue siendo master** (su ether2 sigue up).
- Los hosts siguen mandando al gateway virtual… y **se quedan sin Internet**, aunque R2 esté sano.

> **Conclusión:** VRRP cubre la caída del *gateway*, pero para la caída del *uplink* necesitás tracking (`check-gateway` / IP SLA + object tracking). Ese es exactamente el caso de la **Capa 2 del mapa de failover** que vimos en la clase. No lo agregamos acá (el lab es VRRP puro, como el video), pero es la pregunta natural que sigue.

---

## 8. Preguntas de reflexión

1. ¿Por qué el host apunta a `10.1.2.254` y no a `10.1.2.1`?
2. ¿Qué pasa con la MAC virtual durante el failover? ¿Cambia?
3. ¿Cuál es la diferencia con HSRP? (RFC 5798 vs RFC 2281 — propietario vs estándar abierto)
4. ¿Qué limitación tiene VRRP solo, y cómo la resolverías?

---

## 📎 Referencias

- [Router Redundancy — VRRP Mikrotik (Step by Step)](https://youtu.be/h_r9FtR8ZUk) — Arawi Network Consulting
- [VRRP Explained](https://youtu.be/Kl3jSFbVMTE) — NetWorks
- RFC 5798 — Virtual Router Redundancy Protocol (VRRP) v3
- RFC 2281 — Cisco HSRP
- MikroTik Wiki: [VRRP Configuration Examples](https://help.mikrotik.com/docs/spaces/ROS/pages/128221211/VRRP+Configuration+Examples)
