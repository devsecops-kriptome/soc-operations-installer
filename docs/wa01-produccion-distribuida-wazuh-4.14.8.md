# Instalación distribuida WA01 con Wazuh 4.14.8 y SOC Operations

> Estado: guía de preparación y despliegue para producción.
> Revisión: 2026-10-04.
> Alcance: Wazuh 4.14.8, tres Indexers, Manager, Dashboard, SOC Operations, HAProxy, Cloudflare, UFW y GeoIP MaxMind.
> Bloqueo: SOC Operations no debe autorizarse para producción hasta superar completamente <code>docs/acceptance.md</code>.

## Objetivo y orden de ejecución

La instalación se realiza en este orden:

- Preparar DNS, certificados, sistema operativo, NTP y firewall.
- Instalar los tres Wazuh Indexer y formar el clúster.
- Dejar el Indexer central exclusivamente con rol <code>cluster_manager</code>.
- Instalar Manager, Filebeat y Dashboard en el servidor central.
- Publicar servicios mediante Cloudflare, NAT y HAProxy.
- Instalar y validar SOC Operations.
- Distribuir GeoIP MaxMind y activarlo de forma rolling.
- Ejecutar pruebas de seguridad, failover, restauración y aceptación.

## Arquitectura

~~~text
Internet
  |
Cloudflare
  |
181.65.251.75
  |
HAProxy 192.168.4.50
  +-- 443  -> Dashboard      192.168.4.117:443
  +-- 443  -> Indexer API    192.168.4.118/119:9200
  +-- 443  -> SOC Operations 192.168.4.117:9443
  +-- 1514 -> Wazuh Manager  192.168.4.117:1514
  +-- 1515 -> Wazuh Manager  192.168.4.117:1515

192.168.4.117 wa01-dashboard.corp.atg
  Dashboard + Manager + Filebeat
  Indexer cluster_manager-only
  SOC Operations y distribuidor GeoIP

192.168.4.118 wa01-indexer01.corp.atg
  Indexer cluster_manager + data + ingest

192.168.4.119 wa01-indexer02.corp.atg
  Indexer cluster_manager + data + ingest
~~~

### Servicios públicos

| Servicio | FQDN | Puerto | Acceso |
|---|---|---:|---|
| Dashboard | <code>wa01-dashboard.kriptome.com</code> | 443/TCP | Whitelist |
| API Indexer | <code>wa01-indexer-api.kriptome.com</code> | 443/TCP | Whitelist y métodos limitados |
| API SOC Operations | <code>wa01-socops-api.kriptome.com</code> | 443/TCP | Whitelist |
| Eventos de agentes | <code>wa01-agents.kriptome.com</code> | 1514/TCP | Público |
| Enrolamiento | <code>wa01-agents.kriptome.com</code> | 1515/TCP | Público |

### Límites de disponibilidad

- Los tres Indexers votan como <code>cluster_manager</code>.
- Solo <code>.118</code> y <code>.119</code> almacenan datos y ejecutan ingest pipelines.
- Se tolera la pérdida de un Indexer de datos.
- El servidor <code>.117</code> es todavía un punto único para Manager, Dashboard, SOC Operations y agentes.
- La redundancia no reemplaza los respaldos.

## Cloudflare, NAT y certificados

- Los tres FQDN HTTPS pueden usar el proxy de Cloudflare.
- <code>wa01-agents.kriptome.com</code> debe quedar como DNS only, excepto si se contrata Cloudflare Spectrum. El proxy estándar no transporta 1514/1515.
- Los A públicos apuntan a <code>181.65.251.75</code>.
- No crear AAAA sin ruta IPv6 y controles equivalentes.
- Aplicar whitelist tanto en Cloudflare como en HAProxy.
- Confiar en <code>CF-Connecting-IP</code> únicamente cuando el origen sea una red oficial de Cloudflare.

NAT requerido:

- <code>181.65.251.75:443/TCP</code> a <code>192.168.4.50:443</code>.
- <code>181.65.251.75:1514/TCP</code> a <code>192.168.4.50:1514</code>.
- <code>181.65.251.75:1515/TCP</code> a <code>192.168.4.50:1515</code>.

No publicar directamente 9200, 9300-9400, 55000, 8443, 8444, PostgreSQL, OpenBao ni S3.

## Matriz de red

| Origen | Destino | Puerto | Uso |
|---|---|---:|---|
| Administración | Todos los servidores | SSH real | Gestión |
| HAProxy <code>.50</code> | Central <code>.117</code> | 443 | Dashboard |
| HAProxy <code>.50</code> | Central <code>.117</code> | 9443 | API SOC |
| HAProxy <code>.50</code> | Central <code>.117</code> | 1514/1515 | Agentes |
| HAProxy <code>.50</code> | Indexers <code>.118/.119</code> | 9200 | API Indexer |
| Central <code>.117</code> | Indexers <code>.118/.119</code> | 9200 | Filebeat, Dashboard y SOC |
| Tres Indexers | Entre sí | 9300-9400 | Transporte |
| Indexers <code>.118/.119</code> | Central <code>.117</code> | 8444 | GeoIP mTLS |
| Bridge de SOC | Agente local | 8443 | Despliegue mTLS |

## Preparación

En DNS interno crear los registros indicados. Temporalmente:

~~~text
192.168.4.117 wa01-dashboard.corp.atg wa01-dashboard
192.168.4.118 wa01-indexer01.corp.atg wa01-indexer01
192.168.4.119 wa01-indexer02.corp.atg wa01-indexer02
192.168.4.50  wa01-haproxy.corp.atg wa01-haproxy
~~~

En cada nodo comprobar:

~~~bash
getent hosts wa01-dashboard.corp.atg
getent hosts wa01-indexer01.corp.atg
getent hosts wa01-indexer02.corp.atg
hostnamectl
timedatectl status
~~~

Requisitos:

- Ubuntu soportado, IP estática, NTP y hostname definitivo.
- SSH con claves, sin contraseña y limitado a la red administrativa.
- Certificados con SAN coherentes con las direcciones usadas.
- Capacidad calculada con EPS, agentes y retención reales.
- Discos de Indexer con monitoreo de watermarks.
- Proxy interno <code>192.168.4.50</code> solo si realmente presta salida HTTP.

### CPU de las máquinas virtuales para MinIO

El servidor central <code>192.168.4.117</code>, donde se ejecuta MinIO, requiere una CPU visible
<code>x86_64</code> compatible con <code>x86-64-v2</code>. La imagen utiliza UBI 9; una VM con
modelo genérico <code>kvm64</code> puede fallar con
<code>Fatal glibc error: CPU does not support x86-64-v2</code>, aunque el host físico sea moderno.
La arquitectura <code>x86_64</code> por sí sola no acredita ese nivel de instrucciones.

Comprobar dentro de Ubuntu:

~~~bash
systemd-detect-virt || true
LC_ALL=C lscpu | grep -Ei 'Architecture|Model name|Hypervisor vendor|Flags'
~~~

El invitado debe exponer <code>cx16</code>, <code>lahf_lm</code>, <code>popcnt</code>,
<code>pni</code> (SSE3), <code>ssse3</code>, <code>sse4_1</code> y <code>sse4_2</code>.
No se requiere AVX para este control. El requisito aplica a cualquier servidor que ejecute esta
imagen, sea VM o físico; no obliga a cambiar la CPU de los Indexers que no ejecutan MinIO.

En Proxmox, verificar primero el procesador físico desde **nodo → Shell**, fuera de la VM:

~~~bash
LC_ALL=C lscpu | grep -Ei 'Model name|Flags'
~~~

Si el host admite esas instrucciones, programar una ventana: apagar completamente la VM
central mediante **Shutdown**, esperar el estado **Stopped**, abrir
**VM → Hardware → Processors → Edit → Type**, cambiar el modelo y volver a iniciarla con
**Start**. Conservar sockets y cores. Un reinicio desde Ubuntu no aplica necesariamente el
cambio de CPU pendiente.

- <code>x86-64-v2-AES</code>: opción para hosts compatibles, con AES además del nivel v2.
  Si hay HA o migraciones, comprobar que todos los nodos de destino admitan ese modelo.
- <code>host</code>: expone las capacidades del procesador físico; usar cuando su compatibilidad
  con los destinos de migración esté garantizada.

Después del arranque, repetir <code>lscpu</code>. Una vez importada la imagen del release,
se puede comprobar su ejecución sin red ni volúmenes:

~~~bash
sudo docker run --rm --pull never --network none \
  soc-operations-minio:RELEASE.2025-07-23T15-54-02Z --version
~~~

Debe mostrar la versión sin el error de glibc. Desde <code>0.1.156</code>, el preflight del
instalador verifica el nivel de CPU en todos los procesadores visibles antes de instalar
componentes. El helper también lo comprueba antes de desplegar dependencias. Si faltan flags
o no se pueden leer, falla e identifica la causa; no modifica la CPU ni instala componentes.
La prueba manual anterior complementa ese control, pero no acredita la salud completa de S3.

