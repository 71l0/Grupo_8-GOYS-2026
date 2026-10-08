# 2026-10-08 17:37:03 by RouterOS 7.21.5
# system id = fbKbocHiiBD
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no name=ether9
set [ find default-name=ether2 ] disable-running-check=no name=ether10
set [ find default-name=ether3 ] disable-running-check=no name=ether11
set [ find default-name=ether4 ] disable-running-check=no name=ether12
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
add address=10.255.0.10/30 interface=ether9 network=10.255.0.8
add address=10.255.0.17/30 interface=ether10 network=10.255.0.16
add address=10.255.0.21/30 interface=ether11 network=10.255.0.20
add address=10.255.0.25/30 interface=ether12 network=10.255.0.24
add address=4.4.4.4 interface=lo network=4.4.4.4
/ip dhcp-client
# Interface not active
add interface=*2
/ip service
set ftp disabled=yes
set telnet disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
/ip ssh
set strong-crypto=yes
/system identity
set name=CORE-1
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none