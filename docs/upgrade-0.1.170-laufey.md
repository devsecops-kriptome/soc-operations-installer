# Actualizar LAUFEY de 0.1.169 a 0.1.170

Revisión: 2026-10-10, America/Lima. Ejecutar únicamente en LAUFEY, servidor central WA01
`.117`, con Manager local, Wazuh `4.14.8-1`, OSD `2.19.6` y topología `distributed`.
No ejecutar en los Indexer `.118`/`.119`. Publicar el release no actualiza el servidor.

## Resultado esperado y límites

- Instalador `0.1.170`; API, worker y agente `0.1.120`; plugin `socOperations@0.1.101`.
- Sin migración nueva desde `0.1.169`: mantiene el esquema `a2c8e4f719b6`. Conserva la cuenta institucional
  protegida, UUID, correo, contraseña, tenants, casos, TLS y custodia OpenBao.
- Bandeja compacta sin tarjetas ni columna Selección; acciones en menú ⋮.
- Importador Discover en bandeja y caso con diagnóstico de consulta, periodo UTC y request_id.
- Detalle compartido con campos completos, copia en texto, scroll único, enlace Discover cuando
  existe origen verificable y navegación entre eventos relacionados.
- Calendarios con contraste adaptativo y barra CSV junto al tenant. Ingeniería L3 comparte
  turnos y ausencias transversalmente; Calendario sin edición solo permite exportar.
- Ingeniería autorizada en responsables y correo; CC validado, sin ampliar acceso entre tenants.
- Casos automáticos: responsable elegible de turno, alternativa de turno o sin responsable;
  sin cobertura se notifica sin menciones. Se conservan límites y permisos de automatización.
- Vulnerabilidades por host y severidad, automatización en modal, consolidado por paquete y
  Top 10 CVE recientes, reportes por host o grupo de endpoints. Lectura completa por lotes
  con controles de integridad; no se eleva el límite de reconciliación del worker.
- Requiere ventana: Dashboard y servicios SOC se detienen. No reinstala Wazuh, no modifica
  Coraza/CSP, no habilita API externa ni configura continuidad/S3 automáticamente.

**Respaldo nuevo obligatorio:** el checkpoint previo a `0.1.169` conserva el estado anterior
a esa actualización, no el estado actual. Mantenerlo intacto y crear otro directorio.
No volver a ejecutar bloques antiguos con rutas y fases anteriores.

El operador eligió respaldo **solo local por ahora**. Los pasos siguientes conservan ese
alcance: NO protegen frente a pérdida de LAUFEY, no respaldan los índices del clúster Wazuh
y no sustituyen una restauración ensayada. La copia de seal tendrá otro directorio y otra
contraseña, pero sigue en el mismo host. Para recuperación ante desastre se requiere
[custodia externa y ensayo aislado](backup-and-restore.md), como trabajo separado.

Detenerse en el primer error; no relanzar automáticamente ni restaurar a ciegas. No usar
`apply`, `openbao-init`, `bootstrap-first-engineer`, `docker compose down -v`, SIGKILL o
downgrade. No probar la desactivación de la cuenta institucional protegida.

## 1. Revisar el estado actual, sin cambios

Abrir SSH en LAUFEY, confirmar acceso a consola y custodia. Abrir una shell limpia para evitar
los errores de sustitución de comandos vistos en perfiles Bash anteriores:

```bash
sudo env -u BASH_ENV -u ENV bash --noprofile --norc
hostname
/usr/local/sbin/soc-operations-install status
df -h /root /var/lib/docker
docker ps --format 'table {{.Names}}\t{{.Status}}'
systemctl is-active wazuh-dashboard.service soc-deploy-agent.service
```

Esperar LAUFEY, `installer_version=0.1.169`, `phase=complete`, `deployment_id=wa01`,
`topology=distributed`, versiones API/worker/agente `0.1.119`, plugin `0.1.100`, readiness
sana y espacio suficiente para respaldo, TAR descifrado e imagen. No mostrar archivos de
entorno, tokens, correo institucional, recovery shares ni claves privadas.
Detenerse ante errores inesperados de estado, custodia o salud. La aceptación exige
verificar las nuevas vistas, importación y reportes, no basta con instalar.
El 401 de `/api/request` y los avisos CSP/telemetría son independientes y no se corrigen aquí.

Los bloques largos siguientes deben guardarse como archivos y validarse con `bash -n`
antes de ejecutarlos si el terminal trunca pegados. Usar transferencia SSH y comparar
el SHA-256 del archivo; no corregir un bloque incompleto a ciegas. Si aparece `>` en
lugar del prompt normal, cancelar con Ctrl+C y revisar qué llegó a ejecutarse.

## 2. Descargar, descifrar y preparar el release fijo

En la misma shell root:

