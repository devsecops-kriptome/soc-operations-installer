# Instalación distribuida WA01 con Wazuh 4.14.8 y SOC Operations

> Estado: guía de preparación y despliegue para producción.
> Revisión: 2026-10-04.
> Alcance: Wazuh 4.14.8, tres Indexers, Manager, Dashboard, SOC Operations, HAProxy, Cloudflare, UFW y GeoIP MaxMind.
> Bloqueo: SOC Operations no debe autorizarse para producción hasta superar completamente <code>docs/acceptance.md</code>.

<a id="objetivo-y-orden-de-ejecución"></a>

## 1. Objetivo y orden de ejecución

La instalación se realiza en este orden:

- Preparar DNS, certificados, sistema operativo, NTP y firewall.
- Instalar los tres Wazuh Indexer y formar el clúster.
- Dejar el Indexer central exclusivamente con rol <code>cluster_manager</code>.
- Instalar Manager, Filebeat y Dashboard en el servidor central.
- Publicar servicios mediante Cloudflare, NAT y HAProxy.
- Instalar y validar SOC Operations.
- Distribuir GeoIP MaxMind y activarlo de forma rolling.
- Ejecutar pruebas de seguridad, failover, restauración y aceptación.

<a id="arquitectura"></a>

## 2. Arquitectura

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

<a id="servicios-públicos"></a>

### 2.1. Servicios públicos

| Servicio | FQDN | Puerto | Acceso |
|---|---|---:|---|
| Dashboard | <code>wa01-dashboard.kriptome.com</code> | 443/TCP | Whitelist |
| API Indexer | <code>wa01-indexer-api.kriptome.com</code> | 443/TCP | Whitelist y métodos limitados |
| API SOC Operations | <code>wa01-socops-api.kriptome.com</code> | 443/TCP | Whitelist |
| Eventos de agentes | <code>wa01-agents.kriptome.com</code> | 1514/TCP | Público |
| Enrolamiento | <code>wa01-agents.kriptome.com</code> | 1515/TCP | Público |

<a id="límites-de-disponibilidad"></a>

### 2.2. Límites de disponibilidad

- Los tres Indexers votan como <code>cluster_manager</code>.
- Solo <code>.118</code> y <code>.119</code> almacenan datos y ejecutan ingest pipelines.
- Se tolera la pérdida de un Indexer de datos.
- El servidor <code>.117</code> es todavía un punto único para Manager, Dashboard, SOC Operations y agentes.
- La redundancia no reemplaza los respaldos.

<a id="cloudflare-nat-y-certificados"></a>

## 3. Cloudflare, NAT y certificados

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

<a id="matriz-de-red"></a>

## 4. Matriz de red

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

<a id="preparación"></a>

## 5. Preparación

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

<a id="cpu-de-las-máquinas-virtuales-para-minio"></a>

### 5.1. CPU de las máquinas virtuales para MinIO

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

<a id="ufw-por-servidor"></a>

## 6. UFW por servidor

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

<a id="central-1921684117"></a>

### 6.1. Central 192.168.4.117

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

<a id="indexer-1-1921684118"></a>

### 6.2. Indexer 1 192.168.4.118

~~~bash
sudo ufw allow from 192.168.4.117 to 192.168.4.118 port 9200 proto tcp comment 'Central a Indexer API'
sudo ufw allow from 192.168.4.50 to 192.168.4.118 port 9200 proto tcp comment 'HAProxy a Indexer API'
sudo ufw allow from 192.168.4.117 to 192.168.4.118 port 9300:9400 proto tcp comment 'Transporte central'
sudo ufw allow from 192.168.4.119 to 192.168.4.118 port 9300:9400 proto tcp comment 'Transporte Indexer02'
sudo ufw enable
~~~

<a id="indexer-2-1921684119"></a>

### 6.3. Indexer 2 192.168.4.119

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

<a id="instalación-de-wazuh-4148"></a>

## 7. Instalación de Wazuh 4.14.8

<a id="preparar-artefactos"></a>

### 7.1. Preparar artefactos

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

<a id="indexers"></a>

### 7.2. Indexers

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

<a id="validar-el-clúster-inicial"></a>

### 7.3. Validar el clúster inicial

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

<a id="convertir-1921684117-en-cluster-manager-exclusivo"></a>

### 7.4. Convertir 192.168.4.117 en cluster manager exclusivo

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

<a id="diagnóstico-si-el-nodo-central-no-arranca"></a>

### 7.5. Diagnóstico si el nodo central no arranca

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

<a id="manager-y-filebeat"></a>

### 7.6. Manager y Filebeat

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

<a id="dashboard"></a>

### 7.7. Dashboard

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

<a id="bloquear-actualizaciones-automáticas-de-wazuh-con-apt"></a>

### 7.8. Bloquear actualizaciones automáticas de Wazuh con APT

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

<a id="haproxy"></a>

## 8. HAProxy

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

<a id="validación-desde-una-fuente-externa-permitida"></a>

### 8.1. Validación desde una fuente externa permitida

La prueba debe ejecutarse desde una conexión que salga a Internet con una IP pública incluida en
la whitelist. No usar la misma LAN de HAProxy ni resolución DNS interna, porque eso no valida
Cloudflare, NAT ni el trayecto público.

<a id="confirmar-la-ip-de-origen"></a>

#### 8.1.1. Confirmar la IP de origen

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

<a id="validar-dns-público"></a>

#### 8.1.2. Validar DNS público

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

<a id="validar-conectividad-tcp"></a>

#### 8.1.3. Validar conectividad TCP

~~~powershell
Test-NetConnection 'wa01-dashboard.kriptome.com' -Port 443
Test-NetConnection 'wa01-indexer-api.kriptome.com' -Port 443
Test-NetConnection 'wa01-socops-api.kriptome.com' -Port 443
Test-NetConnection 'wa01-agents.kriptome.com' -Port 1514
Test-NetConnection 'wa01-agents.kriptome.com' -Port 1515
~~~

Cada prueba aplicable debe mostrar <code>TcpTestSucceeded : True</code>. Si SOC Operations todavía
no está instalado, la prueba de su puerto o health se registra como pendiente, no como aprobada.

<a id="validar-https-certificados-y-routing"></a>

#### 8.1.4. Validar HTTPS, certificados y routing

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

<a id="correlacionar-la-prueba-en-los-servidores"></a>

#### 8.1.5. Correlacionar la prueba en los servidores

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

<a id="prueba-negativa-obligatoria"></a>

#### 8.1.6. Prueba negativa obligatoria

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

<a id="soc-operations"></a>

## 9. SOC Operations

<a id="topología-declarada"></a>

### 9.1. Topología declarada

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
<code>root:root</code> y modo <code>0600</code>. El release <code>0.1.159</code> valida
exactamente este esquema y utiliza únicamente el primer elemento de <code>indexer.urls</code> como
endpoint operativo. Es recomendable reemplazarlo más adelante por una dirección interna estable
con health checks. Mientras no exista, se usa <code>.118</code> y se documenta el cambio manual a
<code>.119</code> durante una contingencia.

Los tres archivos <code>deployment_*</code> no existen en el primer preflight. Se generan al
instalar el agente mTLS después de inicializar OpenBao; es válido que estén ausentes hasta ese
punto.

<a id="instalación-y-seguridad"></a>

### 9.2. Instalación y seguridad

- Instalar el artefacto <code>socOperations-2.19.6.zip</code>, compatible con Wazuh 4.14.8.
- Verificar firma y SHA-256.
- Ejecutar preflight con la topología.
- Usar <code>192.168.4.117</code> como dirección de servicio.
- Declarar solo <code>192.168.4.50/32</code> como proxy externo confiable.
- Usar <code>https://wa01-dashboard.kriptome.com</code> como URL pública.
- Inicializar OpenBao y reanudar solo cuando esté operativo y desbloqueado.
- No pasar secretos persistentes por argumentos ni historial.

<a id="puerta-posterior-al-snapshot"></a>

### 9.3. Puerta posterior al snapshot

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

<a id="preparar-el-release-fijo"></a>

### 9.4. Preparar el release fijo

El release aprobado se publica cifrado en:

<code>https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.159</code>

La identidad privada <code>age</code> se obtiene exclusivamente del gestor de secretos autorizado,
entrada <strong>SOC Operations Installer Descifrado</strong>. Para este procedimiento se utiliza
temporalmente en el servidor de instalación. No publicarla en GitHub, la guía, chats o tickets.

