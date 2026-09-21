# Despliegue completo de MaxMind GeoIP centralizado

## 1. Alcance y estado en SOC Operations 0.1.152

Este procedimiento comienza después de instalar Wazuh 4.14.7 y SOC Operations. Funciona en:

- AIO: Dashboard, Manager e Indexer en el mismo servidor;
- distribuido: un Manager principal y uno o varios Wazuh Indexer del mismo clúster.

La integración MaxMind es opcional y todavía no se configura desde la pantalla Administración de
SOC Operations. En `0.1.152` se administra con archivos `root-only` y servicios systemd. No guarde
la cuenta o la licencia en Git, variables de shell persistentes, historial o PostgreSQL.

Si utiliza esta guía como documento independiente, el release debe haberse verificado y
descifrado previamente con la identidad `age` del gestor de secretos autorizado, entrada
`SOC Operations Installer Descifrado`, siguiendo la [instalación AIO](installation.md). Esa
identidad no es la licencia MaxMind y nunca debe distribuirse a los Indexer.

El Manager principal descarga una sola vez:

```text
GeoLite2-City.mmdb
GeoLite2-Country.mmdb
GeoLite2-ASN.mmdb
```

La cuenta y `LicenseKey` permanecen únicamente en el Manager. Cada Indexer con rol `ingest` usa
un certificado mTLS individual para descargar los mismos archivos y su manifiesto SHA-256. La
ruta activa sigue siendo la estándar:

```text
/usr/share/wazuh-indexer/modules/ingest-geoip/
```

No se modifica el pipeline de Wazuh. OpenSearch carga estas bases al iniciar el Indexer; por eso
la sincronización no equivale a activación y un clúster distribuido exige reinicio rolling.

## 2. Orden de una instalación desde cero

Complete las etapas en este orden:

1. instale Wazuh 4.14.7 y confirme que Dashboard, Manager e Indexer están sanos;
2. instale SOC Operations siguiendo la guía [AIO](installation.md) o
   [distribuida](distributed-installation.md);
3. configure firewall y resolución DNS;
4. instale el distribuidor GeoIP en el Manager principal;
5. genere una identidad mTLS diferente para cada Indexer `ingest`;
6. instale el worker en todos los Indexer `ingest`, sin activar todavía;
7. registre la línea base, haga backup y ejecute `_simulate`;
8. active primero un nodo canario;
9. espere a que el clúster vuelva a verde y continúe nodo por nodo;
10. compare hashes, repita `_simulate` y valide un evento nuevo.

No continúe con GeoIP si la instalación principal de SOC Operations permanece en una fase
pendiente o si el clúster Indexer no tiene todos sus nodos.

## 3. Inventario previo

Desde Dashboard > Dev Tools:

```http
GET /_cluster/health
GET /_cat/nodes?v&h=name,ip,node.role,master
GET /_nodes/ingest?filter_path=nodes.*.name,nodes.*.roles,nodes.*.ingest.processors
GET /_ingest/pipeline/filebeat-7.10.2-wazuh-alerts-pipeline
```

Anote todos los nodos con rol `ingest`. El worker se instala solo en esos nodos. No lo instale en
un nodo exclusivamente `cluster_manager`.

En cada Indexer `ingest` confirme versión, módulo, JAR y bases originales:

```bash
dpkg-query -W wazuh-indexer
systemctl is-active wazuh-indexer
sudo find /usr/share/wazuh-indexer/modules/ingest-geoip -maxdepth 1 \
  -type f \( -name '*.mmdb' -o -name 'maxmind-db-*.jar' \) \
  -printf '%u:%g %m %s %f\n' | sort
sudo sha256sum /usr/share/wazuh-indexer/modules/ingest-geoip/*.mmdb
```

La versión esperada es `4.14.7-1`. Deben existir las tres bases y al menos un
`maxmind-db-*.jar`. El worker se detiene si no puede garantizar el rollback durante la activación.

## 4. Red, DNS y puertos

El Manager necesita salida HTTPS hacia MaxMind. Cada Indexer `ingest` necesita llegar al Manager
por `8444/tcp`. Los Indexer no necesitan salida directa a MaxMind.

