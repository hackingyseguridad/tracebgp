#!/bin/sh
# instalador como comando de tracebgp
# Se instalara en /sbin/ para poder ser ejecutardo como un comando de Linux
apt-get install traceroute whois
chmod 777 bgp2ip
chmod 777 ip2bgp
chmod 777 tracebgp
cp bgp2ip /sbin/
cp ip2bgp /sbin/
cp tracebgp /sbin/
