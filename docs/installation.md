# Instalación limpia AIO de SOC Operations 0.1.148

Esta guía instala SOC Operations sobre un servidor all-in-one de Wazuh ya operativo. El
instalador no instala ni actualiza Wazuh, no modifica el firewall y no está soportado sobre una
instalación parcial o una versión distinta de la indicada.

## 1. Requisitos

- Ubuntu Server 24.04;
- Wazuh Manager, Indexer y Dashboard `4.14.7-1` en el mismo servidor;
- OpenSearch Dashboards `2.19.5`;
- acceso administrativo mediante `sudo`;
- salida HTTPS hacia GitHub y los repositorios oficiales de Ubuntu/Wazuh;
- FQDN HTTPS definitivo de Wazuh Dashboard;
- dirección IPv4 interna del AIO y, si existe, CIDR del reverse proxy/HAProxy;
- acceso autorizado a la identidad privada `age` almacenada en el gestor de secretos bajo
  `SOC Operations Installer Descifrado`.

El release `0.1.148` no es compatible con Wazuh 4.12. El `preflight` lo rechaza antes de instalar
componentes. No modifique esa comprobación; consulte [Compatibilidad](compatibility.md).

La instalación limpia supone un host nuevo o restaurado. Si existen datos anteriores de SOC
Operations, respáldelos y ejecute una restauración controlada; no borre manualmente
`/var/lib/soc-operations-installer`, PostgreSQL u OpenBao para forzar una reinstalación.

## 2. Instalar y validar Wazuh 4.14.7

Trabaje con su cuenta administrativa y anteponga `sudo` solamente cuando sea necesario; no abra
una shell root interactiva. Antes del primer `apt-get update` o `apt-get upgrade`, excluya los
componentes Wazuh de las actualizaciones automáticas:

```bash
sudo tee /etc/apt/apt.conf.d/52unattended-upgrades-wazuh >/dev/null <<'EOF'
Unattended-Upgrade::Package-Blacklist {
  "wazuh-manager";
  "wazuh-indexer";
  "wazuh-dashboard";
  "filebeat";
};
EOF

for package in wazuh-manager wazuh-indexer wazuh-dashboard filebeat; do
  if dpkg-query -W -f='${Status}\n' "$package" 2>/dev/null |
    grep -qx 'install ok installed'; then
    sudo apt-mark hold "$package"
  fi
done

sudo apt-get update
sudo apt-get upgrade -y
```

En una instalación limpia todavía no habrá paquetes Wazuh que retener. El blacklist queda activo
antes de instalarlos; el `hold` se aplica nuevamente después de comprobar la versión. Si el
sistema solicita reinicio, hágalo antes de ejecutar el instalador.

Compruebe primero que no existe una instalación parcial:

```bash
cat /etc/os-release
ip -brief address
dpkg-query -W wazuh-manager wazuh-indexer wazuh-dashboard filebeat 2>&1 || true
systemctl is-active wazuh-manager wazuh-indexer wazuh-dashboard filebeat 2>/dev/null || true
```

En un Ubuntu limpio, descargue y revise el asistente oficial fijado a la rama 4.14 antes de
ejecutarlo:

```bash
set -euo pipefail

install -d -m 0700 "$HOME/wazuh-install"
cd "$HOME/wazuh-install"
curl --fail --location --proto '=https' --tlsv1.2 \
  --output wazuh-install.sh \
  https://packages.wazuh.com/4.14/wazuh-install.sh
chmod 0755 wazuh-install.sh
bash -n wazuh-install.sh
sha256sum wazuh-install.sh
sudo bash ./wazuh-install.sh -a
```

Guarde en un gestor seguro la contraseña de `admin` y el archivo
`wazuh-install-files.tar`. Este último contiene credenciales y certificados: manténgalo con modo
`0600`, fuera de GitHub, chats y tickets.

Antes de continuar, confirme las versiones y servicios:

```bash
dpkg-query -W -f='${Package}\t${Version}\n' \
  wazuh-manager wazuh-indexer wazuh-dashboard filebeat
systemctl is-active wazuh-manager wazuh-indexer wazuh-dashboard filebeat
ss -lntH | grep -E ':(443|1514|1515|9200|55000)[[:space:]]'
```

