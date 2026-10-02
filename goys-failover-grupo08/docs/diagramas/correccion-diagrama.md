# Corrección del diagrama

Diagrama analizado: "Enterprise Network Design (Cisco)", el que vimos en clase. Le encontramos 5 defectos. Esta tabla va en la sección 1.1 de la memoria.

| # | Defecto detectado | Corrección aplicada | Justificación |
|:-:|-------------------|---------------------|---------------|
| 1 | Hay un solo firewall (ASA 5506-X) entre el edge y el core, sin par HA. Es un punto único de falla. | En el lab no hay firewall aparte, el filtrado lo hace EDGE. Dejamos documentado que en una red real tienen que ser dos firewalls en failover (activo/standby). | Los ISR y los ISP están duplicados, pero todo el tráfico pasa por un único ASA. Si se cae, se corta la salida igual y la redundancia de arriba no sirve de nada. En el lab pasa algo parecido con EDGE, que también es uno solo; en producción irían dos. |
| 2 | Subredes repetidas entre sitios: las VLAN 10 y 20 están en el Site 1 y en el Site 2, y la 192.168.10.0/24 aparece dos veces. | Plan de direccionamiento sin solapamientos: cada enlace y cada LAN con su propia red (ver IPAM). | Si la misma red está en dos lugares, al interconectar los sitios el router no sabe a cuál mandar el paquete. OSPF y BGP la anuncian desde dos puntos y el tráfico termina en el sitio equivocado o se pierde. |
| 3 | Entre C1 y C2 (los dos Nexus del core) no hay enlace. | Agregamos el enlace CORE-1 ↔ CORE-2 y corre OSPF área 0 sobre él. | Si se corta EDGE ↔ CORE-1, CORE-1 se queda sin camino directo hacia arriba y el tráfico tiene que bajar a distribución para volver a subir por CORE-2. Con el enlace core-core pasa directo al otro core y OSPF tiene una ruta alternativa corta. |
| 4 | HSRP en el core (VLAN 10, 20 y 30 en los Nexus 9300). Es un diseño "collapsed": el core hace también de gateway de los usuarios. | El gateway pasa a distribución con VRRP entre DIST-1 y DIST-2. El core queda solo para rutear (tránsito puro). | El core tiene que hacer una sola cosa y hacerla rápido. Si además es gateway, un problema de una LAN (ARP, broadcast, cambio de master) termina afectando al equipo del que depende toda la red. En distribución el problema queda en esa capa. Usamos VRRP y no HSRP porque VRRP es estándar (RFC 5798) y HSRP es de Cisco (RFC 2281); en MikroTik no existe HSRP. |
| 5 | El iBGP con route reflector está mal ubicado: la sesión aparece entre las interfaces outside del ASA, atravesando el firewall. | Sin iBGP y sin route reflector. BGP corre solo en EDGE (AS 65000), como eBGP hacia ISP-1 (AS 65001) e ISP-2 (AS 65002). Adentro se usa OSPF. | Un route reflector sirve cuando hay muchos routers iBGP en el mismo AS y no querés hacer full-mesh. Acá hay un solo router de borde, no hay nada que reflejar. Además, si el RR existiera tendría que estar en los routers de borde, no del otro lado del firewall. BGP queda para hablar con los proveedores y OSPF para adentro. |

## Otras cosas que vimos

En el análisis también aparecen problemas que no son de ruteo: no hay QoS para voz, no hay VLAN de gestión y faltan protecciones de capa 2 (port-security, DHCP snooping, DAI, root guard). No los corregimos porque en este lab el acceso es un switch simple sin VLANs, pero los anotamos.

El diagrama corregido está en [`topologia-corregida.md`](topologia-corregida.md).