<a id="preparación-principal-desde-ubuntu"></a>

#### 9.4.1. Preparación principal desde Ubuntu

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
install -d -m 0700 /root/soc-operations-0.1.159-download
cd /root/soc-operations-0.1.159-download

curl --fail --location --proto '=https' --tlsv1.2 \
  --output SHA256SUMS \
  'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.159/SHA256SUMS'

curl --fail --location --proto '=https' --tlsv1.2 \
  --output soc-operations-0.1.159.tar.gz.age \
  'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.159/soc-operations-0.1.159.tar.gz.age'
~~~

Verificar primero el manifiesto descargado y después el activo cifrado contra las huellas fijadas
en esta guía:

~~~bash
printf '%s  %s\n' \
  '65d74c87037c1570492c8e4cff17717ac4dfd3c340b2fcf9eeb192c667d34e29' \
  'SHA256SUMS' | sha256sum --check --strict -

printf '%s  %s\n' \
  'e0e843927a843af01e3bb4198199827886213f3ee9e909f91968b9eb2ec0ab1e' \
  'soc-operations-0.1.159.tar.gz.age' | sha256sum --check --strict -
~~~

Descifrar con la identidad temporal, verificar el TAR y extraerlo. Después de comprobar los
hashes, retirar la copia temporal de la clave; la identidad original permanece en el Vault:

~~~bash
age --decrypt \
  --identity "$SOC_AGE_IDENTITY" \
  --output soc-operations-release-0.1.159.tar.gz \
  soc-operations-0.1.159.tar.gz.age

printf '%s  %s\n' \
  'b395f84f9ec4e68c72f182145e2c9d06dea9fd3305185c641cf504122f4ff6dc' \
  'soc-operations-release-0.1.159.tar.gz' | sha256sum --check --strict -

tar --extract --gzip --file soc-operations-release-0.1.159.tar.gz
cd release-0.1.159
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
cd /root/soc-operations-0.1.159-download
if [ -e /root/soc-operations-release-0.1.159 ]; then
  printf '%s\n' 'El destino ya existe: revisar y verificar el release anterior antes de continuar.' >&2
  exit 1
fi
mv -T -- release-0.1.159 /root/soc-operations-release-0.1.159
chmod 0700 /root/soc-operations-release-0.1.159
~~~

Si trabajaste directamente en <code>.117</code>, continuar en
**Verificar el release e instalar el comando**. Las dos alternativas siguientes solo aplican
cuando se prepara el release en otro equipo.

<a id="solo-si-se-prepara-en-otro-servidor-ubuntu"></a>

#### 9.4.2. Solo si se prepara en otro servidor Ubuntu

Si ejecutaste la preparación anterior en un servidor Ubuntu distinto de <code>.117</code>,
copiar el directorio completo al servidor central mediante la red administrativa. Instalar
<code>rsync</code> en ambos equipos si no está disponible. Sustituir
<code>&lt;USUARIO_ADMIN&gt;</code> por la cuenta SSH autorizada, que debe poder elevar privilegios de
forma controlada:

~~~bash
rsync --archive --protect-args \
  /root/soc-operations-release-0.1.159/ \
  '<USUARIO_ADMIN>@192.168.4.117:/var/tmp/soc-operations-release-0.1.159/'
~~~

En <code>192.168.4.117</code>, copiar el directorio recibido a su ubicación definitiva. La
transferencia incluye solo el release; la identidad <code>age</code> ya se retiró del equipo de origen:

~~~bash
sudo install -d -o root -g root -m 0700 /root/soc-operations-release-0.1.159
sudo rsync --archive --chown=root:root \
  /var/tmp/soc-operations-release-0.1.159/ \
  /root/soc-operations-release-0.1.159/
~~~

<a id="alternativa-desde-windows"></a>

#### 9.4.3. Alternativa desde Windows

Windows se conserva únicamente como estación administrativa alternativa. Con <code>age</code>
instalado:

~~~powershell
$ReleaseDownload = Join-Path $env:USERPROFILE 'Downloads\soc-operations-0.1.159'
New-Item -ItemType Directory -Force -Path $ReleaseDownload | Out-Null
Set-Location $ReleaseDownload

curl.exe --fail --location --proto '=https' --tlsv1.2 --output SHA256SUMS 'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.159/SHA256SUMS'
curl.exe --fail --location --proto '=https' --tlsv1.2 --output soc-operations-0.1.159.tar.gz.age 'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.159/soc-operations-0.1.159.tar.gz.age'

$ExpectedManifest = '65d74c87037c1570492c8e4cff17717ac4dfd3c340b2fcf9eeb192c667d34e29'
$ActualManifest = (Get-FileHash -LiteralPath '.\SHA256SUMS' -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualManifest -ne $ExpectedManifest) { throw 'SHA-256 invalido para SHA256SUMS' }

$ExpectedEncrypted = 'e0e843927a843af01e3bb4198199827886213f3ee9e909f91968b9eb2ec0ab1e'
$ActualEncrypted = (Get-FileHash -LiteralPath '.\soc-operations-0.1.159.tar.gz.age' -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualEncrypted -ne $ExpectedEncrypted) { throw 'SHA-256 invalido para el activo cifrado' }

age --decrypt --identity 'RUTA_SEGURA\identity.txt' --output 'soc-operations-release-0.1.159.tar.gz' 'soc-operations-0.1.159.tar.gz.age'

$ExpectedPlain = 'b395f84f9ec4e68c72f182145e2c9d06dea9fd3305185c641cf504122f4ff6dc'
$ActualPlain = (Get-FileHash -LiteralPath '.\soc-operations-release-0.1.159.tar.gz' -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualPlain -ne $ExpectedPlain) { throw 'SHA-256 invalido para el TAR descifrado' }

tar -xzf '.\soc-operations-release-0.1.159.tar.gz'
~~~

Transferir después <code>release-0.1.159</code> completo por el canal administrativo y ejecutar en
Ubuntu la verificación interna con <code>sha256sum --check --strict SHA256SUMS</code>. Dejar el
directorio en <code>/root/soc-operations-release-0.1.159</code>, como en la alternativa anterior.

<a id="verificar-el-release-e-instalar-el-comando"></a>

#### 9.4.4. Verificar el release e instalar el comando

En el servidor central <code>192.168.4.117</code>, ejecutar como root. Si llegas desde una de las
alternativas, abrir antes una sesión con <code>sudo -i</code>:

No copiar únicamente el ZIP del plugin: el instalador verifica el orquestador, helpers, wheel,
locks, unidades y plantillas mediante hashes fijos.

~~~bash
cd /root/soc-operations-release-0.1.159
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

<a id="almacenamiento-interno-de-evidencias-y-copia-recuperada-de-minio"></a>

### 9.5. Almacenamiento interno de evidencias y copia recuperada de MinIO

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

<a id="preflight-sin-cambios"></a>

### 9.6. Preflight sin cambios

Ejecutar primero solo:

~~~bash
sudo /usr/local/sbin/soc-operations-install preflight \
  --topology-file /root/wa01-soc-topology.json \
  --service-address 192.168.4.117 \
  --staging-root /root/soc-operations-release-0.1.159
~~~

El resultado debe identificar <code>topology=distributed</code>, Wazuh
<code>4.14.8-1</code> y OpenSearch Dashboards <code>2.19.6</code>. El preflight verifica
plataforma, credenciales administrativas, número exacto de nodos y hashes, pero no instala el
producto. Conservar su salida y no ejecutar <code>apply</code> hasta resolver cualquier error.

<a id="instalar-soc-operations-con-apply"></a>

### 9.7. Instalar SOC Operations con apply

Después de un preflight satisfactorio, ejecutar en <code>192.168.4.117</code> durante la ventana
de instalación. <code>apply</code> vuelve a ejecutar el preflight y realiza cambios: instala
helpers, plugin, runtime y dependencias, y configura branding y RBAC de Wazuh. Puede reiniciar
servicios y afectar temporalmente el acceso al Dashboard.