| Origen | Destino | Puerto | Uso |
| --- | --- | --- | --- |
| Manager principal | MaxMind | `443/TCP` | Descargar GeoLite2 |
| Cada Indexer `ingest` | Manager principal | `8444/TCP` | Descargar bases mediante mTLS |
| Operador/worker | Clúster Indexer | `9200/TCP` | Salud y validación |

Autorice `8444` exclusivamente desde las IP de los Indexer `ingest`. Ejemplo UFW en el Manager:

```bash
sudo ufw allow from IP_INDEXER_01 to IP_MANAGER port 8444 proto tcp \
  comment 'GeoIP mTLS indexer-01'
sudo ufw allow from IP_INDEXER_02 to IP_MANAGER port 8444 proto tcp \
  comment 'GeoIP mTLS indexer-02'
```

En AIO utilice la IP de servicio del servidor, no `127.0.0.1`, porque el certificado del
distribuidor se genera para la IP y el DNS declarados.

## 5. Preparar el Manager principal

Entre al directorio extraído del release `0.1.152` e instale dependencias. En Ubuntu 24.04:

```bash
cd "$HOME/soc-installer/release-0.1.152"
sudo apt-get update
sudo apt-get install -y geoipupdate libmaxminddb-bin nginx openssl util-linux
```

### 5.1 Credenciales MaxMind

Instale la plantilla y edítela sin pasar secretos por la línea de comandos:

```bash
sudo install -d -o root -g root -m 0700 /etc/soc-geoip-manager
sudo install -o root -g root -m 0600 ./GeoIP.conf.example \
  /etc/soc-geoip-manager/GeoIP.conf
sudoedit /etc/soc-geoip-manager/GeoIP.conf
```

Contenido esperado:

```text
AccountID REEMPLAZAR_ACCOUNT_ID
LicenseKey REEMPLAZAR_LICENSE_KEY
EditionIDs GeoLite2-City GeoLite2-Country GeoLite2-ASN
```

Compruebe únicamente propietario y modo; no imprima el contenido en registros:

```bash
sudo stat -c '%U:%G %a %n' /etc/soc-geoip-manager/GeoIP.conf
```

Resultado esperado: `root:root 600`.

### 5.2 Endpoint de distribución

Instale y edite el entorno:

```bash
sudo install -o root -g root -m 0600 ./manager.env.example \
  /etc/soc-geoip-manager/manager.env
sudoedit /etc/soc-geoip-manager/manager.env
```

Ejemplo:

```text
SOC_GEOIP_MANAGER_LISTEN_IP=10.20.0.10
SOC_GEOIP_MANAGER_LISTEN_PORT=8444
SOC_GEOIP_MANAGER_SERVER_NAME=wazuh-manager-master.example.com
SOC_GEOIP_MANAGER_MAXMIND_CONFIG=/etc/soc-geoip-manager/GeoIP.conf
SOC_GEOIP_MANAGER_KEEP_RELEASES=4
```

El DNS debe resolver a `SOC_GEOIP_MANAGER_LISTEN_IP` desde todos los Indexer.

### 5.3 Preflight e instalación

```bash
sudo install -o root -g root -m 0755 ./soc-geoip-manager \
  /usr/local/sbin/soc-geoip-manager

sudo env SOC_GEOIP_STAGING_ROOT="$PWD" \
  /usr/local/sbin/soc-geoip-manager preflight

sudo env SOC_GEOIP_STAGING_ROOT="$PWD" \
  /usr/local/sbin/soc-geoip-manager install

sudo /usr/local/sbin/soc-geoip-manager status
sudo systemctl status soc-geoip-manager.timer --no-pager
sudo nginx -t
sudo ss -lntp | grep ':8444'
```

`install` crea una PKI dedicada, configura Nginx, descarga las tres bases, publica el manifiesto y
habilita el timer de actualización de martes y viernes. Una descarga fallida no sustituye la
última versión válida.

No copie a los Indexer estos archivos:

```text
/etc/soc-geoip-manager/GeoIP.conf
/etc/soc-geoip-manager/pki/ca.key
/etc/soc-geoip-manager/pki/server.key
```

## 6. Emitir una identidad por Indexer

En el Manager cree un bundle diferente para cada nodo. El directorio de salida no debe existir:

