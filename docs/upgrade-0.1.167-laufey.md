# Actualizar LAUFEY de 0.1.166 a 0.1.167

Revisión: 2026-10-08 UTC. Ejecutar únicamente en LAUFEY, servidor central WA01
`.117`, con Manager local, Wazuh `4.14.8-1`, OSD `2.19.6` y topología `distributed`.
No ejecutar en los Indexer `.118`/`.119`. Publicar el release no actualiza el servidor.

## Resultado esperado y límites

- Instalador `0.1.167`; API, worker y agente `0.1.118`; plugin `socOperations@0.1.98`.
- Migración aditiva `6d9f2b8c1a53` → `a2c8e4f719b6`. Conserva la cuenta institucional
  protegida, UUID, correo, contraseña, tenants, casos, TLS y custodia OpenBao.
- Ingeniería global aparece como L3 en todos los tenants. Un SOC Manager gestiona su
  disponibilidad desde un tenant donde tiene autorización, sin administrar sus credenciales
  ni recibir datos del resto del personal de tenants ajenos.
- Analista, Analista Junior, SOC Manager e Ingeniería con invitación pendiente son
  programables. Esto NO activa la cuenta ni permite autenticarse antes de aceptar.
- Auditores excluidos. Las cuentas desactivadas/bloqueadas no pueden recibir nuevos turnos;
  su agenda futura se oculta y su historial concluido se conserva. No se borran registros.
- Requiere ventana: Dashboard y servicios SOC se detienen. No reinstala Wazuh, no modifica
  Coraza/CSP, no habilita API externa ni configura continuidad/S3 automáticamente.

**Respaldo nuevo obligatorio:** el checkpoint previo a `0.1.166` conserva el estado anterior
a esa actualización, no el estado actual. Mantenerlo intacto y crear otro directorio.
No volver a ejecutar el antiguo `cold-copy.sh` con rutas y fases de 0.1.166.

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

Esperar LAUFEY, `installer_version=0.1.166`, `phase=complete`, `deployment_id=wa01`,
`topology=distributed`, versiones API/worker/agente `0.1.117`, plugin `0.1.97`, readiness
sana y espacio suficiente para respaldo, TAR descifrado e imagen. No mostrar archivos de
entorno, tokens, correo institucional, recovery shares ni claves privadas.
Si hay errores actuales, detenerse y diagnosticarlos primero. Los anteriores 502 de
vulnerabilidades no se consideran solucionados por este release.

## 2. Descargar, descifrar y preparar el release fijo

En la misma shell root:

```bash
umask 077
SOC_DOWNLOAD="$(mktemp -d /root/soc-operations-0.1.167-download.XXXXXX)"
(
set -euo pipefail
[[ $EUID -eq 0 && "$(hostname)" == LAUFEY ]]
cd "$SOC_DOWNLOAD"
curl --fail --location --proto '=https' --tlsv1.2 --output SHA256SUMS \
  'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.167/SHA256SUMS'
curl --fail --location --proto '=https' --tlsv1.2 --output soc-operations-0.1.167.tar.gz.age \
  'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.167/soc-operations-0.1.167.tar.gz.age'
printf '%s  SHA256SUMS\n' \
  3ff87fea7dad6ac3729a344fa941d180221e09afb1d1e2000e9cc462cfb9be00 | sha256sum --check --strict -
printf '%s  soc-operations-0.1.167.tar.gz.age\n' \
  514cb96f7cdba3c4d133d6fa62fb2919854ceedd54057d97f0cddaae813205d9 | sha256sum --check --strict -
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
test ! -e soc-operations-0.1.167.tar.gz
test ! -e release-0.1.167
test ! -e /root/soc-operations-release-0.1.167
test ! -L /root/soc-operations-release-0.1.167
age --decrypt --identity "$SOC_AGE_IDENTITY" \
  --output soc-operations-0.1.167.tar.gz soc-operations-0.1.167.tar.gz.age
printf '%s  soc-operations-0.1.167.tar.gz\n' \
  59ff558ef1432f54675c32adf0093b8a3c888509be1103bb5afa406d2d8bac02 | sha256sum --check --strict -
tar --extract --gzip --file soc-operations-0.1.167.tar.gz
cd release-0.1.167
sha256sum --check --strict SHA256SUMS
test "$(find . -maxdepth 1 -type f | wc -l)" -eq 49
bash -n soc-operations-install
cd ..
mv -T -- release-0.1.167 /root/soc-operations-release-0.1.167
chmod 0700 /root/soc-operations-release-0.1.167
)
```

Solo después de verificar correctamente, retirar ÚNICAMENTE la identidad temporal, nunca la
original en custodia. Eliminar esa copia no equivale a borrado seguro del almacenamiento:

```bash
rm -- "$SOC_AGE_IDENTITY"
rmdir -- "$SOC_AGE_DIR"
unset SOC_AGE_IDENTITY SOC_AGE_DIR
```