> [!IMPORTANT]
> **Antes de ejecutar:** si Dashboard, Manager y helper comparten servidor y el certificado
> de la API incluye `DNS:localhost`, el host existente de `wazuh.yml` debe usar
> `url: https://localhost`. Si aparece
> `[soc-wazuh-rbac] ERROR: Wazuh API request failed for POST /security/user/authenticate`,
> seguir [el diagnóstico TLS y cambio a localhost](#error-de-conexión-con-la-api-wazuh-durante-rbac).
> No usar esta dirección para una API ubicada en otro servidor ni desactivar la verificación TLS.

Reemplazar el correo y el nombre del ejemplo por los del primer ingeniero antes de ejecutar:

~~~bash
sudo /usr/local/sbin/soc-operations-install apply \
  --email 'ingenieria@kriptome.com' \
  --display-name 'Ingenieria SOC' \
  --public-url 'https://wa01-dashboard.kriptome.com' \
  --topology-file /root/wa01-soc-topology.json \
  --service-address 192.168.4.117 \
  --external-proxy-cidr 192.168.4.50/32 \
  --staging-root /root/soc-operations-release-0.1.159
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

<a id="retomar-el-fallo-de-descarga-de-minio-del-release-01154"></a>

#### 9.7.1. Retomar el fallo de descarga de MinIO del release 0.1.154

Si <code>apply</code> completó <code>runtime</code> y se detuvo en <code>dependencies</code>
con <code>401 UNAUTHORIZED</code> al descargar MinIO desde Quay, descargar y verificar el
release <code>0.1.159</code> según **Preparar el release fijo**. No modificar el paquete
anterior, las marcas de instalación ni los volúmenes de PostgreSQL, MinIO u OpenBao.

Instalar el orquestador del staging nuevo y repetir los comandos de preflight y apply de
esta guía con <code>--staging-root /root/soc-operations-release-0.1.159</code>.
Conservar exactamente el correo, el nombre, la URL pública y la topología del primer intento.
Por ejemplo, si se utilizó <code>cmedina@kriptome.com</code>, conservar esa identidad en vez
de cambiarla por el correo de ejemplo de la guía.

El paso de dependencias debe mostrar
<code>Bundled MinIO image verified and imported; no registry pull required</code>.
El resto de la instalación conserva sus pausas previstas para la custodia de OpenBao y la
activación del primer ingeniero. <code>resume</code> se ejecuta en esas etapas; primero se debe
repetir <code>apply</code> para instalar los helpers nuevos y completar las dependencias.

<a id="retomar-el-fallo-de-conexión-del-release-01153"></a>

#### 9.7.2. Retomar el fallo de conexión del release 0.1.153

El release <code>0.1.159</code> corrige las direcciones loopback fijas del helper del plugin:
usa el Indexer y los certificados declarados en la topología y la IP de servicio del Dashboard
para sus comprobaciones de salud. También corrige esas comprobaciones en runtime y status.

Si <code>0.1.153</code> se detuvo en <code>dashboard-plugin</code> con
<code>Failed to connect to 127.0.0.1 port 9200</code>, descargar y verificar el release
<code>0.1.159</code> siguiendo **Preparar el release fijo**. Conservar el directorio anterior y
los estados de <code>/var/lib/soc-operations-installer</code>: foundation ya aplicó cambios y
no es necesario borrar sus marcas ni volver a desplegar Wazuh.

Instalar el nuevo orquestador y repetir el preflight:

~~~bash
sudo install -o root -g root -m 0755 \
  /root/soc-operations-release-0.1.159/soc-operations-install \
  /usr/local/sbin/soc-operations-install
sudo /usr/local/sbin/soc-operations-install preflight \
  --topology-file /root/wa01-soc-topology.json \
  --service-address 192.168.4.117 \
  --staging-root /root/soc-operations-release-0.1.159
~~~

Después ejecutar el comando <code>apply</code> anterior, conservando exactamente el correo,
nombre y URL usados en el primer intento, y usando el staging <code>0.1.159</code>. El instalador
reinstala los helpers verificados y omite los pasos ya completados, incluidos root-preflight y
foundation en este caso. Debe avanzar más allá de <code>dashboard-plugin</code>; después seguir
la acción indicada para OpenBao. <code>resume</code> no reemplaza esta repetición de
<code>apply</code>, porque aún faltan las dependencias y los servicios iniciales.

Esta recuperación corresponde al fallo reportado antes de instalar el plugin. Si el estado o
el error son distintos, revisarlos antes de continuar. No modificar manualmente los hashes ni
los archivos del release anterior.

<a id="bloqueo-del-branding-en-wazuh-4148"></a>

### 9.8. Bloqueo del branding en Wazuh 4.14.8

Si `apply` termina con `el overlay fue validado para 4.14.7; paquete detectado: 4.14.8-1`,
el problema es la comprobación antigua del script incluido en el TAR de branding, no las
dependencias ni OpenBao. No cambiar la versión detectada ni editar el TAR publicado:
el instalador verifica su SHA-256.

La corrección se distribuye en el release `0.1.159` de GitHub. Acepta únicamente Dashboard 4.14.7 y 4.14.8 y conserva la
comprobación de destinos, hashes, respaldo y rollback. Las pruebas locales de versiones
no sustituyen la validación de salud y visual en WA01.

Una vez recibido y verificado el release corregido, instalar su ejecutable:

~~~bash
sudo install -o root -g root -m 0755 \
  /root/soc-operations-release-0.1.159/soc-operations-install \
  /usr/local/sbin/soc-operations-install
~~~

Repetir el comando `apply` anterior con los mismos parámetros de identidad, topología
y publicación, sustituyendo únicamente `--staging-root` por
`/root/soc-operations-release-0.1.159`. No borrar los estados ni los volúmenes; el
instalador debe reconocer los pasos completados. Inicializar OpenBao solo después de
que `apply` finalice correctamente.

<a id="error-de-conexión-con-la-api-wazuh-durante-rbac"></a>

### 9.9. Error de conexión con la API Wazuh durante RBAC

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

<a id="inicializar-openbao-y-continuar-la-instalación"></a>

### 9.10. Inicializar OpenBao y continuar la instalación

En una instalación nueva, el estado esperado tras <code>apply</code> es
<code>waiting_for_openbao_custody</code>. Solo si OpenBao aún no está inicializado, ejecutar:

~~~bash
sudo /usr/local/sbin/soc-operations-install openbao-init
~~~

El helper del release <code>0.1.159</code> solicita literalmente <code>INIT WA001</code>.
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

<a id="instalar-el-agente-en-el-manager-de-wa01"></a>

### 9.11. Instalar el agente en el Manager de WA01

<a id="retomar-el-error-de-versión-del-paquete-del-agente"></a>

#### 9.11.1. Retomar el error de versión del paquete del agente

Los instaladores hasta `0.1.157` consultaban `soc_operations.__version__`, cuyo valor
interno quedó en `0.1.112`, aunque el wheel y sus metadatos de distribución son `0.1.113`.
Esto provoca `installed agent package version is invalid` después de que pip informe éxito.
El instalador `0.1.159` consulta los metadatos mediante `importlib.metadata` en modo aislado
y los verifica tanto después de instalar como antes de reutilizar un entorno existente.
No cambia el wheel ni desactiva su verificación SHA-256.

Para una instalación parcial, preparar y verificar el release nuevo con el procedimiento
anterior; instalar su ejecutable `soc-operations-install` y repetir el `apply` original
con los mismos parámetros de identidad, topología y publicación, usando el staging
`/root/soc-operations-release-0.1.159`. Esto actualiza los helpers y registra el nuevo staging
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
  SOC_STAGING_ROOT=/root/soc-operations-release-0.1.159 \
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

<a id="ufw-y-contenedores"></a>

### 9.12. UFW y contenedores

El instalador no modifica UFW. Después de crear la red:

~~~bash
sudo docker network inspect soc-operations-wa001_frontend

sudo docker network inspect soc-operations-wa001_frontend \
  --format '{{json .IPAM.Config}}'
~~~

El nombre de red incluye el proyecto Compose fijo <code>soc-operations-wa001</code>,
aunque el deployment sea <code>wa01</code>. Consultar <code>soc-operations_frontend</code>
produce <code>network not found</code>; no crear otra red ni reinstalar el agente para resolverlo.

<a id="obtener-la-interfaz-subred-y-gateway-reales"></a>

#### 9.12.1. Obtener la interfaz, subred y gateway reales

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

<a id="confirmar-el-destino-del-agente-desde-el-contenedor"></a>

#### 9.12.2. Confirmar el destino del agente desde el contenedor

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

<a id="regla-ufw-para-el-agente-local-de-wa01"></a>

#### 9.12.3. Regla UFW para el agente local de WA01

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

<a id="reanudación-final-y-primer-acceso"></a>

### 9.13. Reanudación final y primer acceso

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

<a id="bloqueo-de-certificados"></a>

### 9.14. Bloqueo de certificados

El aprovisionador actual genera certificados mTLS del agente válidos por 30 días y no existe rotación automática documentada. Antes de producción se debe implementar y probar:

- Renovación sin interrupción.
- Alertas de vencimiento.
- Solapamiento controlado de certificados.
- Revocación y recuperación.
- Prueba incorporada a aceptación.

<a id="geoip-maxmind"></a>

## 10. GeoIP MaxMind

<a id="diseño"></a>

### 10.1. Diseño

- <code>.117</code> descarga GeoLite2 City, Country y ASN.
- Publica releases por mTLS en 8444.
- Solo <code>.118</code> y <code>.119</code> instalan worker.
- Cada worker usa certificado cliente propio.
- La sincronización es automática y la activación manual, rolling.
- El distribuidor conserva cuatro releases. El worker `0.1.159` no implementa poda
  automática de sus releases locales; vigilar el espacio en `/var/lib/soc-geoip-indexer`.

> [!IMPORTANT]
> **Estado del procedimiento:** el helper `0.1.159` corrige la detección de comandos, pero
> conserva un defecto de permisos al generar `manifest.json`. La mitigación de esta guía
> permite probar el flujo; no equivale a publicar un helper corregido ni a aprobar GeoIP
> para producción. Mantener suspendida la actualización automática del distribuidor hasta
> disponer de esa corrección validada. Las bases activas de Wazuh no se borran ni se detienen
> por suspender únicamente `soc-geoip-manager.timer`.

Ejecutar los bloques **en orden y en el servidor indicado**. Los bloques `bash` son comandos;
los bloques `text` e `ini` son contenido para guardar dentro del archivo que se está editando.
Si se cierra la sesión SSH, definir de nuevo las variables de staging en la nueva sesión.

| Punto de control | Qué confirma | Qué no confirma |
| --- | --- | --- |
| Cuatro archivos del worker con `OK` | Integridad del subconjunto del release recibido | Presencia del bundle mTLS, configuración o instalación |
| `preflight passed` | Comprobaciones locales del helper | Acceso HTTP al manifiesto ni descarga de las bases |
| GET de `manifest.json` por mTLS | Acceso al distribuidor desde ese Indexer | Integridad y lectura de todas las bases |
| `install` finalizado y `pending_release` presente | Worker instalado y bases descargadas/verificadas | Bases activas en Wazuh |
| `active_release` correcto, hashes coincidentes y clúster `green` | Activación y continuidad del clúster | Enriquecimiento real: comprobar también pipeline y evento nuevo |

<a id="distribuidor-en-1921684117"></a>

### 10.2. Distribuidor en 192.168.4.117

Las plantillas del TAR `0.1.159` están en la raíz del release. La ruta
`deploy/geoip/manager.env.example` pertenece al repositorio fuente y **no existe** en el
paquete extraído. Usar el staging verificado, sin depender del directorio actual.
Si aparece `install: cannot stat 'deploy/geoip/manager.env.example'`, no descargar otra
plantilla: comprobar `/root/soc-operations-release-0.1.159/manager.env.example`.

> [!IMPORTANT]
> **Para GeoIP, usar los helpers corregidos 0.1.159.** El staging indicado abajo corresponde
> al paquete corregido distribuido en GitHub. No basta con
> reinstalar los helpers de 0.1.158. Preparar y verificar el paquete corregido antes de continuar.
> La corrección de `command -v` no corrige por sí sola el HTTP 403 del manifiesto;
> completar también la comprobación de permisos de 10.2.3.

Si SOC Operations ya está instalado y se creó el primer ingeniero, para esta corrección basta
con preparar/verificar el release 0.1.159 e instalar sus helpers mediante los bloques GeoIP
siguientes. No repetir `apply` ni `upgrade`, reinstalar la aplicación o reinicializar OpenBao
solo para corregir GeoIP. Conservar `manager.env`, `worker.env`, `GeoIP.conf` y cualquier PKI existente.

#### 10.2.1. Preparar las dependencias y la configuración

~~~bash
SOC_GEOIP_RELEASE='/root/soc-operations-release-0.1.159'
(
set -euo pipefail
sudo test -f "$SOC_GEOIP_RELEASE/manager.env.example"
sudo test -f "$SOC_GEOIP_RELEASE/GeoIP.conf.example"
# Continuar solo si ambas comprobaciones terminan sin error.
sudo apt-get update
sudo apt-get install -y geoipupdate mmdb-bin curl jq nginx openssl util-linux python3
sudo bash -c 'set -e; for binary in curl geoipupdate mmdblookup nginx openssl python3 sha256sum systemctl flock; do command -v "$binary"; done'
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
)
~~~

**Contenido del archivo `/etc/soc-geoip-manager/manager.env` — no ejecutar en la consola:**

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
En Ubuntu 24.04, `mmdb-bin` proporciona `mmdblookup`, requerido para validar las bases
descargadas. Consultar la [referencia oficial de Ubuntu](https://manpages.ubuntu.com/manpages/noble/man1/mmdblookup.1.html).

> [!IMPORTANT]
> Si aparece `E: Unable to locate package libmaxminddb-bin`, el comando usa un nombre
> incorrecto para Ubuntu. Sustituirlo por `mmdb-bin` y repetir el bloque de preparación.
> La comprobación de las tres herramientas debe terminar correctamente antes de continuar;
> no borrar configuraciones ni reinstalar SOC Operations para resolver este error.

> [!WARNING]
> **Corrección GeoIP:** los helpers de `0.1.158` invocaban `/usr/bin/command`, que no existe
> en Ubuntu. Los helpers corregidos tienen versión `0.1.159` y usan el builtin `command -v`.
> El paquete corregido se distribuye en el release 0.1.159 de GitHub. No continuar GeoIP
> con el TAR antiguo ni crear un ejecutable `/usr/bin/command` para evitar el error.
> Conservar credenciales y PKI existentes. Las pruebas locales no acreditan GeoIP end-to-end.

#### 10.2.2. Instalar el distribuidor y publicar la primera descarga

Instalar el ejecutable verificado y pasar el staging explícitamente: copiar el helper a
`/usr/local/sbin` no copia su plantilla Nginx ni sus unidades systemd.
Si el distribuidor ya está instalado y `status` muestra un release publicado, no repetir
este bloque: continuar en 10.2.3. `install` ya ejecuta la primera actualización.

~~~bash
(
set -euo pipefail
: "${SOC_GEOIP_RELEASE:?Definir primero el staging verificado del release corregido}"
sudo grep -Fqx 'readonly VERSION="0.1.159"' "$SOC_GEOIP_RELEASE/soc-geoip-manager"
sudo install -o root -g root -m 0755 \
  "$SOC_GEOIP_RELEASE/soc-geoip-manager" /usr/local/sbin/soc-geoip-manager
sudo env SOC_GEOIP_STAGING_ROOT="$SOC_GEOIP_RELEASE" soc-geoip-manager preflight
# set -e detiene este bloque si falla preflight; no se crean certificados después del fallo.
sudo env SOC_GEOIP_STAGING_ROOT="$SOC_GEOIP_RELEASE" soc-geoip-manager install
# Mitigación temporal del defecto de permisos de 0.1.159: no publicar otro manifiesto
# automáticamente hasta instalar un helper corregido y validado.
sudo systemctl disable --now soc-geoip-manager.timer
sudo soc-geoip-manager status
)
~~~

#### 10.2.3. Comprobar la publicación y los permisos del manifiesto

En `.117`, revisar el release publicado y la ruta utilizada por Nginx:

~~~bash
sudo soc-geoip-manager status
sudo stat -Lc '%a %U:%G %n' /var/lib/soc-geoip-manager/current/manifest.json
sudo namei -l /var/lib/soc-geoip-manager/current/manifest.json
sudo tail -n 40 /var/log/nginx/error.log
~~~

El manifiesto es metadato de distribución, no contiene la licencia MaxMind ni claves.
Debe ser `root:root 0644`; las bases son `0644` y los directorios publicados permiten
recorrido con `0755`. **No aplicar esos permisos a `/etc/soc-geoip-manager` ni a su PKI.**

En el helper `0.1.159` revisado, `umask 077` y la creación del manifiesto sin `chmod` producen
un archivo `0600`. Eso impide su lectura a un worker Nginx no root. La causa de un 403 en
el servidor concreto se confirma correlacionando la petición con el log de Nginx; no
atribuir todo 403 a UFW o a HAProxy. La plantilla usa `alias` para servir la ruta publicada.
Consultar [Nginx: alias](https://nginx.org/en/docs/http/ngx_http_core_module.html#alias)
y [diagnóstico mediante sus logs](https://nginx.org/en/docs/beginners_guide.html).

Si el release está publicado y se confirma el manifiesto `0600`, aplicar esta mitigación
limitada en `.117`. También suspender el timer si ya había quedado activo:

~~~bash
(
set -euo pipefail
sudo systemctl disable --now soc-geoip-manager.timer
sudo test -f /var/lib/soc-geoip-manager/current/manifest.json
sudo test ! -L /var/lib/soc-geoip-manager/current/manifest.json
sudo chmod 0644 /var/lib/soc-geoip-manager/current/manifest.json
sudo stat -Lc '%a %U:%G %n' /var/lib/soc-geoip-manager/current/manifest.json
)
~~~

No es necesario reiniciar Nginx ni Wazuh por cambiar ese permiso. No usar `chmod -R`,
`777`, `curl -k` ni `ssl_verify_client off`. Si los permisos ya son correctos y el 403
continúa, seguir 10.4.3 antes de modificar controles de acceso.

> [!WARNING]
> **Mitigación temporal, no corrección del instalador:** cada `soc-geoip-manager update`
> de este helper puede volver a crear el manifiesto `0600`. Mientras se use `0.1.159`,
> mantener el timer del distribuidor deshabilitado y realizar las actualizaciones en una
> ventana manual, comprobando y corrigiendo el manifiesto después de cada publicación.
> Para volver a automatizar, corregir su modo a `0644` antes de publicar el release,
> probar lectura HTTP como Nginx y desde ambos Indexers, y distribuir un nuevo artefacto
> verificado. No editar el staging firmado/verificado de `0.1.159` conservando sus hashes.

El resultado esperado con esta mitigación es un `release_id` presente y `timer=inactive`
en el distribuidor; no confundirlo con un fallo de Wazuh ni con los timers de los workers.

#### 10.2.4. Emitir o conservar el bundle de cada Indexer

Si ya se emitieron ambos bundles, conservarlos y continuar con la transferencia. El helper
no admite volver a emitir sobre un directorio existente; no borrarlo para forzar el comando.
En una instalación nueva, ejecutar en `.117`:

~~~bash
(
set -euo pipefail
for SOC_NODE in wa01-indexer01 wa01-indexer02; do
  SOC_BUNDLE="/root/geoip-$SOC_NODE"
  if sudo test -e "$SOC_BUNDLE" || sudo test -L "$SOC_BUNDLE"; then
    sudo test -d "$SOC_BUNDLE"
    sudo test ! -L "$SOC_BUNDLE"
    for SOC_FILE in ca.crt client.crt client.key; do
      sudo test -f "$SOC_BUNDLE/$SOC_FILE"
      sudo test ! -L "$SOC_BUNDLE/$SOC_FILE"
    done
    printf 'Bundle existente: conservar y verificar %s\n' "$SOC_BUNDLE"
  else
    sudo soc-geoip-manager issue-client "$SOC_NODE" "$SOC_BUNDLE"
  fi
  sudo openssl verify -purpose sslclient \
    -CAfile /etc/soc-geoip-manager/pki/ca.crt "$SOC_BUNDLE/client.crt"
done
)
~~~

Transferir cada bundle solo a su nodo. Retirar las copias temporales después de confirmar
la instalación; no imprimir ni compartir la clave cliente.

<a id="workers-en-1921684118-y-1921684119"></a>

### 10.3. Workers en 192.168.4.118 y 192.168.4.119

Preparar en **cada nodo** el mismo release verificado y el bundle mTLS de ese nodo mediante
el canal SSH autorizado. No transferir `GeoIP.conf`, la licencia MaxMind ni la clave privada
de la CA del distribuidor. Los archivos del release están en su raíz, no en `deploy/geoip/`.
El helper lee `/etc/soc-geoip-indexer/worker.env`: `indexer.env.example` es solo el nombre de
la plantilla.

> [!IMPORTANT]
> **El usuario SSH no necesita ser root.** Recibir los archivos en
> `$HOME/soc-geoip-incoming` del usuario de login. No copiar por SCP a `/root` ni dar permisos
> de escritura sobre `/root`. Usar `sudo` únicamente para instalar en `/etc`, `/usr/local/sbin`
> y systemd. Si el usuario no tiene esos privilegios, un administrador debe ejecutar esos pasos.
> Haber verificado los cuatro archivos del worker no acredita que el bundle mTLS esté presente
> ni que GeoIP esté instalado o activo.

#### 10.3.1. Transferir desde .117 al home del usuario SSH

El worker viene del release verificado de SOC Operations en `.117`; no es el contenedor
`worker` de la API. Copiar solamente los cuatro archivos del worker, `SHA256SUMS` y las tres
credenciales del bundle correspondiente. Desde `.117`, con un usuario que pueda leer los
originales mediante `sudo`, preparar la transferencia para `.118`:

~~~bash
(
set -euo pipefail
SOC_GEOIP_RELEASE='/root/soc-operations-release-0.1.159'
SOC_INDEXER_IP='192.168.4.118'
SOC_INDEXER_NODE='wa01-indexer01'
read -rp 'Usuario SSH del Indexer (no root): ' SOC_SSH_USER
test -n "$SOC_SSH_USER"
SOC_TRANSFER=$(mktemp -d -t soc-geoip-transfer.XXXXXXXX)
chmod 0700 "$SOC_TRANSFER"
for SOC_FILE in soc-geoip-indexer soc-geoip-indexer.service soc-geoip-indexer.timer indexer.env.example SHA256SUMS; do
  sudo install -o "$(id -u)" -g "$(id -g)" -m 0600 \
    "$SOC_GEOIP_RELEASE/$SOC_FILE" "$SOC_TRANSFER/$SOC_FILE"
done
for SOC_FILE in ca.crt client.crt client.key; do
  sudo install -o "$(id -u)" -g "$(id -g)" -m 0600 \
    "/root/geoip-$SOC_INDEXER_NODE/$SOC_FILE" "$SOC_TRANSFER/$SOC_FILE"
done
ssh -p 11050 -l "$SOC_SSH_USER" "$SOC_INDEXER_IP" \
  'umask 077; mkdir -p "$HOME/soc-geoip-incoming"; chmod 0700 "$HOME/soc-geoip-incoming"; test -z "$(ls -A "$HOME/soc-geoip-incoming")"'
# El destino debe estar vacío: no sobrescribir un bundle anterior ni mezclar nodos.
scp -p -P 11050 -o "User=$SOC_SSH_USER" \
  "$SOC_TRANSFER/soc-geoip-indexer" "$SOC_TRANSFER/soc-geoip-indexer.service" \
  "$SOC_TRANSFER/soc-geoip-indexer.timer" "$SOC_TRANSFER/indexer.env.example" \
  "$SOC_TRANSFER/SHA256SUMS" "$SOC_TRANSFER/ca.crt" \
  "$SOC_TRANSFER/client.crt" "$SOC_TRANSFER/client.key" \
  "$SOC_INDEXER_IP:soc-geoip-incoming/"
printf 'Transferencia completada. Copia temporal privada en .117: %s\n' "$SOC_TRANSFER"
)
~~~

Para `.119`, repetir con `SOC_INDEXER_IP='192.168.4.119'` y
`SOC_INDEXER_NODE='wa01-indexer02'`, usando su usuario SSH real. Si el destino ya contiene
archivos verificados, no repetir SCP; continuar en ese Indexer. Verificar la huella SSH por
el canal autorizado; no desactivar la comprobación del host. La clave cliente no aparece
en `SHA256SUMS` del release: se obtiene del bundle emitido en `.117`, por el canal SSH confiable.

#### 10.3.2. Verificar y configurar en cada Indexer

Después del login SSH normal en `.118` o `.119`, trabajar desde el home. Si ya se obtuvieron
los cuatro resultados `OK`, este es el siguiente paso. Comprobar también que se recibieron
`ca.crt`, `client.crt` y `client.key` del nodo correcto:

> [!IMPORTANT]
> **Si `/etc/soc-geoip-indexer/worker.env` indica «directorio no existe», falta ejecutar
> el bloque de preparación siguiente.** No empezar por `nano`: el bloque crea primero
> `/etc/soc-geoip-indexer`, instala el bundle y crea `worker.env` desde la plantilla.
> Para editarlo se usa `sudo nano`, no `nano` con el usuario normal.

Confirmar la IP local con `hostname -I`; el nombre SLEIPNIR no determina por sí solo si
se está en `.118` o `.119`. Usar la URL y el bundle de la IP correspondiente.

~~~bash
SOC_GEOIP_RELEASE="$HOME/soc-geoip-incoming"
(
set -euo pipefail
cd "$SOC_GEOIP_RELEASE"
chmod 0700 "$SOC_GEOIP_RELEASE"
for SOC_FILE in soc-geoip-indexer soc-geoip-indexer.service soc-geoip-indexer.timer indexer.env.example SHA256SUMS ca.crt client.crt client.key; do
  test -f "$SOC_FILE"
  test ! -L "$SOC_FILE"
done
chmod 0600 client.key
sha256sum --check --strict --ignore-missing SHA256SUMS
grep -Fqx 'readonly VERSION="0.1.159"' soc-geoip-indexer
sudo apt-get update
sudo apt-get install -y curl python3 openssl util-linux
sudo bash -c 'set -e; for binary in curl python3 openssl sha256sum systemctl flock; do command -v "$binary"; done'
# Continuar solo si están TODOS los archivos y pasan sus hashes. --ignore-missing permite
# verificar el subconjunto del release, pero por sí solo no detecta un worker ausente.
sudo install -d -o root -g root -m 0700 /etc/soc-geoip-indexer
for SOC_FILE in ca.crt client.crt client.key; do
  if sudo test -e "/etc/soc-geoip-indexer/$SOC_FILE" || sudo test -L "/etc/soc-geoip-indexer/$SOC_FILE"; then
    sudo test -f "/etc/soc-geoip-indexer/$SOC_FILE"
    sudo test ! -L "/etc/soc-geoip-indexer/$SOC_FILE"
    sudo cmp --silent "$SOC_FILE" "/etc/soc-geoip-indexer/$SOC_FILE"
  fi
done
# Si alguna credencial existente es distinta, detenerse y revisar: no sobrescribir PKI.
for SOC_FILE in ca.crt client.crt client.key; do
  if ! sudo test -e "/etc/soc-geoip-indexer/$SOC_FILE"; then
    sudo install -o root -g root -m 0600 "$SOC_FILE" "/etc/soc-geoip-indexer/$SOC_FILE"
  fi
done
if sudo test -e /etc/soc-geoip-indexer/worker.env || sudo test -L /etc/soc-geoip-indexer/worker.env; then
  sudo test -f /etc/soc-geoip-indexer/worker.env
  sudo test ! -L /etc/soc-geoip-indexer/worker.env
  printf '%s\n' 'worker.env ya existe: conservar y revisar, no sobrescribir.'
else
  sudo install -o root -g root -m 0600 \
    "$SOC_GEOIP_RELEASE/indexer.env.example" /etc/soc-geoip-indexer/worker.env
fi
sudo nano /etc/soc-geoip-indexer/worker.env
)
~~~

**Contenido de `/etc/soc-geoip-indexer/worker.env` — guardar en nano, no pegar en la consola:**

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
El bloque anterior ya instala `ca.crt`, `client.crt` y `client.key` en esas rutas;
no usar el certificado cliente del otro Indexer. En nano, guardar con `Ctrl+O`, confirmar
con Enter y salir con `Ctrl+X`.

Después de guardar `worker.env`, verificar permisos y el canal mTLS desde el Indexer:

~~~bash
(
set -euo pipefail
sudo chown root:root /etc/soc-geoip-indexer/worker.env /etc/soc-geoip-indexer/client.key
sudo chmod 0600 /etc/soc-geoip-indexer/worker.env /etc/soc-geoip-indexer/client.key
getent hosts wa01-dashboard.corp.atg
sudo openssl verify -purpose sslclient -CAfile /etc/soc-geoip-indexer/ca.crt \
  /etc/soc-geoip-indexer/client.crt
sudo openssl x509 -in /etc/soc-geoip-indexer/client.crt -noout -subject -issuer -dates
sudo curl --noproxy '*' --fail-with-body --silent --show-error --connect-timeout 10 --max-time 30 \
  --cert /etc/soc-geoip-indexer/client.crt \
  --key /etc/soc-geoip-indexer/client.key \
  --cacert /etc/soc-geoip-indexer/ca.crt \
  'https://wa01-dashboard.corp.atg:8444/geoip/v1/manifest.json'
)
~~~

El nombre debe resolver a `.117` y el endpoint devolver el manifiesto GeoIP, sin errores
TLS ni HTTP. Si falla, revisar DNS, el permiso UFW de `.117:8444` para ese Indexer,
el servicio Nginx del distribuidor y el bundle del nodo. No usar `-k`.
No continuar con `install` si esta petición falla. Si devuelve 403, ir a 10.4.3.
La prueba usa acceso interno directo a `.117:8444`, no Cloudflare ni el FQDN público.
Comprobar también el sujeto del certificado: en `.118`, el bundle emitido por el helper
debe mostrar `CN=soc-geoip-indexer-wa01-indexer01`; en `.119`,
`CN=soc-geoip-indexer-wa01-indexer02`. La CA y el propósito correctos no garantizan que
se haya copiado el bundle del nodo correcto. Si el sujeto no coincide, revisar la entrega,
no regenerar toda la PKI. Los datos de certificado son públicos; no imprimir `client.key`.

Los nombres anteriores son los que lee el helper; no usar `SOC_GEOIP_SELF_INDEXER_URL`,
`SOC_GEOIP_EXPECTED_NODES` ni `SOC_GEOIP_SOURCE_SERVER_NAME`, que no son sus parámetros.

#### 10.3.3. Instalar y sincronizar el worker sin activar

Para el timer de Wazuh 4.14.8, la unidad necesita también el override de versión:
el helper resuelve `SOC_EXPECTED_WAZUH_VERSION` antes de leer `worker.env`.
Antes de instalar/activar el worker, preparar el drop-in:

~~~bash
sudo install -d -o root -g root -m 0755 /etc/systemd/system/soc-geoip-indexer.service.d
sudo nano /etc/systemd/system/soc-geoip-indexer.service.d/wazuh-version.conf
~~~

**Contenido del archivo abierto en nano — NO son comandos de Bash:**

~~~ini
[Service]
Environment=SOC_EXPECTED_WAZUH_VERSION=4.14.8-1
~~~

Guardar con `Ctrl+O`, Enter y salir con `Ctrl+X`. Si se pegó `[Service]` en el prompt
`cmedina@...$`, no se creó el override: volver a abrir el archivo y guardar ambas líneas.
Conservar otros overrides existentes. Verificar el contenido y recargar systemd:

~~~bash
(
set -euo pipefail
sudo grep -Fqx '[Service]' /etc/systemd/system/soc-geoip-indexer.service.d/wazuh-version.conf
sudo grep -Fqx 'Environment=SOC_EXPECTED_WAZUH_VERSION=4.14.8-1' \
  /etc/systemd/system/soc-geoip-indexer.service.d/wazuh-version.conf
sudo chown root:root /etc/systemd/system/soc-geoip-indexer.service.d/wazuh-version.conf
sudo chmod 0644 /etc/systemd/system/soc-geoip-indexer.service.d/wazuh-version.conf
sudo systemctl daemon-reload
)
~~~

No confiar en que una variable de la sesión SSH se transfiera automáticamente a los timers.
`Environment=` configura el proceso del servicio, según
[systemd.exec en Ubuntu](https://manpages.ubuntu.com/manpages/noble/man5/systemd.exec.5.html).
El `sudo env ...=4.14.8-1` de una ejecución manual no prueba que el archivo esté guardado.

~~~bash
(
set -euo pipefail
SOC_GEOIP_RELEASE="$HOME/soc-geoip-incoming"
cd "$SOC_GEOIP_RELEASE"
for SOC_FILE in soc-geoip-indexer soc-geoip-indexer.service soc-geoip-indexer.timer indexer.env.example SHA256SUMS; do
  test -f "$SOC_FILE"
  test ! -L "$SOC_FILE"
done
sha256sum --check --strict --ignore-missing SHA256SUMS
sudo grep -Fqx 'readonly VERSION="0.1.159"' "$SOC_GEOIP_RELEASE/soc-geoip-indexer"
sudo grep -Fqx '[Service]' /etc/systemd/system/soc-geoip-indexer.service.d/wazuh-version.conf
sudo grep -Fqx 'Environment=SOC_EXPECTED_WAZUH_VERSION=4.14.8-1' \
  /etc/systemd/system/soc-geoip-indexer.service.d/wazuh-version.conf
# El sync valida las bases con el lector Java incluido en Wazuh, no con geoipupdate.
sudo test -d /usr/share/wazuh-indexer/modules/ingest-geoip
sudo test -x /usr/share/wazuh-indexer/jdk/bin/java
SOC_GEOIP_MAXMIND_JAR=$(sudo find /usr/share/wazuh-indexer/modules/ingest-geoip \
  -maxdepth 1 -type f -name 'maxmind-db-*.jar' -print -quit)
test -n "$SOC_GEOIP_MAXMIND_JAR"
# Gate de red antes de instalar las unidades: la prueba local del helper no consulta HTTP.
sudo curl --noproxy '*' --fail-with-body --silent --show-error --connect-timeout 10 --max-time 30 \
  --cert /etc/soc-geoip-indexer/client.crt \
  --key /etc/soc-geoip-indexer/client.key \
  --cacert /etc/soc-geoip-indexer/ca.crt \
  --output /dev/null 'https://wa01-dashboard.corp.atg:8444/geoip/v1/manifest.json'
sudo install -o root -g root -m 0755 \
  "$SOC_GEOIP_RELEASE/soc-geoip-indexer" /usr/local/sbin/soc-geoip-indexer
sudo env SOC_GEOIP_STAGING_ROOT="$SOC_GEOIP_RELEASE" SOC_EXPECTED_WAZUH_VERSION=4.14.8-1 \
  soc-geoip-indexer preflight
# set -e detiene este bloque si falla preflight.
sudo env SOC_GEOIP_STAGING_ROOT="$SOC_GEOIP_RELEASE" SOC_EXPECTED_WAZUH_VERSION=4.14.8-1 \
  soc-geoip-indexer install
sudo env SOC_EXPECTED_WAZUH_VERSION=4.14.8-1 soc-geoip-indexer sync
sudo env SOC_EXPECTED_WAZUH_VERSION=4.14.8-1 soc-geoip-indexer status
sudo systemctl show soc-geoip-indexer.service --property=Environment --value \
  | grep -F 'SOC_EXPECTED_WAZUH_VERSION=4.14.8-1'
)
~~~

`install` habilita el timer y sincroniza las bases; no reinicia Wazuh Indexer ni las activa
con `SOC_GEOIP_AUTO_ACTIVATE=false`. El `sync` explícito permite reconfirmar la descarga.
Esperar `pending_release=<identificador>`, `auto_activate=false`, `indexer_service=active`
y `timer=active`; `active_release=none` es normal antes de la primera activación.
El timer usa las copias instaladas en `/etc`, `/usr/local/sbin` y `/var/lib`, no el home.

Si `install` termina con `curl: (22) ... 403`, la instalación **no está completa** aunque
ya exista el symlink del timer. El helper instala las unidades y habilita el timer antes
de descargar; no hace rollback automático de esas unidades. Seguir 10.4.3 y 10.4.4,
sin reinstalar SOC Operations, borrar bases ni emitir certificados nuevamente.

#### 10.3.4. Activar de forma rolling y validar

> [!WARNING]
> `activate` **reinicia el servicio Wazuh Indexer del nodo actual**. Ejecutar en ventana
> aprobada, con el clúster `green` y sus tres nodos presentes. No activar `.118` y `.119`
> simultáneamente. Si `.118` no recupera `green`, detenerse antes de continuar con `.119`.

Activar primero en Indexer 1 (`.118`):

~~~bash
(
set -euo pipefail
sudo env SOC_EXPECTED_WAZUH_VERSION=4.14.8-1 soc-geoip-indexer activate
sudo env SOC_EXPECTED_WAZUH_VERSION=4.14.8-1 soc-geoip-indexer status
)
~~~

Esperar estado green, verificar pipelines y simular una IP pública. Después repetir en
Indexer 2. Comparar SHA-256 de City, Country y ASN entre distribuidor y receptores.

El helper comprueba `green` antes de activar, pero su espera posterior acepta un clúster
no `red` con tres nodos. Por eso, que `activate` finalice no sustituye la comprobación
explícita de `green` antes de pasar al siguiente Indexer.

En cada Indexer comprobar el clúster después de activar (en `.119`, cambiar la IP):

~~~bash
(
set -euo pipefail
sudo curl --noproxy '*' --fail-with-body --silent --show-error --max-time 140 \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://192.168.4.118:9200/_cluster/health?wait_for_status=green&timeout=120s' \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps(d,indent=2)); sys.exit(0 if d.get("status")=="green" and d.get("number_of_nodes")==3 and d.get("timed_out") is False else 1)'
)
~~~

Confirmar `status: green`, `number_of_nodes: 3` y `timed_out: false`. El HTTP 200 por sí
solo no acredita esas condiciones. En `soc-geoip-indexer status`, la versión activa debe
coincidir con la pendiente. Comparar los hashes con los siguientes comandos:

En `.117`, bases publicadas:

~~~bash
sudo sha256sum /var/lib/soc-geoip-manager/current/GeoLite2-{City,Country,ASN}.mmdb
~~~

En `.118` y `.119`, bases descargadas y bases realmente utilizadas por el módulo:

~~~bash
(
set -euo pipefail
sudo sha256sum /var/lib/soc-geoip-indexer/pending/GeoLite2-{City,Country,ASN}.mmdb
sudo sha256sum /usr/share/wazuh-indexer/modules/ingest-geoip/GeoLite2-{City,Country,ASN}.mmdb
)
~~~

La primera columna de cada salida debe coincidir para **el mismo nombre de base** en
todos los nodos; no comparar rutas completas ni comparar City con Country o ASN.
También debe coincidir con el SHA-256 declarado para esa base en el manifiesto del release.
Si `pending` no existe, volver a sincronizar; si el hash activo difiere, no dar GeoIP
por instalado ni pasar al siguiente nodo. El `status` no sustituye esta comprobación.
Validar después el pipeline y un evento nuevo: estas bases no recalculan documentos
históricos automáticamente. No enviar logs reales ni secretos para una prueba sintética.

Conservar las evidencias de validación; después retirar las
copias temporales de `client.key` en el home del Indexer y en la carpeta temporal de `.117`,
dejando intacta la copia instalada root-owned en `/etc/soc-geoip-indexer/client.key`.
No borrar el staging antes de completar todos los pasos de instalación.

Timers previstos después de corregir y validar la publicación del manifiesto:

- Distribuidor: martes y viernes 04:15, demora aleatoria de hasta una hora.
- Workers: martes y viernes 06:15, demora aleatoria de hasta cuatro horas.

Con <code>SOC_GEOIP_AUTO_ACTIVATE=false</code>, el timer sincroniza pero no activa.
Con la mitigación de `0.1.159`, el timer del distribuidor permanece deshabilitado;
los timers de los workers pueden sincronizar el último release legible. No se deben
confundir esas dos automatizaciones. Revisar la zona horaria de los servidores antes de
interpretar los horarios; las unidades no fijan explícitamente `America/Lima`.

~~~bash
systemctl list-timers --all | grep -i geoip
timedatectl show --property=Timezone --value
sudo journalctl -u soc-geoip-manager --since '-7 days' --no-pager
sudo journalctl -u soc-geoip-indexer --since '-7 days' --no-pager
~~~

Antes de actualizar SOC Operations o Wazuh, consultar la sección de actualizaciones de
[la referencia GeoIP del proyecto](maxmind-geoip.md). Sus ejemplos se escribieron
para Wazuh 4.14.7; para WA01 conservar los overrides de versión y los controles de esta guía.
Después de un upgrade, comparar los hashes reales de las bases con el release aprobado;
el identificador `active_release` por sí solo no prueba que el paquete no haya repuesto
archivos. Si los hashes difieren y el helper responde «already active», detenerse y
solicitar un procedimiento de reactivación validado, no borrar su estado para forzarlo.

### 10.4. Diagnóstico y recuperación GeoIP

#### 10.4.1. Directorio o plantilla inexistente

- `/etc/soc-geoip-indexer/worker.env`: ejecutar primero el bloque de 10.3.2 que crea el
  directorio y copia `indexer.env.example`; editar después con `sudo nano`.
- `deploy/geoip/manager.env.example`: esa ruta es del repositorio fuente, no del TAR.
  En `.117`, usar la raíz del staging verificado; en los Indexers, usar el home del login.
- Cuatro archivos con `OK` no verifican el bundle ni aseguran que haya pasado `install`.

#### 10.4.2. Override de versión no guardado

El texto `[Service]` y `Environment=...` pertenece a `wazuh-version.conf`, no a la consola.
Si se pulsó `Ctrl+C` en el prompt, comprobar el archivo con los `grep` de 10.3.3. Después
de instalar la unidad, `systemctl show ... --property=Environment` debe mostrar
`SOC_EXPECTED_WAZUH_VERSION=4.14.8-1`. No modificar el paquete Wazuh para sortear esta validación.

#### 10.4.3. HTTP 403 al descargar el manifiesto

Un 403 demuestra que **algún servidor HTTP** respondió; no demuestra por sí solo que
respondiera el distribuidor correcto, que el certificado fuera aceptado o que UFW bloquee
el puerto. Correlacionar la prueba directa desde el Indexer con los logs de `.117`.

En el Indexer afectado, ejecutar:

~~~bash
sudo grep '^SOC_GEOIP_SOURCE_URL=' /etc/soc-geoip-indexer/worker.env
getent hosts wa01-dashboard.corp.atg
sudo curl --noproxy '*' --fail-with-body --silent --show-error --include \
  --connect-timeout 10 --max-time 30 \
  --cert /etc/soc-geoip-indexer/client.crt \
  --key /etc/soc-geoip-indexer/client.key \
  --cacert /etc/soc-geoip-indexer/ca.crt \
  'https://wa01-dashboard.corp.atg:8444/geoip/v1/manifest.json'
~~~

Usar el archivo `manifest.json`, no solo `/geoip/v1/`: el listado de directorios está
deshabilitado deliberadamente. `--include` muestra la respuesta, sin imprimir claves.
Si existen proxies de salida, verificar por qué la prueba directa y el helper toman
rutas diferentes; no publicar valores de variables de proxy que contengan credenciales.

En `.117`, inmediatamente después de la petición:

~~~bash
sudo tail -n 60 /var/log/nginx/error.log
sudo tail -n 60 /var/log/nginx/access.log
sudo stat -Lc '%a %U:%G %n' /var/lib/soc-geoip-manager/current/manifest.json
sudo namei -l /var/lib/soc-geoip-manager/current/manifest.json
sudo ss -lntp | grep ':8444'
~~~

- `Permission denied` al abrir el manifiesto y modo `600`: aplicar 10.2.3 en `.117`;
  repetir la petición desde el Indexer y exigir HTTP 200 con el JSON esperado.
- Error al recorrer un directorio: revisar ese componente, ACL o controles del sistema.
  No abrir recursivamente `/etc` ni el árbol de claves para resolverlo.
- `directory index ... is forbidden`: se consultó un directorio; usar la URL completa.
- Rechazo de certificado: verificar emisor, vigencia, propósito `sslclient` y bundle
  del nodo. No reemitir PKI ni desactivar mTLS sin diagnóstico.
- Sin registro de la petición en el listener correcto: revisar resolución DNS, ruta,
  proxy de salida y selección del servidor Nginx. No ampliar UFW a `Anywhere` por un 403.

#### 10.4.4. Reanudar una instalación parcial del worker

Si `install` falló tras habilitar el timer, detener solo ese timer mientras se diagnostica:

~~~bash
sudo systemctl disable --now soc-geoip-indexer.timer
sudo journalctl -u soc-geoip-indexer.service --since '-30 minutes' --no-pager
~~~

Corregir primero el GET mTLS de 10.3.2, guardar/verificar el override y repetir el bloque
de instalación de 10.3.3 desde `$HOME/soc-geoip-incoming`. `install` vuelve a habilitar el
timer y sincroniza; no necesita otro `apply` del instalador principal. No continuar a
`activate` si no existe `pending_release`, si hay un error o si el clúster no está `green`.
Los logs sirven como diagnóstico; sanitizarlos antes de compartirlos.

<a id="pruebas-de-aceptación"></a>

## 11. Pruebas de aceptación

<a id="plataforma"></a>

### 11.1. Plataforma

- Tres Indexers visibles, estado green y dos nodos de datos.
- Ningún shard en el Indexer central.
- Filebeat y Dashboard siguen operativos al detener individualmente <code>.118</code> o <code>.119</code>.
- Un agente sintético se enrola por el FQDN público y envía eventos por 1514.
- La API 55000 no es pública.

<a id="publicación"></a>

### 11.2. Publicación

- Los tres servicios HTTPS rechazan IP no autorizada.
- Una IP permitida accede con certificado válido.
- API Indexer permite consultas de lectura y rechaza mutaciones.
- 1514/1515 funcionan con el registro Cloudflare en DNS only.
- HAProxy audita origen, destino, resultado y latencia sin credenciales.

<a id="soc-operations-1"></a>

### 11.3. SOC Operations

- Todas las pruebas de <code>docs/acceptance.md</code> pasan.
- Dos tenants superan pruebas positivas y negativas de aislamiento.
- OpenBao, PostgreSQL, S3, SMTP y auditoría funcionan de extremo a extremo.
- El agente privilegiado acepta solo mTLS y operaciones allowlist.
- La rotación de certificados se prueba antes de 30 días.
- La API externa presenta <code>soc-external-api-wa01</code>.

<a id="geoip-y-continuidad"></a>

### 11.4. GeoIP y continuidad

- GET mTLS del manifiesto y descarga verificable desde `.118` y `.119`, sin desactivar TLS.
- Manifiesto `0644` publicado y credenciales privadas conservadas `0600` bajo root.
- Override `4.14.8-1` visible en el entorno efectivo del servicio de cada worker.
- Los hashes City, Country y ASN coinciden.
- Los pipelines enriquecen documentos en ambos nodos.
- Un release inválido no se activa y rollback recupera el anterior.
- Después de activar cada nodo, estado `green`, tres nodos y `timed_out: false`.
- No aprobar la actualización automática del distribuidor con la mitigación temporal
  de `0.1.159`; exige corregir y validar los permisos de publicación en el helper.
- Snapshot OpenSearch y restauración probados.
- PostgreSQL demuestra RPO 15 minutos y el conjunto RTO 4 horas.
- Cada nodo puede reiniciarse de forma ordenada sin pérdida de quorum.

<a id="rollback-y-evidencia"></a>

## 12. Rollback y evidencia

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

<a id="pendientes-previos-a-producción"></a>

## 13. Pendientes previos a producción

- Definir <code>ADMIN_CIDR</code> y <code>SSH_PORT</code>.
- Confirmar SAN antes de configurar <code>verifyhost</code>.
- Proporcionar una dirección interna estable para Indexer.
- Automatizar rotación mTLS de SOC Operations.
- Dimensionar con EPS, agentes y retención reales.
- Aprobar <code>docs/acceptance.md</code>.
- Corregir el modo del manifiesto GeoIP antes de publicarlo, probar ambas descargas mTLS
  y distribuir un helper nuevo verificado antes de rehabilitar el timer del distribuidor.
- Evaluar separar el Indexer manager-only del servidor central en una evolución futura.

<a id="referencias"></a>

## 14. Referencias

- Arquitectura y puertos Wazuh: https://documentation.wazuh.com/current/getting-started/architecture.html
- Instalación Indexer: https://documentation.wazuh.com/current/installation-guide/wazuh-indexer/installation-assistant.html
- Instalación Server: https://documentation.wazuh.com/current/installation-guide/wazuh-server/step-by-step.html
- Instalación Dashboard: https://documentation.wazuh.com/current/installation-guide/wazuh-dashboard/step-by-step.html
- Puertos proxy Cloudflare: https://developers.cloudflare.com/fundamentals/reference/network-ports/
- GeoIP del proyecto: <code>docs/maxmind-geoip.md</code>
- Compatibilidad: <code>docs/compatibility.md</code>
- Aceptación: <code>docs/acceptance.md</code>