```bash
sudo /usr/local/sbin/soc-geoip-manager issue-client indexer-01 \
  /root/geoip-client-indexer-01
sudo /usr/local/sbin/soc-geoip-manager issue-client indexer-02 \
  /root/geoip-client-indexer-02
```

Cada directorio contiene:

```text
ca.crt
client.crt
client.key
```

Transfiéralo por un canal administrativo cifrado al nodo correspondiente. No reutilice una clave
en dos nodos. Después de instalarla y validar el acceso, elimine la copia temporal de entrega
según el procedimiento seguro de su organización.

## 7. Preparar cada Indexer `ingest`

Copie también el release `0.1.152` al Indexer. Suponga que el bundle individual quedó en
`/root/geoip-client`:

```bash
cd "$HOME/soc-installer/release-0.1.152"
sudo install -d -o root -g root -m 0700 /etc/soc-geoip-indexer
sudo install -o root -g root -m 0444 /root/geoip-client/ca.crt \
  /etc/soc-geoip-indexer/ca.crt
sudo install -o root -g root -m 0444 /root/geoip-client/client.crt \
  /etc/soc-geoip-indexer/client.crt
sudo install -o root -g root -m 0600 /root/geoip-client/client.key \
  /etc/soc-geoip-indexer/client.key
sudo install -o root -g root -m 0600 ./indexer.env.example \
  /etc/soc-geoip-indexer/worker.env
sudoedit /etc/soc-geoip-indexer/worker.env
```

Ejemplo para un clúster de tres nodos totales:

```text
SOC_GEOIP_SOURCE_URL=https://wazuh-manager-master.example.com:8444/geoip/v1
SOC_GEOIP_CLIENT_CERT=/etc/soc-geoip-indexer/client.crt
SOC_GEOIP_CLIENT_KEY=/etc/soc-geoip-indexer/client.key
SOC_GEOIP_CA_BUNDLE=/etc/soc-geoip-indexer/ca.crt
SOC_GEOIP_INDEXER_URL=https://wazuh-indexer-01.example.com:9200
SOC_GEOIP_INDEXER_ADMIN_CERT=/etc/wazuh-indexer/certs/admin.pem
SOC_GEOIP_INDEXER_ADMIN_KEY=/etc/wazuh-indexer/certs/admin-key.pem
SOC_GEOIP_INDEXER_CA_BUNDLE=/etc/wazuh-indexer/certs/root-ca.pem
SOC_GEOIP_EXPECTED_INDEXER_NODES=3
SOC_GEOIP_AUTO_ACTIVATE=false
SOC_GEOIP_INDEXER_SERVICE=wazuh-indexer.service
```

`SOC_GEOIP_EXPECTED_INDEXER_NODES` representa todos los nodos del clúster Indexer, no solo los
nodos `ingest`. `SOC_GEOIP_INDEXER_URL` debe usar una IP o DNS incluido en el certificado HTTP.

Instale y compruebe:

```bash
sudo install -o root -g root -m 0755 ./soc-geoip-indexer \
  /usr/local/sbin/soc-geoip-indexer

sudo env SOC_GEOIP_STAGING_ROOT="$PWD" \
  /usr/local/sbin/soc-geoip-indexer preflight

sudo env SOC_GEOIP_STAGING_ROOT="$PWD" \
  /usr/local/sbin/soc-geoip-indexer install

sudo /usr/local/sbin/soc-geoip-indexer status
sudo systemctl status soc-geoip-indexer.timer --no-pager
```

La instalación sincroniza una versión pendiente, pero con `AUTO_ACTIVATE=false` no reinicia el
Indexer.

### 7.1 Probar mTLS sin activar

```bash
sudo curl --fail --silent --show-error \
  --cert /etc/soc-geoip-indexer/client.crt \
  --key /etc/soc-geoip-indexer/client.key \
  --cacert /etc/soc-geoip-indexer/ca.crt \
  https://wazuh-manager-master.example.com:8444/geoip/v1/manifest.json
```

Debe devolver JSON con tres entradas, tamaños, tipos y SHA-256. Un `401`, `403`, error TLS o
timeout debe resolverse antes de continuar.

Repita toda esta sección en cada Indexer `ingest`.

