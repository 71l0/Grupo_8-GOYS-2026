# Política de seguridad — Grupo 8

> Laboratorio Failover Routing · GOYS · UTN FRLP
> Corresponde a la sección **1.3** de la memoria (Epic F0).
> Alcance: los **7 routers CHR** (ISP-1, ISP-2, EDGE, CORE-1, CORE-2, DIST-1, DIST-2), RouterOS 7.

Principio rector: **mínimo privilegio y mínima superficie de ataque**. Cada usuario tiene solo los permisos que necesita, cada servicio que no se usa se apaga, y todo protocolo de control (OSPF, BGP, VRRP) se autentica para que ningún equipo no autorizado pueda inyectar rutas o tomar el gateway.

---

## 1. Usuarios y privilegios

| Usuario | Grupo | Permisos | Uso |
|---------|-------|----------|-----|
| `admin` | `full` | Total | Configuración. Password obligatoria, distinta de la de fábrica (vacía) |
| `monitor` | `monitor` (custom) | Solo lectura: `read`, `test`, `ssh`, `winbox` | Consultas de estado, verificación de drills, monitoreo |

Reglas:

- **Password de `admin`**: mínimo 12 caracteres. CHR viene con `admin` sin password, por eso es lo primero que se configura al levantar cada router.
- **`monitor` no puede** escribir config, reiniciar, cambiar passwords, ver datos sensibles (`!sensitive`) ni usar `ftp`, `telnet`, `web`, `api` o `sniff`.
- No se crean más usuarios con grupo `full`.

```routeros
/user set admin password=<ADMIN_PASS>
/user group add name=monitor policy=read,test,ssh,winbox,!local,!telnet,!ftp,!reboot,!write,!policy,!password,!web,!sniff,!sensitive,!api,!romon,!rest-api
/user add name=monitor group=monitor password=<MONITOR_PASS>
```

---

## 2. Servicios a deshabilitar

### 2.1 Servicios de gestión (`/ip service`)

| Servicio | Puerto | Decisión | Motivo |
|----------|:------:|:--------:|--------|
| telnet | 23 | Apagar | Texto plano, credenciales visibles en la red |
| ftp | 21 | Apagar | Texto plano; no se usa |
| www | 80 | Apagar | WebFig sin cifrar; no se usa |
| www-ssl | 443 | Apagar | No se usa |
| api | 8728 | Apagar | No se usa |
| api-ssl | 8729 | Apagar | No se usa |
| ssh | 22 | Mantener | Gestión cifrada |
| winbox | 8291 | Mantener | Gestión GUI |

SSH y Winbox se restringen a redes internas en F3, con el firewall del EDGE.

```routeros
/ip service disable telnet,ftp,www,www-ssl,api,api-ssl
/ip ssh set strong-crypto=yes
```

### 2.2 Otros servicios y descubrimiento

| Servicio | Decisión | Motivo |
|----------|:--------:|--------|
| Neighbor discovery (MNDP/CDP/LLDP) | Apagar | Revela identidad, modelo y versión a cualquier vecino |
| MAC-Telnet / MAC-Winbox | Apagar | Acceso de capa 2 que no pasa por el firewall IP |
| Bandwidth test server | Apagar | Se puede usar para saturar el router |
| DNS remoto | Apagar | Evita que el router sea resolver abierto |
| Proxy / SOCKS / UPnP | Apagar | No se usan |
| IP Cloud (DDNS) | Apagar | No se usa; hace conexiones salientes |
| SNMP | Apagado hasta F4 | Se habilita en F4 para monitoreo, solo lectura y con community propia (no `public`) |

```routeros
/ip neighbor discovery-settings set discover-interface-list=none
/tool mac-server set allowed-interface-list=none
/tool mac-server mac-winbox set allowed-interface-list=none
/tool bandwidth-server set enabled=no
/ip dns set allow-remote-requests=no
/ip proxy set enabled=no
/ip socks set enabled=no
/ip upnp set enabled=no
/ip cloud set ddns-enabled=no update-time=no
```

> ⚠️ Si alguien gestiona por **Winbox vía MAC** dentro de GNS3, apagar MAC-Winbox lo deja afuera. Conectarse por IP (Winbox o SSH) o por la consola de GNS3, que no se ve afectada.

---

## 3. Claves de autenticación del plano de control

### 3.1 Resumen

