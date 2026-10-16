# 2026-10-11 22:21:04 by RouterOS 7.21.5
# system id = jzT+RnJwg8M
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no name=ether9
set [ find default-name=ether2 ] disable-running-check=no name=ether10
set [ find default-name=ether3 ] disable-running-check=no name=ether11
set [ find default-name=ether4 ] disable-running-check=no name=ether12
/routing bgp instance
add as=65002 name=default router-id=2.2.2.2
/routing bgp template
add name=ebgp-edge routing-table=main
/user group
add name=monitor policy=ssh,read,test,winbox,!local,!telnet,!ftp,!reboot,!write,!policy,!password,!web,!sniff,!sensitive,!api,!romon,!rest-api
/ip neighbor discovery-settings
set discover-interface-list=none
/ip settings
set max-neighbor-entries=12288
/ipv6 settings
set max-neighbor-entries=6144 min-neighbor-entries=1536 soft-max-neighbor-entries=3072
/ip address
add address=192.168.1.1/24 interface=*2 network=192.168.1.0
add address=192.168.2.1/24 interface=*3 network=192.168.2.0
add address=10.255.0.6/30 interface=ether9 network=10.255.0.4
add address=2.2.2.2 interface=lo network=2.2.2.2
/ip service
set ftp disabled=yes
set telnet disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/ip ssh
set strong-crypto=yes
/routing bgp connection
add instance=default local.role=ebgp name=bgp-edge output.redistribute=connected remote.address=10.255.0.5/32 .as=65000 templates=ebgp-edge
/system identity
set name=ISP-2
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none