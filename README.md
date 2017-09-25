tracebgp Muestra traza y los AS 
chmod +x tracebgp
uso: ./tracebgp IP

whois -h whois.radb.net -- '-i origin AS1849' | awk '/^route:/ {print $2;}' | sort | uniq

# www.hackingyseguridad.com 
# (c) hackingyseguridad .com 2017
