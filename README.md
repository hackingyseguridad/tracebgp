### tracebgp — Traceroute enriquecido con información BGP/AS

**tracebgp** es una pequeña suite de utilidades en Bash que combina `traceroute` con consultas **whois** a bases de datos de enrutamiento (RADB y Team Cymru) para enriquecer cada salto de una traza con el **Sistema Autónomo (AS)** al que pertenece, y para moverte libremente entre una IP, su AS y los rangos de red que ese AS anuncia en BGP.

En una traza de red normal solo ves IPs. Con **tracebgp** ves, además, **de qué operador u organización es cada salto**, lo cual es muy útil para:

- Diagnosticar por qué el tráfico "sale" hacia un proveedor concreto.
- Detectar cambios de ruta o *hijacks* de BGP.
- Investigar la infraestructura de un objetivo en labores de reconocimiento de red.
- Entender la topología de Internet en cualquier traceroute.

> Proyecto de [hackingyseguridad.com](http://www.hackingyseguridad.com)

---

### Tabla de contenidos

1. [Características](#-características)
2. [Scripts incluidos](#-scripts-incluidos)
3. [Cómo encajan las piezas](#-cómo-encajan-las-piezas)
4. [¿Cómo funciona traceroute?](#-cómo-funciona-traceroute)
5. [Opciones del comando traceroute en Linux](#-opciones-del-comando-traceroute-en-linux)
6. [Requisitos](#-requisitos)
7. [Instalación](#-instalación)
8. [Uso](#-uso)
9. [Ejemplos de salida](#-ejemplos-de-salida)
10. [Fuentes de datos (whois)](#-fuentes-de-datos-whois)
11. [Aviso legal y buenas prácticas](#-aviso-legal-y-buenas-prácticas)
12. [Licencia](#-licencia)

---

### Características

- Traceroute salto a salto anotado con el **AS de origen** de cada IP intermedia.
- Resolución automática del **nombre/descripción del AS** vía Team Cymru whois.
- Consulta inversa: a partir de una IP pública, obtén su AS y país (`ip2bgp`).
- Consulta de prefijos: a partir de un número de AS, lista **todos los rangos IPv4/IPv6** (`route:`/`route6:`) que ese AS anuncia en RADB (`bgp2ip`).
- Instalación en un solo paso como comandos globales del sistema.
- Sin dependencias exóticas: solo `bash`, `traceroute` y `whois`.

---

### Scripts 

| Script | Entrada | Qué hace | Fuente de datos consultada |
|---|---|---|---|
| `tracebgp` | Una IP o *host* destino | Ejecuta `traceroute -A` y añade a cada salto con AS visible el nombre/descripción de ese AS | `whois.cymru.com` |
| `ip2bgp` | Una IP pública | Devuelve el AS y el país al que pertenece esa IP | `ip-api.com` |
| `bgp2ip` | Un número de AS (ej. `AS1849`) | Lista todos los rangos de red (IPv4 y IPv6) anunciados por ese AS | `whois.radb.net` (RADB) |
| `instalar.sh` | — | Instala las dependencias (`traceroute`, `whois`) y copia los tres comandos a `/sbin/` | — |

---

### Cómo funciona

```
                 ┌───────────────────────┐
                 │   1. tracebgp <IP>     │
                 │  traceroute -A + AS    │
                 └──────────┬────────────┘
                            │ obtienes una IP intermedia / su AS
                            ▼
                 ┌───────────────────────┐
                 │   2. ip2bgp <IP>       │
                 │   IP → AS + país       │
                 └──────────┬────────────┘
                            │ obtienes el número de AS
                            ▼
                 ┌───────────────────────┐
                 │   3. bgp2ip <AS>       │
                 │  AS → todos sus rangos │
                 │     IPv4 / IPv6        │
                 └───────────────────────┘
```

Un flujo típico de investigación de red sería: lanzar `tracebgp` hacia un destino → identificar un salto interesante → resolver su AS con `ip2bgp` → listar con `bgp2ip` todo el rango de direcciones que pertenece a ese operador.

---

### Cómo funciona traceroute

`tracebgp` es en el fondo una capa encima de `traceroute -A`, así que entender el mecanismo interno de `traceroute` ayuda a interpretar correctamente cada salto de la traza.

### El truco del TTL (Time To Live)

Todo paquete IP lleva un campo **TTL** (Time To Live) que se decrementa en 1 cada vez que atraviesa un router. Cuando el TTL llega a 0, el router que lo tiene en ese momento **descarta el paquete** y responde al origen con un mensaje ICMP **"Time Exceeded"** (tipo 11). `traceroute` explota justo este comportamiento:

1. Envía un primer paquete de sondeo con **TTL = 1**. El primer router en la ruta lo descarta y devuelve un ICMP Time Exceeded → así se descubre el **salto 1**.
2. Envía otro paquete con **TTL = 2**. Esta vez es el segundo router quien lo descarta → se descubre el **salto 2**.
3. Repite incrementando el TTL en 1 en cada ronda, hasta que un paquete llega finalmente al destino (o se alcanza el número máximo de saltos configurado).
4. Cuando el paquete sí llega al destino final, este responde de forma distinta según el tipo de sondeo usado (ver más abajo), lo que le indica a `traceroute` que la traza ha terminado.

```
TTL=1 ───▶ [Router 1] ──X (descarta, TTL=0) ──▶ ICMP Time Exceeded ──▶ origen
TTL=2 ───▶ [Router 1] ──▶ [Router 2] ──X ──▶ ICMP Time Exceeded ──▶ origen
TTL=3 ───▶ [Router 1] ──▶ [Router 2] ──▶ [Router 3] ──X ──▶ ICMP Time Exceeded ──▶ origen
  ⋮
TTL=n ───▶ ... ──▶ [Destino] ──▶ respuesta final ──▶ origen
```

Por cada valor de TTL, `traceroute` envía por defecto **3 sondeos** (configurable con `-q`) y mide el **RTT** (tiempo de ida y vuelta) de cada uno; de ahí que en la salida clásica se vean 3 tiempos por línea. Un `*` en lugar de un tiempo significa que ese sondeo concreto no obtuvo respuesta antes de agotarse el tiempo de espera (por ejemplo, porque un firewall intermedio filtra ICMP o el tráfico del sondeo).

### Tipo de paquete de sondeo

El comportamiento anterior es independiente del tipo de paquete usado para "sondear" cada salto; en Linux, `traceroute` puede enviar tres tipos distintos:

| Tipo de sondeo | Opción | Comportamiento | Cuándo usarlo |
|---|---|---|---|
| **UDP** (por defecto) | *(ninguna, o `-U`)* | Envía datagramas UDP a un puerto alto poco probable de estar abierto; el destino final responde con ICMP "Port Unreachable", lo que señala el final de la traza | Uso general; es el método clásico de Unix |
| **ICMP Echo** | `-I` | Igual que un `ping`; el destino final responde con ICMP Echo Reply | Redes donde el UDP está filtrado pero el ICMP sí pasa |
| **TCP SYN** | `-T` | Envía un SYN a un puerto (por defecto el 80); el destino responde con SYN-ACK o RST | Muy útil para atravesar firewalls que solo permiten tráfico "tipo web" (equivalente al comportamiento de herramientas como `tcptraceroute`) |

`tracebgp` no fija ninguno de estos modos explícitamente, por lo que usa el método **UDP por defecto** de `traceroute`, además de activar la resolución de AS con `-A` (ver siguiente sección).

### ¿Por qué a veces aparecen asteriscos (`* * *`)?

- Un router intermedio tiene ICMP deshabilitado o limitado por *rate-limiting*.
- Existe un firewall que descarta silenciosamente el tipo de paquete de sondeo usado.
- El salto no decrementa el TTL de forma visible (algunos equipos de MPLS "esconden" saltos internos).
- Hay pérdida de paquetes real en la red en ese tramo.

---

### Opciones del comando traceroute en Linux

La implementación de `traceroute` que trae por defecto la mayoría de distribuciones Linux (Debian/Ubuntu/Kali, paquete `traceroute`) admite muchas más opciones que el uso básico. Estas son las más relevantes:

| Opción | Descripción |
|---|---|
| `-4` / `-6` | Fuerza el uso de IPv4 o IPv6 |
| `-I` | Usa sondeos **ICMP ECHO** en lugar de UDP |
| `-T` | Usa sondeos **TCP SYN** en lugar de UDP |
| `-U` | Usa sondeos **UDP** explícitamente (comportamiento por defecto) |
| `-A` | **Resuelve el Sistema Autónomo (AS)** de cada salto mediante whois — *esta es la opción que usa `tracebgp`* |
| `-n` | No resuelve nombres DNS: muestra solo direcciones IP (traza más rápida) |
| `-m <max_ttl>` | Número máximo de saltos a explorar (por defecto 30) |
| `-f <first_ttl>` | TTL inicial desde el que empezar a trazar (por defecto 1); útil para omitir saltos ya conocidos |
| `-q <nqueries>` | Número de sondeos enviados por cada salto (por defecto 3) |
| `-w <waittime>` | Tiempo máximo de espera de respuesta por sondeo, en segundos |
| `-z <sendwait>` | Tiempo mínimo entre sondeos consecutivos (para no saturar la red) |
| `-p <port>` | Puerto de destino de los sondeos (UDP) o puerto base (TCP) |
| `-i <device>` | Interfaz de red por la que enviar los sondeos |
| `-s <src_addr>` | Dirección IP de origen a usar en los sondeos |
| `-g <gateway>` | Ruta de origen laxa (*loose source routing*) a través de una o varias puertas de enlace |
| `-N <squeries>` | Número de sondeos enviados en paralelo (acelera la traza) |
| `-t <tos>` | Valor de Type of Service / DSCP a usar en los paquetes |
| `-F` | Envía los paquetes con el bit *Don't Fragment* activado |
| `-M <module>` | Selecciona explícitamente el método de sondeo (`icmp`, `udp`, `tcp`, `raw`, `dccp`) |
| `-V` | Muestra la versión del programa |
| `--help` | Muestra la ayuda resumida de opciones |

> ⚠️ **Nota sobre `-h`:** en la implementación estándar de `traceroute` en Linux **no existe** una opción `-h` para pedir ayuda (se usa `--help`); en cambio, sí existe una opción `-h` en el `tracert` de Windows y en algunas variantes tipo BSD, donde equivale a fijar el número máximo de saltos (lo mismo que `-m` en Linux). Conviene no confundir ambas convenciones al migrar comandos entre sistemas operativos.

### `tracebgp` usa `-A`

El script `tracebgp` de este repositorio invoca internamente `traceroute -A "$1"`. La opción `-A` hace que, por cada salto en el que la IP responde, `traceroute` intente automáticamente identificar el **AS de origen** de esa IP y lo muestre entre corchetes junto a la dirección (p. ej. `[AS15169]`). `tracebgp` toma esa información en bruto y la enriquece más todavía, sustituyendo el número de AS por su **nombre/descripción real** obtenido de Team Cymru, de modo que en vez de ver solo `AS15169` veas directamente `AS15169:GOOGLE`.

---

### Requisitos

| Requisito | Detalle |
|---|---|
| Sistema operativo | Linux (Debian/Ubuntu/Kali u otras distros con `apt-get`) |
| Shell | `bash` |
| Paquete `traceroute` | Necesario para `tracebgp` (traza con soporte de AS, opción `-A`) |
| Paquete `whois` | Necesario para `tracebgp` y `bgp2ip` (consultas whois a RADB y Cymru) |
| `curl` | Necesario para `ip2bgp` |
| Conexión a Internet | Imprescindible: todo el valor añadido viene de consultas whois/API externas en tiempo real |
| Permisos de escritura en `/sbin/` | Necesarios solo si usas `instalar.sh` (normalmente vía `sudo`) |

---

### Instalación

### Opción 1 — Clonar e instalar como comandos del sistema

```bash
git clone https://github.com/hackingyseguridad/tracebgp.git
cd tracebgp
sudo sh instalar.sh
```

`instalar.sh` hace tres cosas:

1. Instala las dependencias con `apt-get install traceroute whois`.
2. Da permisos de ejecución a los tres scripts.
3. Copia `bgp2ip`, `ip2bgp` y `tracebgp` a `/sbin/`, dejándolos disponibles como comandos globales.

### Opción 2 — Uso puntual sin instalar

```bash
git clone https://github.com/hackingyseguridad/tracebgp.git
cd tracebgp
chmod +x tracebgp bgp2ip ip2bgp
./tracebgp 8.8.8.8
```

> Si solo quieres probar el script una vez, no hace falta instalarlo ni tener privilegios de root: basta con darle permisos de ejecución y llamarlo con `./`.

---

### Uso

```bash
tracebgp <IP_o_host>     # traza con AS resuelto en cada salto
ip2bgp <IP>               # AS y país de una IP concreta
bgp2ip <AS>                # todos los rangos de red de un AS (ej: AS15169)
```

### Tabla rápida de sintaxis

| Comando | Sintaxis | Ejemplo |
|---|---|---|
| `tracebgp` | `tracebgp <IP\|host>` | `tracebgp 8.8.8.8` |
| `ip2bgp` | `ip2bgp <IP>` | `ip2bgp 8.8.8.8` |
| `bgp2ip` | `bgp2ip <AS>` | `bgp2ip AS15169` |

---

### Ejemplos 

### `tracebgp` — traza con AS resuelto

```text
$ tracebgp 8.8.8.8
 1  192.168.1.1  0.5 ms
 2  10.10.10.1  4.2 ms
 3  203.0.113.1 [AS1234:NombreDelOperador]  8.1 ms
 4  198.51.100.7 [AS15169:GOOGLE]  12.3 ms
 5  8.8.8.8 [AS15169:GOOGLE]  14.0 ms
```

*(salida ilustrativa; el número y contenido exacto de los saltos depende de la ruta real de red)*

### `ip2bgp` — IP → AS y país

```text
$ ip2bgp 8.8.8.8
AS15169 | US
```

### `bgp2ip` — AS → rangos de red anunciados

```text
$ bgp2ip AS15169
Uso: ./bgp2ip AS
8.8.8.0/24
8.8.4.0/24
2001:4860::/32
...
```

---

## 🗄️ Fuentes de datos (whois)

| Fuente | Usada por | Qué aporta |
|---|---|---|
| **RADB** (`whois.radb.net`) | `bgp2ip` | Prefijos IPv4/IPv6 (`route:` / `route6:`) registrados como originados por un AS |
| **Team Cymru** (`whois.cymru.com`) | `tracebgp` | Nombre/descripción legible de un número de AS a partir de una consulta `-v <AS>` |
| **ip-api.com** | `ip2bgp` | AS y país asociados a una IP pública concreta |

> Estas fuentes son servicios públicos de terceros; su disponibilidad, límites de consultas y política de uso pueden cambiar sin previo aviso. Para uso intensivo o automatizado a gran escala, consulta las condiciones de cada proveedor.

---

### Aviso legal 

- Estas herramientas solo consultan **información pública de enrutamiento** (whois de RADB/Cymru e IP pública); no acceden a los sistemas destino ni realizan ninguna acción intrusiva más allá de un `traceroute` estándar.
- Aun así, algunos entornos corporativos consideran el escaneo/trazado de sus rangos de red como una actividad a vigilar. Utiliza estas herramientas de forma responsable y, en contextos de auditoría, siempre con autorización explícita.
- El acceso no autorizado a sistemas de terceros está prohibido y puede constituir un delito según la legislación vigente.

---

### 📄 Licencia

Este proyecto se distribuye bajo licencia **GPL-3.0**. Consulta el fichero [`LICENSE`](./LICENSE) para más detalles.

---

<p align="center">
  <a href="http://www.hackingyseguridad.com">www.hackingyseguridad.com</a>
</p>