Comprobar el preflight mientras Dashboard aún está activo; esto no instala ni migra:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.167
(
set -euo pipefail
cd "$SOC_RELEASE"
printf '%s  soc-operations-install\n' \
  c268b127270c6ff63e1c2f0adaf66cb5d579697ce30b85a3be3566d9fd17f2f4 | sha256sum --check --strict -
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
SOC_BACKUP="$(mktemp -d /root/socops-preupgrade-0.1.167.XXXXXX)"
(
set -Eeuo pipefail
umask 077
SOC_STAGE=inventory
trap 'printf "DETENER: fase=%s; conservar %s; no actualizar ni reiniciar a ciegas.\n" "$SOC_STAGE" "$SOC_BACKUP" >&2' ERR
[[ $EUID -eq 0 && "$(hostname)" == LAUFEY ]]
[[ "$(realpath -e "$SOC_BACKUP")" == "$SOC_BACKUP" ]]
[[ "$(stat -c '%u:%g %a' "$SOC_BACKUP")" == '0:0 700' ]]
test -x /var/ossec/bin/wazuh-control
grep -Fqx 'readonly INSTALLER_VERSION="0.1.166"' /usr/local/sbin/soc-operations-install
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
grep -qx 6d9f2b8c1a53 "$SOC_BACKUP/schema-before.txt"
docker exec soc-operations-wa001-postgres-1 psql -U soc_operations_owner -d soc_operations -At \
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
protegida esperada o el esquema no es el de 0.1.166, no continuar.

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
  opt/soc-operations-lab opt/soc-deploy-agent root/soc-operations-release-0.1.166
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
SOC_CUSTODY="$(mktemp -d /root/socops-seal-custody-0167.XXXXXX)"
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

## 6. Arrancar solo almacenamiento y Dashboard; mantener escritores detenidos

Dashboard debe estar activo para el preflight. Los usuarios siguen fuera de la aplicación;
API, API externa, worker y agente permanecen detenidos hasta que el upgrade los reconcilie.
No iniciar OpenBao de cero ni cambiar su clave si aparece sellado.

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
printf 'ALMACENAMIENTO_LISTO; Dashboard activo, escritores SOC detenidos.\n'
)
```

Si los escritores ya están activos sin haberlos iniciado explícitamente, detenerse y revisar
qué los arrancó; no saltar el control ni volver a detenerlos a ciegas.

## 7. Ejecutar preflight limpio y upgrade supervisado

```bash
(
set -Eeuo pipefail
umask 077
SOC_LOG="$(mktemp "$SOC_BACKUP/upgrade-0.1.167.XXXXXX.log")"
SOC_STAGE=checks
trap 'printf "DETENER: paso=%s; log privado=%s. No relanzar, restaurar ni borrar datos.\n" "$SOC_STAGE" "$SOC_LOG" >&2' ERR
[[ $EUID -eq 0 && "$(hostname)" == LAUFEY ]]
[[ "$(realpath -e "$SOC_BACKUP")" == "$SOC_BACKUP" ]]
[[ "$(stat -c '%u:%g %a' "$SOC_BACKUP")" == '0:0 700' ]]
grep -qx cold-copy-local-encrypted-verified "$SOC_BACKUP/phase"
(cd "$SOC_CIPHER" && sha256sum --check --strict SHA256SUMS)
(cd "$SOC_CUSTODY" && sha256sum --check --strict SHA256SUMS)
cd "$SOC_RELEASE"
sha256sum --check --strict SHA256SUMS
test "$(find . -maxdepth 1 -type f | wc -l)" -eq 49
printf '%s  soc-operations-install\n' \
  c268b127270c6ff63e1c2f0adaf66cb5d579697ce30b85a3be3566d9fd17f2f4 | sha256sum --check --strict -
grep -Fqx 'readonly INSTALLER_VERSION="0.1.167"' soc-operations-install
test -x /var/ossec/bin/wazuh-control
for SOC_SERVICE in api external-api worker; do
  [[ "$(docker inspect --format '{{.State.Running}}' "soc-operations-wa001-$SOC_SERVICE-1")" == false ]]
done
[[ "$(systemctl is-active soc-deploy-agent.service || true)" == inactive ]]
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
docker exec soc-operations-wa001-postgres-1 psql -U soc_operations_owner -d soc_operations -At \
  --set ON_ERROR_STOP=1 --command 'SELECT version_num FROM alembic_version;'
curl --fail-with-body --silent --show-error http://127.0.0.1:8080/health/ready
```

Esperar `phase=complete`, instalador `0.1.167`, las tres versiones `0.1.118`, plugin `0.1.98`,
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
About. Confirmar build `0.1.98-global-engineer-workforce`. Con cuentas individuales de prueba:

1. Un SOC Manager ve Ingeniería global una sola vez en Programación y puede gestionar turnos
   y vacaciones desde su tenant. Otro SOC Manager autorizado ve esa misma disponibilidad.
2. Invitados Analista, Analista Junior, SOC Manager e Ingeniería aparecen con **Invitación
   pendiente** y permiten programar. No pueden iniciar sesión antes de aceptar la invitación.
3. Auditores no aparecen como personal programable, incluso si tienen otro rol adicional.
4. Una cuenta individual de prueba desactivada desaparece de la agenda futura; el historial
   concluido permanece, sin botones de nuevos turnos. No desactivar la cuenta protegida.
5. Se rechazan solapamientos y vacaciones incompatibles. Un analista no obtiene privilegios
   de SOC Manager ni acceso a personal de otros tenants. Revisar login, casos, reportes,
   consultas y errores 502 antes de cerrar la ventana.

## 9. Si falla

Conservar staging, logs privados, backups actuales y anteriores, imágenes y custodia original.
No borrar estados ni forzar recreación. La migración es transaccional, pero TODO el upgrade
no lo es: agente o plugin pueden haber cambiado antes de un fallo. Diagnosticar la fase exacta
y decidir una recuperación coordinada; no aplicar el dump sobre producción ni revertir un
Indexer aislado de un clúster activo. No declarar aceptación solo porque los contenedores arrancan.
