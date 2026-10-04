# Instalación distribuida WA01 con Wazuh 4.14.8 y SOC Operations

> Estado: guía de preparación y despliegue para producción.
> Revisión: 2026-10-04.
> Alcance: Wazuh 4.14.8, tres Indexers, Manager, Dashboard, SOC Operations, HAProxy, Cloudflare, UFW, snapshots S3 y GeoIP MaxMind.
> Bloqueo: SOC Operations no debe autorizarse para producción hasta superar completamente <code>docs/acceptance.md</code>.

<a id="objetivo-y-orden-de-ejecución"></a>

## 1. Objetivo y orden de ejecución

La instalación se realiza en este orden:

- Preparar DNS, certificados, sistema operativo, NTP y firewall.
- Instalar los tres Wazuh Indexer y formar el clúster.
- Dejar el Indexer central exclusivamente con rol <code>cluster_manager</code>.
- Instalar Manager, Filebeat y Dashboard en el servidor central.
- Ajustar los recursos de cada Indexer con `configurar_indexer.sh` y comprobarlos nodo por nodo.
- Configurar el repositorio S3 de snapshots, probar un respaldo y aprobar su programación/retención.
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
| Tres Indexers | Endpoint S3 aprobado | 443/TCP saliente o puerto TLS privado aprobado | Snapshots; no requiere NAT entrante |
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

<a id="ajustes-de-recursos-de-los-indexers"></a>

### 7.9. Ajustes de recursos de los Indexers

Utilizar el script existente `D:\WazuhDoc\Source_wazuh\scripts\wazuh-4.14.7\configurar_indexer.sh`
en los tres servidores **después de instalar Wazuh Indexer y formar el clúster**. La carpeta
`wazuh-4.14.7` identifica su ubicación histórica: el script no instala ni actualiza Wazuh,
no cambia roles y no aprovisiona tenants. Antes de usarlo con `4.14.8-1`, comprobar los archivos
y el resultado efectivo según los pasos siguientes; su nombre no constituye una validación
de compatibilidad por sí solo.

El script configura:

- Heap fijo `Xms=Xmx`, con un valor entero en GiB que debe elegir el administrador.
- `bootstrap.memory_lock: true` en `/etc/wazuh-indexer/opensearch.yml`.
- `LimitMEMLOCK=infinity` en el override systemd `memory-lock.conf`.
- `vm.max_map_count=262144` y `vm.swappiness=1` en `/etc/sysctl.d/99-wazuh-indexer.conf`.
- Recarga de sysctl y systemd; reinicio del Indexer solo cuando se añade `--restart` a `--apply`.