```bash
umask 077
SOC_DOWNLOAD="$(mktemp -d /root/soc-operations-0.1.170-download.XXXXXX)"
(
set -euo pipefail
[[ $EUID -eq 0 && "$(hostname)" == LAUFEY ]]
cd "$SOC_DOWNLOAD"
curl --fail --location --proto '=https' --tlsv1.2 --output SHA256SUMS \
  'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.170/SHA256SUMS'
curl --fail --location --proto '=https' --tlsv1.2 --output soc-operations-0.1.170.tar.gz.age \
  'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.170/soc-operations-0.1.170.tar.gz.age'
printf '%s  SHA256SUMS\n' \
  9eb7de588a555b6ae431597e1ad3e690321c5cf6d2dbd81fde8fba0110d99e76 | sha256sum --check --strict -
printf '%s  soc-operations-0.1.170.tar.gz.age\n' \
  7077015f01633e2c0ed1661d4d8674bf941f81cbca11b53ceefea14e31620c58 | sha256sum --check --strict -
printf 'DESCARGA_VERIFICADA=%s\n' "$SOC_DOWNLOAD"
)
```

Recuperar la identidad ORIGINAL de **SOC Operations Installer Descifrado** en el gestor
autorizado. No generar otra identidad ni pegarla en comandos/chat. Crear una copia temporal
root-only en `/run` y editarla en privado:

```bash
SOC_AGE_DIR="$(mktemp -d /run/soc-operations-age.XXXXXX)"
SOC_AGE_IDENTITY="$SOC_AGE_DIR/identity.txt"
install -m 0600 /dev/null "$SOC_AGE_IDENTITY"
nano "$SOC_AGE_IDENTITY"
age-keygen -y "$SOC_AGE_IDENTITY" >/dev/null
```

Si cualquier bloque falla, no seguir. El destino de release NO debe existir:

```bash
(
set -euo pipefail
cd "$SOC_DOWNLOAD"
test ! -e soc-operations-0.1.170.tar.gz
test ! -e release-0.1.170
test ! -e /root/soc-operations-release-0.1.170
test ! -L /root/soc-operations-release-0.1.170
age --decrypt --identity "$SOC_AGE_IDENTITY" \
  --output soc-operations-0.1.170.tar.gz soc-operations-0.1.170.tar.gz.age
printf '%s  soc-operations-0.1.170.tar.gz\n' \
  fd60148e5ba6264ac878bae36f55131183b726c509d6cdea0032c0e7976b53d4 | sha256sum --check --strict -
tar --extract --gzip --file soc-operations-0.1.170.tar.gz
cd release-0.1.170
sha256sum --check --strict SHA256SUMS
test "$(find . -maxdepth 1 -type f | wc -l)" -eq 49
bash -n soc-operations-install
cd ..
mv -T -- release-0.1.170 /root/soc-operations-release-0.1.170
chmod 0700 /root/soc-operations-release-0.1.170
)
```

Solo después de verificar correctamente, retirar ÚNICAMENTE la identidad temporal, nunca la
original en custodia. Eliminar esa copia no equivale a borrado seguro del almacenamiento:

```bash
(
set -Eeuo pipefail
[[ "$(realpath -e "$SOC_AGE_DIR")" == "$SOC_AGE_DIR" && "$SOC_AGE_DIR" == /run/soc-operations-age.* ]]
[[ "$SOC_AGE_IDENTITY" == "$SOC_AGE_DIR/identity.txt" && -f "$SOC_AGE_IDENTITY" && ! -L "$SOC_AGE_IDENTITY" ]]
[[ "$(stat -c '%u:%g %a' "$SOC_AGE_IDENTITY")" == '0:0 600' ]]
rm -- "$SOC_AGE_IDENTITY"
rmdir -- "$SOC_AGE_DIR"
)
```