| Protocolo | Mecanismo | Dónde | Alcance de la clave | Responsable |
|-----------|-----------|-------|---------------------|-------------|
| OSPF | MD5 (key-id 1) | EDGE, CORE-1, CORE-2, DIST-1, DIST-2 | Una clave para todo el área 0 | R3 (con R1 y R4) |
| BGP | TCP-MD5 (RFC 2385) | EDGE ↔ ISP-1, EDGE ↔ ISP-2 | Una clave **distinta por sesión** | R1 + R2 |
| VRRP | Simple (VRRPv2) | DIST-1 ↔ DIST-2 | Una clave **por grupo** (vrid 10 y vrid 20) | R4 |

Criterio:

- **OSPF**: una sola clave en el área es suficiente porque todos los routers pertenecen al mismo dominio administrativo.
- **BGP**: cada sesión es una relación con otra organización (cada ISP). Si la clave de un proveedor se filtra, la sesión con el otro sigue protegida.
- **VRRP**: una clave por grupo, para que un error de configuración en un grupo no afecte al otro.

### 3.2 Convención de claves

| Clave | Identificador | Requisito |
|-------|---------------|-----------|
| `<OSPF_KEY>` | OSPF área 0 | Hasta 16 caracteres (límite de MD5 en OSPF) |
| `<BGP_KEY_ISP1>` | Sesión EDGE ↔ ISP-1 | ≥ 12 caracteres |
| `<BGP_KEY_ISP2>` | Sesión EDGE ↔ ISP-2 | ≥ 12 caracteres, distinta de la de ISP-1 |
| `<VRRP_KEY_10>` | VRRP vrid 10 (USERS) | **Máximo 8 caracteres** (límite de VRRPv2) |
| `<VRRP_KEY_20>` | VRRP vrid 20 (SERVERS) | Máximo 8 caracteres |

**Las claves reales no se commitean al repo.** En los `.rsc` y en la memoria se usan los placeholders de la tabla. Las claves reales se comparten por un canal privado del grupo y se le pasan al docente si las pide.

### 3.3 Configuración de referencia

**OSPF MD5:** se aplica en el interface-template de cada router OSPF.

```routeros
/routing ospf interface-template set [find] auth=md5 auth-id=1 auth-key=<OSPF_KEY>
```

**BGP TCP-MD5:** en EDGE y en el ISP correspondiente, con la misma clave en ambos extremos.

```routeros
# EDGE
/routing bgp connection set [find name=to-isp1] tcp-md5-key=<BGP_KEY_ISP1>
/routing bgp connection set [find name=to-isp2] tcp-md5-key=<BGP_KEY_ISP2>
```

**VRRP auth:** en DIST-1 y DIST-2.

```routeros
/interface vrrp set [find vrid=10] version=2 authentication=simple password=<VRRP_KEY_10>
/interface vrrp set [find vrid=20] version=2 authentication=simple password=<VRRP_KEY_20>
```

> ⚠️ **VRRPv3 (RFC 5798), que es el default de RouterOS 7, no soporta autenticación.** El RFC la eliminó porque una clave simple viaja en texto plano y no aporta seguridad real. Para cumplir la consigna se usa **VRRPv2 (RFC 3768) con auth simple**. Conviene saberlo para la defensa: la auth simple de VRRP evita errores de configuración (un router mal configurado que se suma al grupo), pero no frena a un atacante que capture el tráfico.

---

## 4. Relación con backups

- `/export` en RouterOS 7 **oculta los datos sensibles por defecto**: passwords y claves no aparecen. Por eso los `/export` del directorio `backups/` se pueden versionar sin filtrar claves.
- Al restaurar desde un `/export` hay que **volver a cargar las claves** a mano.
- Los archivos binarios de `/system backup save` sí contienen las claves. Se guardan **con password** (`password=`) y **no se commitean** (van en `.gitignore`).

---

## 5. Verificación (F1 y F4)

| Control | Cómo se verifica | Resultado esperado |
|---------|------------------|--------------------|
| Password admin | Login sin password | Rechazado |
| Usuario `monitor` | Login como `monitor` + `/system identity set name=x` | Lee config, **no** puede escribir |
| Servicios | `/ip service print` | Solo `ssh` y `winbox` habilitados |
| OSPF MD5 | Cambiar `auth-key` en un vecino | Adyacencia cae (no llega a FULL) |
| BGP TCP-MD5 | Cambiar `tcp-md5-key` en un extremo | Sesión no llega a established |
| VRRP auth | Cambiar `password` en DIST-2 | Los dos routers no se reconocen: ambos pasan a master (comportamiento a documentar) |

Las tres últimas son la **prueba obligatoria de clave incorrecta** del Epic F4 y se documentan con captura en la sección 5 de la memoria.