Manager, Indexer y Dashboard deben mostrar `4.14.7-1`; los cuatro servicios deben estar activos.

Retenga el stack completo y verifique la selección de APT:

```bash
for package in wazuh-manager wazuh-indexer wazuh-dashboard filebeat; do
  dpkg-query -W -f='${Status}\n' "$package" 2>/dev/null |
    grep -qx 'install ok installed' && sudo apt-mark hold "$package"
done
apt-mark showhold | grep -E '^(wazuh-manager|wazuh-indexer|wazuh-dashboard|filebeat)$'
```

No libere ni actualice un componente de forma aislada. Wazuh Manager, Indexer, Dashboard y
Filebeat se actualizan juntos durante una ventana controlada.

### 2.1 Baseline de memoria y shards

Antes de instalar SOC Operations, deje aplicados y verificados los límites del Indexer. Como base:

```bash
sudo tee /etc/sysctl.d/99-wazuh-indexer.conf >/dev/null <<'EOF'
vm.max_map_count=262144
vm.swappiness=1
EOF
sudo sysctl --system
sudo sysctl vm.max_map_count vm.swappiness
```

Configure `Xms` y `Xmx` con el mismo valor, sin superar la mitad de la RAM ni `31g`, active
`bootstrap.memory_lock: true` y establezca `LimitMEMLOCK=infinity` en el servicio. En AIO reserve
memoria para Manager, Dashboard, Filebeat, Docker, OpenBao, PostgreSQL y caché del sistema; no
asigne automáticamente la mitad de toda la RAM al Indexer sin calcular esos consumos.

Estas son las tres ubicaciones concretas:

| Ajuste | Archivo |
| --- | --- |
| `Xms` y `Xmx` | `/etc/wazuh-indexer/jvm.options` |
| `bootstrap.memory_lock` | `/etc/wazuh-indexer/opensearch.yml` |
| `LimitMEMLOCK` | `/etc/systemd/system/wazuh-indexer.service.d/memory-lock.conf` |

Ejecute después de instalar Wazuh y antes de instalar SOC Operations. Defina primero el heap
aprobado; `8` es solo un ejemplo para un AIO de 32 GB cuyo consumo completo ya fue calculado:

```bash
INDEXER_HEAP_GB=8
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

sudo cp -a /etc/wazuh-indexer/jvm.options \
  "/etc/wazuh-indexer/jvm.options.pre-tuning-${STAMP}"
sudo cp -a /etc/wazuh-indexer/opensearch.yml \
  "/etc/wazuh-indexer/opensearch.yml.pre-tuning-${STAMP}"

sudo sed -ri \
  "s/^-Xms[0-9]+[gGmM]/-Xms${INDEXER_HEAP_GB}g/; \
   s/^-Xmx[0-9]+[gGmM]/-Xmx${INDEXER_HEAP_GB}g/" \
  /etc/wazuh-indexer/jvm.options

if sudo grep -qE '^[[:space:]]*bootstrap\.memory_lock:' \
  /etc/wazuh-indexer/opensearch.yml; then
  sudo sed -ri \
    's/^[[:space:]]*bootstrap\.memory_lock:.*/bootstrap.memory_lock: true/' \
    /etc/wazuh-indexer/opensearch.yml
else
  printf '\nbootstrap.memory_lock: true\n' |
    sudo tee -a /etc/wazuh-indexer/opensearch.yml >/dev/null
fi

sudo install -d -o root -g root -m 0755 \
  /etc/systemd/system/wazuh-indexer.service.d
printf '%s\n' '[Service]' 'LimitMEMLOCK=infinity' |
  sudo tee /etc/systemd/system/wazuh-indexer.service.d/memory-lock.conf >/dev/null

sudo systemctl daemon-reload
sudo systemctl restart wazuh-indexer
sudo systemctl --no-pager --full status wazuh-indexer
```

Valide los archivos y el valor efectivo:

