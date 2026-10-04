# Instalación distribuida WA01 con Wazuh 4.14.8 y SOC Operations

> Estado: guía de preparación y despliegue para producción.
> Revisión: 2026-10-03.
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

Si los certificados no incluyen IP como SAN, usar sus FQDN internos. No degradar permanentemente TLS. La configuración Wazuh del Dashboard debe usar la API local:

~~~yaml
hosts:
  - default:
      url: https://127.0.0.1
      port: 55000
      run_as: true
~~~

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
<code>root:root</code> y modo <code>0600</code>. El release <code>0.1.153</code> valida
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

<code>https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.153</code>

La identidad privada <code>age</code> se obtiene exclusivamente del gestor de secretos autorizado,
entrada <strong>SOC Operations Installer Descifrado</strong>. No copiarla a GitHub, la guía, el
servidor Wazuh, chats o tickets.

#### Preparación principal desde Ubuntu

Realizar la descarga y el descifrado en un host administrativo Ubuntu protegido, preferentemente
el bastión de despliegue y no el servidor Wazuh. Instalar las herramientas necesarias:

~~~bash
sudo apt-get update
sudo apt-get install --yes age curl rsync
~~~

Crear la carpeta privada de la identidad en el host administrativo Ubuntu. Este bloque crea
<code>identity.txt</code> vacío solo si no existe, conservando una identidad previamente guardada:

~~~bash
umask 077
SOC_AGE_DIR="$HOME/.config/soc-operations/age"
SOC_AGE_IDENTITY="$SOC_AGE_DIR/identity.txt"
install -d -m 0700 "$SOC_AGE_DIR"
if [ ! -e "$SOC_AGE_IDENTITY" ]; then
  install -m 0600 /dev/null "$SOC_AGE_IDENTITY"
fi
chmod 0600 "$SOC_AGE_IDENTITY"
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
la carpeta y <code>600</code> para el archivo, propiedad del usuario administrativo. Continuar
en la misma sesión Bash para conservar <code>SOC_AGE_IDENTITY</code>; si se abre otra sesión,
volver a definir la ruta antes del descifrado.

Crear un directorio privado separado y descargar el manifiesto y el activo cifrado:

~~~bash
umask 077
install -d -m 0700 soc-operations-0.1.153-download
cd soc-operations-0.1.153-download

curl --fail --location --proto '=https' --tlsv1.2 \
  --output SHA256SUMS \
  'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.153/SHA256SUMS'

curl --fail --location --proto '=https' --tlsv1.2 \
  --output soc-operations-0.1.153.tar.gz.age \
  'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.153/soc-operations-0.1.153.tar.gz.age'
~~~

Verificar primero el manifiesto descargado y después el activo cifrado contra las huellas fijadas
en esta guía:

~~~bash
printf '%s  %s\n' \
  '9e4cda7907fe538cce9c3d6aac8e8ea1a1e54ca8b902c1f1fbcdef141a460276' \
  'SHA256SUMS' | sha256sum --check --strict -

printf '%s  %s\n' \
  '6b6e18e16948f7a7cd0d60cb66460c8d64417e5dd518e6a3c2e7a89f9f1f4976' \
  'soc-operations-0.1.153.tar.gz.age' | sha256sum --check --strict -
~~~

Descifrar indicando la ruta de la identidad protegida. No copiar esa identidad dentro del
directorio de descarga ni transferirla al servidor Wazuh:

~~~bash
age --decrypt \
  --identity "$SOC_AGE_IDENTITY" \
  --output soc-operations-release-0.1.153.tar.gz \
  soc-operations-0.1.153.tar.gz.age

printf '%s  %s\n' \
  'bd27d296ff15f0c686421fbe7ef074c9120927051705f84b0aae32aed96b0326' \
  'soc-operations-release-0.1.153.tar.gz' | sha256sum --check --strict -

tar --extract --gzip --file soc-operations-release-0.1.153.tar.gz
cd release-0.1.153
sha256sum --check --strict SHA256SUMS
test "$(find . -type f | wc -l)" -eq 42
~~~

Los 41 elementos del manifiesto deben indicar <code>OK</code>. El directorio contiene 42 archivos
contando el propio manifiesto. No continuar ante un hash incorrecto o un número de archivos
distinto.

Transferir el directorio completo al servidor central mediante la red administrativa. Sustituir
<code>&lt;USUARIO_ADMIN&gt;</code> por la cuenta SSH autorizada, que debe poder elevar privilegios de
forma controlada:

~~~bash
cd ..
rsync --archive --protect-args \
  release-0.1.153/ \
  '<USUARIO_ADMIN>@192.168.4.117:/var/tmp/soc-operations-release-0.1.153/'
~~~

En <code>192.168.4.117</code>, mover la copia validada a su ubicación definitiva sin transferir la
identidad <code>age</code>:

~~~bash
sudo install -d -o root -g root -m 0700 /root/soc-operations-release-0.1.153
sudo rsync --archive --chown=root:root \
  /var/tmp/soc-operations-release-0.1.153/ \
  /root/soc-operations-release-0.1.153/
~~~

#### Alternativa desde Windows

Windows se conserva únicamente como estación administrativa alternativa. Con <code>age</code>
instalado:

~~~powershell
$ReleaseDownload = Join-Path $env:USERPROFILE 'Downloads\soc-operations-0.1.153'
New-Item -ItemType Directory -Force -Path $ReleaseDownload | Out-Null
Set-Location $ReleaseDownload

curl.exe --fail --location --proto '=https' --tlsv1.2 --output SHA256SUMS 'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.153/SHA256SUMS'
curl.exe --fail --location --proto '=https' --tlsv1.2 --output soc-operations-0.1.153.tar.gz.age 'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.153/soc-operations-0.1.153.tar.gz.age'

$ExpectedManifest = '9e4cda7907fe538cce9c3d6aac8e8ea1a1e54ca8b902c1f1fbcdef141a460276'
$ActualManifest = (Get-FileHash -LiteralPath '.\SHA256SUMS' -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualManifest -ne $ExpectedManifest) { throw 'SHA-256 invalido para SHA256SUMS' }

$ExpectedEncrypted = '6b6e18e16948f7a7cd0d60cb66460c8d64417e5dd518e6a3c2e7a89f9f1f4976'
$ActualEncrypted = (Get-FileHash -LiteralPath '.\soc-operations-0.1.153.tar.gz.age' -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualEncrypted -ne $ExpectedEncrypted) { throw 'SHA-256 invalido para el activo cifrado' }

age --decrypt --identity 'RUTA_SEGURA\identity.txt' --output 'soc-operations-release-0.1.153.tar.gz' 'soc-operations-0.1.153.tar.gz.age'

$ExpectedPlain = 'bd27d296ff15f0c686421fbe7ef074c9120927051705f84b0aae32aed96b0326'
$ActualPlain = (Get-FileHash -LiteralPath '.\soc-operations-release-0.1.153.tar.gz' -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualPlain -ne $ExpectedPlain) { throw 'SHA-256 invalido para el TAR descifrado' }

tar -xzf '.\soc-operations-release-0.1.153.tar.gz'
~~~

Transferir después <code>release-0.1.153</code> completo por el canal administrativo y ejecutar en
Ubuntu la verificación interna con <code>sha256sum --check --strict SHA256SUMS</code>.

No copiar únicamente el ZIP del plugin: el instalador verifica el orquestador, helpers, wheel,
locks, unidades y plantillas mediante hashes fijos.

~~~bash
cd /root/soc-operations-release-0.1.153
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

### Preflight sin cambios

Ejecutar primero solo:

~~~bash
sudo /usr/local/sbin/soc-operations-install preflight \
  --topology-file /root/wa01-soc-topology.json \
  --service-address 192.168.4.117 \
  --staging-root /root/soc-operations-release-0.1.153
~~~

El resultado debe identificar <code>topology=distributed</code>, Wazuh
<code>4.14.8-1</code> y OpenSearch Dashboards <code>2.19.6</code>. El preflight verifica
plataforma, credenciales administrativas, número exacto de nodos y hashes, pero no instala el
producto. Conservar su salida y no ejecutar <code>apply</code> hasta resolver cualquier error.

El agente privilegiado se instala en <code>.117</code>:

~~~text
SOC_DEPLOYMENT_ID=wa01
SOC_AIO_SERVICE_ADDRESS=192.168.4.117
SOC_EXTERNAL_API_PROXY_CIDR=127.0.0.1/32
SOC_WAZUH_TOPOLOGY=distributed
SOC_EXPECTED_WAZUH_VERSION=4.14.8-1
SOC_WAZUH_VERSION=4.14.8
SOC_DEPLOYMENT_AGENT_URL=https://wa01-dashboard.corp.atg:8443
SOC_INDEXER_URL=https://192.168.4.118:9200
SOC_INDEXER_TLS_SERVER_NAME=192.168.4.118
SOC_INDEXER_ADMIN_CERT=/etc/wazuh-indexer/certs/admin.pem
SOC_INDEXER_ADMIN_KEY=/etc/wazuh-indexer/certs/admin-key.pem
SOC_INDEXER_CA_BUNDLE=/etc/wazuh-indexer/certs/root-ca.pem
SOC_WAZUH_API_CONFIG=/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml
SOC_WAZUH_API_CA_BUNDLE=/var/ossec/api/configuration/ssl/server.crt
~~~

El nombre TLS debe coincidir con un SAN. Copiar el bundle cliente a las rutas protegidas de la topología.

### UFW y contenedores

El instalador no modifica UFW. Después de crear la red:

~~~bash
docker network inspect soc-operations_frontend
~~~

El valor previsto es <code>172.19.0.0/16</code>, gateway <code>172.19.0.1</code>, pero se deben usar los valores reales:

~~~bash
sudo ufw allow in on SOC_BRIDGE from SOC_SUBNET to SOC_GATEWAY port 8443 proto tcp \
  comment 'SOC Operations bridge to deploy agent'
~~~

No abrir 8443 en la LAN.

Docker administra reglas de netfilter y, según la plataforma, puede evitar parte del filtrado
esperado por UFW. Verificar además la cadena <code>DOCKER-USER</code>, el binding real de los
puertos publicados y una prueba desde la LAN. La condición de aceptación es que 8443 solo sea
alcanzable desde el bridge autorizado.

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

~~~bash
sudo apt-get install -y geoipupdate curl jq openssl
sudo install -d -m 0750 /etc/soc-geoip-manager
sudo install -m 0640 deploy/geoip/manager.env.example /etc/soc-geoip-manager/manager.env
sudo install -m 0600 /dev/null /etc/soc-geoip-manager/GeoIP.conf
~~~

Configurar:

~~~text
SOC_GEOIP_MANAGER_LISTEN_IP=192.168.4.117
SOC_GEOIP_MANAGER_LISTEN_PORT=8444
SOC_GEOIP_MANAGER_SERVER_NAME=wa01-dashboard.corp.atg
SOC_GEOIP_MANAGER_MAXMIND_CONFIG=/etc/soc-geoip-manager/GeoIP.conf
SOC_GEOIP_MANAGER_KEEP_RELEASES=4
~~~

En <code>GeoIP.conf</code> agregar las credenciales de MaxMind y:

~~~text
EditionIDs GeoLite2-City GeoLite2-Country GeoLite2-ASN
~~~

Mantenerlo <code>root:root 0600</code>; nunca guardar la licencia en Git o evidencia.

~~~bash
sudo soc-geoip-manager preflight
sudo soc-geoip-manager install
sudo soc-geoip-manager update
sudo soc-geoip-manager issue-client wa01-indexer01 /root/geoip-wa01-indexer01
sudo soc-geoip-manager issue-client wa01-indexer02 /root/geoip-wa01-indexer02
sudo soc-geoip-manager status
~~~

Transferir cada bundle solo a su nodo y eliminar las copias temporales.

### Workers en 192.168.4.118 y 192.168.4.119

~~~bash
sudo install -d -m 0750 /etc/soc-geoip-indexer
sudo install -m 0640 deploy/geoip/indexer.env.example /etc/soc-geoip-indexer/indexer.env
~~~

Base para cada nodo:

~~~text
SOC_GEOIP_SOURCE_URL=https://wa01-dashboard.corp.atg:8444
SOC_GEOIP_SOURCE_SERVER_NAME=wa01-dashboard.corp.atg
SOC_GEOIP_SELF_INDEXER_URL=https://127.0.0.1:9200
SOC_GEOIP_EXPECTED_NODES=3
SOC_GEOIP_AUTO_ACTIVATE=false
~~~

Configurar las rutas a CA del distribuidor, certificado y clave cliente propios, CA del Indexer, certificado administrativo y clave administrativa. Claves y entorno deben ser 0600.

~~~bash
sudo soc-geoip-indexer preflight
sudo soc-geoip-indexer install
sudo soc-geoip-indexer sync
sudo soc-geoip-indexer status
~~~

Activar primero en Indexer 1:

~~~bash
sudo soc-geoip-indexer activate
sudo soc-geoip-indexer status
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
