# MaxMind GeoIP centralizado

## Diseño

El Manager principal descarga una sola vez estas bases:

```text
GeoLite2-City.mmdb
GeoLite2-Country.mmdb
GeoLite2-ASN.mmdb
```

La cuenta y `LicenseKey` de MaxMind permanecen únicamente en
`/etc/soc-geoip-manager/GeoIP.conf` con `root:root 0600`. Nginx publica las bases y un manifiesto
SHA-256 en `8444/tcp`, protegido por mTLS. Cada Indexer con rol `ingest` recibe un certificado
cliente distinto; no recibe la licencia.

El worker descarga y verifica automáticamente. La activación sustituye los archivos estándar en
`/usr/share/wazuh-indexer/modules/ingest-geoip/` con el servicio detenido. Esto conserva el
pipeline Wazuh sin modificaciones, pero exige reiniciar un nodo por vez.

## Manager principal

En Ubuntu 24.04 instale `geoipupdate`, `libmaxminddb-bin`, Nginx, OpenSSL y `util-linux`. Después:

```bash
install -d -o root -g root -m 0700 /etc/soc-geoip-manager
install -o root -g root -m 0600 ./GeoIP.conf.example \
  /etc/soc-geoip-manager/GeoIP.conf
install -o root -g root -m 0600 ./manager.env.example \
  /etc/soc-geoip-manager/manager.env
sudoedit /etc/soc-geoip-manager/GeoIP.conf
sudoedit /etc/soc-geoip-manager/manager.env

install -o root -g root -m 0755 ./soc-geoip-manager \
  /usr/local/sbin/soc-geoip-manager
env SOC_GEOIP_STAGING_ROOT="$PWD" soc-geoip-manager preflight
env SOC_GEOIP_STAGING_ROOT="$PWD" soc-geoip-manager install
soc-geoip-manager status
```

Para cada Indexer, emita una identidad en un directorio nuevo y transfiérala por un canal seguro:

```bash
soc-geoip-manager issue-client indexer-01 /root/geoip-client-indexer-01
```

## Cada Indexer `ingest`

Instale `ca.crt`, `client.crt`, `client.key` y `worker.env` dentro de
`/etc/soc-geoip-indexer/`. La clave debe ser `root:root 0600`. Ajuste el endpoint del Manager, el
endpoint HTTPS local/estable del Indexer y la cantidad exacta de nodos.

```bash
install -o root -g root -m 0755 ./soc-geoip-indexer \
  /usr/local/sbin/soc-geoip-indexer
env SOC_GEOIP_STAGING_ROOT="$PWD" soc-geoip-indexer preflight
env SOC_GEOIP_STAGING_ROOT="$PWD" soc-geoip-indexer install
soc-geoip-indexer status
```

No instale el worker en un nodo exclusivamente `cluster_manager`. Mantenga
`SOC_GEOIP_AUTO_ACTIVATE=false` cuando exista más de un Indexer.

## Activación

Con el clúster en verde, ejecute en el canario:

```bash
soc-geoip-indexer sync
soc-geoip-indexer status
soc-geoip-indexer activate
```

Espere a que el nodo y el clúster se recuperen antes de repetir en el siguiente. El script exige
las tres bases anteriores para garantizar rollback y revierte si el servicio o la salud no
regresan. Al finalizar, compare los tres SHA-256 en todos los nodos `ingest` y ejecute `_simulate`
contra el pipeline Wazuh.

Las bases solo enriquecen eventos nuevos; los documentos históricos no se recalculan. Después de
actualizar el paquete `wazuh-indexer`, compare hashes y reactive si el paquete repuso sus bases.
Si se pierde una clave cliente, cierre `8444`, rote la PKI dedicada y vuelva a emitir los clientes;
eliminar el archivo del nodo no revoca una copia robada. La aceptación en producción requiere un
piloto canario real sobre Wazuh 4.14.7.