```bash
sudo grep -nE '^-Xm[sx]' /etc/wazuh-indexer/jvm.options
sudo grep -nE '^bootstrap\.memory_lock:' /etc/wazuh-indexer/opensearch.yml
sudo systemctl show wazuh-indexer -p LimitMEMLOCK
sudo sysctl vm.max_map_count vm.swappiness
```

En Dev Tools, confirme que el proceso bloqueó la memoria y que el heap coincide con lo aprobado:

```http
GET /_nodes?filter_path=**.mlockall,**.jvm.mem.heap_max_in_bytes&pretty
```

No continúe si `mlockall` es `false`, el servicio no inicia o el heap no coincide. Revise
`journalctl -u wazuh-indexer -b --no-pager` y restaure los backups `pre-tuning` si necesita
rollback. El reinicio del único Indexer interrumpe brevemente la búsqueda e indexación.

Un AIO de un solo Indexer debe comenzar con `1` primary y `0` réplicas para cada patrón gestionado.
Configurar una réplica en un único nodo dejaría el clúster permanentemente amarillo. Aumente
primarios únicamente cuando el volumen calculado supere aproximadamente `20–40 GB` por primary;
no aumente globalmente los shards como sustituto de más disco o data nodes. Confirme estado
`green` y ausencia de shards `UNASSIGNED` antes de continuar.

En todos los templates Wazuh o por tenant administrados, conserve mappings y aliases y establezca
explícitamente estos settings para los índices futuros:

```json
{
  "index.number_of_shards": "1",
  "index.number_of_replicas": "0",
  "index.auto_expand_replicas": "false"
}
```

No reemplace un template completo con ese fragmento. Para corregir los índices Wazuh existentes,
después de confirmar que `number_of_data_nodes` es exactamente `1`, ejecute en Dev Tools:

```http
GET /_cluster/health?pretty
GET /_cat/nodes?v&h=name,node.role

PUT /wazuh-*/_settings?allow_no_indices=true&expand_wildcards=all
{
  "index": {
    "number_of_replicas": 0,
    "auto_expand_replicas": "false"
  }
}

GET /_cat/indices/wazuh-*?v&h=health,status,index,pri,rep
GET /_cat/shards/wazuh-*?v&h=index,shard,prirep,state,unassigned.reason
```

El resultado requerido es `green` y ningún shard réplica `UNASSIGNED`. Si posteriormente agrega
otro data node, cambie los templates y los índices existentes a `number_of_replicas: 1`.

## 3. Descargar y verificar el release cifrado

Continúe con la cuenta administrativa; use `sudo` solo para instalar dependencias. Mantenga el
release en el home de esa cuenta:

```bash
sudo apt-get update
sudo apt-get install -y age ca-certificates curl
install -d -m 0700 "$HOME/soc-installer"
cd "$HOME/soc-installer"

curl --fail --location --remote-name \
  https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.148/soc-operations-0.1.148.tar.gz.age
curl --fail --location --remote-name \
  https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.148/SHA256SUMS

grep 'soc-operations-0.1.148.tar.gz.age$' SHA256SUMS | sha256sum --check
```

El resultado debe ser:

```text
soc-operations-0.1.148.tar.gz.age: OK
```

Recupere la identidad privada desde el gestor de secretos autorizado, usando exactamente la
entrada `SOC Operations Installer Descifrado`, y colóquela temporalmente en
`$HOME/.soc-operations-installer-key.txt`. Nunca la descargue desde GitHub ni copie su valor en
chats, tickets, documentación o historial de comandos:

```bash
chmod 0600 "$HOME/.soc-operations-installer-key.txt"
age --decrypt \
  --identity "$HOME/.soc-operations-installer-key.txt" \
  --output soc-operations-0.1.148.tar.gz \
  soc-operations-0.1.148.tar.gz.age

sha256sum --check SHA256SUMS
tar -xzf soc-operations-0.1.148.tar.gz
cd release-0.1.148
sha256sum --check SHA256SUMS
test "$(find . -maxdepth 1 -type f | wc -l)" -eq 38
```

La primera verificación valida el asset cifrado y el TAR; la segunda valida los 37 artefactos del
release. El directorio contiene 38 archivos en total porque incluye su propio `SHA256SUMS`.