Comprobar el preflight mientras Dashboard aún está activo; esto no instala ni migra:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.170
(
set -euo pipefail
cd "$SOC_RELEASE"
printf '%s  soc-operations-install\n' \
  8a6ea7832b24c4b77a0e1f828daa44b22dd16070261cb0130b6bd6b6126f0952 | sha256sum --check --strict -
export SOC_INDEXER_TLS_SERVER_NAME=wa01-indexer01
bash ./soc-operations-install preflight --staging-root "$SOC_RELEASE"
)
```

## 3. Congelar escrituras y generar un dump NUEVO

Avisar a los usuarios, cerrar sesiones operativas y suspender consumidores externos. No
abrir Dashboard ni realizar administración hasta la aceptación. Los bloques son para
ejecución supervisada y por etapas, no un script de recuperación automática.
Conservar las variables de esta sesión y anotar las rutas impresas; si se pierde la sesión,
recuperarlas explícitamente, sin elegir rutas con comodines.

```bash
SOC_BACKUP="$(mktemp -d /root/socops-preupgrade-0.1.170.XXXXXX)"
(
set -Eeuo pipefail
umask 077
SOC_STAGE=inventory
trap 'printf "DETENER: fase=%s; conservar %s; no actualizar ni reiniciar a ciegas.\n" "$SOC_STAGE" "$SOC_BACKUP" >&2' ERR
[[ $EUID -eq 0 && "$(hostname)" == LAUFEY ]]
[[ "$(realpath -e "$SOC_BACKUP")" == "$SOC_BACKUP" ]]
[[ "$(stat -c '%u:%g %a' "$SOC_BACKUP")" == '0:0 700' ]]
test -x /var/ossec/bin/wazuh-control
grep -Fqx 'readonly INSTALLER_VERSION="0.1.169"' /usr/local/sbin/soc-operations-install
grep -qx complete /var/lib/soc-operations-installer/phase
/usr/local/sbin/soc-operations-install status > "$SOC_BACKUP/status-before.txt"
for SOC_UNIT in wazuh-dashboard.service soc-deploy-agent.service; do
  systemctl is-active "$SOC_UNIT" > "$SOC_BACKUP/$SOC_UNIT.before"
  grep -qx active "$SOC_BACKUP/$SOC_UNIT.before"
done
SOC_WRITERS=(soc-operations-wa001-external-api-1 soc-operations-wa001-api-1 soc-operations-wa001-worker-1)
SOC_STORAGE=(soc-operations-wa001-postgres-1 soc-operations-wa001-minio-1 soc-operations-wa001-openbao-1)
for SOC_CONTAINER in "${SOC_WRITERS[@]}" "${SOC_STORAGE[@]}"; do
  [[ "$(docker inspect --format '{{.State.Running}}' "$SOC_CONTAINER")" == true ]]
  [[ "$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$SOC_CONTAINER")" == soc-operations-wa001 ]]
  docker inspect --format '{{.Name}} {{.Image}}' "$SOC_CONTAINER" >> "$SOC_BACKUP/images-before.txt"
done
docker inspect --format '{{range .Mounts}}{{if eq .Type "volume"}}{{println .Name}}{{end}}{{end}}' \
  "${SOC_WRITERS[@]}" "${SOC_STORAGE[@]}" | sed '/^$/d' | sort -u > "$SOC_BACKUP/volumes.txt"
test -s "$SOC_BACKUP/volumes.txt"
for SOC_CONTAINER in "${SOC_WRITERS[@]}"; do
  SOC_MASK="$(docker exec "$SOC_CONTAINER" awk '$1=="SigCgt:"{print $2}' /proc/1/status)"
  [[ "$SOC_MASK" =~ ^[[:xdigit:]]+$ ]]
  SOC_BIT=16384
  [[ "$SOC_CONTAINER" != soc-operations-wa001-worker-1 ]] || SOC_BIT=2
  (( (16#$SOC_MASK & SOC_BIT) != 0 ))
done
SOC_STAGE=stop-writers
systemctl stop wazuh-dashboard.service
for SOC_CONTAINER in "${SOC_WRITERS[@]}"; do
  SOC_SIGNAL=SIGTERM
  [[ "$SOC_CONTAINER" != soc-operations-wa001-worker-1 ]] || SOC_SIGNAL=SIGINT
  timeout --foreground 60s docker stop --signal "$SOC_SIGNAL" --timeout -1 "$SOC_CONTAINER"
  [[ "$(docker inspect --format '{{.State.Running}}' "$SOC_CONTAINER")" == false ]]
  SOC_EXIT="$(docker inspect --format '{{.State.ExitCode}}' "$SOC_CONTAINER")"
  if [[ "$SOC_SIGNAL" == SIGINT ]]; then
    case "$SOC_EXIT" in 0|130) ;; *) false ;; esac
  else
    case "$SOC_EXIT" in 0|143) ;; *) false ;; esac
  fi
done
systemctl stop soc-deploy-agent.service
SOC_STAGE=dump
docker exec soc-operations-wa001-postgres-1 pg_dump \
  --username soc_operations_owner --dbname soc_operations --format=custom > "$SOC_BACKUP/postgresql.dump"
test -s "$SOC_BACKUP/postgresql.dump"
docker exec -i soc-operations-wa001-postgres-1 pg_restore --list \
  < "$SOC_BACKUP/postgresql.dump" > "$SOC_BACKUP/postgresql-contents.txt"
docker exec soc-operations-wa001-postgres-1 psql -U soc_operations_owner -d soc_operations -qAt \
  --set ON_ERROR_STOP=1 --command \
  "BEGIN READ ONLY; SET LOCAL app.global_roles = 'service_worker'; SELECT json_build_object('tenants',(SELECT count(*) FROM tenants),'users',(SELECT count(*) FROM users),'cases',(SELECT count(*) FROM cases),'audit_events',(SELECT count(*) FROM audit_events),'report_runs',(SELECT count(*) FROM report_runs)); COMMIT;" > "$SOC_BACKUP/counts-before.json"
docker exec soc-operations-wa001-postgres-1 psql -U soc_operations_owner -d soc_operations -qAt \
  --set ON_ERROR_STOP=1 --command 'SELECT version_num FROM alembic_version;' > "$SOC_BACKUP/schema-before.txt"
grep -qx a2c8e4f719b6 "$SOC_BACKUP/schema-before.txt"
docker exec soc-operations-wa001-postgres-1 psql -U soc_operations_owner -d soc_operations -qAt \
  --set ON_ERROR_STOP=1 --command \
  "BEGIN READ ONLY; SET LOCAL app.global_roles = 'service_worker'; SELECT json_build_object('id',id,'status',status,'protected',is_primary_admin,'engineering',global_roles::jsonb ? 'soc_engineering') FROM users WHERE is_primary_admin; COMMIT;" > "$SOC_BACKUP/primary-admin-before.json"
python3 - "$SOC_BACKUP/primary-admin-before.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
assert p['status'] == 'active' and p['protected'] and p['engineering'], 'DETENER: cuenta protegida inválida'
print('PRIMARY_ADMIN_BEFORE=' + p['id'])
PY
sha256sum "$SOC_BACKUP/postgresql.dump" > "$SOC_BACKUP/dump.SHA256SUMS"
printf 'quiesced-dump-only\n' > "$SOC_BACKUP/phase"
printf 'DUMP_LEGIBLE; respaldo completo y cifrado PENDIENTES. SOC_BACKUP=%s\n' "$SOC_BACKUP"
)
```

`pg_restore --list` verifica legibilidad, no prueba una restauración. Si no aparece la cuenta
protegida esperada o el esquema no es el de 0.1.169, no continuar.

## 4. Copia fría de volúmenes y configuración

```bash
(
set -Eeuo pipefail
umask 077
SOC_STAGE=cold-preflight
trap 'printf "DETENER: fase=%s; conservar %s; no actualizar ni borrar datos.\n" "$SOC_STAGE" "$SOC_BACKUP" >&2' ERR
[[ $EUID -eq 0 && "$(hostname)" == LAUFEY ]]
[[ "$(realpath -e "$SOC_BACKUP")" == "$SOC_BACKUP" ]]
[[ "$(stat -c '%u:%g %a' "$SOC_BACKUP")" == '0:0 700' ]]
grep -qx quiesced-dump-only "$SOC_BACKUP/phase"
sha256sum --check --strict "$SOC_BACKUP/dump.SHA256SUMS"
for SOC_FILE in docker-volumes.cold.tar configuration.tar SHA256SUMS; do
  [[ ! -e "$SOC_BACKUP/$SOC_FILE" && ! -L "$SOC_BACKUP/$SOC_FILE" ]]
done
for SOC_UNIT in wazuh-dashboard.service soc-deploy-agent.service; do
  [[ "$(systemctl is-active "$SOC_UNIT" || true)" == inactive ]]
done
for SOC_SERVICE in api external-api worker; do
  [[ "$(docker inspect --format '{{.State.Running}}' "soc-operations-wa001-$SOC_SERVICE-1")" == false ]]
done
mapfile -t SOC_VOLUMES < "$SOC_BACKUP/volumes.txt"
SOC_MEMBERS=()
for SOC_VOLUME in "${SOC_VOLUMES[@]}"; do
  [[ "$SOC_VOLUME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]+$ ]]
  SOC_SOURCE="/var/lib/docker/volumes/$SOC_VOLUME/_data"
  [[ "$(docker volume inspect --format '{{.Mountpoint}}' "$SOC_VOLUME")" == "$SOC_SOURCE" ]]
  [[ "$(realpath -e "$SOC_SOURCE")" == "$SOC_SOURCE" ]]
  SOC_MEMBERS+=("$SOC_VOLUME/_data")
done
SOC_CONFIG_PATHS=(etc/soc-operations-lab etc/soc-deploy-agent etc/wazuh-dashboard
  var/lib/soc-operations-installer var/lib/soc-deploy-agent-installer
  opt/soc-operations-lab opt/soc-deploy-agent root/soc-operations-release-0.1.169
  usr/share/wazuh-dashboard/plugins/socOperations)
for SOC_PATH in "${SOC_CONFIG_PATHS[@]}"; do [[ -d "/$SOC_PATH" ]]; done
for SOC_PATH in etc/nginx/sites-available/soc-deploy-agent etc/systemd/system/soc-deploy-agent.service \
  var/lib/soc-deploy-agent var/lib/soc-operations-lab; do
  [[ ! -e "/$SOC_PATH" ]] || SOC_CONFIG_PATHS+=("$SOC_PATH")
done
for SOC_PATH in /usr/local/sbin/soc-*; do
  [[ ! -f "$SOC_PATH" ]] || SOC_CONFIG_PATHS+=("${SOC_PATH#/}")
done
SOC_SEAL=/etc/soc-operations-lab/openbao/auto-unseal.key
[[ -f "$SOC_SEAL" && ! -L "$SOC_SEAL" && "$(stat -c '%s' "$SOC_SEAL")" == 32 ]]
sha256sum "$SOC_SEAL" > "$SOC_BACKUP/seal-key-fingerprint.txt"
dpkg-query -W -f='${Package} ${Version}\n' wazuh-dashboard > "$SOC_BACKUP/dashboard-package-before.txt"
SOC_STAGE=stop-storage
for SOC_SERVICE in postgres minio openbao; do
  SOC_CONTAINER="soc-operations-wa001-$SOC_SERVICE-1"
  [[ "$(docker inspect --format '{{.State.Running}}' "$SOC_CONTAINER")" == true ]]
  SOC_SIGNAL=SIGTERM
  [[ "$SOC_SERVICE" != postgres ]] || SOC_SIGNAL=SIGINT
  timeout --foreground 90s docker stop --signal "$SOC_SIGNAL" --timeout -1 "$SOC_CONTAINER"
  [[ "$(docker inspect --format '{{.State.Running}}' "$SOC_CONTAINER")" == false ]]
  [[ "$(docker inspect --format '{{.State.ExitCode}}' "$SOC_CONTAINER")" == 0 ]]
done
SOC_RUNNING_IDS="$(docker ps -q)"
if [[ -n "$SOC_RUNNING_IDS" ]]; then
  mapfile -t SOC_RUNNING <<< "$SOC_RUNNING_IDS"
  SOC_ACTIVE_VOLUMES="$(docker inspect --format '{{range .Mounts}}{{if eq .Type "volume"}}{{println .Name}}{{end}}{{end}}' "${SOC_RUNNING[@]}")"
  for SOC_VOLUME in "${SOC_VOLUMES[@]}"; do
    if grep -Fqx "$SOC_VOLUME" <<< "$SOC_ACTIVE_VOLUMES"; then
      printf 'DETENER: volumen todavía utilizado: %s\n' "$SOC_VOLUME" >&2
      exit 1
    fi
  done
fi
SOC_STAGE=archives
tar --create --acls --xattrs --numeric-owner --sparse \
  --file "$SOC_BACKUP/docker-volumes.cold.tar" --directory /var/lib/docker/volumes "${SOC_MEMBERS[@]}"
tar --list --file "$SOC_BACKUP/docker-volumes.cold.tar" > "$SOC_BACKUP/cold-volumes-members.txt"
for SOC_VOLUME in "${SOC_VOLUMES[@]}"; do
  grep -Fqx "$SOC_VOLUME/_data/" "$SOC_BACKUP/cold-volumes-members.txt"
done
tar --create --acls --xattrs --numeric-owner \
  --exclude='auto-unseal.key' --exclude='*/auto-unseal.key' \
  --file "$SOC_BACKUP/configuration.tar" --directory / "${SOC_CONFIG_PATHS[@]}"
tar --list --file "$SOC_BACKUP/configuration.tar" > "$SOC_BACKUP/configuration-members.txt"
if grep -Eq '(^|/)auto-unseal\.key$' "$SOC_BACKUP/configuration-members.txt"; then
  printf 'DETENER: seal incluida inesperadamente; no usar archivo.\n' >&2
  exit 1
fi
cd "$SOC_BACKUP"
sha256sum postgresql.dump postgresql-contents.txt docker-volumes.cold.tar configuration.tar \
  status-before.txt images-before.txt counts-before.json schema-before.txt primary-admin-before.json \
  dashboard-package-before.txt seal-key-fingerprint.txt cold-volumes-members.txt configuration-members.txt \
  volumes.txt dump.SHA256SUMS wazuh-dashboard.service.before soc-deploy-agent.service.before > SHA256SUMS
sha256sum --check --strict SHA256SUMS
printf 'cold-copy-local-encryption-pending\n' > phase
printf 'COPIA_FRIA_OK; cifrado PENDIENTE. Servicios SOC y almacenamiento detenidos.\n'
)
```

Revisar inventario privado de bind mounts y rutas antes de aprobar la cobertura. El listado de
volúmenes se obtiene de los contenedores existentes: incluye los volúmenes anónimos OpenBao.
No copia un volumen en uso. No incluye los índices Wazuh remotos ni imágenes Docker completas
anteriores fuera de sus releases; conservar además las imágenes antiguas sin hacer prune.

## 5. Cifrar respaldo y seal con contraseñas DIFERENTES

Introducir contraseñas solo en los prompts ocultos de `age`, no en variables/historial/chat.
Custodiarlas fuera del host. La copia principal contiene tokens y configuración sensible.

```bash
SOC_CIPHER="$(mktemp -d "$SOC_BACKUP/cifrado.XXXXXX")"
SOC_CUSTODY="$(mktemp -d /root/socops-seal-custody-0170.XXXXXX)"
(
set -Eeuo pipefail
umask 077
trap 'printf "DETENER: conservar respaldo y custodia; no actualizar.\n" >&2' ERR
[[ $EUID -eq 0 && "$(hostname)" == LAUFEY && -t 0 ]]
grep -qx cold-copy-local-encryption-pending "$SOC_BACKUP/phase"
for SOC_SERVICE in api external-api worker postgres minio openbao; do
  [[ "$(docker inspect --format '{{.State.Running}}' "soc-operations-wa001-$SOC_SERVICE-1")" == false ]]
done
cd "$SOC_BACKUP"
sha256sum --check --strict SHA256SUMS
SOC_FILES=(SHA256SUMS postgresql.dump postgresql-contents.txt docker-volumes.cold.tar configuration.tar
  status-before.txt images-before.txt counts-before.json schema-before.txt primary-admin-before.json
  dashboard-package-before.txt seal-key-fingerprint.txt cold-volumes-members.txt configuration-members.txt
  volumes.txt dump.SHA256SUMS wazuh-dashboard.service.before soc-deploy-agent.service.before)
tar --create --file "$SOC_CIPHER/checkpoint.cold.tar" --directory "$SOC_BACKUP" "${SOC_FILES[@]}"
SOC_PLAIN_HASH="$(sha256sum "$SOC_CIPHER/checkpoint.cold.tar" | awk '{print $1}')"
printf '%s  checkpoint.cold.tar\n' "$SOC_PLAIN_HASH" > "$SOC_CIPHER/plaintext.SHA256SUMS"
printf 'Ahora: contraseña del RESPALDO PRINCIPAL.\n'
age --passphrase --output "$SOC_CIPHER/checkpoint.cold.tar.age" "$SOC_CIPHER/checkpoint.cold.tar"
printf 'Ahora: repetir contraseña del RESPALDO PRINCIPAL para verificar.\n'
SOC_ROUNDTRIP="$(age --decrypt "$SOC_CIPHER/checkpoint.cold.tar.age" | sha256sum | awk '{print $1}')"
[[ "$SOC_ROUNDTRIP" == "$SOC_PLAIN_HASH" ]]
printf 'DESCIFRADO_PRINCIPAL_OK\n'
SOC_SEAL=/etc/soc-operations-lab/openbao/auto-unseal.key
[[ -f "$SOC_SEAL" && ! -L "$SOC_SEAL" ]]
sha256sum --check --strict "$SOC_BACKUP/seal-key-fingerprint.txt"
SOC_SEAL_HASH="$(sha256sum "$SOC_SEAL" | awk '{print $1}')"
printf 'Ahora: OTRA contraseña para AUTO-UNSEAL.\n'
age --passphrase --output "$SOC_CUSTODY/auto-unseal.key.age" "$SOC_SEAL"
printf 'Ahora: repetir contraseña de AUTO-UNSEAL para verificar.\n'
SOC_ROUNDTRIP="$(age --decrypt "$SOC_CUSTODY/auto-unseal.key.age" | sha256sum | awk '{print $1}')"
[[ "$SOC_ROUNDTRIP" == "$SOC_SEAL_HASH" ]]
printf 'DESCIFRADO_SEAL_OK; clave no mostrada.\n'
(cd "$SOC_CIPHER" && sha256sum checkpoint.cold.tar.age > SHA256SUMS && sha256sum --check --strict SHA256SUMS)
(cd "$SOC_CUSTODY" && sha256sum auto-unseal.key.age > SHA256SUMS && sha256sum --check --strict SHA256SUMS)
printf 'cold-copy-local-encrypted-verified\n' > "$SOC_BACKUP/phase"
printf 'RESPALDO_CIFRADO=%s/checkpoint.cold.tar.age\nCLAVE_CIFRADA=%s/auto-unseal.key.age\n' "$SOC_CIPHER" "$SOC_CUSTODY"
)
```

Se verifica descifrado por hash, sin restaurar. Quedan copias en claro bajo root; no se eliminan
automáticamente. Los hashes internos y el historial NO deben sobrescribirse después del upgrade.

## 6. Arrancar almacenamiento, Dashboard y agente mTLS; mantener escritores SOC detenidos

Dashboard debe estar activo para el preflight. Los usuarios siguen fuera de la aplicación;
API, API externa y worker permanecen detenidos. Arrancar el agente existente antes del upgrade;
verificar mTLS antes de continuar. No inicializar OpenBao ni cambiar su clave si aparece sellado.

```bash
(
set -Eeuo pipefail
grep -qx cold-copy-local-encrypted-verified "$SOC_BACKUP/phase"
(cd "$SOC_CIPHER" && sha256sum --check --strict SHA256SUMS)
(cd "$SOC_CUSTODY" && sha256sum --check --strict SHA256SUMS)
sha256sum --check --strict "$SOC_BACKUP/seal-key-fingerprint.txt"
for SOC_SERVICE in api external-api worker; do
  [[ "$(docker inspect --format '{{.State.Running}}' "soc-operations-wa001-$SOC_SERVICE-1")" == false ]]
done
[[ "$(systemctl is-active soc-deploy-agent.service || true)" == inactive ]]
for SOC_SERVICE in postgres minio openbao; do docker start "soc-operations-wa001-$SOC_SERVICE-1"; done
SOC_READY=false
for SOC_ATTEMPT in {1..30}; do
  if docker exec soc-operations-wa001-postgres-1 pg_isready -U soc_operations_owner -d soc_operations >/dev/null 2>&1; then SOC_READY=true; break; fi
  sleep 2
done
[[ "$SOC_READY" == true ]]
for SOC_URL in http://127.0.0.1:9000/minio/health/live http://127.0.0.1:8200/v1/sys/health; do
  SOC_READY=false
  for SOC_ATTEMPT in {1..20}; do
    SOC_CODE="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 3 "$SOC_URL" || true)"
    if [[ "$SOC_CODE" == 200 ]]; then SOC_READY=true; break; fi
    sleep 2
  done
  [[ "$SOC_READY" == true ]]
done
curl --fail --silent --show-error --max-time 5 http://127.0.0.1:8200/v1/sys/health \
  | python3 -c 'import json,sys; p=json.load(sys.stdin); assert p["initialized"] is True and p["sealed"] is False; print("OpenBao listo, sin cambiar custodia")'
systemctl start wazuh-dashboard.service
systemctl is-active --quiet wazuh-dashboard.service
systemctl start soc-deploy-agent.service
systemctl is-active --quiet soc-deploy-agent.service
curl --fail --silent --show-error --retry 10 --retry-delay 2 --retry-connrefused --max-time 5 \
  --cert /etc/soc-operations-lab/deploy-tls/client.crt \
  --key /etc/soc-operations-lab/deploy-tls/client.key \
  --cacert /etc/soc-operations-lab/deploy-tls/service-ca.crt \
  https://192.168.4.117:8443/health/live \
  | python3 -c 'import json,sys; p=json.load(sys.stdin); assert p["status"] == "ok" and p["version"] == "0.1.119"; print("AGENTE_ACTUAL_LISTO; mTLS=200")'
printf 'ALMACENAMIENTO_LISTO; Dashboard y agente activos; escritores SOC detenidos.\n'
)
```

Si los escritores ya están activos sin haberlos iniciado explícitamente, detenerse y revisar
qué los arrancó; no saltar el control ni volver a detenerlos a ciegas.

## 7. Ejecutar preflight limpio y upgrade supervisado

```bash
(
set -Eeuo pipefail
umask 077
SOC_LOG="$(mktemp "$SOC_BACKUP/upgrade-0.1.170.XXXXXX.log")"
SOC_STAGE=checks
trap 'printf "DETENER: paso=%s; log privado=%s. No relanzar, restaurar ni borrar datos.\n" "$SOC_STAGE" "$SOC_LOG" >&2' ERR
[[ $EUID -eq 0 && "$(hostname)" == LAUFEY ]]
[[ "$(realpath -e "$SOC_BACKUP")" == "$SOC_BACKUP" ]]
[[ "$(stat -c '%u:%g %a' "$SOC_BACKUP")" == '0:0 700' ]]
grep -qx cold-copy-local-encrypted-verified "$SOC_BACKUP/phase"
(cd "$SOC_CIPHER" && sha256sum --check --strict SHA256SUMS)
(cd "$SOC_CUSTODY" && sha256sum --check --strict SHA256SUMS)
cd "$SOC_RELEASE"
sha256sum --check --strict "$SOC_BACKUP/seal-key-fingerprint.txt"
sha256sum --check --strict SHA256SUMS
test "$(find . -maxdepth 1 -type f | wc -l)" -eq 49
printf '%s  soc-operations-install\n' \
  8a6ea7832b24c4b77a0e1f828daa44b22dd16070261cb0130b6bd6b6126f0952 | sha256sum --check --strict -
grep -Fqx 'readonly INSTALLER_VERSION="0.1.170"' soc-operations-install
test -x /var/ossec/bin/wazuh-control
for SOC_SERVICE in api external-api worker; do
  [[ "$(docker inspect --format '{{.State.Running}}' "soc-operations-wa001-$SOC_SERVICE-1")" == false ]]
done
[[ "$(systemctl is-active soc-deploy-agent.service || true)" == active ]]
export SOC_INDEXER_TLS_SERVER_NAME=wa01-indexer01
SOC_STAGE=preflight
env -u BASH_ENV -u ENV bash --noprofile --norc ./soc-operations-install preflight --staging-root "$SOC_RELEASE" 2>&1 | tee -a "$SOC_LOG"
SOC_STAGE=upgrade
env -u BASH_ENV -u ENV bash --noprofile --norc ./soc-operations-install upgrade --staging-root "$SOC_RELEASE" 2>&1 | tee -a "$SOC_LOG"
SOC_STAGE=status
/usr/local/sbin/soc-operations-install status 2>&1 | tee -a "$SOC_LOG"
printf 'UPGRADE_EJECUTADO; aceptación PENDIENTE. LOG_PRIVADO=%s\n' "$SOC_LOG"
)
```

No cambiar email, nombre, deployment ni topología. El agente del Manager local se actualiza
antes del runtime. Si el Manager fuese remoto, NO usar este bloque: actualizar allí primero
el agente con su procedimiento. El log es privado y puede contener datos identificativos;
revisarlo/sanitizarlo antes de compartir fragmentos.

## 8. Aceptación técnica y funcional

```bash
/usr/local/sbin/soc-operations-install status
docker exec soc-operations-wa001-api-1 python -c 'from importlib.metadata import version; print(version("soc-operations"))'
docker exec soc-operations-wa001-worker-1 python -c 'from importlib.metadata import version; print(version("soc-operations"))'
/opt/soc-deploy-agent/current/venv/bin/python -I -c 'from importlib.metadata import version; print(version("soc-operations"))'
sudo -u wazuh-dashboard /usr/share/wazuh-dashboard/bin/opensearch-dashboards-plugin list | grep '^socOperations@'
docker exec soc-operations-wa001-postgres-1 psql -U soc_operations_owner -d soc_operations -qAt \
  --set ON_ERROR_STOP=1 --command 'SELECT version_num FROM alembic_version;'
curl --fail-with-body --silent --show-error http://127.0.0.1:8080/health/ready
```

Esperar `phase=complete`, instalador `0.1.170`, las tres versiones `0.1.120`, plugin `0.1.101`,
esquema `a2c8e4f719b6`, todas las comprobaciones de readiness sanas y cero bucles de reinicio.
`s3=configured` es configuración, no una prueba de recuperación ante desastre.

Comparar con el NUEVO inventario del paso 3. La auditoría puede aumentar por acciones legítimas;
no basta contar filas para demostrar conservación completa, pero tenants/usuarios/casos/reportes
no deben caer inesperadamente. Verificar mismo UUID institucional, activo, protegido e Ingeniería:

```bash
cat "$SOC_BACKUP/counts-before.json"
cat "$SOC_BACKUP/primary-admin-before.json"
docker exec soc-operations-wa001-postgres-1 psql -U soc_operations_owner -d soc_operations \
  --set ON_ERROR_STOP=1 --command \
  "BEGIN READ ONLY; SET LOCAL app.global_roles = 'service_worker'; SELECT id,status,is_primary_admin,global_roles::jsonb ? 'soc_engineering' AS engineering FROM users WHERE is_primary_admin; SELECT json_build_object('tenants',(SELECT count(*) FROM tenants),'users',(SELECT count(*) FROM users),'cases',(SELECT count(*) FROM cases),'audit_events',(SELECT count(*) FROM audit_events),'report_runs',(SELECT count(*) FROM report_runs)); COMMIT;"
```

En el navegador, guardar cambios pendientes y aceptar **Limpiar caché y recargar** o usar
About. Confirmar build `0.1.101-events-host-vulnerabilities-calendar-toolbar`. Con cuentas individuales de prueba:

1. En About confirmar build cargado y servidor `0.1.101-events-host-vulnerabilities-calendar-toolbar`.
   Guardar cambios antes de recargar. Si persiste el bundle antiguo: F12 → Network → Disable cache,
   recarga completa y diagnóstico de proxy/CDN. No reinstalar ni relajar CSP a ciegas.
2. Bandeja: no hay tarjetas ni columna Selección; las acciones ⋮ permanecen visibles. Con permisos
   adecuados, abrir detalles, crear un caso de prueba y vincular un evento autorizado.
3. Importar una búsqueda Discover con resultados conocidos en bandeja y desde un caso. Comparar
   consulta, filtros y periodo UTC; revisar el diagnóstico y request_id si falla. No compartir tokens
   ni resultados sensibles. Distinguir una consulta sin coincidencias de una búsqueda fallida.
4. Detalle: comprobar campos anidados, arrays, null, false y 0; copiar todos los campos en texto;
   un único scroll vertical y enlace al documento cuando está disponible. En eventos relacionados
   recorrer Anterior/Siguiente y comprobar campos y origen de cada evento, sin perder el contexto del caso.
5. Calendario Admin y Calendario: verificar temas claro/oscuro y anchos reducidos. Barra CSV a la
   derecha del tenant; solo exportación para lectores. Confirmar Ingeniería L3 global y una ausencia
   compartida desde dos tenants autorizados, sin modificar turnos reales para probar.
6. Caso de prueba: Ingeniería activa aparece entre responsables y destinatarios autorizados.
   Validar CC, sin enviar correo real sin autorización ni seleccionar usuarios de otro tenant.
7. Vulnerabilidades: comparar conteos de severidad por host con el inventario completo. Abrir
   consolidado: nombre/SO/grupos/IP y paquetes con total y Top 10 CVE recientes, score como desempate,
   publicación, CTI y descripción. Mostrar automatización solo desde modal. Una simulación/reporte
   incompleto debe fallar explícitamente; nunca interpretarse como ausencia de vulnerabilidades.
8. Generar reporte autorizado por host y por grupo de endpoints: recomendación inicial y agrupación
   host/paquete o grupo/paquete/hosts relacionados. Revisar CSV y Word/PDF. Las comprobaciones de
   estructura DOCX locales no sustituyen revisión visual del documento generado en producción.
9. Casos automáticos: probar únicamente en configuración/datos controlados los tres escenarios
   (responsable en turno, alternativa en turno, nadie en turno). El último queda sin responsable
   y notifica sin etiquetas. No activar políticas ni cerrar incidentes reales solo para aceptación.
10. Confirmar login, cuenta institucional protegida, historial, evidencias, permisos y aislamiento
    entre tenants. Las pruebas locales no equivalen a una restauración ni aceptación de LAUFEY.

## 9. Si falla

Conservar staging, logs privados, backups actuales y anteriores, imágenes y custodia original.
No borrar estados ni forzar recreación. Aunque no hay migración nueva desde 0.1.169,
TODO el upgrade no es transaccional: agente o plugin pueden haber cambiado antes de un fallo. Diagnosticar la fase exacta
y decidir una recuperación coordinada; no aplicar el dump sobre producción ni revertir un
Indexer aislado de un clúster activo. No declarar aceptación solo porque los contenedores arrancan.