## 8. Línea base y backup obligatorio

Antes del primer cambio ejecute desde Dev Tools:

```http
POST /_ingest/pipeline/_simulate
{
  "pipeline": {
    "processors": [
      {
        "geoip": {
          "field": "data.srcip",
          "target_field": "GeoLocation",
          "properties": ["city_name", "country_name", "region_name", "location"],
          "ignore_missing": true,
          "ignore_failure": false
        }
      }
    ]
  },
  "docs": [
    { "_source": { "data": { "srcip": "8.8.8.8" } } }
  ]
}
```

Guarde la respuesta. Debe contener `GeoLocation` y no debe contener `error`. La ciudad exacta no
es contractual porque puede cambiar entre versiones.

En cada nodo cree un backup durable previo a la activación:

```bash
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP="/var/backups/wazuh-indexer-geoip/$STAMP"
sudo install -d -o root -g root -m 0700 "$BACKUP"
sudo install -o root -g root -m 0600 \
  /usr/share/wazuh-indexer/modules/ingest-geoip/GeoLite2-City.mmdb \
  /usr/share/wazuh-indexer/modules/ingest-geoip/GeoLite2-Country.mmdb \
  /usr/share/wazuh-indexer/modules/ingest-geoip/GeoLite2-ASN.mmdb \
  "$BACKUP/"
sudo sha256sum "$BACKUP"/*.mmdb
printf 'Backup: %s\n' "$BACKUP"
```

Registre la ruta porque se utilizará si una validación funcional posterior exige rollback.

## 9. Activación canaria y rolling

Antes de tocar cada nodo verifique:

```http
GET /_cluster/health
GET /_cat/nodes?v&h=name,ip,node.role,master
GET /_cat/shards?v&s=state,index&h=index,shard,prirep,state,node
GET /_cat/recovery?v&active_only=true
GET /_cluster/pending_tasks
GET /_snapshot/_status
```

No continúe si:

- el clúster no está `green`;
- falta algún nodo;
- hay shards inicializando, relocalizando o no asignados;
- existe una recuperación o snapshot activo;
- el nodo elegido no tiene rol `ingest`.

En el primer Indexer canario:

```bash
sudo /usr/local/sbin/soc-geoip-indexer sync
sudo /usr/local/sbin/soc-geoip-indexer status
sudo /usr/local/sbin/soc-geoip-indexer activate
```

El comando vuelve a comprobar la salud, detiene el servicio, reemplaza las tres bases, inicia el
Indexer y espera que regresen todos los nodos. Si el servicio o el clúster no se recuperan,
restaura automáticamente las bases anteriores usadas al comenzar ese comando.

Después del canario:

```bash
sudo systemctl status wazuh-indexer --no-pager
sudo journalctl -u wazuh-indexer --since '-15 minutes' --no-pager
sudo /usr/local/sbin/soc-geoip-indexer status
sudo sha256sum \
  /usr/share/wazuh-indexer/modules/ingest-geoip/GeoLite2-{City,Country,ASN}.mmdb
```

Espere que el clúster vuelva a `green`, repita `_simulate` y valide un evento nuevo. Solo entonces
active el siguiente Indexer. Nunca reinicie dos nodos de datos simultáneamente.

Al terminar, los tres hashes activos deben ser iguales en todos los nodos `ingest`.

## 10. AIO y activación automática

En AIO configure:

```text
SOC_GEOIP_EXPECTED_INDEXER_NODES=1
SOC_GEOIP_AUTO_ACTIVATE=false
```

Se recomienda mantener `false` durante la primera instalación. Después de validar backup,
reinicio y `_simulate`, puede cambiarlo a `true` si acepta el breve corte del único Indexer en cada
actualización. La activación automática se rechaza cuando el número esperado de nodos es mayor a
uno.

## 11. Activar y desactivar la integración

En `0.1.152` no existe todavía un interruptor en la interfaz web.

Para detener nuevas descargas y sincronizaciones sin borrar las bases activas:

```bash
# Manager
sudo systemctl disable --now soc-geoip-manager.timer

# En cada Indexer ingest
sudo systemctl disable --now soc-geoip-indexer.timer
```

