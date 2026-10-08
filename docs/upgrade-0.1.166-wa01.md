# Actualizar WA01 de 0.1.165 a 0.1.166

Revisión: 2026-10-07. Ejecutar en el servidor central `.117` (LAUFEY), no en los
Indexer `.118`/`.119`. Publicar este release no implica que WA01 ya esté actualizado.

## Alcance y límites

- Instalador `0.1.166`; API, worker y agente `0.1.117`; plugin `0.1.97` para OSD `2.19.6`.
- Conserva Wazuh `4.14.8-1`, topología `distributed`, deployment `wa01`, proyecto Compose
  histórico `soc-operations-wa001`, correo, contraseña, UUID, tenants, casos, TLS y OpenBao.
- Migra PostgreSQL de `c9d4e1f7a620` a `6d9f2b8c1a53`. La cuenta inicial debe existir,
  estar activa y conservar `soc_engineering`; el correo registrado por el instalador es
  la referencia. Una discrepancia interrumpe la migración sin reactivar ni elegir otro usuario.
- Cuenta inicial: administración institucional y contingencia, no personal ni identidad de
  ejecución de API/worker. Si el correo sigue siendo personal, registrar el pendiente de
  custodia; el upgrade no cambia ese correo. Usar cuentas individuales para el trabajo diario.
- Ventana de mantenimiento: se reinicia Dashboard y se recrean servicios SOC. No se garantiza
  cero indisponibilidad ni rollback global. No ejecutar `apply`, `openbao-init`,
  `bootstrap-first-engineer`, borrado de volúmenes ni downgrade para retirar la protección.
- El operador confirmó que los colores de 0.1.165 funcionan al reiniciar desde About.
  No se cambia CSP ni Coraza. Los errores 502 de vulnerabilidades deben revisarse por separado.

## 1. Comprobación previa, sin actualizar

Desde SSH en `.117`, abrir una sesión root controlada. No compartir archivos de entorno,
contraseñas, claves privadas, tokens ni recovery shares.

```bash
sudo -i
hostname
/usr/local/sbin/soc-operations-install status
test -s /var/lib/soc-operations-installer/engineer-email
test ! -L /var/lib/soc-operations-installer/engineer-email
df -h /root /var/lib/docker
```

Esperar instalador `0.1.165`, `topology=distributed`, `deployment_id=wa01`, pasos completos
y sondas sanas. Si hay fallos actuales, diagnosticarlos antes del upgrade. Confirmar acceso
a consola Proxmox y a la custodia de recuperación. No instalar todavía el orquestador nuevo.

Comprobar la identidad inicial mediante una lectura de la base actual, sin mostrar correo
ni credenciales y sin escribir usuarios:

```bash
(
set -euo pipefail
SOC_INITIAL_EMAIL="$(cat /var/lib/soc-operations-installer/engineer-email)"
docker exec -i --env "SOC_DIAG_PRIMARY_EMAIL=$SOC_INITIAL_EMAIL" \
  soc-operations-wa001-api-1 python - <<'PY'
import os
from sqlalchemy import select
from soc_operations.database import SessionFactory, apply_internal_context
from soc_operations.models import User
with SessionFactory() as session:
    apply_internal_context(session, 'service_bootstrap')
    user = session.scalar(select(User).where(
        User.email == os.environ['SOC_DIAG_PRIMARY_EMAIL'].strip().lower()))
    if user is None:
        raise SystemExit('DETENER: identidad inicial no encontrada')
    status = getattr(user.status, 'value', user.status)
    print('primary_admin_uuid_before=' + str(user.id))
    print('primary_admin_active=' + str(status == 'active').lower())
    print('primary_admin_engineering=' + str('soc_engineering' in user.global_roles).lower())
    if status != 'active' or 'soc_engineering' not in user.global_roles:
        raise SystemExit('DETENER: recuperación manual necesaria')
PY
)
```

Guardar el UUID para compararlo después; `active` y `engineering` deben ser `true`.

## 2. Punto de recuperación vigente: obligatorio

Esta versión cambia el esquema. **No omitir el respaldo reutilizando el checkpoint anterior
a 0.1.164**, aunque no se hayan creado casos nuevos. Congelar las escrituras operativas durante
la ventana y mantenerlas suspendidas hasta terminar la aceptación.

