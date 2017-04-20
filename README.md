traceroute-BGP
==============

A bash script that shows AS Info on top of the standard traceroute <br>

It should be simple enough to figure out how to use.

whois -h whois.radb.net -- '-i origin AS1849' | awk '/^route:/ {print $2;}' | sort | uniq