Después cierre `8444/tcp` en el firewall. Las últimas bases válidas permanecen activas y Wazuh
continúa funcionando con ellas.

Para reactivar:

```bash
# Manager
sudo systemctl enable --now soc-geoip-manager.timer
sudo /usr/local/sbin/soc-geoip-manager update

# En cada Indexer ingest
sudo systemctl enable --now soc-geoip-indexer.timer
sudo /usr/local/sbin/soc-geoip-indexer sync
```

En distribuido, active la versión pendiente manualmente y nodo por nodo. No confunda “integración
habilitada” con “base pendiente ya activada”.

## 12. Rollback posterior a la activación

Si el comando terminó correctamente pero `_simulate` o los eventos nuevos fallan, use el backup
durable de la sección 8 en el nodo afectado:

```bash
BACKUP=/var/backups/wazuh-indexer-geoip/REEMPLAZAR_TIMESTAMP
sudo test -f "$BACKUP/GeoLite2-City.mmdb"
sudo test -f "$BACKUP/GeoLite2-Country.mmdb"
sudo test -f "$BACKUP/GeoLite2-ASN.mmdb"

sudo systemctl stop wazuh-indexer
for DB in GeoLite2-City.mmdb GeoLite2-Country.mmdb GeoLite2-ASN.mmdb; do
  sudo install -o wazuh-indexer -g wazuh-indexer -m 0640 \
    "$BACKUP/$DB" \
    "/usr/share/wazuh-indexer/modules/ingest-geoip/$DB"
done
sudo systemctl start wazuh-indexer
```

Valide servicio, salud y `_simulate`. No avance a otro nodo hasta cerrar la causa.

## 13. Rotación y pérdida de credenciales

- Para cambiar la licencia MaxMind, edite `GeoIP.conf` con `sudoedit`, ejecute
  `soc-geoip-manager update` y compruebe `status`.
- Nunca copie `LicenseKey` a un Indexer.
- Perder una clave cliente no expone la licencia MaxMind, pero permite leer las bases mientras su
  certificado sea aceptado.
- Si una clave cliente se pierde o se copia fuera de control, cierre `8444`, rote la PKI dedicada
  y vuelva a emitir todos los clientes autorizados. Eliminar el archivo del nodo no revoca una
  copia robada.

La futura interfaz Administración > Integraciones > MaxMind deberá guardar el secreto en OpenBao
y controlar estos servicios, pero esa función no forma parte de `0.1.152`.

## 14. Actualizaciones de Wazuh y límites

La ruta activa pertenece al paquete `wazuh-indexer`; una actualización puede reponer sus bases.
Después de actualizar Wazuh:

1. confirme nuevamente la versión exacta;
2. compare hashes y fechas internas;
3. ejecute `sync`;
4. active nodo por nodo si hay diferencias;
5. repita `_simulate` y valide un evento nuevo.

Las bases nuevas solo enriquecen eventos nuevos. Los documentos históricos no se recalculan; eso
requiere una reindexación separada y planificada. GeoIP aporta contexto aproximado y no demuestra
la ubicación física de una persona o equipo.

## 15. Diagnóstico rápido

| Resultado | Revisión |
| --- | --- |
| `preflight` rechaza versión | Confirme `wazuh-indexer 4.14.7-1` |
| Manager no descarga | Revise licencia, DNS, proxy y salida HTTPS |
| `curl` mTLS falla | Revise DNS, hora, CA, certificado, clave y firewall `8444` |
| El manifiesto no tiene tres bases | Revise `EditionIDs` y vuelva a ejecutar `update` |
| El worker indica versión pendiente | Sincronizó correctamente; aún falta `activate` |
| Activación rechazada | El clúster no está verde o la cantidad de nodos no coincide |
| Un nodo tiene hashes diferentes | Detenga el rolling y vuelva a sincronizar/activar ese nodo |
| `_simulate` falla tras el cambio | Ejecute rollback con el backup durable |
| GeoIP antiguo después de upgrade | El paquete repuso las bases; reactive el release validado |

Antes de producción complete un piloto real con la cantidad definitiva de Indexer, pruebe el
rollback y conserve como evidencia: salud anterior/posterior, hashes, manifiesto, `_simulate` y
evento nuevo enriquecido.
