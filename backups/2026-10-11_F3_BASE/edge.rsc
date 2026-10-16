# 2026-10-11 22:21:39 by RouterOS 7.21.5
# system id = ArGi4SUGx4B
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no name=ether9
set [ find default-name=ether2 ] disable-running-check=no name=ether10
set [ find default-name=ether3 ] disable-running-check=no name=ether11
set [ find default-name=ether4 ] disable-running-check=no name=ether12
/interface list
add name=WAN
/routing bgp instance
add as=65000 name=default router-id=3.3.3.3
/routing bgp template
add hold-time=1m30s keepalive-time=30s name=ebgp-peers routing-table=main
/routing ospf instance
add name=ospf-instance-1 originate-default=always router-id=3.3.3.3
/routing ospf area
add instance=ospf-instance-1 name=backbone-area
/user group
add name=monitor policy=ssh,read,test,winbox,!local,!telnet,!ftp,!reboot,!write,!policy,!password,!web,!sniff,!sensitive,!api,!romon,!rest-api
/ip neighbor discovery-settings
set discover-interface-list=none
/ip settings
set max-neighbor-entries=12288
/ipv6 settings
set max-neighbor-entries=6144 min-neighbor-entries=1536 soft-max-neighbor-entries=3072
/interface list member
add interface=ether9 list=WAN
add interface=ether10 list=WAN
/ip address
add address=192.168.1.1/24 interface=*2 network=192.168.1.0
add address=192.168.2.1/24 interface=*3 network=192.168.2.0
add address=10.255.0.1/30 interface=ether9 network=10.255.0.0
add address=10.255.0.5/30 interface=ether10 network=10.255.0.4
add address=10.255.0.9/30 interface=ether11 network=10.255.0.8
add address=10.255.0.13/30 interface=ether12 network=10.255.0.12
add address=3.3.3.3 interface=lo network=3.3.3.3
/ip dhcp-client
# Interface not active
add interface=*2
/ip firewall filter
add action=accept chain=input comment="Aceptar conexiones establecidas/relacionadas" connection-state=established,related
add action=accept chain=input comment="Permitir OSPF" protocol=ospf
add action=accept chain=input comment="Permitir ping/ICMP de gestion" protocol=icmp
add action=drop chain=input comment="Bloquear trafico no deseado desde WAN ISP-1" in-interface=ether9
add action=drop chain=input comment="Bloquear trafico no deseado desde WAN ISP-2" in-interface=ether10
add action=accept chain=forward comment="Aceptar establecido/relacionado" connection-state=established,related
add action=accept chain=forward comment="Aceptar trafico establecido/relacionado" connection-state=established,related
add action=accept chain=forward comment="Permitir salida de LANs a Internet" src-address=192.168.0.0/16
add action=drop chain=forward comment="Descartar paquetes invalidos" connection-state=invalid
add action=drop chain=forward comment="Bloquear trafico entrante no solicitado desde ISP-1" connection-nat-state=!dstnat in-interface=ether9
add action=drop chain=forward comment="Bloquear trafico entrante no solicitado desde ISP-2" connection-nat-state=!dstnat in-interface=ether10
add action=accept chain=input comment="Permitir SSH/Winbox desde la LAN interna" dst-port=22,8291 in-interface-list=!WAN protocol=tcp
/ip firewall nat
add action=masquerade chain=srcnat comment="NAT hacia ISP-1" out-interface=ether9
add action=masquerade chain=srcnat comment="NAT hacia ISP-2" out-interface=ether10
/ip service
set ftp disabled=yes
set telnet disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/ip ssh
set strong-crypto=yes
/routing bgp connection
add instance=default local.role=ebgp name=bgp-isp1 output.filter-chain=bgp-out-filter .redistribute=ospf remote.address=10.255.0.2/32 .as=65001 templates=ebgp-peers
add instance=default local.role=ebgp name=bgp-isp2 output.filter-chain=bgp-out-filter .redistribute=ospf remote.address=10.255.0.6/32 .as=65002 templates=ebgp-peers
/routing filter rule
add chain=bgp-out-filter rule="if (dst in 192.168.0.0/16) { accept }"
/routing ospf interface-template
add area=backbone-area auth=md5 auth-id=1 interfaces=ether11,ether12,lo
/system identity
set name=EDGE
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none