Preparar el dump y configuración actuales según
[el bloque de recuperación 9.15.2](wa01-produccion-distribuida-wazuh-4.14.8.md#actualizar-soc-operations-sin-reinstalar-wa01),
ignorando su excepción histórica de reutilización para 0.1.165. Completar también el respaldo
consistente de OpenBao/Raft, evidencias/S3 y volúmenes de la aplicación conforme al
[procedimiento de custodia y recuperación](backup-and-restore.md). Si se usa un checkpoint
frío de `.117`, coordinar la parada/arranque y excluir la reversión aislada de su nodo Indexer
dentro de un clúster activo. Un snapshot genérico previo a la instalación no es suficiente.

Requisitos antes de continuar: hashes verificados, dump legible, componentes necesarios y
versiones inventariados, copia cifrada fuera del servidor, claves de recuperación disponibles
en custodia separada y procedimiento de restauración aprobado. `pg_restore --list` comprueba
legibilidad, no acredita por sí solo una restauración ensayada. No enviar respaldos al chat.

## 3. Descargar y comprobar el release fijo

En la sesión root de `.117`, usar un directorio nuevo para no sobrescribir una descarga previa:

```bash
(
set -euo pipefail
umask 077
SOC_DOWNLOAD="$(mktemp -d /root/soc-operations-0.1.166-download.XXXXXX)"
cd "$SOC_DOWNLOAD"
curl --fail --location --proto '=https' --tlsv1.2 --output SHA256SUMS \
  'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.166/SHA256SUMS'
curl --fail --location --proto '=https' --tlsv1.2 --output soc-operations-0.1.166.tar.gz.age \
  'https://github.com/devsecops-kriptome/soc-operations-installer/releases/download/v0.1.166/soc-operations-0.1.166.tar.gz.age'
printf '%s  %s\n' \
  '9f3235fac72652355a2534057cab50c965fefb2a55765d5e7697dc4dfa76a19e' \
  SHA256SUMS | sha256sum --check --strict -
printf '%s  %s\n' \
  '707fed1999b60a9b0984b9de784cf7e67fee08164ee73a8d3ebded8323256fd3' \
  soc-operations-0.1.166.tar.gz.age | sha256sum --check --strict -
printf 'Descarga verificada: %s\n' "$SOC_DOWNLOAD"
)
```

Entrar después en la ruta que imprimió el bloque; no adivinar ni usar comodines para elegirla.
Recuperar la identidad `age` exclusivamente de la entrada **SOC Operations Installer Descifrado**
del gestor de secretos autorizado. Conservarla temporalmente en `/run`, root `0600`, por ejemplo:

```bash
umask 077
SOC_AGE_DIR="$(mktemp -d /run/soc-operations-age.XXXXXX)"
SOC_AGE_IDENTITY="$SOC_AGE_DIR/identity.txt"
install -m 0600 /dev/null "$SOC_AGE_IDENTITY"
nano "$SOC_AGE_IDENTITY"
age-keygen -y "$SOC_AGE_IDENTITY" >/dev/null
```

No pegar la clave en comandos, historial o chat; el archivo contiene la identidad privada,
no el destinatario público `age1...`. No generar una identidad nueva.

Dentro del directorio de descarga verificado:

```bash
(
set -euo pipefail
age --decrypt --identity "$SOC_AGE_IDENTITY" \
  --output soc-operations-0.1.166.tar.gz soc-operations-0.1.166.tar.gz.age
printf '%s  %s\n' \
  'ae5c8fd39a71dbbd9e8b47b7d525c5901e910a5b363118c7526d7e4909bec6cd' \
  soc-operations-0.1.166.tar.gz | sha256sum --check --strict -
tar --extract --gzip --file soc-operations-0.1.166.tar.gz
cd release-0.1.166
sha256sum --check --strict SHA256SUMS
test "$(find . -maxdepth 1 -type f | wc -l)" -eq 49
test ! -e /root/soc-operations-release-0.1.166
cd ..
mv -T -- release-0.1.166 /root/soc-operations-release-0.1.166
chmod 0700 /root/soc-operations-release-0.1.166
)
```

Si el destino ya existe, detenerse y verificarlo; no sobrescribirlo. Después del descifrado
correcto retirar únicamente la copia temporal de la identidad (la original queda en custodia):

```bash
rm -- "$SOC_AGE_IDENTITY"
rmdir -- "$SOC_AGE_DIR"
unset SOC_AGE_IDENTITY SOC_AGE_DIR
```

## 4. Preflight y upgrade

No continuar sin confirmar el checkpoint vigente del paso 2, identidad activa y hashes correctos.
Ejecutar en la misma sesión root. No pasar otro correo, nombre, contraseña ni topología.

```bash
(
set -euo pipefail
SOC_NEW_RELEASE='/root/soc-operations-release-0.1.166'
cd "$SOC_NEW_RELEASE"
sha256sum --check --strict SHA256SUMS
test "$(find . -maxdepth 1 -type f | wc -l)" -eq 49
grep -Fqx 'readonly INSTALLER_VERSION="0.1.166"' soc-operations-install
printf '%s  %s\n' \
  '960ee8994bf3a3c75bcc778df3335c2ab70b0fd501ce3937dbc0902690ac12f6' \
  soc-operations-install | sha256sum --check --strict -
bash ./soc-operations-install preflight --staging-root "$SOC_NEW_RELEASE"
SOC_WORKER=soc-operations-wa001-worker-1
if [ "$(docker inspect --format '{{.State.Running}}' "$SOC_WORKER")" = true ]; then
  SOC_SIGNAL_MASK=$(docker exec "$SOC_WORKER" awk '$1=="SigCgt:"{print $2}' /proc/1/status)
  [[ "$SOC_SIGNAL_MASK" =~ ^[[:xdigit:]]+$ ]]
  (( (16#$SOC_SIGNAL_MASK & 2) != 0 ))
  timeout --foreground 45s docker stop --signal SIGINT --timeout -1 "$SOC_WORKER"
  SOC_WORKER_EXIT=$(docker inspect --format '{{.State.ExitCode}}' "$SOC_WORKER")
  case "$SOC_WORKER_EXIT" in 0|130) ;; *) echo 'DETENER: salida inesperada del worker' >&2; exit 1;; esac
fi
test "$(docker inspect --format '{{.State.Running}}' "$SOC_WORKER")" = false
export SOC_INDEXER_TLS_SERVER_NAME=wa01-indexer01
bash ./soc-operations-install upgrade --staging-root "$SOC_NEW_RELEASE"
/usr/local/sbin/soc-operations-install status
)
```

El agente local se actualiza antes del runtime. No ejecutar el bloque sobre una instalación con
Manager remoto; ese caso requiere actualizar allí el agente antes. SIGINT fue comprobado en WA01:
si falta manejador, vence el timeout o la salida no es `0/130`, detenerse; no usar SIGKILL.

## 5. Aceptación después del upgrade

Esperar `installer_version=0.1.166`, `phase=complete`, `topology=distributed`, `deployment_id=wa01`,
API live/ready `200`, Dashboard `200/302` y mismos tenants/casos. Comprobar versiones:

```bash
docker exec soc-operations-wa001-api-1 python -c \
  'from importlib.metadata import version; print(version("soc-operations"))'
docker exec soc-operations-wa001-worker-1 python -c \
  'from importlib.metadata import version; print(version("soc-operations"))'
/opt/soc-deploy-agent/current/venv/bin/python -I -c \
  'from importlib.metadata import version; print(version("soc-operations"))'
sudo -u wazuh-dashboard /usr/share/wazuh-dashboard/bin/opensearch-dashboards-plugin list \
  | grep '^socOperations@'
curl --fail-with-body --silent --show-error http://127.0.0.1:8080/health/ready
```

API/worker/agente `0.1.117`; plugin `socOperations@0.1.97`. Readiness debe incluir
`opensearch_query=ok`. Mantener `proxy_ssl_verify on`, el nombre TLS `wa01-indexer01`,
custodia OpenBao y estado previo de activación de API externa; no forzar su activación.

Repetir la lectura del paso 1 añadiendo `print('primary_admin_protected=' +
str(user.is_primary_admin).lower())` dentro del bloque `with`. Debe mostrar el **mismo UUID**,
activo, Ingeniería y `primary_admin_protected=true`. Confirmar en Administración → Usuarios
la etiqueta **Administración institucional · Protegida**; no probar una eliminación real.
En About usar **Reiniciar caché y recargar** y verificar
`0.1.97-primary-admin-version-popup`. Revisar login, permisos tenant, tarjetas y consultas.
Desde esta versión aparece un popup cuando el servidor dispone de un build diferente o al
primer acceso tras una actualización. Ofrece **Limpiar caché y recargar** y **Más tarde**;
guardar primero los cambios pendientes. La recarga es voluntaria y conserva sesión,
preferencias y datos. Comprueba la versión instalada, no la disponibilidad de releases en
GitHub. La primera actualización desde 0.1.96 requiere recargar para recibir esta función.

## 6. Si falla

Detenerse en el primer error, conservar staging, logs sanitizados y backups. No borrar estados,
usuarios, volúmenes ni claves. Si la migración rechaza la cuenta, no promover otra ni editar
el registro del instalador para esquivarla; recuperar la identidad con un procedimiento aprobado.
No ejecutar downgrade Alembic: esta protección no se retira automáticamente.

La migración PostgreSQL falla transaccionalmente ante una cuenta ausente/inactiva, pero el upgrade
completo no es una transacción: el agente o plugin podrían haber cambiado antes. Mantener el worker
suspendido si el runtime falla y diagnosticar el componente. Una vuelta atrás requiere planificar
la compatibilidad y la recuperación completa desde el checkpoint; no restaurar un dump sobre
producción a ciegas ni revertir un Indexer aislado. No dar la ventana por terminada si hay errores 502.