Si la política no permite conservar la identidad en el servidor, elimine únicamente su copia
temporal después del descifrado:

```bash
rm -f "$HOME/.soc-operations-installer-key.txt"
```

Esta identidad descifra exclusivamente el paquete de instalación. No la reutilice como clave de
OpenBao, `auto-unseal.key` ni como clave de cifrado de los respaldos de SOC Operations.

## 4. Ejecutar el preflight

Desde `$HOME/soc-installer/release-0.1.148` instale solo el orquestador:

```bash
sudo install -o root -g root -m 0755 \
  ./soc-operations-install \
  /usr/local/sbin/soc-operations-install

grep '  soc-operations-install$' SHA256SUMS | sha256sum --check

EXPECTED_INSTALLER_SHA256="$(
  awk '$2 == "soc-operations-install" {print $1}' SHA256SUMS
)"
INSTALLED_INSTALLER_SHA256="$(
  sha256sum /usr/local/sbin/soc-operations-install | awk '{print $1}'
)"

printf 'Esperado:  %s\nInstalado: %s\n' \
  "$EXPECTED_INSTALLER_SHA256" "$INSTALLED_INSTALLER_SHA256"
test "$INSTALLED_INSTALLER_SHA256" = "$EXPECTED_INSTALLER_SHA256"
```

Para el release `0.1.148` publicado, ambas huellas deben ser:

```text
87e75ec248749683cbb3dd6127d59a832dac0507888f544eee5200a996598aba
```

La comparación contra el `SHA256SUMS` interno es la validación autoritativa.

Ejecute la validación sin cambios persistentes:

```bash
sudo /usr/local/sbin/soc-operations-install preflight \
  --staging-root "$HOME/soc-installer/release-0.1.148"
```

En un host con varias interfaces, añada `--service-address IP_INTERNA`. No continúe si falla una
versión, servicio, dirección o hash.

## 5. Aplicar la fase técnica

Reemplace los valores de ejemplo:

```bash
sudo /usr/local/sbin/soc-operations-install apply \
  --staging-root "$HOME/soc-installer/release-0.1.148" \
  --service-address IP_INTERNA_AIO \
  --external-proxy-cidr IP_O_CIDR_DEL_PROXY \
  --email INGENIERO@EMPRESA.COM \
  --display-name "Primer ingeniero SOC" \
  --public-url https://dashboard.example.com
```

`--service-address` puede omitirse si la ruta predeterminada identifica la IP correcta.
`--external-proxy-cidr` puede omitirse si la API externa debe permanecer accesible solo desde
loopback. `--public-url` debe ser un origen HTTPS sin ruta, consulta ni fragmento.

La fase es reanudable. Si se interrumpe, corrija la causa y repita el mismo comando con la misma
identidad; no elimine el estado. El resultado esperado es:

```text
phase=waiting_for_openbao_custody
```

El instalador `0.1.148` crea los directorios `/opt/soc-operations-lab` y
`/opt/soc-operations/docs` antes de desplegar los archivos auxiliares, incluido
`continuity.env.example`. En una instalación nueva no es necesario prepararlos manualmente.
También valida la identidad fija de la imagen de API tanto con el ID de configuración como con el
ID de manifiesto OCI devuelto por Docker cuando utiliza el almacén containerd.
La generación inicial del certificado TLS de la API externa crea primero los archivos dentro de
un directorio temporal protegido con `umask 077` y aplica sus permisos después de generarlos.

Antes de `resume`, aplique y pruebe las reglas aprobadas de
[firewall](firewall-reference.md), incluida la ruta del bridge Docker hacia el agente mTLS.

## 6. Inicializar OpenBao y custodiar las credenciales

En una instalación nueva ejecute una sola vez:

```bash
sudo /usr/local/sbin/soc-operations-install openbao-init
```

El comando genera cinco recovery shares y un token raíz inicial. Debe custodiar fuera del servidor:

1. las cinco recovery shares, distribuidas entre custodios;
2. el token raíz inicial en un almacén offline;
3. una copia cifrada y externa de
   `/etc/soc-operations-lab/openbao/auto-unseal.key`, en una custodia separada.

