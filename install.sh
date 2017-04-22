#!/bin/sh
# instalador como comando de tracebgp
# Se instalara en /sbin/ para poder ser ejecutardo como un comando de Linux
apt-get install traceroute
chmod 777 tracebgp
cp tracebgp /sbin/
