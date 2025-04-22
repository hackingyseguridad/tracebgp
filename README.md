## tracebgp Muestra los saltos de la ruta y los AS de la traza 

chmod +x tracebgp

uso: ./tracebgp IP

whois -h whois.radb.net -- '-i origin AS1849' | awk '/^route:/ {print $2;}' | sort | uniq



http://www.hackingyseguridad.com/