> **Antes de ejecutar:** no superar la mitad de la RAM detectada ni `31` GiB; esos son límites
> del script, no un dimensionamiento automático. En `.117`, reservar además memoria para
> Manager, Filebeat, Dashboard, PostgreSQL, SOC Operations, OpenBao, MinIO y el sistema.
> En `.118` y `.119`, reservar memoria nativa y caché de archivos. No copiar el mismo heap
> a todos los roles. No duplicar `-Xms/-Xmx` en variables de entorno u otros archivos JVM.
> Referencia: [ajustes de OpenSearch 2.19](https://docs.opensearch.org/2.19/install-and-configure/install-opensearch/index/).

#### 7.9.1. Copiar el script al home del usuario SSH

Desde una estación administrativa Ubuntu con el checkout autorizado de `WazuhDoc`, ajustar
la ruta y el usuario real. Se copia al home, nunca directamente a `/root`:

~~~bash
(
set -euo pipefail
SOC_WAZUHDOC_ROOT="$HOME/WazuhDoc"
SOC_INDEXER_SCRIPT="$SOC_WAZUHDOC_ROOT/Source_wazuh/scripts/wazuh-4.14.7/configurar_indexer.sh"
SOC_SSH_USER='cmedina'
test -f "$SOC_INDEXER_SCRIPT"
bash -n "$SOC_INDEXER_SCRIPT"
printf '%s  %s\n' \
  'b82dc0adbbc2312ecd1948ad31c90cd3c4502e2304842dceb943edbe3055a639' \
  "$SOC_INDEXER_SCRIPT" | sha256sum --check --strict -
for SOC_INDEXER_IP in 192.168.4.117 192.168.4.118 192.168.4.119; do
  ssh -p 11050 -o StrictHostKeyChecking=yes "$SOC_SSH_USER@$SOC_INDEXER_IP" \
    'install -d -m 0700 "$HOME/wazuh-indexer-tuning"'
  scp -P 11050 -o StrictHostKeyChecking=yes "$SOC_INDEXER_SCRIPT" \
    "$SOC_SSH_USER@$SOC_INDEXER_IP:wazuh-indexer-tuning/configurar_indexer.sh"
done
)
~~~

Verificar previamente las huellas SSH por un canal independiente. Si se modifica el script,
revisarlo y aprobar otro hash: no sustituir el hash para ocultar una diferencia. Este archivo
no forma parte del TAR de SOC Operations `0.1.159`; proviene del repositorio WazuhDoc indicado.

**Alternativa desde Windows:** copiar el mismo archivo local al home con `scp.exe -P 11050`,
por ejemplo para `.118`, y repetir para los demás nodos:

~~~powershell
scp.exe -P 11050 -o StrictHostKeyChecking=yes "D:\WazuhDoc\Source_wazuh\scripts\wazuh-4.14.7\configurar_indexer.sh" cmedina@192.168.4.118:configurar_indexer.sh
~~~

En ese caso, entrar por SSH y preparar la ubicación común antes de continuar:

~~~bash
install -d -m 0700 "$HOME/wazuh-indexer-tuning"
mv -i -- "$HOME/configurar_indexer.sh" "$HOME/wazuh-indexer-tuning/configurar_indexer.sh"
~~~

#### 7.9.2. Revisar el heap y ejecutar el dry-run

En **cada nodo**, con el usuario normal y `sudo`, comprobar el archivo y las condiciones
del script. No ejecutar los bloques de los tres nodos en paralelo:

~~~bash
(
set -euo pipefail
cd "$HOME/wazuh-indexer-tuning"
printf '%s  configurar_indexer.sh\n' \
  'b82dc0adbbc2312ecd1948ad31c90cd3c4502e2304842dceb943edbe3055a639' \
  | sha256sum --check --strict -
bash -n configurar_indexer.sh
test "$(dpkg-query -W -f='${Version}' wazuh-indexer)" = '4.14.8-1'
sudo test -f /etc/wazuh-indexer/jvm.options
sudo test ! -L /etc/wazuh-indexer/jvm.options
sudo test -f /etc/wazuh-indexer/opensearch.yml
sudo test ! -L /etc/wazuh-indexer/opensearch.yml
test "$(sudo grep -cE '^-Xms[0-9]+[gGmM]([[:space:]]|$)' /etc/wazuh-indexer/jvm.options)" -eq 1
test "$(sudo grep -cE '^-Xmx[0-9]+[gGmM]([[:space:]]|$)' /etc/wazuh-indexer/jvm.options)" -eq 1
free -h
sudo grep -nE '^-Xm[sx]|^[[:space:]]*bootstrap\.memory_lock:' \
  /etc/wazuh-indexer/jvm.options /etc/wazuh-indexer/opensearch.yml
read -r -p 'Heap aprobado para ESTE nodo, en GiB enteros: ' INDEXER_HEAP_GB
bash configurar_indexer.sh --heap-gb "$INDEXER_HEAP_GB"
)
~~~

El modo sin `--apply` no cambia archivos. Detenerse si faltan las líneas JVM esperadas, hay
definiciones duplicadas, una versión distinta o un heap no aprobado. Revisar también posibles
overrides de JVM y sysctl antes de aplicar; el script ejecuta `sysctl --system`, que carga
**todas** las configuraciones sysctl, no solo la de Wazuh.

#### 7.9.3. Respaldar y aplicar, un nodo cada vez

> **Ventana controlada:** comenzar únicamente con tres nodos activos, clúster `green` y sin
> recuperación pendiente. Reiniciar `.118`, comprobar su retorno y salud; después `.119`;
> finalmente `.117`. No reiniciar dos votantes a la vez. En una plataforma con datos reales,
> comprobar antes el respaldo y el procedimiento de mantenimiento aprobado.

El script guarda copias `.pre-tuning-<fecha>` de `jvm.options` y `opensearch.yml`, pero **no**
respalda los overrides systemd/sysctl existentes. Guardarlos y registrar sus valores antes
de aplicar. Reintroducir el heap revisado, porque el bloque anterior usó una subshell:

~~~bash
(
set -euo pipefail
cd "$HOME/wazuh-indexer-tuning"
printf '%s  configurar_indexer.sh\n' \
  'b82dc0adbbc2312ecd1948ad31c90cd3c4502e2304842dceb943edbe3055a639' \
  | sha256sum --check --strict -
read -r -p 'Heap aprobado y revisado en dry-run para ESTE nodo: ' INDEXER_HEAP_GB
bash configurar_indexer.sh --heap-gb "$INDEXER_HEAP_GB"
SOC_TUNING_BACKUP="/var/backups/wazuh-indexer-tuning/$(date -u +%Y%m%dT%H%M%SZ)"
sudo install -d -o root -g root -m 0700 "$SOC_TUNING_BACKUP"
for SOC_TUNING_FILE in \
  /etc/systemd/system/wazuh-indexer.service.d/memory-lock.conf \
  /etc/sysctl.d/99-wazuh-indexer.conf; do
  sudo test ! -L "$SOC_TUNING_FILE"
  if sudo test -e "$SOC_TUNING_FILE"; then
    sudo cp -a -- "$SOC_TUNING_FILE" "$SOC_TUNING_BACKUP/"
  fi
done
sysctl vm.max_map_count vm.swappiness \
  | sudo tee "$SOC_TUNING_BACKUP/kernel.before.txt" >/dev/null
sudo bash configurar_indexer.sh --heap-gb "$INDEXER_HEAP_GB" --apply --restart
sudo systemctl is-active wazuh-indexer
sudo grep -nE '^-Xm[sx]' /etc/wazuh-indexer/jvm.options
sudo grep -nE '^[[:space:]]*bootstrap\.memory_lock:' /etc/wazuh-indexer/opensearch.yml
sudo systemctl show wazuh-indexer -p LimitMEMLOCK
sudo sysctl vm.max_map_count vm.swappiness
)
~~~

Para dejar el reinicio pendiente, omitir únicamente `--restart`; el heap y el bloqueo de
memoria no se consideran activos hasta reiniciar el servicio y comprobarlos.

#### 7.9.4. Validar los ajustes efectivos antes del siguiente nodo

Desde `.117`, usar su endpoint LAN cubierto por el certificado. En una estación administrativa
con `jq`, verificar el clúster y obtener heap y bloqueo efectivos de los tres nodos:

~~~bash
(
set -euo pipefail
sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://192.168.4.117:9200/_cluster/health?wait_for_status=green&wait_for_no_relocating_shards=true&wait_for_no_initializing_shards=true&timeout=120s' \
  | jq -e '.status == "green" and .number_of_nodes == 3 and .timed_out == false and .relocating_shards == 0 and .initializing_shards == 0'
sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://192.168.4.117:9200/_nodes?filter_path=nodes.*.name,nodes.*.process.mlockall,nodes.*.jvm.mem.heap_max_in_bytes&pretty'
)
~~~

En el nodo recién reiniciado, `mlockall` debe ser `true` y `heap_max_in_bytes` debe ser el
heap aprobado multiplicado por `1073741824`. Comprobar también `_cat/nodes` y los roles del
apartado 7.4: el script no debe alterar `node.roles`. Si el servicio no vuelve, el clúster
no recupera `green`, no se bloquea la memoria o el heap difiere, **no continuar con otro nodo**;
revisar `journalctl -u wazuh-indexer` y restaurar la configuración en la ventana de rollback.
Referencia: [Nodes Info API](https://docs.opensearch.org/latest/api-reference/nodes-apis/nodes-info/).

<a id="limite-de-shards-para-despliegues-grandes"></a>

### 7.10. Límite de shards para despliegues grandes

En despliegues con muchos tenants, índices diarios o retención extensa, evaluar el ajuste
`cluster.max_shards_per_node`. Es un **límite de admisión de shards del clúster**, no una
ampliación de CPU, heap o disco. No aumenta `index.number_of_shards` de los índices existentes
ni sustituye el dimensionamiento del apartado 7.9. `configurar_indexer.sh` no modifica este
parámetro; se administra por separado mediante la API del Indexer.

OpenSearch 2.19 define `1000` como valor predeterminado. El presupuesto nominal se calcula
como el valor configurado multiplicado por los nodos de datos; cuenta primarios y réplicas
de índices abiertos, incluidas las copias sin asignar. En WA01, `.118` y `.119` son los dos
nodos de datos; `.117`, exclusivamente `cluster_manager`, no suma. Con `2000`, el presupuesto
nominal es **`2000 × 2 = 4000`**, no 6000, sujeto a otros límites configurados.
Referencias: [límite en OpenSearch 2.19](https://docs.opensearch.org/2.19/install-and-configure/configuring-opensearch/cluster-settings/)
y [validación de shards](https://github.com/opensearch-project/OpenSearch/blob/2.19/server/src/main/java/org/opensearch/indices/ShardLimitValidator.java).

> **Consideración de capacidad:** `2000` es un ejemplo que requiere aprobación, no el valor
> obligatorio para cualquier Wazuh grande. Antes de elevarlo, revisar cantidad y tamaño de
> shards, heap/GC, CPU, disco, latencia, retención y recuperación tras perder un nodo de datos.
> Priorizar un diseño con menos índices/shards pequeños, rollover y ciclo de vida apropiados
> o añadir nodos de datos. No reducir réplicas ni eliminar índices para sortear el límite sin
> evaluar disponibilidad y conservación de datos. Este parámetro tampoco equivale a
> `cluster.routing.allocation.total_shards_per_node`, que controla la asignación por nodo.

#### 7.10.1. Registrar el estado y aprobar el presupuesto

Ejecutar desde `.117` por la LAN, usando sus certificados administrativos locales y el
endpoint `.118` cubierto por los SAN. Requiere `jq` y privilegios de administración del
clúster; el rol `auditor` no debe poder ejecutar la mutación. No publicar este acceso
administrativo ni copiar la clave privada al equipo cliente.

~~~bash
SOC_SHARD_BACKUP="/var/backups/wazuh-indexer-shards/$(date -u +%Y%m%dT%H%M%SZ)"
(
set -euo pipefail
sudo install -d -o root -g root -m 0700 "$SOC_SHARD_BACKUP"
sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://192.168.4.118:9200/_cluster/settings?include_defaults=true&flat_settings=true' \
  | sudo tee "$SOC_SHARD_BACKUP/settings.before.json" >/dev/null
sudo jq '{persistent: .persistent["cluster.max_shards_per_node"], transient: .transient["cluster.max_shards_per_node"], defaults: .defaults["cluster.max_shards_per_node"]}' \
  "$SOC_SHARD_BACKUP/settings.before.json"
sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://192.168.4.118:9200/_cluster/health?wait_for_status=green&timeout=120s' \
  | jq -e '.status == "green" and .number_of_nodes == 3 and .number_of_data_nodes == 2 and .timed_out == false and .relocating_shards == 0 and .initializing_shards == 0'
sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://192.168.4.118:9200/_cat/indices?v&h=health,status,index,pri,rep,store.size'
sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://192.168.4.118:9200/_cat/allocation?v&h=node,shards,disk.percent,disk.avail'
printf 'Respaldo del ajuste: %s/settings.before.json\n' "$SOC_SHARD_BACKUP"
)
~~~

Estimar la demanda sumando, para cada índice abierto, `primarios × (1 + réplicas)`, incluyendo
las familias de alertas, archives, estados y sistema. Ejemplo ilustrativo: 50 tenants con un
índice diario de alertas durante 30 días, un primario y una réplica necesitan **3000 shards
solo para alertas**, antes de sumar las demás familias. Verificar la creación de índices,
restauraciones y recuperación dentro del presupuesto aprobado; no planificar hasta el límite.

Revisar también los overrides y límites de asignación en el JSON respaldado. Un valor
`transient` prevalece sobre `persistent`; si existe, detenerse y resolver explícitamente ese
override antes de aplicar el ejemplo. No asumir que una respuesta HTTP 200 demuestra que
el valor efectivo cambió. [Precedencia de ajustes](https://docs.opensearch.org/2.19/install-and-configure/configuring-opensearch/index/).

#### 7.10.2. Aplicar 2000 y verificar el valor efectivo

Solo después de aprobar la capacidad y las comprobaciones anteriores, ejecutar **una vez
para todo el clúster**. Aunque se envíe a `.118`, también aplica a los otros nodos; no repetir
en cada servidor ni añadirlo al script de heap. El ajuste es dinámico y persistente: no
requiere reiniciar Indexers y permanece después de reiniciar el clúster.
[Cluster Settings API](https://docs.opensearch.org/2.19/api-reference/cluster-api/cluster-settings/).

~~~bash
(
set -euo pipefail
sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  -H 'Content-Type: application/json' \
  -X PUT 'https://192.168.4.118:9200/_cluster/settings' \
  -d '{"persistent":{"cluster.max_shards_per_node":2000}}' \
  | jq -e '.acknowledged == true'
sudo curl --fail-with-body --silent --show-error \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  'https://192.168.4.118:9200/_cluster/settings?include_defaults=true&flat_settings=true' \
  | jq -e '(.persistent["cluster.max_shards_per_node"] | tonumber) == 2000 and ((.transient["cluster.max_shards_per_node"] // .persistent["cluster.max_shards_per_node"] // .defaults["cluster.max_shards_per_node"]) | tonumber) == 2000'
)
~~~

Si se prefiere autenticación con usuario en lugar del certificado administrativo, usar una
cuenta autorizada y `curl --user admin --cacert /etc/wazuh-indexer/certs/root-ca.pem ...`;
curl pedirá la contraseña, sin ponerla en el comando. No usar `-k`, no pegar contraseñas en
la guía ni desactivar TLS para reproducir el ejemplo original.

Registrar el cambio en la evidencia de despliegue. Comprobar después salud, ingestión de
Filebeat, errores de creación de índices, heap/GC y latencia durante la ventana de observación.
Si aparece `this action would add ... maximum shards open`, contrastar la demanda con el
presupuesto efectivo; un clúster `red`, watermarks o un problema de asignación no se resuelven
simplemente elevando este valor.

#### 7.10.3. Revertir al valor registrado

Antes de reducir el límite, revisar la cantidad de shards abiertos y el presupuesto resultante:
el cambio no elimina shards existentes, pero puede impedir nuevas creaciones o aperturas de
índices. No borrar datos automáticamente como parte del rollback. Conservar la ruta de respaldo;
si se abre otra sesión SSH, definir `SOC_SHARD_BACKUP` con el directorio exacto generado en 7.10.1.

El comando siguiente restaura **solo** `cluster.max_shards_per_node`, incluidos sus valores
`persistent` y `transient` anteriores; no restaura otros ajustes del JSON. Un `null` elimina
el override, dejando que se aplique el siguiente nivel de precedencia. Revisar y aprobar el
payload antes de enviarlo, especialmente si hubo cambios concurrentes de otro administrador.
[Restablecimiento de ajustes](https://docs.opensearch.org/latest/api-reference/cluster-api/cluster-settings/#example-resetting-a-setting).

~~~bash
(
set -euo pipefail
: "${SOC_SHARD_BACKUP:?Definir el directorio exacto del respaldo de 7.10.1}"
sudo test -f "$SOC_SHARD_BACKUP/settings.before.json"
sudo jq '{persistent: {"cluster.max_shards_per_node": .persistent["cluster.max_shards_per_node"]}, transient: {"cluster.max_shards_per_node": .transient["cluster.max_shards_per_node"]}}' \
  "$SOC_SHARD_BACKUP/settings.before.json"
read -r -p 'Para restaurar los valores mostrados, escribir REVERTIR SHARDS: ' SOC_SHARD_CONFIRM
test "$SOC_SHARD_CONFIRM" = 'REVERTIR SHARDS'
sudo jq '{persistent: {"cluster.max_shards_per_node": .persistent["cluster.max_shards_per_node"]}, transient: {"cluster.max_shards_per_node": .transient["cluster.max_shards_per_node"]}}' \
  "$SOC_SHARD_BACKUP/settings.before.json" \
  | sudo curl --fail-with-body --silent --show-error \
      --cert /etc/wazuh-indexer/certs/admin.pem \
      --key /etc/wazuh-indexer/certs/admin-key.pem \
      --cacert /etc/wazuh-indexer/certs/root-ca.pem \
      -H 'Content-Type: application/json' \
      -X PUT 'https://192.168.4.118:9200/_cluster/settings' \
      --data-binary @- \
  | jq -e '.acknowledged == true'
)
~~~

Repetir después el GET de ajustes y las consultas de salud/asignación de 7.10.1. Restaurar
`null` no garantiza volver a `1000` si hay un valor local en `opensearch.yml`; verificar
siempre el resultado efectivo.

<a id="snapshots-indexer-s3"></a>

### 7.11. Snapshots de los Indexers en S3

> **Consideración — dos almacenamientos distintos:** el MinIO del apartado 9.5 almacena
> evidencias de SOC Operations. No registra ni programa snapshots de Wazuh Indexer.
> Para respaldos de producción, usar un bucket dedicado y almacenamiento independiente
> del servidor `.117`. Perder ese servidor no debe destruir también la única copia recuperable.

El repositorio pertenece al **clúster**, no a un Indexer individual: se registra una vez,
pero el plugin y las credenciales deben estar disponibles en `.117`, `.118` y `.119`.
Este procedimiento configura AWS S3 con HTTPS; la variante compatible está en 7.11.7.
No monta el bucket como disco, no usa `path.repo` y no copia manualmente los archivos del data directory.

#### 7.11.1. Aprobar el destino, el alcance y la red

Antes de ejecutar, completar la ficha con el responsable de almacenamiento y de los datos:

| Parámetro | Valor para WA01 / decisión pendiente |
|---|---|
| Repositorio lógico | `repository-s3-wa01` |
| Cliente del plugin | `wa01snapshots`, separado de otros clientes S3 |
| Bucket | Nombre real aprobado; todavía no se ha proporcionado |
| Región | Región real del bucket; no asumir `us-east-1` |
| `base_path` | `wazuh/wa01/production/repo-v1` para un repositorio nuevo |
| Escritor | Solo el clúster WA01; un consumidor de restauración usa `readonly: true` |
| Alcance | Allowlists por tenant y familia: alerts, archives y, si se aprueba, history/states |
| Calendario y retención | UTC; intervalos, días y mínimo de copias aprobados por alcance |
| Continuidad | RPO/RTO del Indexer, capacidad del bucket y prueba de restauración |
| Credenciales | Identidad de servicio dedicada; referencia al secreto en el vault, nunca su valor |

`repo-v1` es la generación del repositorio, no Wazuh 4.14.8. No reutilizar una ubicación de
lab02 ni mover objetos de un repositorio existente para adoptar esta convención. El nombre
lógico no aísla dos repositorios que apunten al mismo bucket y ruta. Un repositorio compartido
no concede aislamiento S3 por tenant: sus objetos deben quedar fuera del acceso directo de
analysts, managers y auditores tenant.

Desde la consola AWS autorizada, crear o revisar un **bucket de propósito general**:

- Activar las cuatro opciones de **Block Public Access**, conservar Object Ownership
  **Bucket owner enforced** y exigir HTTPS mediante la política de seguridad aprobada.
  [Bloqueo público](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html),
  [propiedad del bucket](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-ownership-new-bucket.html).
- Configurar cifrado predeterminado, preferiblemente SSE-KMS con una CMK aprobada cuando
  lo requiera la clasificación. Autorizar `kms:GenerateDataKey` y `kms:Decrypt` sobre esa
  clave tanto en IAM como en su key policy según la cuenta; conservar acceso a la clave
  durante toda la retención. El ejemplo de registro no envía `server_side_encryption: true`,
  porque esa opción solicita SSE-S3, no SSE-KMS. [Cifrado SSE-KMS y permisos](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html).
- Evaluar versionado, auditoría de operaciones de objetos y una copia independiente con
  sus costes y recuperación. No asumir que versionado por sí solo protege de un compromiso
  administrativo. [Seguridad y auditoría S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html).
- No habilitar expiración de objetos actuales, transición a Glacier/Deep Archive ni Object
  Lock sobre el repositorio operativo sin validar un diseño específico. La limpieza de
  snapshots debe realizarla OpenSearch: comparten blobs y el borrado externo puede romper
  copias vigentes. Una copia inmutable exige un flujo independiente probado.

En los **tres nodos** comprobar DNS, NTP y salida TLS al endpoint S3. UFW de esta guía
permite salida por defecto; no hace falta abrir un puerto entrante ni publicar S3 por
HAProxy/Cloudflare. Si la salida está restringida, autorizar DNS/NTP y HTTPS según el
proveedor o el proxy de egreso real. No confundir HAProxy `.50` con un proxy HTTP de salida
ni fijar una sola IP de AWS como si fuera permanente.

#### 7.11.2. Identidad de servicio y permisos del bucket

Para estas VMs Proxmox, usar credenciales de una identidad dedicada al prefijo de WA01,
con rotación definida. No usar las credenciales root de AWS/MinIO ni claves del operador.
Si posteriormente se ejecuta en EC2, evaluar un instance profile en lugar de claves estáticas.
Los dos campos secretos se cargarán interactivamente en el keystore de **cada nodo**.

Aplicar al principal escritor la siguiente **plantilla de política IAM**, sustituyendo
`REEMPLAZAR_BUCKET` por el bucket aprobado. No es una bucket policy y no crea recursos.
Separar la ubicación del bucket de la condición `s3:prefix`: no aplicar esa condición
a `GetBucketLocation` ni a operaciones que no la admiten.
[Permisos de las operaciones S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-with-s3-policy-actions.html).

~~~json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BucketLocationAndMultipartInventory",
      "Effect": "Allow",
      "Action": ["s3:GetBucketLocation", "s3:ListBucketMultipartUploads"],
      "Resource": "arn:aws:s3:::REEMPLAZAR_BUCKET"
    },
    {
      "Sid": "ListWa01SnapshotPrefix",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::REEMPLAZAR_BUCKET",
      "Condition": {
        "StringLike": {
          "s3:prefix": ["wazuh/wa01/production/repo-v1", "wazuh/wa01/production/repo-v1/*"]
        }
      }
    },
    {
      "Sid": "ManageWa01SnapshotObjects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
        "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"
      ],
      "Resource": "arn:aws:s3:::REEMPLAZAR_BUCKET/wazuh/wa01/production/repo-v1/*"
    },
    {
      "Sid": "CompatibleOwnerHeaderOnly",
      "Effect": "Allow",
      "Action": "s3:PutObjectAcl",
      "Resource": "arn:aws:s3:::REEMPLAZAR_BUCKET/wazuh/wa01/production/repo-v1/*",
      "Condition": {"StringEquals": {"s3:x-amz-acl": "bucket-owner-full-control"}}
    }
  ]
}
~~~

El encabezado `bucket-owner-full-control` del registro evita enviar la ACL `private` a
un bucket con ACLs deshabilitadas; el permiso correspondiente queda condicionado al
encabezado y al prefijo. No habilitar ACLs ni acceso público para corregir un error.
[Encabezado de propiedad y PutObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PutObject.html).

`DeleteObject` permite verificar/limpiar el repositorio y aplicar retención; no permite
borrar el bucket. Para un clúster restaurador independiente, emitir otra identidad **solo
lectura**: `GetBucketLocation`, `ListBucket` limitado al prefijo y `GetObject` sobre sus
objetos, además de `kms:Decrypt` si corresponde. No reutilizar las claves del escritor.
Revisar también bucket policy, SCP, restricciones de red y key policy: una denegación
explícita puede prevalecer sobre esta autorización.

#### 7.11.3. Instalar el plugin y cargar el keystore, nodo por nodo

> **Antes de ejecutar:** ventana de mantenimiento, clúster `green`, tres votantes presentes,
> sin snapshots/restauraciones ni recuperación activa. Trabajar `.118` → `.119` → `.117`;
> nunca detener dos votantes simultáneamente. No cambiar `node.roles` ni ejecutar de nuevo
> `--start-cluster`. Si falla una comprobación, detener el procedimiento y conservar el respaldo.

En una sesión de administración en `.117`, definir el cliente TLS para los comandos de
este apartado. `wa01_indexer` es una función de esta sesión, no un programa instalado;
si se abre otra sesión, volver a definirla. Usa la API **interna**, no el FQDN externo
limitado a consultas, y no desactiva la verificación del certificado.
Comprobar primero `command -v curl` y `command -v jq`; si falta alguno, instalar las
dependencias en la ventana autorizada con `sudo apt-get update` y
`sudo apt-get install -y curl jq ca-certificates`. No ejecutar las comprobaciones siguientes
si esa preparación falla.

~~~bash
SOC_INDEXER_URL='https://192.168.4.118:9200'
SOC_SNAPSHOT_REPOSITORY='repository-s3-wa01'
SOC_SNAPSHOT_BASE_PATH='wazuh/wa01/production/repo-v1'
wa01_indexer() {
  sudo curl --fail-with-body --silent --show-error \
    --connect-timeout 10 --max-time 180 \
    --cert /etc/wazuh-indexer/certs/admin.pem \
    --key /etc/wazuh-indexer/certs/admin-key.pem \
    --cacert /etc/wazuh-indexer/certs/root-ca.pem "$@"
}
~~~

**Antes de cada nodo**, desde esa sesión en `.117`:

~~~bash
(
set -euo pipefail
wa01_indexer "$SOC_INDEXER_URL/" | jq '{cluster_name, version}'
wa01_indexer "$SOC_INDEXER_URL/_cluster/health" \
  | jq -e '.status == "green" and .number_of_nodes == 3 and .number_of_data_nodes == 2 and .relocating_shards == 0 and .initializing_shards == 0 and .unassigned_shards == 0'
wa01_indexer "$SOC_INDEXER_URL/_snapshot/_status" | jq -e '(.snapshots | length) == 0'
wa01_indexer "$SOC_INDEXER_URL/_cat/recovery?active_only=true&format=json" | jq -e 'length == 0'
)
~~~

Registrar la versión OpenSearch real del GET `/`. El plugin debe coincidir con esa versión,
no con el número `4.14.8` de Wazuh ni con el de OpenSearch Dashboards. Usar el instalador
incluido en el paquete; no forzar un ZIP de otra versión ni descargar `latest`.
[Compatibilidad de plugins](https://docs.opensearch.org/2.19/install-and-configure/plugins/).

En el **nodo que corresponde al turno**, con el usuario SSH normal y `sudo`, ejecutar:

~~~bash
(
set -euo pipefail
test "$(dpkg-query -W -f='${Version}' wazuh-indexer)" = '4.14.8-1'
test "$(systemctl show wazuh-indexer -p User --value)" = 'wazuh-indexer'
sudo test -x /usr/share/wazuh-indexer/bin/opensearch-plugin
sudo test -x /usr/share/wazuh-indexer/bin/opensearch-keystore
sudo test -f /etc/wazuh-indexer/opensearch.keystore
SOC_S3_NODE_BACKUP=$(sudo mktemp -d /var/backups/wa01-indexer-s3.XXXXXXXX)
sudo cp -a /etc/wazuh-indexer/opensearch.keystore /etc/wazuh-indexer/opensearch.yml "$SOC_S3_NODE_BACKUP/"
printf 'Respaldo protegido del nodo: %s\n' "$SOC_S3_NODE_BACKUP"
sudo systemctl stop wazuh-indexer
SOC_S3_PLUGINS=$(sudo env OPENSEARCH_PATH_CONF=/etc/wazuh-indexer \
  /usr/share/wazuh-indexer/bin/opensearch-plugin list)
if ! grep -Fxq 'repository-s3' <<< "$SOC_S3_PLUGINS"; then
  sudo env OPENSEARCH_PATH_CONF=/etc/wazuh-indexer \
    /usr/share/wazuh-indexer/bin/opensearch-plugin install --batch repository-s3
fi
SOC_S3_KEY_NAMES=$(sudo env OPENSEARCH_PATH_CONF=/etc/wazuh-indexer \
  /usr/share/wazuh-indexer/bin/opensearch-keystore list)
for SOC_S3_SUFFIX in access_key secret_key; do
  SOC_S3_SETTING="s3.client.wa01snapshots.$SOC_S3_SUFFIX"
  if grep -Fxq "$SOC_S3_SETTING" <<< "$SOC_S3_KEY_NAMES"; then
    printf '%s ya existe: conservar; una rotación requiere su procedimiento separado.\n' "$SOC_S3_SETTING"
  else
    sudo env OPENSEARCH_PATH_CONF=/etc/wazuh-indexer \
      /usr/share/wazuh-indexer/bin/opensearch-keystore add "$SOC_S3_SETTING"
  fi
done
sudo chown wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/opensearch.keystore
sudo chmod 0660 /etc/wazuh-indexer/opensearch.keystore
sudo systemctl start wazuh-indexer
sudo systemctl is-active --quiet wazuh-indexer
sudo env OPENSEARCH_PATH_CONF=/etc/wazuh-indexer \
  /usr/share/wazuh-indexer/bin/opensearch-keystore list \
  | grep -E '^s3\.client\.wa01snapshots\.(access_key|secret_key|session_token)$'
)
~~~

Introducir cada valor del vault **solo en el prompt del keystore**; el listado muestra
nombres de claves, no valores. Con credenciales temporales también se necesita
`s3.client.wa01snapshots.session_token` y renovación antes del vencimiento: no usarlas como
si fueran permanentes. No ejecutar `keystore create` sobre el existente ni usar `--force`
para sobrescribir entradas. Respaldar el keystore como material sensible, no publicarlo.

**Después de arrancar cada nodo**, desde `.117`, esperar recuperación completa:

~~~bash
(
set -euo pipefail
wa01_indexer "$SOC_INDEXER_URL/_cluster/health?wait_for_status=green&wait_for_no_relocating_shards=true&wait_for_no_initializing_shards=true&timeout=120s" \
  | jq -e '.timed_out == false and .status == "green" and .number_of_nodes == 3 and .number_of_data_nodes == 2 and .unassigned_shards == 0'
wa01_indexer "$SOC_INDEXER_URL/_cat/plugins?v&h=name,component,version"
)
~~~

Comprobar `repository-s3` en el nodo tratado y su versión antes del siguiente. Al terminar
deben aparecer los tres nodos con ese plugin. Verificar también ingestión Filebeat y
Dashboard; estar `active` en systemd por sí solo no acredita pertenencia al clúster.

#### 7.11.4. Registrar el repositorio una vez y verificar los tres nodos

Desde la misma sesión `.117`, indicar los parámetros **no secretos** del bucket AWS ya
creado. El ejemplo usa el endpoint regional comercial de AWS; para otras particiones o
S3 compatible usar el endpoint aprobado y adaptar 7.11.7 antes de registrar.

~~~bash
read -r -p 'Nombre real del bucket AWS aprobado: ' SOC_SNAPSHOT_BUCKET
read -r -p 'Region real del bucket AWS: ' SOC_SNAPSHOT_REGION
(
set -euo pipefail
: "${SOC_SNAPSHOT_REPOSITORY:?Definir la sesion de 7.11.3}"
: "${SOC_SNAPSHOT_BASE_PATH:?Definir la sesion de 7.11.3}"
[[ "$SOC_SNAPSHOT_BUCKET" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]]
[[ "$SOC_SNAPSHOT_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]]
wa01_indexer "$SOC_INDEXER_URL/_snapshot/_all" | jq .
read -r -p 'Confirmar bucket/ruta sin otro escritor; escribir REGISTRAR S3 WA01: ' SOC_S3_CONFIRM
test "$SOC_S3_CONFIRM" = 'REGISTRAR S3 WA01'
jq -n --arg bucket "$SOC_SNAPSHOT_BUCKET" --arg region "$SOC_SNAPSHOT_REGION" \
  --arg base_path "$SOC_SNAPSHOT_BASE_PATH" \
  '{type:"s3",settings:{bucket:$bucket,base_path:$base_path,client:"wa01snapshots",region:$region,endpoint:("s3."+$region+".amazonaws.com"),protocol:"https",readonly:false,compress:true,storage_class:"standard",canned_acl:"bucket-owner-full-control"}}' \
  | wa01_indexer -H 'Content-Type: application/json' -X PUT \
      "$SOC_INDEXER_URL/_snapshot/$SOC_SNAPSHOT_REPOSITORY" --data-binary @- \
  | jq -e '.acknowledged == true'
wa01_indexer "$SOC_INDEXER_URL/_snapshot/$SOC_SNAPSHOT_REPOSITORY" | jq .
wa01_indexer -X POST "$SOC_INDEXER_URL/_snapshot/$SOC_SNAPSHOT_REPOSITORY/_verify" \
  | jq -e '([.nodes[].name] | sort) == (["wa01-indexer-manager","wa01-indexer01","wa01-indexer02"] | sort)'
)
~~~

> **Detener si el repositorio ya existe con otra ubicación:** no ejecutar el PUT para
> cambiarlo a ciegas. Comparar configuración, inventariar sus snapshots y aprobar una
> migración independiente. Tampoco registrar otro nombre como escritor de la misma ruta.

`bucket` no lleva `s3://`, ARN ni ruta; `base_path` no lleva barra inicial/final. Las
credenciales no van en este JSON. El GET confirma configuración; `_verify` comprueba
acceso de los nodos y debe devolver los **tres nombres** de WA01, incluido el manager-only.
`acknowledged: true` no es una prueba de restauración.
[Registro S3](https://docs.opensearch.org/2.19/api-reference/snapshots/create-repository/),
[verificación del repositorio](https://docs.opensearch.org/2.19/api-reference/snapshots/verify-snapshot-repository/).

#### 7.11.5. Primer snapshot y restauración piloto

Con autorización de ingeniería, elegir un índice Wazuh **exacto, abierto, histórico y sin
escrituras**. Consultar primero `_cat/indices?v` y confirmar propietario/familia; no usar
`*` ni un índice de seguridad. En `.117`, con la función TLS anterior:

~~~bash
read -r -p 'Indice Wazuh historico EXACTO aprobado para el piloto: ' SOC_S3_PILOT_INDEX
SOC_S3_PILOT_SNAPSHOT="wazuh-wa01-pilot-$(date -u +%Y%m%dt%H%M%Sz)"
(
set -euo pipefail
[[ "$SOC_S3_PILOT_INDEX" =~ ^wazuh-[a-z0-9._-]+$ ]]
wa01_indexer "$SOC_INDEXER_URL/_cluster/health" | jq -e '.status == "green"'
wa01_indexer "$SOC_INDEXER_URL/_snapshot/_status" | jq -e '(.snapshots | length) == 0'
wa01_indexer "$SOC_INDEXER_URL/_cat/indices/$SOC_S3_PILOT_INDEX?format=json" \
  | jq -e --arg index "$SOC_S3_PILOT_INDEX" 'length == 1 and (.[0].index == $index) and (.[0].status == "open")'
wa01_indexer "$SOC_INDEXER_URL/$SOC_S3_PILOT_INDEX/_count" \
  | jq -e 'select(._shards.failed == 0) | {count, _shards}'
printf 'Registrar conteo anterior, indice=%s, snapshot=%s, repository=%s\n' \
  "$SOC_S3_PILOT_INDEX" "$SOC_S3_PILOT_SNAPSHOT" "$SOC_SNAPSHOT_REPOSITORY"
jq -n --arg indices "$SOC_S3_PILOT_INDEX" \
  '{indices:$indices,ignore_unavailable:false,include_global_state:false,partial:false,metadata:{deployment_id:"wa01",purpose:"restore-pilot"}}' \
  | wa01_indexer -H 'Content-Type: application/json' -X PUT \
      "$SOC_INDEXER_URL/_snapshot/$SOC_SNAPSHOT_REPOSITORY/$SOC_S3_PILOT_SNAPSHOT?wait_for_completion=false" --data-binary @- \
  | jq -e '.accepted == true'
)
~~~

La aceptación inicia una operación asíncrona. Repetir esta consulta hasta su finalización;
no crear otro snapshot por perder la sesión. Si se vuelve a conectar, definir los nombres
**exactos ya registrados**, no generar un timestamp nuevo:

~~~bash
(
set -euo pipefail
: "${SOC_S3_PILOT_SNAPSHOT:?Definir el nombre del snapshot ya solicitado}"
wa01_indexer "$SOC_INDEXER_URL/_snapshot/$SOC_SNAPSHOT_REPOSITORY/$SOC_S3_PILOT_SNAPSHOT" \
  | jq -e --arg index "$SOC_S3_PILOT_INDEX" '.snapshots | length == 1 and (.[0].state == "SUCCESS") and (.[0].shards.failed == 0) and (.[0].include_global_state == false) and (.[0].indices == [$index])'
)
~~~

**Solo `SUCCESS` con cero shards fallidos permite continuar**; un resultado en progreso
puede hacer fallar esta comprobación sin que haya fallado el snapshot. Conservar el JSON
final, UUID, índices, versión OpenSearch, fechas y conteos. Los snapshots no representan
una transacción global instantánea y no incluyen PostgreSQL, evidencias ni configuración
completa de Manager/Dashboard. [Creación de snapshot](https://docs.opensearch.org/2.19/api-reference/snapshots/create-snapshot/),
[funcionamiento y exclusión de seguridad](https://docs.opensearch.org/2.19/tuning-your-cluster/availability-and-recovery/snapshots/snapshot-restore/).

El piloto selecciona únicamente ese índice concreto: no incluye `.opendistro_security`
ni otros índices de sistema. La verificación compara la lista real con el índice aprobado;
no ampliar la selección a `*` para corregir un índice inexistente.

Ensayar preferentemente en un **clúster aislado compatible**, con su propio plugin/keystore,
identidad S3 de lectura y registro del mismo bucket/base_path con `readonly: true`.
No probar compatibilidad deduciéndola solamente del número de Wazuh.
Si se autoriza un piloto en WA01, reservar capacidad adicional y un nombre nuevo; no borrar,
cerrar ni sobrescribir un índice productivo para liberar su nombre.

En **Dev Tools del Dashboard conectado al clúster elegido**, con un administrador autorizado,
sustituir los tres marcadores siguientes por snapshot, índice exacto y destino temporal
aprobados. En el clúster de ensayo registrar el repositorio con el mismo nombre lógico
de este ejemplo y solo lectura. No pegar los marcadores literalmente:

~~~http
POST /_snapshot/repository-s3-wa01/SNAPSHOT_APROBADO/_restore
{
  "indices": "INDICE_EXACTO_APROBADO",
  "ignore_unavailable": false,
  "include_global_state": false,
  "include_aliases": false,
  "partial": false,
  "rename_pattern": "(.+)",
  "rename_replacement": "restore-check-wa01-DESTINO_UNICO",
  "index_settings": {"index.blocks.write": true},
  "ignore_index_settings": [
    "index.plugins.index_state_management.policy_id",
    "index.opendistro.index_state_management.policy_id"
  ]
}
~~~

Antes del POST comprobar que el destino no existe y revisar plantillas/ISM: el prefijo
temporal no debe entrar en enrutamiento productivo ni en políticas de eliminación. Ignorar
IDs de políticas copiados no sustituye revisar cualquier asociación automática del destino.
Después, usando el **mismo nombre temporal real** en todas las consultas:

~~~http
GET /_cat/recovery/restore-check-wa01-DESTINO_UNICO?v&active_only=true
GET /_cluster/health/restore-check-wa01-DESTINO_UNICO?level=indices
GET /_plugins/_ism/explain/restore-check-wa01-DESTINO_UNICO?show_policy=true
GET /restore-check-wa01-DESTINO_UNICO/_count
GET /restore-check-wa01-DESTINO_UNICO/_mapping
~~~

Exigir recuperación terminada, salud `green`, cero shards fallidos y conteo/mapping/rango
temporal equivalentes al piloto sin escrituras. Comprobar `tenant.id`, muestras y aislamiento
RBAC antes de cualquier publicación. Medir RTO real. Un POST aceptado o una lista de
recuperación vacía no prueban por sí solos que los datos estén completos.
[Parámetros de restauración](https://docs.opensearch.org/2.19/api-reference/snapshots/restore-snapshot/).
Mantener snapshot y piloto hasta aceptación; esta guía no ordena eliminar datos.

#### 7.11.6. Programar, integrar con SOC Operations y controlar retención

Registrar un repositorio no instala una política ni inicia respaldos automáticos. Después
del piloto, comprobar que **Snapshot Management / Index Management** está disponible.
Ingeniería administra el repositorio; no conceder gestión de snapshots a un rol auditor
tenant por el hecho de tener permiso de lectura de índices.

En SOC Operations, **al dar de alta un tenant con snapshots habilitados**, seleccionar
`repository-s3-wa01`, aprobar `snapshot_interval_hours` y `snapshot_retention_days`, y
comprobar que completa el job de aprovisionamiento. El release publicado `0.1.161` admite
intervalos de `1, 2, 3, 4, 6, 8, 12 o 24` horas y crea la política
`soc-<tenant_id>-snapshots` para alerts/archives de su `index_prefix`.
En ese release la edición conserva la activación y el repositorio elegidos en el alta;
registrar S3 después no activa snapshots en un tenant creado sin ellos. El flujo corregido
para `0.1.162` y sus versiones de API/worker, plugin y agente se describe abajo.
El inventario nativo `GET /api/v1/admin/snapshot-repositories` exige rol global admin o
`soc_engineering`; no es una ruta de la API Indexer.

> **Consideración — alcance y RPO:** esa política tenant no cubre automáticamente Global,
> cuarentena, history, states ni todos los índices operativos. Crear políticas independientes
> aprobadas para las familias necesarias. El mínimo actual de una hora de SOC Operations
> no demuestra un RPO de 15 minutos para el Indexer; el WAL de PostgreSQL es otro respaldo.
> No aceptar el valor predeterminado de 365 días sin la aprobación de retención correspondiente.

Verificar en Dev Tools, sustituyendo `TENANT_REAL` por el ID y revisando el contenido,
no solo la existencia de la política:

~~~http
GET /_plugins/_sm/policies/soc-TENANT_REAL-snapshots
GET /_plugins/_sm/policies/soc-TENANT_REAL-snapshots/_explain
~~~

Validar repositorio, prefijos de índices, UTC, creación, eliminación, últimos resultados
y duración. El código actual conserva un mínimo de **un snapshot** al aplicar su retención:
pueden quedar copias más antiguas que `max_age`. No editar una política gestionada por SOC
por fuera sin coordinar la reconciliación, ni crear otra política con el mismo alcance/horario.

Para un alcance **no gestionado por SOC**, crear una política propia mediante Snapshot
Management → Snapshot Policies → Create policy. Elegir el repositorio verificado, una
allowlist aprobada y cron UTC con carga escalonada. Guardar primero deshabilitada, revisar
su JSON y aprobar su activación. Si la UI no ofrece esa opción, usar la API SM con
`enabled: false`, no crear una tarea activa sin revisión. La configuración debe incluir `include_global_state: false`
y `partial: false`; acordar el comportamiento si un patrón no tiene índices. Programar y
probar explícitamente la eliminación por edad/mínimo de copias, sin `snapshot_pattern: "*"`
que pueda alcanzar respaldos ajenos o manuales.
[Programación, roles y seguimiento SM](https://docs.opensearch.org/2.19/tuning-your-cluster/availability-and-recovery/snapshots/snapshot-management/).

<a id="habilitar-snapshots-en-un-tenant-existente"></a>

##### 7.11.6.1. Activar o reconciliar snapshots de un tenant existente

> **Consideración — versión necesaria:** este flujo requiere el instalador `0.1.162`,
> API/worker/agente `0.1.114` y plugin `0.1.94`. No está incluido en los activos inmutables
> `0.1.161`; reinstalarlos o recargar el navegador no corrige ese release. La validación
> end-to-end en WA01 sigue pendiente: completar los controles de la sección 9.15.

Después de actualizar según la sección 9.15, con una sesión `soc_engineering`
o admin:

- Confirmar que el repositorio S3 está registrado y verificado en el clúster. El bucket
  de evidencias de SOC Operations no sustituye al repositorio de snapshots de OpenSearch.
- Abrir **Admin → Tenants → Modificación** del tenant existente y pulsar **Actualizar
  repositorios**. Esto refresca el inventario: no inicia respaldos ni activa otros tenants.
- Marcar **Habilitar snapshots de alertas y archives (políticas separadas)** y seleccionar
  un repositorio escribible. Configurar frecuencia, retención y un motivo auditable.
- Pulsar **Guardar y reconciliar**, incluso sin cambiar los valores cuando se desea
  regenerar una política ausente o corregir drift. El ID, el prefijo, el grupo principal,
  los datos y las aprobaciones existentes se conservan; se reencolan solo los jobs ISM/SM.
- Comprobar que `opensearch.snapshot_policy` pasa a `completed`. Si faltan aprobaciones,
  el worker o el agente no están disponibles, sigue pendiente o muestra el error real;
  guardar la configuración no significa que ya se haya aplicado en OpenSearch.
- En el tenant seleccionado, **Actualizar inventario** muestra la existencia, estado
  real y coincidencia de cada política. El polling de aprovisionamiento refresca ese
  resumen al terminar los jobs; no es necesario recrear el tenant.

Se gestionan dos políticas independientes con alcance exacto por familia:

| Familia | Política | Patrón de índices |
| --- | --- | --- |
| Alertas | `soc-<tenant_id>-alerts-snapshots` | `wazuh-alerts-<index_prefix>-4.x-*` |
| Archivos | `soc-<tenant_id>-archives-snapshots` | `wazuh-archives-<index_prefix>-4.x-*` |

La frecuencia y retención del formulario son comunes a ambas políticas en esta
corrección. Sus ejecuciones se escalonan en UTC: alertas al minuto `00` y archives al
`15` de las horas seleccionadas; limpieza a los minutos `30` y `45`, respectivamente.
Se mantiene `min_count: 1`, `include_global_state: false` y `partial: false`. Si archives
no genera índices, la existencia de su política no demuestra que haya datos respaldados.

Contrato interno de edición (sesión autorizada de SOC Operations, **no** clave externa
de solo lectura). Los clientes antiguos pueden omitir los dos campos nuevos para
conservar la activación y el repositorio actuales:

~~~http
PATCH /api/v1/admin/tenants/TENANT_REAL/retention
Content-Type: application/json

{
  "alerts_retention_days": 30,
  "archives_retention_days": 90,
  "snapshot_enabled": true,
  "snapshot_repository": "repository-s3-wa01",
  "snapshot_interval_hours": 6,
  "snapshot_retention_days": 90,
  "reason": "Activación autorizada tras verificar el repositorio S3"
}
~~~

Validación de lectura en Dev Tools del Indexer:

~~~http
GET /_plugins/_sm/policies/soc-TENANT_REAL-alerts-snapshots
GET /_plugins/_sm/policies/soc-TENANT_REAL-archives-snapshots
GET /_plugins/_sm/policies/soc-TENANT_REAL-alerts-snapshots/_explain
GET /_plugins/_sm/policies/soc-TENANT_REAL-archives-snapshots/_explain
~~~

> **Consideración — migración y conservación:** al reconciliar se verifica la propiedad
> de las políticas antes de escribir. Las dos políticas de familia deben superar su
> verificación antes de deshabilitar la política mixta `soc-<tenant_id>-snapshots`.
> Sus snapshots anteriores **no se borran ni se copian**. Al desactivar snapshots se
> detienen las políticas gestionadas; su limpieza programada también se detiene. La
> eliminación futura de copias antiguas requiere una política/operación aprobada aparte.
> Ante fallo, el agente intenta restaurar las definiciones modificadas y retirar solo
> las definiciones recién creadas, nunca los snapshots; un rollback incompleto se informa
> como error y debe investigarse. Cambiar el repositorio no migra las copias del anterior.

La reconciliación no equivale a ejecutar un snapshot inmediato. Revisar `_explain`, el
estado `SUCCESS`, el alcance y una restauración de prueba después del horario programado.
No habilitar snapshots para todos los tenants automáticamente al registrar un repositorio,
no editar PostgreSQL directamente y no usar patrones `*` de clúster para resolver este
problema. Dimensionar la carga de dos políticas por tenant antes de un despliegue masivo.
[API oficial SM: actualización, estado y seguimiento](https://docs.opensearch.org/2.19/tuning-your-cluster/availability-and-recovery/snapshots/sm-api/).

Operación y aceptación del respaldo:

- Alertar por fallo, resultado parcial, incumplimiento de RPO, aumento de duración,
  falta de espacio, vencimiento de claves y fallo del repositorio en cualquier nodo.
- Si el respaldo requerido falla, **suspender la retirada de índices** y escalar; un cron
  periódico independiente no garantiza copia válida antes de un borrado ISM.
- Eliminar snapshots únicamente mediante OpenSearch/SM y la política aprobada; no `aws s3 rm`,
  borrado manual ni Lifecycle de objetos actuales del repositorio.
- Auditar llamadas de repositorio/snapshot/restore y operaciones S3 sin registrar secretos;
  conservar aprobaciones, UTC, operador, tenant/familia, estado y evidencia de restauración.
- Rotar claves con copia protegida del keystore, distribución a los tres nodos, activación
  rolling y `_verify`; revocar las antiguas solo tras probar la nueva identidad. No asumir
  que añadir una clave al vault actualiza automáticamente el keystore del Indexer.
- Ensayar restauración periódica —como mínimo la revisión trimestral definida para el
  proyecto— y antes de aceptar una actualización de Indexer/plugin. Respaldar separadamente
  configuraciones Wazuh, certificados, keystores, configuración Security, PostgreSQL y evidencias.
  [Respaldo de componentes Wazuh](https://documentation.wazuh.com/current/migration-guide/creating/wazuh-central-components.html).

#### 7.11.7. S3 compatible y diagnóstico

Si se elige MinIO u otro S3 compatible, aprobar primero endpoint, versión, disponibilidad,
cifrado, retención y restauración con el plugin instalado. **No asumir compatibilidad por
exponer una API S3 ni usar el MinIO local `.117` como único respaldo de producción.**

- Mantener nombre de cliente y entradas del keystore; usar otra identidad/bucket dedicado,
  no credenciales root ni las del almacenamiento de evidencias.
- En el JSON de registro reemplazar `endpoint` por el FQDN/puerto TLS real, `region` por
  la región de firma del proveedor y agregar `path_style_access: true` si lo exige.
  Ajustar `canned_acl` a lo admitido por ese proveedor; no trasladar sin prueba la opción
  AWS de propiedad del bucket. No incluir una ruta de consola web en `endpoint`.
- Verificar DNS y SAN desde los tres nodos; la JVM incluida también debe confiar en la CA.
  Con una CA privada, configurar su confianza mediante un procedimiento aprobado para
  ese JDK y conservar la configuración tras upgrades. Que curl confíe en la CA no prueba
  que Java confíe; nunca resolverlo con HTTP o verificación TLS deshabilitada.
- En un proveedor no EC2, si hay intentos de consultar metadatos AWS, añadir
  `Environment=AWS_EC2_METADATA_DISABLED=true` en un drop-in `[Service]` propio de
  `wazuh-indexer.service`; no basta exportarlo en una sesión SSH. Ejecutar daemon-reload
  y reinicio rolling. Si existe proxy de egreso, configurar los parámetros `s3.client.wa01snapshots.proxy.*`
  correspondientes, con usuario/contraseña en keystore; no asumir que `HTTPS_PROXY` de la
  shell configura el servicio Java.
  [Configuración del cliente S3](https://github.com/opensearch-project/OpenSearch/blob/2.19/plugins/repository-s3/src/main/java/org/opensearch/repositories/s3/S3ClientSettings.java),
  [metadatos y configuración S3](https://docs.opensearch.org/2.19/tuning-your-cluster/availability-and-recovery/snapshots/snapshot-restore/#amazon-s3).
- Repetir `_verify`, snapshot y restauración antes de habilitar calendarios o borrado.

| Error | Comprobación segura |
|---|---|
| `repository type [s3] does not exist` | Plugin instalado y cargado tras reinicio en los tres nodos; misma versión OpenSearch |
| `_verify` devuelve menos de tres nodos | Credenciales, CA Java, salida/DNS, plugin y estado del nodo ausente |
| S3 `403 AccessDenied` | IAM, bucket policy, prefijo real, KMS, SCP y origen permitido; no cambiar a permisos `*` |
| `AccessControlListNotSupported` | Propiedad/ACL del bucket y encabezado enviado; no habilitar ACLs públicas |
| `SignatureDoesNotMatch` o `AuthorizationHeaderMalformed` | Región, endpoint, NTP y pareja de claves; no mostrar valores |
| `PKIX`, SAN o handshake TLS | Confianza de la JVM y nombre del endpoint; no desactivar TLS |
| Snapshot `FAILED`/`PARTIAL` o restore incompatible | Detalle de fallos, salud/recuperación, capacidad y versión real del Indexer |

Conservar las respuestas sanitizadas y revisar `journalctl -u wazuh-indexer` en el nodo
afectado. Para rollback de esta preparación, detener únicamente ese nodo, restaurar su
keystore/configuración desde la copia exacta de 7.11.3 y reiniciarlo; no retirar un plugin
usado por repositorios activos ni borrar sus objetos. Repetir salud y verificación antes
de continuar; cambios de bucket/políticas IAM requieren su reversión aprobada aparte.

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

<code>https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.162</code>

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
install -d -m 0700 /root/soc-operations-0.1.162-download
cd /root/soc-operations-0.1.162-download

curl --fail --location --proto '=https' --tlsv1.2 \
  --output SHA256SUMS \
  'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.162/SHA256SUMS'

curl --fail --location --proto '=https' --tlsv1.2 \
  --output soc-operations-0.1.162.tar.gz.age \
  'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.162/soc-operations-0.1.162.tar.gz.age'
~~~

Verificar primero el manifiesto descargado y después el activo cifrado contra las huellas fijadas
en esta guía:

~~~bash
printf '%s  %s\n' \
  'af304e55d04305275c92cfb7d6c662cafb3dbe7e96fe00b9726f770de3f147f9' \
  'SHA256SUMS' | sha256sum --check --strict -

printf '%s  %s\n' \
  'f172e1144ade8ac9919b6817ce98821c145d1cfdb8767279a52279f8e64c5635' \
  'soc-operations-0.1.162.tar.gz.age' | sha256sum --check --strict -
~~~

Descifrar con la identidad temporal, verificar el TAR y extraerlo. Después de comprobar los
hashes, retirar la copia temporal de la clave; la identidad original permanece en el Vault:

~~~bash
age --decrypt \
  --identity "$SOC_AGE_IDENTITY" \
  --output soc-operations-release-0.1.162.tar.gz \
  soc-operations-0.1.162.tar.gz.age

printf '%s  %s\n' \
  '06515069e69478a31b45d979010516ba63f6b49d63094a7f1dd608535fbf9deb' \
  'soc-operations-release-0.1.162.tar.gz' | sha256sum --check --strict -

tar --extract --gzip --file soc-operations-release-0.1.162.tar.gz
cd release-0.1.162
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
cd /root/soc-operations-0.1.162-download
if [ -e /root/soc-operations-release-0.1.162 ]; then
  printf '%s\n' 'El destino ya existe: revisar y verificar el release anterior antes de continuar.' >&2
  exit 1
fi
mv -T -- release-0.1.162 /root/soc-operations-release-0.1.162
chmod 0700 /root/soc-operations-release-0.1.162
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
  /root/soc-operations-release-0.1.162/ \
  '<USUARIO_ADMIN>@192.168.4.117:/var/tmp/soc-operations-release-0.1.162/'
~~~

En <code>192.168.4.117</code>, copiar el directorio recibido a su ubicación definitiva. La
transferencia incluye solo el release; la identidad <code>age</code> ya se retiró del equipo de origen:

~~~bash
sudo install -d -o root -g root -m 0700 /root/soc-operations-release-0.1.162
sudo rsync --archive --chown=root:root \
  /var/tmp/soc-operations-release-0.1.162/ \
  /root/soc-operations-release-0.1.162/
~~~

<a id="alternativa-desde-windows"></a>

#### 9.4.3. Alternativa desde Windows

Windows se conserva únicamente como estación administrativa alternativa. Con <code>age</code>
instalado:

~~~powershell
$ReleaseDownload = Join-Path $env:USERPROFILE 'Downloads\soc-operations-0.1.162'
New-Item -ItemType Directory -Force -Path $ReleaseDownload | Out-Null
Set-Location $ReleaseDownload

curl.exe --fail --location --proto '=https' --tlsv1.2 --output SHA256SUMS 'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.162/SHA256SUMS'
curl.exe --fail --location --proto '=https' --tlsv1.2 --output soc-operations-0.1.162.tar.gz.age 'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.162/soc-operations-0.1.162.tar.gz.age'

$ExpectedManifest = 'af304e55d04305275c92cfb7d6c662cafb3dbe7e96fe00b9726f770de3f147f9'
$ActualManifest = (Get-FileHash -LiteralPath '.\SHA256SUMS' -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualManifest -ne $ExpectedManifest) { throw 'SHA-256 invalido para SHA256SUMS' }

$ExpectedEncrypted = 'f172e1144ade8ac9919b6817ce98821c145d1cfdb8767279a52279f8e64c5635'
$ActualEncrypted = (Get-FileHash -LiteralPath '.\soc-operations-0.1.162.tar.gz.age' -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualEncrypted -ne $ExpectedEncrypted) { throw 'SHA-256 invalido para el activo cifrado' }

age --decrypt --identity 'RUTA_SEGURA\identity.txt' --output 'soc-operations-release-0.1.162.tar.gz' 'soc-operations-0.1.162.tar.gz.age'

$ExpectedPlain = '06515069e69478a31b45d979010516ba63f6b49d63094a7f1dd608535fbf9deb'
$ActualPlain = (Get-FileHash -LiteralPath '.\soc-operations-release-0.1.162.tar.gz' -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualPlain -ne $ExpectedPlain) { throw 'SHA-256 invalido para el TAR descifrado' }

tar -xzf '.\soc-operations-release-0.1.162.tar.gz'
~~~

Transferir después <code>release-0.1.162</code> completo por el canal administrativo y ejecutar en
Ubuntu la verificación interna con <code>sha256sum --check --strict SHA256SUMS</code>. Dejar el
directorio en <code>/root/soc-operations-release-0.1.162</code>, como en la alternativa anterior.

<a id="verificar-el-release-e-instalar-el-comando"></a>

#### 9.4.4. Verificar el release e instalar el comando

En el servidor central <code>192.168.4.117</code>, ejecutar como root. Si llegas desde una de las
alternativas, abrir antes una sesión con <code>sudo -i</code>:

No copiar únicamente el ZIP del plugin: el instalador verifica el orquestador, helpers, wheel,
locks, unidades y plantillas mediante hashes fijos.

~~~bash
cd /root/soc-operations-release-0.1.162
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
  --staging-root /root/soc-operations-release-0.1.162
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
  --staging-root /root/soc-operations-release-0.1.162
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
release <code>0.1.162</code> según **Preparar el release fijo**. No modificar el paquete
anterior, las marcas de instalación ni los volúmenes de PostgreSQL, MinIO u OpenBao.

Instalar el orquestador del staging nuevo y repetir los comandos de preflight y apply de
esta guía con <code>--staging-root /root/soc-operations-release-0.1.162</code>.
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

El release <code>0.1.162</code> corrige las direcciones loopback fijas del helper del plugin:
usa el Indexer y los certificados declarados en la topología y la IP de servicio del Dashboard
para sus comprobaciones de salud. También corrige esas comprobaciones en runtime y status.

Si <code>0.1.153</code> se detuvo en <code>dashboard-plugin</code> con
<code>Failed to connect to 127.0.0.1 port 9200</code>, descargar y verificar el release
<code>0.1.162</code> siguiendo **Preparar el release fijo**. Conservar el directorio anterior y
los estados de <code>/var/lib/soc-operations-installer</code>: foundation ya aplicó cambios y
no es necesario borrar sus marcas ni volver a desplegar Wazuh.

Instalar el nuevo orquestador y repetir el preflight:

~~~bash
sudo install -o root -g root -m 0755 \
  /root/soc-operations-release-0.1.162/soc-operations-install \
  /usr/local/sbin/soc-operations-install
sudo /usr/local/sbin/soc-operations-install preflight \
  --topology-file /root/wa01-soc-topology.json \
  --service-address 192.168.4.117 \
  --staging-root /root/soc-operations-release-0.1.162
~~~

Después ejecutar el comando <code>apply</code> anterior, conservando exactamente el correo,
nombre y URL usados en el primer intento, y usando el staging <code>0.1.162</code>. El instalador
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

La corrección se distribuye en el release `0.1.162` de GitHub. Acepta únicamente Dashboard 4.14.7 y 4.14.8 y conserva la
comprobación de destinos, hashes, respaldo y rollback. Las pruebas locales de versiones
no sustituyen la validación de salud y visual en WA01.

Una vez recibido y verificado el release corregido, instalar su ejecutable:

~~~bash
sudo install -o root -g root -m 0755 \
  /root/soc-operations-release-0.1.162/soc-operations-install \
  /usr/local/sbin/soc-operations-install
~~~

Repetir el comando `apply` anterior con los mismos parámetros de identidad, topología
y publicación, sustituyendo únicamente `--staging-root` por
`/root/soc-operations-release-0.1.162`. No borrar los estados ni los volúmenes; el
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
`/root/soc-operations-release-0.1.162`. Esto actualiza los helpers y registra el nuevo staging
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
  SOC_STAGING_ROOT=/root/soc-operations-release-0.1.162 \
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

<a id="aprovisionamiento-rechazado-por-entorno"></a>

#### 9.13.1. Aprovisionamiento rechazado por entorno

El error `tenant provisioning agent rejected the operation: manifest targets another environment`
no es un fallo de red: el agente rechaza correctamente un manifiesto destinado a otro entorno.
En los instaladores hasta `0.1.159`, el helper de OpenBao fija `lab` para el worker incluso en
topología distribuida. Para WA01, worker y agente deben coincidir en **`production` / `wa01`**:

~~~bash
sudo grep -E '^SOC_PROVISIONING_(ENVIRONMENT|CLUSTER_ID)=' /etc/soc-operations-lab/runtime.env
sudo grep -E '^SOC_DEPLOY_(ENVIRONMENT|CLUSTER_ID)=' /etc/soc-deploy-agent/agent.env
sudo docker exec soc-operations-wa001-worker-1 python -c \
  'from soc_operations.config import get_settings; s=get_settings(); print("environment="+s.provisioning_environment); print("cluster_id="+s.provisioning_cluster_id)'
~~~

> **Corrección del instalador:** el release `0.1.162` deriva `production` para
> `distributed` y conserva `lab` para `aio`. `upgrade` y `resume` comprueban el worker aunque
> OpenBao figure como configurado. Solo recrean el worker cuando su destino efectivo difiere;
> no rotan tokens, no cambian el clúster, las aprobaciones ni la configuración del agente.
> Incluye la corrección preparada en `0.1.160`, que no se publicó por separado.

Después de disponer del staging **verificado** de `0.1.162` en el servidor `.117`, se puede
aplicar únicamente esta reparación con el helper corregido, sin reinstalar los servicios:

~~~bash
(
set -euo pipefail
SOC_TARGET_RELEASE='/root/soc-operations-release-0.1.162'
cd "$SOC_TARGET_RELEASE"
test -f soc-operations-install
test -f soc-lab-openbao-operator
sha256sum --check --strict SHA256SUMS
grep -Fqx 'readonly INSTALLER_VERSION="0.1.162"' soc-operations-install
sudo install -o root -g root -m 0755 \
  soc-lab-openbao-operator /usr/local/sbin/soc-lab-openbao-operator
sudo /usr/local/sbin/soc-lab-openbao-operator reconcile-provisioning-target
sudo docker exec soc-operations-wa001-worker-1 python -c \
  'from soc_operations.config import get_settings; s=get_settings(); print("environment="+s.provisioning_environment); print("cluster_id="+s.provisioning_cluster_id)'
)
~~~

El staging bajo `/root` requiere una sesión administrativa `sudo -i`; si se transfiere por
SSH con un usuario normal, recibir primero el release en su home y llevarlo al staging root
con `sudo`, como en el apartado 9.4. El helper no pide el token root de OpenBao para esta
reparación y detiene la operación si el clúster no coincide con la topología persistida.
Si falla la recreación/verificación, restaura `runtime.env` e intenta recuperar el worker previo.

Los jobs `pending` se vuelven a intentar cuando vence su espera; los nuevos intentos generan
y firman un manifiesto con el entorno corregido. El backoff llega a 60 minutos y tras ocho
intentos un job pasa a `failed`: no se reencola automáticamente con esta corrección. En ese
caso detenerse y preparar una recuperación autorizada y auditada, conservando las aprobaciones;
no editar SQL, recrear el tenant ni borrar su trazabilidad.
No cambiar `SOC_ENVIRONMENT`, no sustituir `wa01` por `wa001` por el nombre histórico del
proyecto Docker y no hacer que el agente de producción acepte `lab`.

<a id="activacion-api-externa-y-runtime-desactualizado"></a>

#### 9.13.2. Activación de API externa y contenedor desactualizado

> **Antes de ejecutar:** este procedimiento corresponde a `.117`, donde Manager, Dashboard,
> agente de despliegue y runtime SOC comparten servidor. Si el Manager está en otro servidor,
> no copiarle `runtime.env` ni habilitar control de un runtime remoto. Mantener whitelist,
> TLS y mTLS; no abrir puertos ni compartir API keys para resolver este problema.

En **Administración → Credenciales API**, el rol global `soc_engineering` puede activar o
desactivar la API externa confirmando su contraseña. Crear una credencial no activa el servicio.
El instalador conserva `SOC_EXTERNAL_API_ENABLED=false` por defecto. La clave exige además
alcances, tenants autorizados y vigencia; para `/manage/customers/list` se necesita `customers:read`.

En versiones anteriores, el helper podía dejar `SOC_DEPLOY_ALLOW_RUNTIME_CONFIGURATION=false`
por el simple hecho de que la topología fuera distribuida. La consulta de estado fallaba y
el botón quedaba deshabilitado. `0.1.162` detecta la instalación **local** de Manager y runtime,
valida propietario/permisos y el hash de Compose, y habilita su administración sin activar
implícitamente la API. Un Manager remoto sin runtime conserva el control deshabilitado.

Si se editó `runtime.env` sin recrear el contenedor, puede existir esta discrepancia:

~~~text
SOC_EXTERNAL_API_ENABLED=true
external_api_enabled=false
~~~

Un `docker restart` no recarga variables de entorno. La reparación usa el gestor transaccional
del agente instalado: conserva el valor persistido, recrea **solo** `external-api` cuando la
respuesta no coincide, comprueba HTTP 401/503 y restaura el estado anterior si falla.
No reinstala Wazuh, no cambia API keys y no ejecuta `compose down` ni elimina volúmenes.

**Instalación existente en WA01:** descargar, descifrar y verificar `0.1.162` con el apartado
9.4. Si la sesión SSH es de un usuario ordinario, recibir los archivos en su home y trasladarlos
al staging protegido mediante `sudo`; abrir después una sesión administrativa `sudo -i`.
No repetir `apply` ni inicializar de nuevo OpenBao para aplicar esta reparación puntual:

~~~bash
(
set -euo pipefail
SOC_TARGET_RELEASE='/root/soc-operations-release-0.1.162'
cd "$SOC_TARGET_RELEASE"
sha256sum --check --strict SHA256SUMS
grep -Fqx 'readonly INSTALLER_VERSION="0.1.162"' soc-operations-install
# Verifica los artefactos fijados, actualiza helpers y registra este staging.
# Respeta el estado true/false existente; no activa la API por sí mismo.
sudo bash ./soc-operations-install reconcile-external-api \
  --staging-root "$SOC_TARGET_RELEASE"
sudo /usr/local/sbin/soc-operations-install status
)
~~~

La reparación requiere que el paso `deployment-agent` esté completado. Solo reinicia ese agente
si cambió su permiso de administración; verifica su salud mTLS y recupera el archivo anterior
si el reinicio falla. `install`, `upgrade` y `resume` también reconcilian este estado, incluso
cuando el paso del agente estaba marcado como completado.

Comprobar sin imprimir secretos:

~~~bash
sudo grep '^SOC_EXTERNAL_API_ENABLED=' /etc/soc-operations-lab/runtime.env
sudo grep '^SOC_DEPLOY_ALLOW_RUNTIME_CONFIGURATION=' /etc/soc-deploy-agent/agent.env
sudo docker exec soc-operations-wa001-external-api-1 python -c \
  'from soc_operations.config import get_settings; print("external_api_enabled="+str(get_settings().external_api_enabled).lower())'
curl --silent --show-error --connect-timeout 5 --max-time 10 \
  --output /dev/null --write-out 'HTTP %{http_code}\n' \
  http://127.0.0.1:8091/manage/customers/list
~~~

- Archivo y contenedor deben mostrar el mismo valor.
- Con `true`, la prueba sin credencial debe responder **401**: API habilitada, autenticación requerida.
- Con `false`, debe responder **503**: desactivación deliberada; activar desde la interfaz si corresponde.
- `000` o una discrepancia persistente requieren diagnóstico; no se consideran una activación correcta.
- `/health/live` con 200 solo demuestra liveness, no habilitación ni validez de una API key.

Desde una fuente externa permitida, repetir la consulta autenticada a
`https://wa01-socops-api.kriptome.com/manage/customers/list`. Esperar 200 únicamente si la clave
es válida y tiene el alcance y los tenants requeridos. No pegarla en chats, tickets, URLs ni
registros. La reparación local no acredita automáticamente el funcionamiento de Cloudflare/HAProxy.

<a id="bloqueo-de-certificados"></a>

### 9.14. Bloqueo de certificados

El aprovisionador actual genera certificados mTLS del agente válidos por 30 días y no existe rotación automática documentada. Antes de producción se debe implementar y probar:

- Renovación sin interrupción.
- Alertas de vencimiento.
- Solapamiento controlado de certificados.
- Revocación y recuperación.
- Prueba incorporada a aceptación.

<a id="actualizar-soc-operations-sin-reinstalar-wa01"></a>

### 9.15. Actualizar SOC Operations sin reinstalar WA01

> **Antes de ejecutar:** este es un **upgrade de SOC Operations**, no una instalación
> limpia ni una actualización de Wazuh. Ejecutar en `.117`; no reinstalar `.118`/`.119`.
> Reservar una ventana de mantenimiento: el plugin requiere reiniciar Dashboard y se
> recrean API, external-api y worker. No se promete cero indisponibilidad. No ejecutar
> `apply`, `openbao-init`, `bootstrap-first-engineer`, `docker compose down --volumes`,
> `docker volume rm` ni el rollback global para actualizar una instalación ya terminada.

#### 9.15.1. Qué cambia y qué se conserva

- Instalador `0.1.162`; API/worker/agente `0.1.114`; plugin `0.1.94` para las dos parejas
  Wazuh/OSD admitidas. El árbol de migraciones coincide con el runtime anterior `0.1.113`:
  esta corrección no añade migraciones ni convierte datos de tenants.
- Se conservan PostgreSQL y sus volúmenes, tenants, miembros, casos, credenciales API,
  secretos de `runtime.env`, custodia OpenBao, TLS existente, evidencias, GeoIP y prefijos.
- `upgrade` reutiliza identidad, URL pública y topología persistidas. No solicita otra
  contraseña del primer ingeniero si su activación ya está completa.
- El agente local de `.117` se actualiza **antes** del runtime nuevo, incluso con topología
  distribuida; conserva las opciones adicionales y flags operativos de su `agent.env`.
  El marcador interno Nginx/agente se reconcilia como parte de esa actualización.
- Si el Manager/agente estuviera realmente en otro servidor, actualizar allí el agente
  con el mismo release verificado antes de `upgrade`. Un agente sin versión `0.1.114` y
  capacidad `tenant_snapshots_by_family_v1` hace que el upgrade se detenga antes del runtime.
- No se activan snapshots masivamente. Los jobs existentes pendientes pueden reintentarse
  cuando vuelva el worker; no se borran, se mantienen las aprobaciones. La nueva política
  se solicita por tenant mediante **Guardar y reconciliar**.

#### 9.15.2. Preparar un punto de recuperación actual

Conservar el release anterior y disponer de consola Proxmox. El snapshot tomado antes
de instalar SOC Operations no contiene los usuarios ni tenants creados después: realizar
un respaldo actual antes de esta ventana y mantener copia cifrada en custodia independiente.
No compartir los archivos siguientes: incluyen claves privadas y secretos.

Preparar y verificar el release `0.1.162` según la sección 9.4, sin ejecutar `apply`.
Abrir una sesión root controlada solo para estos bloques; el usuario SSH puede seguir
siendo `cmedina`:

~~~bash
sudo -i
~~~

En la sesión root, cerrar cambios operativos en la interfaz durante la ventana y ejecutar:

~~~bash
set -euo pipefail
umask 077
SOC_UPGRADE_BACKUP="/root/socops-upgrade-$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 0700 "$SOC_UPGRADE_BACKUP"
df -h /root /var/lib/docker
/usr/local/sbin/soc-operations-install status > "$SOC_UPGRADE_BACKUP/status-before.txt"
docker inspect --format '{{.Image}}' soc-operations-wa001-api-1 \
  > "$SOC_UPGRADE_BACKUP/api-image-before.txt"
readlink -f /opt/soc-deploy-agent/current > "$SOC_UPGRADE_BACKUP/agent-release-before.txt"
docker exec soc-operations-wa001-postgres-1 \
  pg_dump --username soc_operations_owner --dbname soc_operations --format=custom \
  > "$SOC_UPGRADE_BACKUP/postgresql.dump"
test -s "$SOC_UPGRADE_BACKUP/postgresql.dump"
docker exec -i soc-operations-wa001-postgres-1 pg_restore --list \
  < "$SOC_UPGRADE_BACKUP/postgresql.dump" > "$SOC_UPGRADE_BACKUP/postgresql-contents.txt"
tar --acls --xattrs --create --file "$SOC_UPGRADE_BACKUP/configuration.tar" --directory / \
  etc/soc-operations-lab etc/soc-deploy-agent etc/wazuh-dashboard \
  var/lib/soc-operations-installer var/lib/soc-deploy-agent-installer \
  opt/soc-operations-lab/docker-compose.yml
sha256sum "$SOC_UPGRADE_BACKUP/postgresql.dump" "$SOC_UPGRADE_BACKUP/configuration.tar" \
  > "$SOC_UPGRADE_BACKUP/SHA256SUMS"
printf 'Punto de recuperación: %s\n' "$SOC_UPGRADE_BACKUP"
~~~

`pg_restore --list` confirma legibilidad, no una restauración probada. Confirmar también
un respaldo vigente de evidencias/S3 y de OpenBao según custodia; `configuration.tar`
no contiene los datos del volumen Raft. No respaldar una base activa copiando directamente
el directorio Docker. Guardar un snapshot coordinado de las VMs si se usará como recuperación
del conjunto, sin revertir un nodo Indexer aislado que ya pertenezca a un clúster activo.

#### 9.15.3. Verificar y ejecutar upgrade

En la misma sesión root:

~~~bash
SOC_NEW_RELEASE='/root/soc-operations-release-0.1.162'
cd "$SOC_NEW_RELEASE"
sha256sum --check --strict SHA256SUMS
test "$(find . -maxdepth 1 -type f | wc -l)" -eq 49
bash ./soc-operations-install preflight --staging-root "$SOC_NEW_RELEASE"
docker compose --project-name soc-operations-wa001 \
  --env-file /etc/soc-operations-lab/runtime.env \
  --file /opt/soc-operations-lab/docker-compose.yml stop worker
bash ./soc-operations-install upgrade --staging-root "$SOC_NEW_RELEASE"
/usr/local/sbin/soc-operations-install status
~~~

El comando carga las rutas y la topología guardadas; no volver a declarar la topología AIO
ni cambiar `deployment_id=wa01`. Verificar que continúa `topology=distributed`,
`installer_version=0.1.162`, `phase=complete`, Dashboard 200/302 y API live/ready 200.
El proyecto Compose conserva el nombre histórico `soc-operations-wa001`.

#### 9.15.4. Controles antes de terminar la ventana

~~~bash
docker exec soc-operations-wa001-api-1 python -c \
  'from importlib.metadata import version; print(version("soc-operations"))'
docker exec soc-operations-wa001-worker-1 python -c \
  'from importlib.metadata import version; print(version("soc-operations"))'
/opt/soc-deploy-agent/current/venv/bin/python -I -c \
  'from importlib.metadata import version; print(version("soc-operations"))'
sudo -u wazuh-dashboard /usr/share/wazuh-dashboard/bin/opensearch-dashboards-plugin list \
  | grep '^socOperations@'
curl --fail-with-body --silent --show-error http://127.0.0.1:8080/health/ready
docker compose --project-name soc-operations-wa001 \
  --env-file /etc/soc-operations-lab/runtime.env \
  --file /opt/soc-operations-lab/docker-compose.yml ps
~~~

- Esperar `0.1.114` en API, worker y agente; `socOperations@0.1.94` en Dashboard.
- Comparar el estado de habilitación de API externa con la sección 9.13.2: conserva
  el valor anterior, no fuerza `true`. Confirmar login del ingeniero y de una cuenta tenant.
- Confirmar que los tenants, miembros, casos y credenciales existentes siguen disponibles.
- Recargar el navegador, abrir un tenant creado **sin** snapshots y ejecutar el flujo 7.11.6.1.
  Deben existir ambas políticas, coincidir repositorio/patrón y terminar el job SM.
- Revisar `_explain`, el siguiente snapshot `SUCCESS` y una restauración de prueba antes
  de dar por aceptado el respaldo. No modificar todos los tenants para probar el release.

#### 9.15.5. Si el upgrade falla

Detenerse en el primer error; no borrar directorios, estados, volúmenes ni material TLS.
Conservar el release anterior y las rutas de backup impresas por los helpers. El plugin
y el agente intentan restaurar su componente anterior si falla su health check; esto
**no es una transacción global** que garantice revertir todos los pasos del upgrade.

Si el runtime nuevo no está sano, mantener suspendido el worker durante el diagnóstico:

~~~bash
docker compose --project-name soc-operations-wa001 \
  --env-file /etc/soc-operations-lab/runtime.env \
  --file /opt/soc-operations-lab/docker-compose.yml stop worker
/usr/local/sbin/soc-operations-install status
docker logs --tail 100 soc-operations-wa001-api-1
journalctl -u soc-deploy-agent.service --since '-15 minutes' --no-pager
~~~

Sanitizar logs antes de compartirlos. Repetir `upgrade` con el **mismo staging verificado**
solo después de resolver la causa. No usar `resume` como sustituto del upgrade de todos los
artefactos: sus pasos completados pueden saltarse la actualización del agente remoto.
Para volver a la versión anterior, revisar qué componente cambió y restaurar sus backups/
artefactos aprobados; no ejecutar un downgrade global ni restaurar el dump sobre producción
a ciegas. Si ya se reconciliaron políticas SM, inventariarlas antes del rollback: siguen
en OpenSearch aunque se restaure la API. Los snapshots existentes nunca se eliminan como
parte de esta corrección. Usar el punto de recuperación completo solo con parada y
procedimiento de restauración aprobado.

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
plantilla: comprobar `/root/soc-operations-release-0.1.162/manager.env.example`.

> [!IMPORTANT]
> **Para GeoIP, usar los helpers corregidos 0.1.159 incluidos en el release 0.1.162.** El staging indicado abajo corresponde
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
SOC_GEOIP_RELEASE='/root/soc-operations-release-0.1.162'
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
SOC_GEOIP_RELEASE='/root/soc-operations-release-0.1.162'
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
[la referencia GeoIP del proyecto](https://github.com/devsecops-kriptome/soc-operations-installer/blob/main/docs/maxmind-geoip.md). Sus ejemplos se escribieron
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
- Heap efectivo por rol, `mlockall=true`, límites systemd/sysctl y reinicios rolling validados
  según el apartado 7.9, sin modificar roles ni perder quorum.
- Si se eleva el límite de shards, presupuesto y capacidad aprobados, valor efectivo verificado,
  respaldo/rollback documentados y observación de ingestión/recuperación según 7.10.

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
- Worker y agente coinciden en `production` / `wa01`; el agente rechaza un manifiesto `lab`
  o de otro clúster y el aprovisionamiento válido completa sus jobs con trazabilidad.
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
- Repositorio `repository-s3-wa01` verificado en los tres nodos, S3 independiente de `.117`,
  cifrado/permisos comprobados y piloto `SUCCESS` restaurado con nombre temporal según 7.11.
- Allowlists, programación/retención UTC y alertas de backup aprobadas por tenant/familia;
  `.opendistro_security` y estado global excluidos, sin borrado externo de blobs.
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
- Repositorio/bucket/base_path, identidad S3 sin secretos, políticas sanitizadas, resultado
  `_verify`, snapshot/UUID, índices, conteos y tiempos de restauración del apartado 7.11.
- Ticket, aprobaciones, operador, hora y rollback.

<a id="pendientes-previos-a-producción"></a>

## 13. Pendientes previos a producción

- Definir <code>ADMIN_CIDR</code> y <code>SSH_PORT</code>.
- Confirmar SAN antes de configurar <code>verifyhost</code>.
- Proporcionar una dirección interna estable para Indexer.
- Automatizar rotación mTLS de SOC Operations.
- Dimensionar con EPS, agentes y retención reales.
- Aprobar bucket/endpoint/región, identidad S3, RPO/RTO del Indexer y retención por familia;
  completar snapshot/restore y políticas automáticas del apartado 7.11 antes de borrar índices.
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
- GeoIP del proyecto: [guía GeoIP publicada](https://github.com/devsecops-kriptome/soc-operations-installer/blob/main/docs/maxmind-geoip.md).
- Snapshots S3, permisos y restauración: referencias oficiales enlazadas en el apartado 7.11.
- Compatibilidad: [matriz publicada](https://github.com/devsecops-kriptome/soc-operations-installer/blob/main/docs/compatibility.md).
- Aceptación: <code>docs/acceptance.md</code>
