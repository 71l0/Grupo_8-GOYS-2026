# 2026-10-08 18:00:00 by RouterOS 7.21.5
# system id = kzKYW7eIQ5J
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no name=ether9
set [ find default-name=ether2 ] disable-running-check=no name=ether10
set [ find default-name=ether3 ] disable-running-check=no name=ether11
set [ find default-name=ether4 ] disable-running-check=no name=ether12
/interface vlan
add interface=ether11 name=vlan10 vlan-id=10
add interface=ether12 name=vlan20 vlan-id=20
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
add address=10.255.0.26/30 interface=ether9 network=10.255.0.24
add address=10.255.0.34/30 interface=ether10 network=10.255.0.32
add address=192.168.10.3/24 interface=vlan10 network=192.168.10.0
add address=192.168.20.3/24 interface=vlan20 network=192.168.20.0
add address=7.7.7.7 interface=lo network=7.7.7.7
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
set name=DIST-2
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none