Referencias: [CPU de Proxmox](https://github.com/proxmox/pve-docs/blob/master/qm.adoc)
y [requisito de CPU de UBI 9](https://access.redhat.com/solutions/7057314).

## UFW por servidor

Antes de habilitarlo, mantener una segunda sesión SSH abierta. Sustituir <code>ADMIN_CIDR</code> y <code>SSH_PORT</code>. No ejecutar <code>ufw reset</code> en equipos ya administrados.

En todos:

~~~bash
sudo apt-get update
sudo apt-get install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from ADMIN_CIDR to any port SSH_PORT proto tcp comment 'SSH administracion'
sudo ufw logging medium
~~~

### Central 192.168.4.117

~~~bash
sudo ufw allow from 192.168.4.50 to 192.168.4.117 port 443 proto tcp comment 'HAProxy Dashboard'
sudo ufw allow from 192.168.4.50 to 192.168.4.117 port 9443 proto tcp comment 'HAProxy SOC API'
sudo ufw allow from 192.168.4.50 to 192.168.4.117 port 1514 proto tcp comment 'Eventos agentes'
sudo ufw allow from 192.168.4.50 to 192.168.4.117 port 1515 proto tcp comment 'Enrollment agentes'
sudo ufw allow from 192.168.4.118 to 192.168.4.117 port 9300:9400 proto tcp comment 'Transporte Indexer01'
sudo ufw allow from 192.168.4.119 to 192.168.4.117 port 9300:9400 proto tcp comment 'Transporte Indexer02'
sudo ufw allow from 192.168.4.118 to 192.168.4.117 port 8444 proto tcp comment 'GeoIP Indexer01'
sudo ufw allow from 192.168.4.119 to 192.168.4.117 port 8444 proto tcp comment 'GeoIP Indexer02'
sudo ufw enable
~~~

No abrir 55000 a Internet. Dashboard y SOC Operations consumen la API local.

### Indexer 1 192.168.4.118

~~~bash
sudo ufw allow from 192.168.4.117 to 192.168.4.118 port 9200 proto tcp comment 'Central a Indexer API'
sudo ufw allow from 192.168.4.50 to 192.168.4.118 port 9200 proto tcp comment 'HAProxy a Indexer API'
sudo ufw allow from 192.168.4.117 to 192.168.4.118 port 9300:9400 proto tcp comment 'Transporte central'
sudo ufw allow from 192.168.4.119 to 192.168.4.118 port 9300:9400 proto tcp comment 'Transporte Indexer02'
sudo ufw enable
~~~

### Indexer 2 192.168.4.119

~~~bash
sudo ufw allow from 192.168.4.117 to 192.168.4.119 port 9200 proto tcp comment 'Central a Indexer API'
sudo ufw allow from 192.168.4.50 to 192.168.4.119 port 9200 proto tcp comment 'HAProxy a Indexer API'
sudo ufw allow from 192.168.4.117 to 192.168.4.119 port 9300:9400 proto tcp comment 'Transporte central'
sudo ufw allow from 192.168.4.118 to 192.168.4.119 port 9300:9400 proto tcp comment 'Transporte Indexer01'
sudo ufw enable
~~~

Verificar en cada host:

~~~bash
sudo ufw status verbose
sudo ss -lntup
sudo journalctl -k --grep='UFW BLOCK' --since '-15 minutes'
~~~

Probar cada flujo permitido y al menos uno denegado. UFW no sustituye al firewall perimetral.

## Instalación de Wazuh 4.14.8

### Preparar artefactos

~~~bash
mkdir -p /root/wa01-deploy
cd /root/wa01-deploy
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh
curl -sO https://packages.wazuh.com/4.14/config.yml
chmod 700 wazuh-install.sh
sha256sum wazuh-install.sh config.yml | tee SHA256SUMS.local
grep -n WAZUH_VERSION wazuh-install.sh
~~~

Confirmar que el asistente resuelve <code>4.14.8-1</code>. Archivar hashes y fecha. Editar <code>config.yml</code>:

~~~yaml
nodes:
  indexer:
    - name: wa01-indexer-manager
      ip: 192.168.4.117
    - name: wa01-indexer01
      ip: 192.168.4.118
    - name: wa01-indexer02
      ip: 192.168.4.119
  server:
    - name: wa01-manager
      ip: 192.168.4.117
  dashboard:
    - name: wa01-dashboard
      ip: 192.168.4.117
~~~

Generar una sola vez y distribuir los mismos artefactos:

~~~bash
sudo bash wazuh-install.sh --generate-config-files
sudo chmod 600 wazuh-install-files.tar
tar -tf wazuh-install-files.tar
~~~

Verificar hashes después de cada copia.

### Indexers

En <code>.117</code>:

~~~bash
sudo bash wazuh-install.sh --wazuh-indexer wa01-indexer-manager
~~~

No cambie todavía <code>node.roles</code>. El asistente arranca el servicio con los roles
predeterminados y puede escribir shards o metadatos locales. Si se retira el rol <code>data</code>
en este punto, OpenSearch puede rechazar el siguiente arranque.

En <code>.118</code>:

~~~bash
sudo bash wazuh-install.sh --wazuh-indexer wa01-indexer01
~~~

En <code>.119</code>:

~~~bash
sudo bash wazuh-install.sh --wazuh-indexer wa01-indexer02
~~~

Inicializar el clúster una sola vez, sin cambiar todavía los roles:

~~~bash
sudo bash wazuh-install.sh --start-cluster
~~~

### Validar el clúster inicial

Antes de convertir <code>.117</code>, comprobar que los tres nodos están activos y el clúster está
green. Desde un nodo con el certificado administrativo:

~~~bash
sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://127.0.0.1:9200/_cluster/health?pretty'

sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://127.0.0.1:9200/_cat/nodes?v&h=name,ip,node.role,master'

sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://127.0.0.1:9200/_cat/allocation?v'
~~~

En este momento es normal que los tres nodos todavía tengan los roles predeterminados y que
<code>wa01-indexer-manager</code> contenga shards.

### Convertir 192.168.4.117 en cluster manager exclusivo

Esta conversión elimina del nodo central sus copias locales de shards, pero no elimina índices del
clúster. Antes de continuar:

- Confirmar estado green y presencia de los tres nodos.
- Crear un snapshot si ya se incorporaron datos reales.
- Ejecutar la exclusión desde un nodo con certificado administrativo.
- No apagar ninguno de los dos nodos de datos durante la conversión.

Excluir <code>wa01-indexer-manager</code> de la asignación de shards:

~~~bash
sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  -H 'Content-Type: application/json' \
  -X PUT 'https://127.0.0.1:9200/_cluster/settings' \
  -d '{"persistent":{"cluster.routing.allocation.exclude._name":"wa01-indexer-manager"}}'
~~~

Esperar hasta que el clúster vuelva a green y la segunda consulta no devuelva ninguna línea:

~~~bash
sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://127.0.0.1:9200/_cluster/health?wait_for_status=green&timeout=10m&pretty'

sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://127.0.0.1:9200/_cat/shards?h=index,shard,prirep,state,node' \
  | awk '$5 == "wa01-indexer-manager"'
~~~

En <code>.117</code>, detener el servicio y respaldar la configuración:

~~~bash
sudo systemctl stop wazuh-indexer
sudo cp -a /etc/wazuh-indexer/opensearch.yml /etc/wazuh-indexer/opensearch.yml.pre-manager-only
sudo systemctl is-active wazuh-indexer
~~~

El último comando debe responder <code>inactive</code>. Antes de editar, localizar las
declaraciones de roles heredadas que puede haber generado el instalador:

~~~bash
sudo grep -nE '^[[:space:]]*node\.(roles|data|master|ingest|remote_cluster_client|ml)[[:space:]]*:' \
  /etc/wazuh-indexer/opensearch.yml
~~~

Editar <code>/etc/wazuh-indexer/opensearch.yml</code>. Retirar o comentar todas las declaraciones
activas <code>node.data</code>, <code>node.master</code>, <code>node.ingest</code>,
<code>node.remote_cluster_client</code> y <code>node.ml</code>. No configurarlas como
<code>false</code>: OpenSearch tampoco permite mezclar esas claves heredadas con
<code>node.roles</code>.

Dejar una sola declaración moderna:

~~~yaml
node.roles: [ cluster_manager ]
~~~

Comprobar que la salida solo contiene <code>node.roles</code>:

~~~bash
sudo grep -nE '^[[:space:]]*node\.(roles|data|master|ingest|remote_cluster_client|ml)[[:space:]]*:' \
  /etc/wazuh-indexer/opensearch.yml
~~~

Como el instalador ya inició este nodo anteriormente, repurpose debe limpiar los restos de shards
que OpenSearch no permite conservar en un nodo sin rol <code>data</code>. Revisar primero que la
herramienta exista y ejecutar de forma interactiva:

~~~bash
sudo test -x /usr/share/wazuh-indexer/bin/opensearch-node
sudo -u wazuh-indexer env OPENSEARCH_PATH_CONF=/etc/wazuh-indexer \
  /usr/share/wazuh-indexer/bin/opensearch-node -v repurpose
~~~

Leer la lista mostrada y confirmar solo si corresponde a
<code>wa01-indexer-manager</code>. No ejecutar esta herramienta con el servicio activo ni en
<code>.118</code> o <code>.119</code>.

Si la evacuación fue completa, la herramienta puede responder
<code>No shard data to clean-up found</code>. Es un resultado válido: no hay shards locales que
eliminar y se puede continuar con el arranque. Las advertencias de Java sobre native access,
MemorySegment o Vector API son informativas; el criterio es que no aparezca una excepción y que el
comando finalice sin error.

Arrancar el nodo y validar sus roles:

~~~bash
sudo systemctl start wazuh-indexer
sudo systemctl status wazuh-indexer --no-pager

sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://127.0.0.1:9200/_cat/nodes?v&h=name,ip,node.role,node.roles,cluster_manager'
~~~

Cuando los tres nodos estén presentes y el clúster esté green, retirar la exclusión:

~~~bash
sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  -H 'Content-Type: application/json' \
  -X PUT 'https://127.0.0.1:9200/_cluster/settings' \
  -d '{"persistent":{"cluster.routing.allocation.exclude._name":null}}'
~~~

Resultado esperado:

- Tres nodos y estado green.
- <code>wa01-indexer-manager</code> solo con rol <code>cluster_manager</code>.
- <code>wa01-indexer01</code> y <code>wa01-indexer02</code> con roles de datos e ingest.
- Ningún shard asignado a <code>wa01-indexer-manager</code>.

La columna <code>cluster_manager</code> marca con <code>*</code> al nodo elegido actualmente, no al
único nodo apto para la elección. Es válido que el asterisco aparezca en cualquiera de los tres.
Los nodos que conservan roles predeterminados también pueden mostrar <code>master</code> en
<code>node.roles</code> y la abreviatura <code>m</code> en <code>node.role</code>; en esta versión
es la representación heredada de su capacidad <code>cluster_manager</code>.

### Diagnóstico si el nodo central no arranca

No borrar <code>/var/lib/wazuh-indexer</code>. Recopilar primero:

~~~bash
sudo systemctl status wazuh-indexer --no-pager -l
sudo journalctl -u wazuh-indexer -b -n 200 --no-pager
sudo grep -nE '^[[:space:]]*(node\.roles|node\.data|node\.master):' \
  /etc/wazuh-indexer/opensearch.yml
~~~

- Si el registro indica que el nodo no tiene rol data pero contiene shard data, faltó ejecutar
  <code>opensearch-node repurpose</code> con el servicio detenido.
- Si informa una clave duplicada, conservar una sola declaración <code>node.roles</code>.
- Si informa <code>can not explicitly configure node roles and use legacy role setting</code>,
  retirar todas las claves heredadas <code>node.data</code>, <code>node.master</code>,
  <code>node.ingest</code>, <code>node.remote_cluster_client</code> y <code>node.ml</code>;
  no basta con cambiar su valor a <code>false</code>.
- Si informa que no descubre cluster manager, revisar 9300-9400, DNS,
  <code>discovery.seed_hosts</code>, nombres de nodo y certificados.

### Manager y Filebeat

En <code>.117</code>:

~~~bash
sudo bash wazuh-install.sh --wazuh-server wa01-manager
sudo systemctl status wazuh-manager filebeat --no-pager
~~~

El archivo generado puede declarar las propiedades comunes dentro de
<code>output.elasticsearch</code> y los hosts al final mediante
<code>output.elasticsearch.hosts</code>. Ambas formas son válidas, pero no deben mantenerse dos
declaraciones paralelas. Consolidar todo en un único bloque:

~~~yaml
output.elasticsearch:
  hosts:
    - 192.168.4.118:9200
    - 192.168.4.119:9200
  protocol: https
  loadbalance: true
  username: ${username}
  password: ${password}
  ssl.certificate_authorities:
    - /etc/filebeat/certs/root-ca.pem
  ssl.certificate: /etc/filebeat/certs/wa01-manager.pem
  ssl.key: /etc/filebeat/certs/wa01-manager-key.pem
~~~

Eliminar entonces el bloque separado <code>output.elasticsearch.hosts</code> del final del archivo.
No cambiar <code>username</code> ni <code>password</code>: son referencias al keystore, no
credenciales literales. <code>loadbalance</code> es <code>true</code> por defecto en Filebeat,
pero se declara explícitamente para que la intención operativa quede documentada.

Validar la sintaxis antes de reiniciar:

~~~bash
sudo filebeat test config -e
sudo filebeat test output -e
~~~

En el bloque <code>indexer</code> de <code>/var/ossec/etc/ossec.conf</code>:

~~~xml
<hosts>
  <host>https://192.168.4.118:9200</host>
  <host>https://192.168.4.119:9200</host>
</hosts>
~~~

~~~bash
sudo /var/ossec/bin/wazuh-control status
sudo systemctl restart wazuh-manager filebeat
~~~

### Dashboard

~~~bash
sudo bash wazuh-install.sh --wazuh-dashboard wa01-dashboard
~~~

Comprobar en <code>/etc/wazuh-dashboard/opensearch_dashboards.yml</code>:

~~~yaml
server.host: 192.168.4.117
opensearch.hosts:
  - https://192.168.4.118:9200
  - https://192.168.4.119:9200
opensearch.ssl.verificationMode: full
~~~

Si los certificados del Indexer no incluyen IP como SAN, usar sus FQDN internos. No degradar
la verificación TLS. Para la API Wazuh, Dashboard y Manager comparten `.117` y el certificado
observado contiene `DNS:localhost`: usar `https://localhost`, no la IP LAN ni `127.0.0.1`.
Comprobar los SAN antes de cambiar el destino. En
`/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml`, modificar únicamente la URL del
host existente y conservar usuario, contraseña, puerto y `run_as`. Este fragmento no sustituye
el archivo completo:

~~~yaml
hosts:
  - default:
      url: https://localhost
      port: 55000
      run_as: true
~~~

Si la API está en otro servidor, no usar `localhost`: configurar un FQDN del Manager que
coincida con su certificado. El procedimiento de comprobación y respaldo está en
[Error de conexión con la API Wazuh durante RBAC](#error-de-conexión-con-la-api-wazuh-durante-rbac).

~~~bash
sudo systemctl restart wazuh-dashboard
sudo journalctl -u wazuh-dashboard -n 100 --no-pager
~~~

### Bloquear actualizaciones automáticas de Wazuh con APT

Aplicar el bloqueo después de instalar los paquetes y comprobar sus versiones, antes de ejecutar
un <code>apt upgrade</code> general. Si el stack ya está instalado, ejecutar este paso ahora en los
tres servidores. <code>apt-mark hold</code> conserva la versión instalada; no instala ni corrige
una versión equivocada. En WA01, los paquetes Wazuh deben mostrar <code>4.14.8-1</code>.
Filebeat tiene su propia versión: registrar y conservar la instalada por el asistente Wazuh.

En el servidor central <code>192.168.4.117</code>:

~~~bash
dpkg-query -W -f='${Package}\t${Version}\n' \
  wazuh-indexer wazuh-manager wazuh-dashboard filebeat
sudo apt-mark hold wazuh-indexer wazuh-manager wazuh-dashboard filebeat
apt-mark showhold
~~~

En cada Indexer de datos, <code>192.168.4.118</code> y <code>192.168.4.119</code>:

~~~bash
dpkg-query -W -f='${Package}\t${Version}\n' wazuh-indexer
sudo apt-mark hold wazuh-indexer
apt-mark showhold
~~~

Comprobar que <code>showhold</code> enumere los cuatro paquetes en <code>.117</code> y
<code>wazuh-indexer</code> en cada nodo de datos. Otros paquetes previamente bloqueados pueden
aparecer también. En cada servidor, simular la actualización general sin instalar cambios:

~~~bash
sudo apt-get update
sudo apt-get --simulate upgrade
sudo apt-get --simulate dist-upgrade
~~~

Los paquetes bloqueados no deben aparecer como operaciones de instalación, actualización o
eliminación propuestas. El bloqueo evita su actualización automática mediante APT, incluido el
flujo normal de <code>unattended-upgrades</code>; los demás paquetes Ubuntu pueden seguir
recibiendo actualizaciones. No usar <code>--allow-change-held-packages</code> en tareas generales.
El bloqueo no impide que un administrador lo retire o instale manualmente paquetes con
<code>dpkg</code>, ni controla archivos del plugin instalados fuera de APT.

Para una actualización planificada, validar primero la compatibilidad Wazuh/OSD/SOC Operations,
preparar respaldo y rollback y seguir el orden del procedimiento de actualización aprobado.
Retirar el bloqueo únicamente del paquete y nodo que se vaya a actualizar; por ejemplo, durante
la ventana de mantenimiento de un Indexer:

~~~bash
sudo apt-mark unhold wazuh-indexer
# Ejecutar aquí la actualización aprobada a una versión explícita y sus comprobaciones.
# Volver a bloquear al terminar, incluso si se cancela la actualización.
sudo apt-mark hold wazuh-indexer
dpkg-query -W -f='${Package}\t${Version}\n' wazuh-indexer
apt-mark showhold
~~~

Aplicar el mismo ciclo individual a Manager, Dashboard o Filebeat cuando corresponda. Revisar
periódicamente las correcciones de seguridad disponibles para programar su actualización.
Referencia: [Ubuntu — apt-mark](https://manpages.ubuntu.com/manpages/noble/man8/apt-mark.8.html).

## HAProxy

En <code>D:\GPT\Haproxy\Estructura</code>, agregar los tres FQDN HTTPS a:

- <code>haproxy/maps/access/admin-hosts.lst</code>.
- <code>haproxy/maps/policy/host-access-mode.map</code>.
- <code>haproxy/maps/routing/http-host-backend.map</code>.
- <code>haproxy/maps/routing/https-host-backend.map</code>.

Enrutamiento lógico:

~~~text
wa01-dashboard.kriptome.com    be_wa01_dashboard
wa01-indexer-api.kriptome.com  be_wa01_indexer_api
wa01-socops-api.kriptome.com   be_wa01_socops_api
~~~

La configuración de referencia de <code>D:\GPT\Haproxy\Estructura</code> carga todos los
<code>*.cfg</code> de <code>haproxy/conf.d</code> en orden. Aunque HAProxy permite reunir varias
secciones en un único archivo, para WA01 producción se conserva una unidad operativa por archivo:

- <code>46-backend-wa01-prod-dashboard.cfg</code>: backend del Dashboard.
- <code>47-backend-wa01-prod-index-api.cfg</code>: backend y restricciones de la API Indexer.
- <code>48-backend-wa01-prod-socops-api.cfg</code>: backend de SOC Operations.
- <code>72-service-wa01-prod-agents-tcp.cfg</code>: ambos frontends y backends TCP de agentes.

Estos números son los siguientes disponibles en el árbol revisado. No reutilizar los archivos de
LAB02 ni mezclar el servicio TCP con los backends HTTP. Si primero se prepara una plantilla,
mantener la extensión <code>.cfg.example</code>; HAProxy solo la cargará al publicarla como
<code>.cfg</code>.

Backends de referencia; cada sección se guarda en el archivo correspondiente:

~~~haproxy
backend be_wa01_dashboard
    mode http
    option httpchk GET /api/status
    server dashboard01 192.168.4.117:443 ssl verify required ca-file /etc/haproxy/pki/wa01-ca.pem check

backend be_wa01_indexer_api
    mode http
    balance roundrobin
    option tcp-check
    server indexer01 192.168.4.118:9200 ssl verify required ca-file /etc/haproxy/pki/wa01-ca.pem check
    server indexer02 192.168.4.119:9200 ssl verify required ca-file /etc/haproxy/pki/wa01-ca.pem check

backend be_wa01_socops_api
    mode http
    option httpchk GET /health
    server socops01 192.168.4.117:9443 ssl verify required ca-file /etc/haproxy/pki/socops-ca.pem verifyhost soc-external-api-wa01 check
~~~

Confirmar SAN y endpoint de health reales antes de activar checks. El ejemplo del Indexer valida
conectividad y negociación TLS. Si se requiere comprobar salud HTTP, crear una identidad técnica
de solo monitoreo y almacenarla mediante el mecanismo de secretos de HAProxy; no entregar a
HAProxy el certificado administrativo del clúster. Para la API Indexer:

- Permitir GET y HEAD.
- Permitir POST solo a <code>_search</code>, <code>_msearch</code>, <code>_count</code>, <code>_field_caps</code> y <code>_validate/query</code>.
- Denegar PUT, PATCH y DELETE.
- Mantener RBAC de OpenSearch; la whitelist no reemplaza autorización.

Los agentes requieren TCP, sin Coraza ni routing por hostname:

~~~haproxy
frontend fe_wa01_agents_events
    bind 192.168.4.50:1514
    mode tcp
    option tcplog
    default_backend be_wa01_agents_events

backend be_wa01_agents_events
    mode tcp
    server manager01 192.168.4.117:1514 check

frontend fe_wa01_agents_enrollment
    bind 192.168.4.50:1515
    mode tcp
    option tcplog
    default_backend be_wa01_agents_enrollment

backend be_wa01_agents_enrollment
    mode tcp
    server manager01 192.168.4.117:1515 check
~~~

~~~bash
sudo haproxy -c -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/conf.d
sudo systemctl reload haproxy
sudo systemctl status haproxy --no-pager
sudo ss -lntp | grep -E ':443|:1514|:1515'
~~~

### Validación desde una fuente externa permitida

La prueba debe ejecutarse desde una conexión que salga a Internet con una IP pública incluida en
la whitelist. No usar la misma LAN de HAProxy ni resolución DNS interna, porque eso no valida
Cloudflare, NAT ni el trayecto público.

#### Confirmar la IP de origen

Desde PowerShell en el equipo externo:

~~~powershell
$AllowedPublicIp = (Invoke-RestMethod -Uri 'https://api.ipify.org').Trim()
$AllowedPublicIp
~~~

Confirmar fuera de banda que esa IP, o el CIDR que la contiene, esté autorizada:

- En la regla WAF o Access correspondiente de Cloudflare.
- En <code>restricted-client-allowlist.lst</code>.
- En <code>admin-client-allowlist.lst</code> cuando el FQDN esté clasificado como administrativo.

No ampliar temporalmente la whitelist a <code>0.0.0.0/0</code>.

#### Validar DNS público

~~~powershell
$HttpsNames = @(
  'wa01-dashboard.kriptome.com',
  'wa01-indexer-api.kriptome.com',
  'wa01-socops-api.kriptome.com'
)

$HttpsNames | ForEach-Object {
  Resolve-DnsName $_ -Type A -Server 1.1.1.1
}

Resolve-DnsName 'wa01-agents.kriptome.com' -Type A -Server 1.1.1.1
Resolve-DnsName 'wa01-agents.kriptome.com' -Type AAAA -Server 1.1.1.1
~~~

Resultados esperados:

- Los FQDN HTTPS con proxy de Cloudflare pueden devolver direcciones de Cloudflare.
- <code>wa01-agents.kriptome.com</code>, configurado como DNS only, debe resolver directamente a
  <code>181.65.251.75</code>.
- No debe existir AAAA para agentes mientras IPv6 no esté publicado de extremo a extremo.

#### Validar conectividad TCP

~~~powershell
Test-NetConnection 'wa01-dashboard.kriptome.com' -Port 443
Test-NetConnection 'wa01-indexer-api.kriptome.com' -Port 443
Test-NetConnection 'wa01-socops-api.kriptome.com' -Port 443
Test-NetConnection 'wa01-agents.kriptome.com' -Port 1514
Test-NetConnection 'wa01-agents.kriptome.com' -Port 1515
~~~

Cada prueba aplicable debe mostrar <code>TcpTestSucceeded : True</code>. Si SOC Operations todavía
no está instalado, la prueba de su puerto o health se registra como pendiente, no como aprobada.

#### Validar HTTPS, certificados y routing

Usar <code>curl.exe</code> para evitar el alias histórico de PowerShell:

~~~powershell
curl.exe --silent --show-error --output NUL --write-out "dashboard http=%{http_code} remote=%{remote_ip} tls=%{ssl_verify_result}\n" 'https://wa01-dashboard.kriptome.com/api/status'

curl.exe --silent --show-error --output NUL --write-out "indexer http=%{http_code} remote=%{remote_ip} tls=%{ssl_verify_result}\n" 'https://wa01-indexer-api.kriptome.com/'

curl.exe --silent --show-error --output NUL --write-out "socops http=%{http_code} remote=%{remote_ip} tls=%{ssl_verify_result}\n" 'https://wa01-socops-api.kriptome.com/health/live'
~~~

Interpretación:

- <code>tls=0</code> confirma que la cadena pública y el hostname son válidos.
- Dashboard debe responder 200 en <code>/api/status</code>, o el código documentado por la versión
  instalada si el endpoint exige autenticación.
- Indexer debe responder 401 o 403 sin credenciales. Ese resultado confirma publicación y evita
  exposición anónima; no usar <code>--fail-with-body</code> en esta prueba porque ambos códigos son
  esperados.
- SOC Operations debe responder 200 en <code>/health/live</code> una vez instalado.
- Un 403 generado por Cloudflare o HAProxy en los tres FQDN, desde una IP que debería estar
  permitida, indica un problema de whitelist o de obtención de la IP real.

Para revisar el certificado presentado:

~~~powershell
curl.exe --verbose --output NUL 'https://wa01-dashboard.kriptome.com/api/status'
curl.exe --verbose --output NUL 'https://wa01-indexer-api.kriptome.com/'
curl.exe --verbose --output NUL 'https://wa01-socops-api.kriptome.com/health/live'
~~~

No incluir credenciales en la línea de comandos ni en la evidencia. Las consultas autenticadas de
Indexer y SOC Operations se ejecutan posteriormente con cuentas sintéticas y secretos introducidos
de forma interactiva.

#### Correlacionar la prueba en los servidores

Mientras se repiten las conexiones externas, en HAProxy:

~~~bash
sudo journalctl -u haproxy --since '-10 minutes' --no-pager
sudo ss -ntp | grep -E ':443|:1514|:1515'
~~~

Revisar también el destino de logs configurado para HAProxy si se envían mediante syslog. Deben
observarse el FQDN o frontend, backend seleccionado, IP real validada, estado y tiempo, sin
credenciales.

En el Manager:

~~~bash
sudo ss -lntp | grep -E ':1514|:1515'
sudo journalctl -u wazuh-manager --since '-10 minutes' --no-pager
~~~

En los Indexers:

~~~bash
sudo journalctl -u wazuh-indexer --since '-10 minutes' --no-pager
~~~

#### Prueba negativa obligatoria

Después de la prueba positiva, repetir únicamente los tres accesos HTTPS desde una IP pública no
incluida en la whitelist. Deben ser rechazados por Cloudflare o HAProxy. No se espera rechazo por
whitelist en 1514/1515 porque los agentes están distribuidos mundialmente; esos puertos se protegen
con el protocolo de Wazuh, controles de enrolamiento, límites de conexión y monitoreo.

Registrar como evidencia:

- Fecha y hora con zona horaria.
- IP pública de origen y regla de whitelist aplicable.
- Resolución DNS observada.
- Resultado TCP y código HTTP.
- Emisor, sujeto, SAN y vencimiento de certificados.
- Backend seleccionado en HAProxy.
- Identificador del cambio, operador y resultado, sin tokens ni contraseñas.

## SOC Operations

### Topología declarada

~~~json
{
  "schema_version": 1,
  "mode": "distributed",
  "deployment_id": "wa01",
  "dashboard": {
    "expected_nodes": 1
  },
  "manager": {
    "expected_nodes": 1,
    "api_ca_bundle": "/var/ossec/api/configuration/ssl/server.crt",
    "deployment_agent_url": "https://wa01-dashboard.corp.atg:8443",
    "deployment_client_cert": "/etc/soc-operations-lab/deploy-tls/client.crt",
    "deployment_client_key": "/etc/soc-operations-lab/deploy-tls/client.key",
    "deployment_ca_bundle": "/etc/soc-operations-lab/deploy-tls/service-ca.crt"
  },
  "indexer": {
    "urls": [
      "https://192.168.4.118:9200"
    ],
    "expected_nodes": 3,
    "admin_cert": "/etc/wazuh-indexer/certs/admin.pem",
    "admin_key": "/etc/wazuh-indexer/certs/admin-key.pem",
    "ca_bundle": "/etc/wazuh-indexer/certs/root-ca.pem"
  }
}
~~~

Guardar este contenido como <code>/root/wa01-soc-topology.json</code>, propiedad
<code>root:root</code> y modo <code>0600</code>. El release <code>0.1.158</code> valida
exactamente este esquema y utiliza únicamente el primer elemento de <code>indexer.urls</code> como
endpoint operativo. Es recomendable reemplazarlo más adelante por una dirección interna estable
con health checks. Mientras no exista, se usa <code>.118</code> y se documenta el cambio manual a
<code>.119</code> durante una contingencia.

Los tres archivos <code>deployment_*</code> no existen en el primer preflight. Se generan al
instalar el agente mTLS después de inicializar OpenBao; es válido que estén ausentes hasta ese
punto.

### Instalación y seguridad

- Instalar el artefacto <code>socOperations-2.19.6.zip</code>, compatible con Wazuh 4.14.8.
- Verificar firma y SHA-256.
- Ejecutar preflight con la topología.
- Usar <code>192.168.4.117</code> como dirección de servicio.
- Declarar solo <code>192.168.4.50/32</code> como proxy externo confiable.
- Usar <code>https://wa01-dashboard.kriptome.com</code> como URL pública.
- Inicializar OpenBao y reanudar solo cuando esté operativo y desbloqueado.
- No pasar secretos persistentes por argumentos ni historial.

### Puerta posterior al snapshot

Registrar los identificadores de los snapshots de los tres servidores y comprobar que terminaron
correctamente. El snapshot no sustituye el respaldo consistente requerido antes de producción,
pero constituye el punto de retorno de esta instalación inicial.

En <code>.117</code>, guardar la línea base:

~~~bash
sudo dpkg-query -W wazuh-indexer wazuh-manager wazuh-dashboard filebeat
sudo systemctl is-active wazuh-indexer wazuh-manager wazuh-dashboard filebeat
sudo /var/ossec/bin/wazuh-control status
sudo filebeat test config -e
sudo filebeat test output -e
sudo ss -lntp | grep -E ':443|:9200|:1514|:1515|:55000'
~~~

Comprobar nuevamente el clúster:

~~~bash
sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://192.168.4.118:9200/_cluster/health?pretty'

sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://192.168.4.118:9200/_cat/nodes?v&h=name,ip,node.roles,cluster_manager'
~~~

No iniciar SOC Operations si falta un servicio, el clúster no está green o no aparecen exactamente
tres Indexers.

### Preparar el release fijo

El release aprobado se publica cifrado en:

<code>https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.158</code>

La identidad privada <code>age</code> se obtiene exclusivamente del gestor de secretos autorizado,
entrada <strong>SOC Operations Installer Descifrado</strong>. Para este procedimiento se utiliza
temporalmente en el servidor de instalación. No publicarla en GitHub, la guía, chats o tickets.

#### Preparación principal desde Ubuntu

Ejecutar directamente en el servidor central Ubuntu <code>192.168.4.117</code>, donde se instalará
SOC Operations. No se necesita otro equipo: descargar, descifrar y preparar el release en ese
mismo servidor. Abrir una sesión administrativa y mantenerla durante estos pasos:

~~~bash
sudo -i
# Detener la secuencia si falla una descarga, un descifrado o una verificación.
set -euo pipefail
apt-get update
apt-get install --yes age curl nano
~~~

Crear una carpeta temporal privada bajo <code>/run</code> y el archivo <code>identity.txt</code>
vacío. La carpeta es nueva en cada ejecución y solo root puede acceder:

~~~bash
umask 077
SOC_AGE_DIR="$(mktemp -d /run/soc-operations-age.XXXXXX)"
SOC_AGE_IDENTITY="$SOC_AGE_DIR/identity.txt"
install -m 0600 /dev/null "$SOC_AGE_IDENTITY"
nano "$SOC_AGE_IDENTITY"
~~~

**Agregar la identidad privada age:** abrir en el Vault la entrada
**SOC Operations Installer Descifrado**, copiar su identidad privada y pegarla en
<code>identity.txt</code>. Debe contener la clave <code>AGE-SECRET-KEY-…</code> completa, sin
comillas; una clave pública <code>age1…</code> no permite descifrar. Guardar y cerrar el editor.
La nota anterior es una instrucción, no el contenido que debe pegarse en el archivo.
No generar una identidad nueva: debe ser la que corresponde al destinatario del release.

Validar que el archivo contiene una identidad utilizable sin mostrar la clave ni su contenido:

~~~bash
age-keygen -y "$SOC_AGE_IDENTITY" >/dev/null
stat -c '%a %U %n' "$SOC_AGE_DIR" "$SOC_AGE_IDENTITY"
~~~

<code>age-keygen</code> debe finalizar sin error y los permisos deben ser <code>700</code> para
la carpeta y <code>600</code> para el archivo, propiedad de root. Continuar en la misma sesión
Bash para conservar <code>SOC_AGE_IDENTITY</code>.

Crear un directorio privado separado y descargar el manifiesto y el activo cifrado:

~~~bash
umask 077
install -d -m 0700 /root/soc-operations-0.1.158-download
cd /root/soc-operations-0.1.158-download

curl --fail --location --proto '=https' --tlsv1.2 \
  --output SHA256SUMS \
  'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.158/SHA256SUMS'

curl --fail --location --proto '=https' --tlsv1.2 \
  --output soc-operations-0.1.158.tar.gz.age \
  'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.158/soc-operations-0.1.158.tar.gz.age'
~~~

Verificar primero el manifiesto descargado y después el activo cifrado contra las huellas fijadas
en esta guía:

~~~bash
printf '%s  %s\n' \
  'fa18226838c6960ca00d7b50a6ce1de5347ede6983fd71596cc36f86d8fe7d45' \
  'SHA256SUMS' | sha256sum --check --strict -

printf '%s  %s\n' \
  'fe75e13514fb00314a14bea6e2e28a15d5b20d303e521408efcd7ca994625d68' \
  'soc-operations-0.1.158.tar.gz.age' | sha256sum --check --strict -
~~~

Descifrar con la identidad temporal, verificar el TAR y extraerlo. Después de comprobar los
hashes, retirar la copia temporal de la clave; la identidad original permanece en el Vault:

~~~bash
age --decrypt \
  --identity "$SOC_AGE_IDENTITY" \
  --output soc-operations-release-0.1.158.tar.gz \
  soc-operations-0.1.158.tar.gz.age

printf '%s  %s\n' \
  'c8b4c3d3cfe37a2aecc175bf95c5153fcc1a9e0b727cc8c64a981810428f2764' \
  'soc-operations-release-0.1.158.tar.gz' | sha256sum --check --strict -

tar --extract --gzip --file soc-operations-release-0.1.158.tar.gz
cd release-0.1.158
sha256sum --check --strict SHA256SUMS
test "$(find . -type f | wc -l)" -eq 49

rm -- "$SOC_AGE_IDENTITY"
rmdir -- "$SOC_AGE_DIR"
unset SOC_AGE_IDENTITY SOC_AGE_DIR
~~~

Los 48 elementos del manifiesto deben indicar <code>OK</code>. El directorio contiene 49 archivos
contando el propio manifiesto. No continuar ante un hash incorrecto o un número de archivos
distinto. Si se interrumpe el procedimiento antes de retirar la identidad, eliminar esa copia
temporal al finalizar la intervención.

Dejar el release en su ubicación definitiva en este mismo servidor. El bloque se detiene si ya
existe el destino, para revisar una preparación anterior antes de reemplazarla:

~~~bash
cd /root/soc-operations-0.1.158-download
if [ -e /root/soc-operations-release-0.1.158 ]; then
  printf '%s\n' 'El destino ya existe: revisar y verificar el release anterior antes de continuar.' >&2
  exit 1
fi
mv -T -- release-0.1.158 /root/soc-operations-release-0.1.158
chmod 0700 /root/soc-operations-release-0.1.158
~~~

Si trabajaste directamente en <code>.117</code>, continuar en
**Verificar el release e instalar el comando**. Las dos alternativas siguientes solo aplican
cuando se prepara el release en otro equipo.

#### Solo si se prepara en otro servidor Ubuntu

Si ejecutaste la preparación anterior en un servidor Ubuntu distinto de <code>.117</code>,
copiar el directorio completo al servidor central mediante la red administrativa. Instalar
<code>rsync</code> en ambos equipos si no está disponible. Sustituir
<code>&lt;USUARIO_ADMIN&gt;</code> por la cuenta SSH autorizada, que debe poder elevar privilegios de
forma controlada:

~~~bash
rsync --archive --protect-args \
  /root/soc-operations-release-0.1.158/ \
  '<USUARIO_ADMIN>@192.168.4.117:/var/tmp/soc-operations-release-0.1.158/'
~~~

En <code>192.168.4.117</code>, copiar el directorio recibido a su ubicación definitiva. La
transferencia incluye solo el release; la identidad <code>age</code> ya se retiró del equipo de origen:

~~~bash
sudo install -d -o root -g root -m 0700 /root/soc-operations-release-0.1.158
sudo rsync --archive --chown=root:root \
  /var/tmp/soc-operations-release-0.1.158/ \
  /root/soc-operations-release-0.1.158/
~~~

#### Alternativa desde Windows

Windows se conserva únicamente como estación administrativa alternativa. Con <code>age</code>
instalado:

~~~powershell
$ReleaseDownload = Join-Path $env:USERPROFILE 'Downloads\soc-operations-0.1.158'
New-Item -ItemType Directory -Force -Path $ReleaseDownload | Out-Null
Set-Location $ReleaseDownload

curl.exe --fail --location --proto '=https' --tlsv1.2 --output SHA256SUMS 'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.158/SHA256SUMS'
curl.exe --fail --location --proto '=https' --tlsv1.2 --output soc-operations-0.1.158.tar.gz.age 'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.158/soc-operations-0.1.158.tar.gz.age'

$ExpectedManifest = 'fa18226838c6960ca00d7b50a6ce1de5347ede6983fd71596cc36f86d8fe7d45'
$ActualManifest = (Get-FileHash -LiteralPath '.\SHA256SUMS' -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualManifest -ne $ExpectedManifest) { throw 'SHA-256 invalido para SHA256SUMS' }

$ExpectedEncrypted = 'fe75e13514fb00314a14bea6e2e28a15d5b20d303e521408efcd7ca994625d68'
$ActualEncrypted = (Get-FileHash -LiteralPath '.\soc-operations-0.1.158.tar.gz.age' -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualEncrypted -ne $ExpectedEncrypted) { throw 'SHA-256 invalido para el activo cifrado' }

age --decrypt --identity 'RUTA_SEGURA\identity.txt' --output 'soc-operations-release-0.1.158.tar.gz' 'soc-operations-0.1.158.tar.gz.age'

$ExpectedPlain = 'c8b4c3d3cfe37a2aecc175bf95c5153fcc1a9e0b727cc8c64a981810428f2764'
$ActualPlain = (Get-FileHash -LiteralPath '.\soc-operations-release-0.1.158.tar.gz' -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualPlain -ne $ExpectedPlain) { throw 'SHA-256 invalido para el TAR descifrado' }

tar -xzf '.\soc-operations-release-0.1.158.tar.gz'
~~~

Transferir después <code>release-0.1.158</code> completo por el canal administrativo y ejecutar en
Ubuntu la verificación interna con <code>sha256sum --check --strict SHA256SUMS</code>. Dejar el
directorio en <code>/root/soc-operations-release-0.1.158</code>, como en la alternativa anterior.

#### Verificar el release e instalar el comando

En el servidor central <code>192.168.4.117</code>, ejecutar como root. Si llegas desde una de las
alternativas, abrir antes una sesión con <code>sudo -i</code>:

No copiar únicamente el ZIP del plugin: el instalador verifica el orquestador, helpers, wheel,
locks, unidades y plantillas mediante hashes fijos.

~~~bash
cd /root/soc-operations-release-0.1.158
sha256sum --check SHA256SUMS
sudo install -o root -g root -m 0755 soc-operations-install \
  /usr/local/sbin/soc-operations-install
sudo chmod 0600 /root/wa01-soc-topology.json
sudo test -r /etc/wazuh-indexer/certs/admin.pem
sudo test -r /etc/wazuh-indexer/certs/admin-key.pem
sudo test -r /etc/wazuh-indexer/certs/root-ca.pem
sudo test -r /var/ossec/api/configuration/ssl/server.crt
~~~

No continuar si un hash falla o si el release no contiene
<code>socOperations-2.19.6.zip</code>.

### Almacenamiento interno de evidencias y copia recuperada de MinIO

SOC Operations utiliza MinIO como almacenamiento interno compatible con S3. No requiere
contratar Amazon S3 ni preparar un servicio externo para esta instalación. Se configura
<code>http://minio:9000</code> y el bucket <code>soc-operations-evidence</code>; los puertos
9000 y 9001 se mantienen en loopback, sin publicarlos mediante Cloudflare o HAProxy.

Desde el release <code>0.1.155</code>, el TAR cifrado incluye
<code>soc-operations-minio-image.tar.gz</code>, recuperado sin modificaciones del laboratorio
anterior. Su SHA-256 es
<code>2223b43be55458a29e8add829dbcd0cc0fda68872c104df6f5e475144b492598</code>.
La copia contiene únicamente la imagen <code>linux/amd64</code>, no los volúmenes ni las
credenciales del laboratorio. El instalador verifica el archivo, carga la imagen, comprueba
su identidad y plataforma y crea una etiqueta local con <code>pull_policy: never</code>.
MinIO no se descarga de Quay; OpenBao y las demás imágenes siguen dependiendo de sus registros.

Consultar <code>MINIO-NOTICE.md</code>, las licencias, los créditos y los archivos de fuentes
incluidos en el release. **Esta imagen debe evaluarse antes de aprobar su uso en producción:**
MinIO Community ya no se mantiene. La integridad y las pruebas locales de operaciones S3 no
certifican ausencia de vulnerabilidades, aislamiento de tenants, custodia de claves ni respaldo
y restauración. Se mantiene la configuración de cifrado existente; recuperar la imagen no
sustituye la evaluación de ese diseño para producción.

### Preflight sin cambios

Ejecutar primero solo:

~~~bash
sudo /usr/local/sbin/soc-operations-install preflight \
  --topology-file /root/wa01-soc-topology.json \
  --service-address 192.168.4.117 \
  --staging-root /root/soc-operations-release-0.1.158
~~~

El resultado debe identificar <code>topology=distributed</code>, Wazuh
<code>4.14.8-1</code> y OpenSearch Dashboards <code>2.19.6</code>. El preflight verifica
plataforma, credenciales administrativas, número exacto de nodos y hashes, pero no instala el
producto. Conservar su salida y no ejecutar <code>apply</code> hasta resolver cualquier error.

### Instalar SOC Operations con apply

Después de un preflight satisfactorio, ejecutar en <code>192.168.4.117</code> durante la ventana
de instalación. <code>apply</code> vuelve a ejecutar el preflight y realiza cambios: instala
helpers, plugin, runtime y dependencias, y configura branding y RBAC de Wazuh. Puede reiniciar
servicios y afectar temporalmente el acceso al Dashboard.

Antes de ejecutar: si Dashboard, Manager y helper comparten servidor y el certificado de la API
incluye `DNS:localhost`, el host existente de `wazuh.yml` debe usar `url: https://localhost`.
Si aparece `[soc-wazuh-rbac] ERROR: Wazuh API request failed for POST /security/user/authenticate`,
seguir [el diagnóstico TLS y cambio a localhost](#error-de-conexión-con-la-api-wazuh-durante-rbac).
No usar esta dirección para una API ubicada en otro servidor ni desactivar la verificación TLS.

Reemplazar el correo y el nombre del ejemplo por los del primer ingeniero antes de ejecutar:

~~~bash
sudo /usr/local/sbin/soc-operations-install apply \
  --email 'ingenieria@kriptome.com' \
  --display-name 'Ingenieria SOC' \
  --public-url 'https://wa01-dashboard.kriptome.com' \
  --topology-file /root/wa01-soc-topology.json \
  --service-address 192.168.4.117 \
  --external-proxy-cidr 192.168.4.50/32 \
  --staging-root /root/soc-operations-release-0.1.158
~~~

| Parámetro | Uso en WA01 |
|---|---|
| <code>--email</code> | Identidad de acceso del primer usuario <code>soc_engineering</code>; usar un correo real bajo custodia del equipo. |
| <code>--display-name</code> | Nombre visible de ese usuario. |
| <code>--public-url</code> | Origen HTTPS del Dashboard; sin rutas ni la dirección de la API SOC. |
| <code>--topology-file</code> | JSON validado con los nodos y las rutas de certificados. |
| <code>--service-address</code> | IP del servidor donde se instala SOC Operations. |
| <code>--external-proxy-cidr</code> | IP de origen de HAProxy autorizada para la API externa en 9443; no sustituye la whitelist de usuarios. |
| <code>--staging-root</code> | Directorio completo del release cuyos hashes verifica el instalador. |

Consultar el estado después de cada etapa:

~~~bash
sudo /usr/local/sbin/soc-operations-install status
~~~

Si <code>apply</code> termina con un error, resolverlo antes de continuar. Las pausas de OpenBao
y del agente que se describen a continuación son estados previstos; no significan que toda la
instalación esté completa. Conservar los parámetros originales si se necesita repetir
<code>apply</code>; <code>resume</code> recupera los datos persistidos y no recibe estos argumentos.

#### Retomar el fallo de descarga de MinIO del release 0.1.154

Si <code>apply</code> completó <code>runtime</code> y se detuvo en <code>dependencies</code>
con <code>401 UNAUTHORIZED</code> al descargar MinIO desde Quay, descargar y verificar el
release <code>0.1.158</code> según **Preparar el release fijo**. No modificar el paquete
anterior, las marcas de instalación ni los volúmenes de PostgreSQL, MinIO u OpenBao.

Instalar el orquestador del staging nuevo y repetir los comandos de preflight y apply de
esta guía con <code>--staging-root /root/soc-operations-release-0.1.158</code>.
Conservar exactamente el correo, el nombre, la URL pública y la topología del primer intento.
Por ejemplo, si se utilizó <code>cmedina@kriptome.com</code>, conservar esa identidad en vez
de cambiarla por el correo de ejemplo de la guía.

El paso de dependencias debe mostrar
<code>Bundled MinIO image verified and imported; no registry pull required</code>.
El resto de la instalación conserva sus pausas previstas para la custodia de OpenBao y la
activación del primer ingeniero. <code>resume</code> se ejecuta en esas etapas; primero se debe
repetir <code>apply</code> para instalar los helpers nuevos y completar las dependencias.

#### Retomar el fallo de conexión del release 0.1.153

El release <code>0.1.158</code> corrige las direcciones loopback fijas del helper del plugin:
usa el Indexer y los certificados declarados en la topología y la IP de servicio del Dashboard
para sus comprobaciones de salud. También corrige esas comprobaciones en runtime y status.

Si <code>0.1.153</code> se detuvo en <code>dashboard-plugin</code> con
<code>Failed to connect to 127.0.0.1 port 9200</code>, descargar y verificar el release
<code>0.1.158</code> siguiendo **Preparar el release fijo**. Conservar el directorio anterior y
los estados de <code>/var/lib/soc-operations-installer</code>: foundation ya aplicó cambios y
no es necesario borrar sus marcas ni volver a desplegar Wazuh.

Instalar el nuevo orquestador y repetir el preflight:

~~~bash
sudo install -o root -g root -m 0755 \
  /root/soc-operations-release-0.1.158/soc-operations-install \
  /usr/local/sbin/soc-operations-install
sudo /usr/local/sbin/soc-operations-install preflight \
  --topology-file /root/wa01-soc-topology.json \
  --service-address 192.168.4.117 \
  --staging-root /root/soc-operations-release-0.1.158
~~~

Después ejecutar el comando <code>apply</code> anterior, conservando exactamente el correo,
nombre y URL usados en el primer intento, y usando el staging <code>0.1.158</code>. El instalador
reinstala los helpers verificados y omite los pasos ya completados, incluidos root-preflight y
foundation en este caso. Debe avanzar más allá de <code>dashboard-plugin</code>; después seguir
la acción indicada para OpenBao. <code>resume</code> no reemplaza esta repetición de
<code>apply</code>, porque aún faltan las dependencias y los servicios iniciales.

Esta recuperación corresponde al fallo reportado antes de instalar el plugin. Si el estado o
el error son distintos, revisarlos antes de continuar. No modificar manualmente los hashes ni
los archivos del release anterior.

### Bloqueo del branding en Wazuh 4.14.8

Si `apply` termina con `el overlay fue validado para 4.14.7; paquete detectado: 4.14.8-1`,
el problema es la comprobación antigua del script incluido en el TAR de branding, no las
dependencias ni OpenBao. No cambiar la versión detectada ni editar el TAR publicado:
el instalador verifica su SHA-256.

La corrección se distribuye en el release `0.1.158` de GitHub. Acepta únicamente Dashboard 4.14.7 y 4.14.8 y conserva la
comprobación de destinos, hashes, respaldo y rollback. Las pruebas locales de versiones
no sustituyen la validación de salud y visual en WA01.

Una vez recibido y verificado el release corregido, instalar su ejecutable:

~~~bash
sudo install -o root -g root -m 0755 \
  /root/soc-operations-release-0.1.158/soc-operations-install \
  /usr/local/sbin/soc-operations-install
~~~

Repetir el comando `apply` anterior con los mismos parámetros de identidad, topología
y publicación, sustituyendo únicamente `--staging-root` por
`/root/soc-operations-release-0.1.158`. No borrar los estados ni los volúmenes; el
instalador debe reconocer los pasos completados. Inicializar OpenBao solo después de
que `apply` finalice correctamente.

### Error de conexión con la API Wazuh durante RBAC

Si `apply` se detiene en `wazuh-rbac` con este mensaje:

~~~text
[soc-wazuh-rbac] ERROR: Wazuh API request failed for POST /security/user/authenticate
~~~

No asumir que la contraseña es incorrecta: este mensaje corresponde a un fallo de
conexión o TLS. Primero comprobar el servicio, el destino y la identidad del certificado,
sin mostrar la contraseña de `wazuh-wui`:

~~~bash
sudo ss -lntp | grep ':55000'

sudo grep -nE '^[[:space:]]*(url|port|run_as):' \
  /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml

sudo openssl x509 \
  -in /var/ossec/api/configuration/ssl/server.crt \
  -noout -subject -issuer -ext subjectAltName
~~~

En WA01, Dashboard y Manager comparten `.117` y el helper RBAC también se ejecuta allí.
El certificado observado identifica únicamente `DNS:localhost`; acceder mediante
`https://192.168.4.117:55000` falla porque la IP no figura en sus SAN. Que los Indexers
estén distribuidos en otros servidores no impide usar localhost para esta conexión local.

Solo si Dashboard, Manager y helper están en el mismo servidor y el certificado identifica
`localhost`, comprobar primero la conexión local conservando la verificación TLS:

~~~bash
sudo curl --silent --show-error --output /dev/null \
  --write-out 'HTTP %{http_code}\n' \
  --cacert /var/ossec/api/configuration/ssl/server.crt \
  https://localhost:55000/
~~~

Un `HTTP 401` sin error TLS confirma que se alcanzó la API sin autenticación; no valida
las credenciales. Si esta prueba funciona, respaldar y editar la configuración:

~~~bash
sudo cp -a \
  /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml \
  "/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml.pre-localhost-$(date -u +%Y%m%dT%H%M%SZ)"

sudo nano /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml
~~~

En el registro del host existente, cambiar únicamente `url`:

~~~yaml
url: https://localhost
~~~

Conservar `port: 55000`, usuario, contraseña y `run_as: true`; no reemplazar todo el archivo
ni agregar un segundo host. Reiniciar Dashboard y comprobar el servicio:

~~~bash
sudo systemctl restart wazuh-dashboard
sudo systemctl is-active wazuh-dashboard
~~~

Después repetir el `apply` original con los mismos parámetros y el staging vigente.
No borrar estados, repetir el branding ya completado ni reinicializar OpenBao.
El helper vuelve a leer el destino desde `wazuh.yml`.

Si Dashboard o el consumidor están en otro servidor, **no usar localhost**: apuntaría a ese
otro equipo. Usar un FQDN interno que resuelva al Manager y coincida con los SAN, o emitir
un certificado con los SAN correctos y configurar la CA confiable en cada consumidor.
No usar `curl -k` ni desactivar la comprobación del nombre para ocultar el problema.

### Inicializar OpenBao y continuar la instalación

En una instalación nueva, el estado esperado tras <code>apply</code> es
<code>waiting_for_openbao_custody</code>. Solo si OpenBao aún no está inicializado, ejecutar:

~~~bash
sudo /usr/local/sbin/soc-operations-install openbao-init
~~~

El helper del release <code>0.1.158</code> solicita literalmente <code>INIT WA001</code>.
Ese texto es una confirmación interna del instalador, aunque el deployment se llame
<code>wa01</code>. La inicialización muestra una sola vez cinco recovery shares, con umbral de
tres, y el token root inicial. Guardarlos con la custodia indicada por el comando, incluyendo
una copia cifrada externa de la clave de sellado. No registrar esta sesión con <code>tee</code>
o grabación de terminal: su salida contiene secretos.

Este release utiliza auto-unseal estático local; la custodia de su clave forma parte de la
recuperación y debe validarse antes de aceptar producción. No repetir <code>openbao-init</code>
si el estado indica que OpenBao ya está inicializado.

Si aparece <code>waiting_for_openbao_unseal</code>, revisar el estado de OpenBao. Para una
instancia existente con sellado Shamir, el comando interactivo es:

~~~bash
sudo /usr/local/sbin/soc-operations-install openbao-unseal
~~~

Para un fallo del auto-unseal estático, recuperar primero su clave/configuración; las recovery
shares no reemplazan esa clave de sellado. Una vez inicializado y desbloqueado, continuar:

~~~bash
sudo /usr/local/sbin/soc-operations-install resume
sudo /usr/local/sbin/soc-operations-install status
~~~

Durante la configuración inicial, <code>resume</code> solicita el token root mediante entrada
oculta. En la topología distribuida, si el agente todavía no existe, se detiene en
<code>waiting_for_manager_agent</code>. Continuar con el apartado siguiente; no repetir la
inicialización de OpenBao.

### Instalar el agente en el Manager de WA01

#### Retomar el error de versión del paquete del agente

Los instaladores hasta `0.1.157` consultaban `soc_operations.__version__`, cuyo valor
interno quedó en `0.1.112`, aunque el wheel y sus metadatos de distribución son `0.1.113`.
Esto provoca `installed agent package version is invalid` después de que pip informe éxito.
El instalador `0.1.158` consulta los metadatos mediante `importlib.metadata` en modo aislado
y los verifica tanto después de instalar como antes de reutilizar un entorno existente.
No cambia el wheel ni desactiva su verificación SHA-256.

Para una instalación parcial, preparar y verificar el release nuevo con el procedimiento
anterior; instalar su ejecutable `soc-operations-install` y repetir el `apply` original
con los mismos parámetros de identidad, topología y publicación, usando el staging
`/root/soc-operations-release-0.1.158`. Esto actualiza los helpers y registra el nuevo staging
sin borrar los pasos completados. No usar `upgrade` para este caso ni reinicializar OpenBao.
Después repetir el comando de instalación del agente que sigue y ejecutar `resume`
cuando la instalación del agente finalice correctamente. No borrar el venv ni los volúmenes.

El agente privilegiado se instala en <code>.117</code>, donde también reside el Dashboard. El
primer <code>resume</code> ya debe haber creado las dos claves públicas de firma. Como ambos
componentes comparten servidor, no es necesario transferirlas entre equipos.

~~~bash
sudo test -r /etc/soc-deploy-agent/release-signing.pem
sudo test -r /etc/soc-deploy-agent/provisioning-signing.pem
sudo test -x /usr/local/sbin/soc-lab-tenant-provisioner

sudo env \
  SOC_DEPLOYMENT_ID=wa01 \
  SOC_STAGING_ROOT=/root/soc-operations-release-0.1.158 \
  SOC_AIO_SERVICE_ADDRESS=192.168.4.117 \
  SOC_EXTERNAL_API_PROXY_CIDR=127.0.0.1/32 \
  SOC_WAZUH_TOPOLOGY=distributed \
  SOC_EXPECTED_WAZUH_VERSION=4.14.8-1 \
  SOC_WAZUH_VERSION=4.14.8 \
  SOC_DEPLOYMENT_AGENT_URL=https://wa01-dashboard.corp.atg:8443 \
  SOC_INDEXER_URL=https://192.168.4.118:9200 \
  SOC_INDEXER_TLS_SERVER_NAME=192.168.4.118 \
  SOC_INDEXER_ADMIN_CERT=/etc/wazuh-indexer/certs/admin.pem \
  SOC_INDEXER_ADMIN_KEY=/etc/wazuh-indexer/certs/admin-key.pem \
  SOC_INDEXER_CA_BUNDLE=/etc/wazuh-indexer/certs/root-ca.pem \
  SOC_WAZUH_API_CONFIG=/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml \
  SOC_WAZUH_API_CA_BUNDLE=/var/ossec/api/configuration/ssl/server.crt \
  /usr/local/sbin/soc-lab-tenant-provisioner install
~~~

La dirección loopback de <code>SOC_EXTERNAL_API_PROXY_CIDR</code> en este comando corresponde al
helper del agente; el gateway del Dashboard conserva el proxy <code>192.168.4.50/32</code>
declarado en <code>apply</code>. Mantener explícitas las variables de versión para Wazuh 4.14.8.

El nombre TLS debe coincidir con un SAN. El agente genera el bundle cliente en
<code>/etc/soc-operations-lab/deploy-tls/</code>: <code>client.crt</code>, <code>client.key</code> y
<code>service-ca.crt</code>. Estas son las rutas declaradas en el JSON de WA01 y ya son locales
al Dashboard. Si se eligieron otras rutas, ajustarlas mediante el procedimiento de topología
antes de reanudar.

### UFW y contenedores

El instalador no modifica UFW. Después de crear la red:

~~~bash
sudo docker network inspect soc-operations-wa001_frontend

sudo docker network inspect soc-operations-wa001_frontend \
  --format '{{json .IPAM.Config}}'
~~~

El nombre de red incluye el proyecto Compose fijo <code>soc-operations-wa001</code>,
aunque el deployment sea <code>wa01</code>. Consultar <code>soc-operations_frontend</code>
produce <code>network not found</code>; no crear otra red ni reinstalar el agente para resolverlo.

#### Obtener la interfaz, subred y gateway reales

Ejecutar estos comandos en `.117`, en la misma sesión Bash. Las variables se calculan;
no escribir `SOC_BRIDGE` como nombre literal de interfaz:

~~~bash
SOC_NETWORK='soc-operations-wa001_frontend'
SOC_BRIDGE=$(sudo docker network inspect "$SOC_NETWORK" \
  --format '{{if index .Options "com.docker.network.bridge.name"}}{{index .Options "com.docker.network.bridge.name"}}{{else}}br-{{slice .Id 0 12}}{{end}}')
SOC_SUBNET=$(sudo docker network inspect "$SOC_NETWORK" \
  --format '{{(index .IPAM.Config 0).Subnet}}')
SOC_GATEWAY=$(sudo docker network inspect "$SOC_NETWORK" \
  --format '{{(index .IPAM.Config 0).Gateway}}')

printf 'Interfaz: %s\nSubred: %s\nGateway: %s\n' \
  "$SOC_BRIDGE" "$SOC_SUBNET" "$SOC_GATEWAY"
ip -4 address show dev "$SOC_BRIDGE"
~~~

Ejemplo ilustrativo; el identificador del bridge cambia entre instalaciones:

~~~text
Interfaz: br-a1b2c3d4e5f6
Subred: 172.19.0.0/16
Gateway: 172.19.0.1
~~~

Detenerse si falla la inspección, la interfaz no existe o la subred/gateway difieren del
perfil esperado `172.19.0.0/16` y `172.19.0.1`. No copiar el bridge ilustrativo.

#### Confirmar el destino del agente desde el contenedor

En modo distribuido, el FQDN del agente de WA01 resuelve a la IP LAN `.117`, no al gateway
Docker. La comprobación mTLS hecha desde el host no garantiza acceso desde el contenedor.
Obtener los datos sin imprimir contraseñas, tokens ni el archivo de entorno completo:

~~~bash
sudo docker ps -a --filter name=soc-operations-wa001-api-1 \
  --format 'table {{.Names}}\t{{.Status}}'
sudo ss -lntp | grep ':8443'
sudo ufw status verbose
sudo grep -h '^SOC_DEPLOYMENT_AGENT_URL=' \
  /var/lib/soc-operations-installer/topology.env \
  /etc/soc-operations-lab/runtime.env
sudo docker exec soc-operations-wa001-api-1 python -c \
  "import socket; print(socket.getaddrinfo('wa01-dashboard.corp.atg', 8443, type=socket.SOCK_STREAM))"
~~~

En WA01 se observó resolución a `192.168.4.117` y Nginx escuchando en `0.0.0.0:8443`.
Si la búsqueda en `runtime.env` no devuelve una URL después de un rollback, revisar el
valor persistido en `topology.env`; no inventar un nuevo endpoint. La resolución correcta
no demuestra por sí sola que firewall y mTLS funcionen.

#### Regla UFW para el agente local de WA01

Solo después de comprobar los datos anteriores: si API y agente comparten `.117`, el FQDN
resuelve a `192.168.4.117` y la API pertenece al bridge indicado, permitir el tráfico del
bridge hacia **esa IP de destino**. Usar las variables calculadas, con `$`:

~~~bash
sudo ufw allow in on "$SOC_BRIDGE" from "$SOC_SUBNET" to 192.168.4.117 port 8443 proto tcp \
  comment 'SOC Operations bridge to deploy agent'
sudo ufw status verbose
~~~

No usar `to "$SOC_GATEWAY"` para una conexión dirigida a `.117`: es un destino diferente.
El gateway solo corresponde a un endpoint que realmente resuelva al gateway, como el alias
local del perfil AIO. Si el Manager está en otro servidor, diseñar la regla en ese servidor
según el origen que reciba después del routing/NAT; no reutilizar este ejemplo local.

Si previamente se copió el marcador y UFW muestra exactamente la regla
`172.19.0.1 8443/tcp on SOC_BRIDGE` desde `172.19.0.0/16`, retirar únicamente esa regla errónea:

~~~bash
sudo ufw delete allow in on SOC_BRIDGE from 172.19.0.0/16 to 172.19.0.1 port 8443 proto tcp
~~~

No ejecutar `ufw reset`, no abrir 8443 a toda la LAN ni desactivar mTLS. La regla limitada
no demuestra que el certificado sea válido: comprobar la salud desde el contenedor antes
de repetir `resume`. Un `identity_agent=unavailable` también puede corresponder a DNS,
material TLS, permisos de los archivos o un rechazo del servicio.

Docker administra reglas de netfilter y, según la plataforma, puede evitar parte del filtrado
esperado por UFW. Verificar además la cadena <code>DOCKER-USER</code>, el binding real de los
puertos publicados y una prueba desde la LAN. La condición de aceptación es que 8443 solo sea
alcanzable desde el bridge autorizado.

### Reanudación final y primer acceso

Después de instalar el agente y comprobar la conectividad del bridge, ejecutar en <code>.117</code>:

~~~bash
sudo /usr/local/sbin/soc-operations-install resume
sudo /usr/local/sbin/soc-operations-install status
~~~

El instalador verifica mTLS, activa los agentes de identidad y aprovisionamiento y crea el primer
ingeniero. Solicita su contraseña por entrada oculta. En el bootstrap de este release no se
envía correo de activación al primer ingeniero: ingresar directamente en
<code>https://wa01-dashboard.kriptome.com</code> con el correo indicado en <code>apply</code> y
la contraseña establecida durante <code>resume</code>.

El estado debe mostrar <code>phase=complete</code>, <code>topology=distributed</code>,
<code>deployment_id=wa01</code> y los pasos completados. Si continúa en
<code>waiting_for_manager_agent</code>, revisar servicio del agente, resolución DNS, TLS, rutas
del bundle y firewall antes de repetir <code>resume</code>. Completar después las pruebas de
aceptación; el estado técnico <code>complete</code> no sustituye la validación de producción.

### Bloqueo de certificados

El aprovisionador actual genera certificados mTLS del agente válidos por 30 días y no existe rotación automática documentada. Antes de producción se debe implementar y probar:

- Renovación sin interrupción.
- Alertas de vencimiento.
- Solapamiento controlado de certificados.
- Revocación y recuperación.
- Prueba incorporada a aceptación.

## GeoIP MaxMind

### Diseño

- <code>.117</code> descarga GeoLite2 City, Country y ASN.
- Publica releases por mTLS en 8444.
- Solo <code>.118</code> y <code>.119</code> instalan worker.
- Cada worker usa certificado cliente propio.
- La sincronización es automática y la activación manual, rolling.
- Se conservan cuatro releases.

### Distribuidor en 192.168.4.117

Las plantillas del TAR `0.1.158` están en la raíz del release. La ruta
`deploy/geoip/manager.env.example` pertenece al repositorio fuente y **no existe** en el
paquete extraído. Usar el staging verificado, sin depender del directorio actual.
Si aparece `install: cannot stat 'deploy/geoip/manager.env.example'`, no descargar otra
plantilla: comprobar `/root/soc-operations-release-0.1.158/manager.env.example`.

~~~bash
SOC_GEOIP_RELEASE='/root/soc-operations-release-0.1.158'
sudo test -f "$SOC_GEOIP_RELEASE/manager.env.example"
sudo test -f "$SOC_GEOIP_RELEASE/GeoIP.conf.example"
# Continuar solo si ambas comprobaciones terminan sin error.
sudo apt-get install -y geoipupdate libmaxminddb-bin curl jq nginx openssl util-linux
sudo install -d -o root -g root -m 0700 /etc/soc-geoip-manager

if sudo test -e /etc/soc-geoip-manager/manager.env; then
  printf '%s\n' 'manager.env ya existe: conservar y revisar, no sobrescribir.'
else
  sudo install -o root -g root -m 0600 \
    "$SOC_GEOIP_RELEASE/manager.env.example" /etc/soc-geoip-manager/manager.env
fi

if sudo test -e /etc/soc-geoip-manager/GeoIP.conf; then
  printf '%s\n' 'GeoIP.conf ya existe: conservar sus credenciales, no sobrescribir.'
else
  sudo install -o root -g root -m 0600 \
    "$SOC_GEOIP_RELEASE/GeoIP.conf.example" /etc/soc-geoip-manager/GeoIP.conf
fi

sudo nano /etc/soc-geoip-manager/manager.env
~~~

Configurar en `manager.env`:

~~~text
SOC_GEOIP_MANAGER_LISTEN_IP=192.168.4.117
SOC_GEOIP_MANAGER_LISTEN_PORT=8444
SOC_GEOIP_MANAGER_SERVER_NAME=wa01-dashboard.corp.atg
SOC_GEOIP_MANAGER_MAXMIND_CONFIG=/etc/soc-geoip-manager/GeoIP.conf
SOC_GEOIP_MANAGER_KEEP_RELEASES=4
~~~

Editar `GeoIP.conf` sin imprimirlo en logs o chats:

~~~bash
sudo nano /etc/soc-geoip-manager/GeoIP.conf
sudo chown root:root /etc/soc-geoip-manager/manager.env /etc/soc-geoip-manager/GeoIP.conf
sudo chmod 0600 /etc/soc-geoip-manager/manager.env /etc/soc-geoip-manager/GeoIP.conf
~~~

Sustituir `YOUR_MAXMIND_ACCOUNT_ID` y `YOUR_MAXMIND_LICENSE_KEY` de la plantilla por los
valores del gestor de secretos autorizado y conservar:

~~~text
EditionIDs GeoLite2-City GeoLite2-Country GeoLite2-ASN
~~~

Mantenerlo <code>root:root 0600</code>; nunca guardar la licencia en Git o evidencia.
No ejecutar `install /dev/null .../GeoIP.conf` sobre un archivo existente: lo vaciaría.
`libmaxminddb-bin` proporciona `mmdblookup`, requerido para validar las bases descargadas.

**Limitación detectada en los helpers del release 0.1.158:** las comprobaciones de
herramientas invocan `/usr/bin/command`, aunque `command` es un builtin de Bash. Si ese
ejecutable no existe en Ubuntu, el preflight se detiene. No crear un alias o ejecutable para
saltarse el control ni continuar con `install`: hace falta corregir y publicar el helper.
Esta actualización de documentación no modifica el instalador ni acredita GeoIP end-to-end.

Instalar el ejecutable verificado y pasar el staging explícitamente: copiar el helper a
`/usr/local/sbin` no copia su plantilla Nginx ni sus unidades systemd.

~~~bash
sudo install -o root -g root -m 0755 \
  "$SOC_GEOIP_RELEASE/soc-geoip-manager" /usr/local/sbin/soc-geoip-manager
sudo env SOC_GEOIP_STAGING_ROOT="$SOC_GEOIP_RELEASE" soc-geoip-manager preflight
# Ejecutar install únicamente después de un preflight satisfactorio.
sudo env SOC_GEOIP_STAGING_ROOT="$SOC_GEOIP_RELEASE" soc-geoip-manager install
sudo soc-geoip-manager update
sudo soc-geoip-manager issue-client wa01-indexer01 /root/geoip-wa01-indexer01
sudo soc-geoip-manager issue-client wa01-indexer02 /root/geoip-wa01-indexer02
sudo soc-geoip-manager status
~~~

Transferir cada bundle solo a su nodo y eliminar las copias temporales.

### Workers en 192.168.4.118 y 192.168.4.119

Preparar en **cada nodo** el mismo release verificado y el bundle mTLS de ese nodo mediante
el canal SSH autorizado. No transferir `GeoIP.conf`, la licencia MaxMind ni la clave privada
de la CA del distribuidor. Los archivos del release están en su raíz, no en `deploy/geoip/`.
El helper lee `/etc/soc-geoip-indexer/worker.env`: `indexer.env.example` es solo el nombre de
la plantilla.

~~~bash
SOC_GEOIP_RELEASE='/root/soc-operations-release-0.1.158'
sudo test -f "$SOC_GEOIP_RELEASE/indexer.env.example"
# Continuar solo si la plantilla está presente y se verificó SHA256SUMS.
sudo install -d -o root -g root -m 0700 /etc/soc-geoip-indexer
if sudo test -e /etc/soc-geoip-indexer/worker.env; then
  printf '%s\n' 'worker.env ya existe: conservar y revisar, no sobrescribir.'
else
  sudo install -o root -g root -m 0600 \
    "$SOC_GEOIP_RELEASE/indexer.env.example" /etc/soc-geoip-indexer/worker.env
fi
sudo nano /etc/soc-geoip-indexer/worker.env
~~~

Base para cada nodo:

~~~text
SOC_GEOIP_SOURCE_URL=https://wa01-dashboard.corp.atg:8444/geoip/v1
SOC_GEOIP_CLIENT_CERT=/etc/soc-geoip-indexer/client.crt
SOC_GEOIP_CLIENT_KEY=/etc/soc-geoip-indexer/client.key
SOC_GEOIP_CA_BUNDLE=/etc/soc-geoip-indexer/ca.crt
# En .119, sustituir esta IP por 192.168.4.119; debe coincidir con los SAN.
SOC_GEOIP_INDEXER_URL=https://192.168.4.118:9200
SOC_GEOIP_INDEXER_ADMIN_CERT=/etc/wazuh-indexer/certs/admin.pem
SOC_GEOIP_INDEXER_ADMIN_KEY=/etc/wazuh-indexer/certs/admin-key.pem
SOC_GEOIP_INDEXER_CA_BUNDLE=/etc/wazuh-indexer/certs/root-ca.pem
SOC_GEOIP_EXPECTED_INDEXER_NODES=3
SOC_GEOIP_AUTO_ACTIVATE=false
SOC_GEOIP_INDEXER_SERVICE=wazuh-indexer.service
~~~

Configurar las rutas a CA del distribuidor, certificado y clave cliente propios, CA del Indexer, certificado administrativo y clave administrativa. Claves y entorno deben ser 0600.
Instalar `ca.crt`, `client.crt` y `client.key` del bundle del nodo en las rutas anteriores
antes del preflight. No usar el certificado cliente del otro Indexer.

Los nombres anteriores son los que lee el helper; no usar `SOC_GEOIP_SELF_INDEXER_URL`,
`SOC_GEOIP_EXPECTED_NODES` ni `SOC_GEOIP_SOURCE_SERVER_NAME`, que no son sus parámetros.

Para el timer de Wazuh 4.14.8, la unidad necesita también el override de versión:
el helper resuelve `SOC_EXPECTED_WAZUH_VERSION` antes de leer `worker.env`.
Antes de instalar/activar el worker, preparar el drop-in:

~~~bash
sudo install -d -o root -g root -m 0755 /etc/systemd/system/soc-geoip-indexer.service.d
sudo nano /etc/systemd/system/soc-geoip-indexer.service.d/wazuh-version.conf
~~~

Contenido del drop-in, conservando otros overrides existentes:

~~~ini
[Service]
Environment=SOC_EXPECTED_WAZUH_VERSION=4.14.8-1
~~~

Después ejecutar `sudo systemctl daemon-reload`. No confiar en que una variable de la
sesión SSH se transfiera automáticamente a los timers de systemd.

~~~bash
sudo install -o root -g root -m 0755 \
  "$SOC_GEOIP_RELEASE/soc-geoip-indexer" /usr/local/sbin/soc-geoip-indexer
sudo env SOC_GEOIP_STAGING_ROOT="$SOC_GEOIP_RELEASE" SOC_EXPECTED_WAZUH_VERSION=4.14.8-1 \
  soc-geoip-indexer preflight
# No continuar si falla el preflight, incluida la limitación /usr/bin/command indicada arriba.
sudo env SOC_GEOIP_STAGING_ROOT="$SOC_GEOIP_RELEASE" SOC_EXPECTED_WAZUH_VERSION=4.14.8-1 \
  soc-geoip-indexer install
sudo env SOC_EXPECTED_WAZUH_VERSION=4.14.8-1 soc-geoip-indexer sync
sudo env SOC_EXPECTED_WAZUH_VERSION=4.14.8-1 soc-geoip-indexer status
~~~

Activar primero en Indexer 1:

~~~bash
sudo env SOC_EXPECTED_WAZUH_VERSION=4.14.8-1 soc-geoip-indexer activate
sudo env SOC_EXPECTED_WAZUH_VERSION=4.14.8-1 soc-geoip-indexer status
~~~

Esperar estado green, verificar pipelines y simular una IP pública. Después repetir en Indexer 2. Comparar SHA-256 de City, Country y ASN entre distribuidor y receptores.

Timers previstos:

- Distribuidor: martes y viernes 04:15, demora aleatoria de hasta una hora.
- Workers: martes y viernes 06:15, demora aleatoria de hasta cuatro horas.

Con <code>SOC_GEOIP_AUTO_ACTIVATE=false</code>, el timer sincroniza pero no activa.

~~~bash
systemctl list-timers --all | grep -i geoip
sudo journalctl -u soc-geoip-manager --since '-7 days' --no-pager
sudo journalctl -u soc-geoip-indexer --since '-7 days' --no-pager
~~~

Antes de actualizar SOC Operations, seguir la preparación de upgrade de <code>docs/maxmind-geoip.md</code>.

## Pruebas de aceptación

### Plataforma

- Tres Indexers visibles, estado green y dos nodos de datos.
- Ningún shard en el Indexer central.
- Filebeat y Dashboard siguen operativos al detener individualmente <code>.118</code> o <code>.119</code>.
- Un agente sintético se enrola por el FQDN público y envía eventos por 1514.
- La API 55000 no es pública.

### Publicación

- Los tres servicios HTTPS rechazan IP no autorizada.
- Una IP permitida accede con certificado válido.
- API Indexer permite consultas de lectura y rechaza mutaciones.
- 1514/1515 funcionan con el registro Cloudflare en DNS only.
- HAProxy audita origen, destino, resultado y latencia sin credenciales.

### SOC Operations

- Todas las pruebas de <code>docs/acceptance.md</code> pasan.
- Dos tenants superan pruebas positivas y negativas de aislamiento.
- OpenBao, PostgreSQL, S3, SMTP y auditoría funcionan de extremo a extremo.
- El agente privilegiado acepta solo mTLS y operaciones allowlist.
- La rotación de certificados se prueba antes de 30 días.
- La API externa presenta <code>soc-external-api-wa01</code>.

### GeoIP y continuidad

- Los hashes City, Country y ASN coinciden.
- Los pipelines enriquecen documentos en ambos nodos.
- Un release inválido no se activa y rollback recupera el anterior.
- Snapshot OpenSearch y restauración probados.
- PostgreSQL demuestra RPO 15 minutos y el conjunto RTO 4 horas.
- Cada nodo puede reiniciarse de forma ordenada sin pérdida de quorum.

## Rollback y evidencia

Para cambios de Indexer:

- Confirmar green.
- Modificar Indexer 1 y esperar green.
- Modificar Indexer 2 y esperar green.
- Modificar el nodo manager-only si corresponde.
- Detener el cambio si el clúster no se recupera.

Conservar como evidencia:

- Versiones y SHA-256 de instaladores, plugin y bundles.
- Configuración sanitizada y roles de nodos.
- Estado UFW y pruebas de flujo.
- Salud, nodos y asignación de shards.
- Pruebas internas y públicas de HAProxy.
- Resultados de aislamiento, failover y restauración.
- Hashes y pruebas GeoIP.
- Ticket, aprobaciones, operador, hora y rollback.

## Pendientes previos a producción

- Definir <code>ADMIN_CIDR</code> y <code>SSH_PORT</code>.
- Confirmar SAN antes de configurar <code>verifyhost</code>.
- Proporcionar una dirección interna estable para Indexer.
- Automatizar rotación mTLS de SOC Operations.
- Dimensionar con EPS, agentes y retención reales.
- Aprobar <code>docs/acceptance.md</code>.
- Evaluar separar el Indexer manager-only del servidor central en una evolución futura.

## Referencias

- Arquitectura y puertos Wazuh: https://documentation.wazuh.com/current/getting-started/architecture.html
- Instalación Indexer: https://documentation.wazuh.com/current/installation-guide/wazuh-indexer/installation-assistant.html
- Instalación Server: https://documentation.wazuh.com/current/installation-guide/wazuh-server/step-by-step.html
- Instalación Dashboard: https://documentation.wazuh.com/current/installation-guide/wazuh-dashboard/step-by-step.html
- Puertos proxy Cloudflare: https://developers.cloudflare.com/fundamentals/reference/network-ports/
- GeoIP del proyecto: <code>docs/maxmind-geoip.md</code>
- Compatibilidad: <code>docs/compatibility.md</code>
- Aceptación: <code>docs/acceptance.md</code>