No copie estos valores en argumentos, historial del shell, GitHub, chats o tickets. La clave
`auto-unseal.key` permite el arranque automático, pero no reemplaza el token raíz ni las recovery
shares. Si se pierde el token raíz, tres shares permiten generar otro; si también se pierden las
shares, el almacén actual no puede administrarse ni recuperarse.

Compruebe el estado:

```bash
sudo /usr/local/sbin/soc-operations-install status
```

Debe indicar:

```text
openbao_initialized=true
openbao_sealed=false
phase=waiting_for_openbao_configuration
```

No ejecute `openbao-unseal` en una instalación nueva con auto-unseal.

## 7. Completar la instalación

```bash
sudo /usr/local/sbin/soc-operations-install resume
```

El proceso solicita de forma oculta:

1. el token raíz inicial de OpenBao;
2. la contraseña del primer ingeniero;
3. la confirmación de esa contraseña.

La contraseña debe tener entre 14 y 256 caracteres y al menos tres clases entre minúsculas,
mayúsculas, números y símbolos. El primer ingeniero queda activo y no recibe invitación por
correo; inicie sesión directamente con el correo y la contraseña definidos.

Valide el resultado:

```bash
sudo /usr/local/sbin/soc-operations-install status
```

La salida final debe incluir:

```text
installer_version=0.1.148
phase=complete
dashboard=302
soc_api_liveness=200
soc_api_readiness=200
openbao_initialized=true
openbao_sealed=false
```

Después del primer acceso configure SMTP y los demás canales desde **SOC Operations →
Administración → Integraciones**. Las invitaciones y restablecimientos posteriores dependen de una
integración de correo funcional.

## 8. Reinicio y aceptación mínima

Reinicie el AIO durante la ventana de prueba y confirme que OpenBao vuelve sin introducir shares:

```bash
sudo reboot
```

Al regresar:

```bash
sudo /usr/local/sbin/soc-operations-install status
curl -sS http://127.0.0.1:8200/v1/sys/health
```

Además, valide un usuario de ingeniería, un tenant de prueba, aislamiento entre tenants, creación
de caso, vulnerabilidades, reporte y envío SMTP. Una instalación técnica no debe promoverse a
producción hasta completar estas pruebas y un simulacro de
[respaldo y restauración](backup-and-restore.md).

## 9. Evidencia segura ante fallos

Puede compartir, después de revisar la salida:

```bash
sudo /usr/local/sbin/soc-operations-install status
sudo docker compose --project-name soc-operations-wa001 \
  --env-file /etc/soc-operations-lab/runtime.env \
  --file /opt/soc-operations-lab/docker-compose.yml ps
sudo docker compose --project-name soc-operations-wa001 \
  --env-file /etc/soc-operations-lab/runtime.env \
  --file /opt/soc-operations-lab/docker-compose.yml \
  logs --no-color --tail 120 api external-api openbao
sudo journalctl --no-pager -u wazuh-dashboard -u wazuh-manager -n 120
```

No comparta `runtime.env`, tokens, recovery shares, claves privadas, el pepper,
`auto-unseal.key`, credenciales Wazuh ni `wazuh-install-files.tar`.

## 10. Activar MaxMind GeoIP en el AIO (opcional)

Complete primero la instalación y la aceptación mínima de SOC Operations. Después configure la
integración centralizada siguiendo [Despliegue completo de MaxMind GeoIP](maxmind-geoip.md). En
un AIO, el Manager y el único Indexer residen en el mismo servidor, pero se mantienen separados
los dos componentes: `soc-geoip-manager` publica las bases y `soc-geoip-indexer` las sincroniza.

Las credenciales MaxMind se guardan exclusivamente como `root` en
`/etc/soc-geoip-manager/GeoIP.conf`; no se introducen en la interfaz web ni se copian al worker.
Antes de activar GeoIP, conserve la línea base y el respaldo indicados en la guía, ejecute
`_simulate` y compruebe la salud del Indexer. En AIO puede habilitar la activación automática solo
después de completar esas pruebas.
