# Actualizar LAUFEY de 0.1.172 a 0.1.173

Este upgrade incorpora la corrección de identidad de nodo para consolidado y reportes.
Resultado esperado: instalador `0.1.173`, API/API externa/worker/agente `0.1.123`,
plugin `socOperations@0.1.103` y esquema `c17e89ab2304`. No hay migraciones nuevas.
Ejecutar solo en el servidor central de esta instalación, no en los Indexer.

## Preparación con los servicios activos

Confirmar `phase=complete` y versión `0.1.172`, salud de servicios, espacio disponible,
acceso de consola y custodia. Usar Bash sin perfiles. No publicar tokens ni claves.
Descargar los dos assets de [v0.1.173](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.173)
a un directorio NUEVO. El SHA-256 del manifiesto externo debe ser
`34d1a955067e8ceec5c233d93919977b85449d13c81c524a7d93f38feda3bf5c`.
Verificar el hash del TAR cifrado, descifrar con la identidad age autorizada y verificar
el TAR descifrado antes de extraer. No sobrescribir un staging existente.

El TAR contiene exclusivamente `release-0.1.173/` y 49 archivos regulares, incluyendo
`SHA256SUMS`. Rechazar rutas absolutas, `..`, enlaces o miembros inesperados.
Después del desempaque comprobar todos los hashes internos:

```bash
(
set -Eeuo pipefail
SOC_RELEASE=/root/soc-operations-release-0.1.173
cd "$SOC_RELEASE"
sha256sum --check --strict SHA256SUMS
test "$(find . -maxdepth 1 -type f | wc -l)" -eq 49
printf '%s  soc-operations-install\n' c72f2347f3924cd152a06f7e21c3584ab461e5d05fce23817bfd68230e3965fd | sha256sum --check --strict -
grep -Fqx 'readonly INSTALLER_VERSION="0.1.173"' soc-operations-install
bash -n soc-operations-install
env -u BASH_ENV -u ENV bash --noprofile --norc ./soc-operations-install preflight --staging-root "$SOC_RELEASE"
)
```

No instalar ni detener servicios si el preflight falla. En Manager remoto, preparar su agente
`0.1.123` antes del upgrade del Dashboard; el contrato mTLS rechaza una versión anterior.

## Respaldo nuevo en caliente

Crear un directorio privado NUEVO para esta actualización, sin reutilizar checkpoints previos.
Completar con los servicios activos: dump PostgreSQL legible, snapshot Raft OpenBao válido,
copia de las versiones S3 referenciadas y artefactos de reportes, configuración, inventario,
baseline de datos/cuenta protegida y huella de auto-unseal. Cifrar el respaldo y custodiar
la copia de auto-unseal por separado; comprobar ambos descifrados y hashes.
La copia de archivos de volúmenes activos no sustituye los snapshots y exportaciones lógicas.

Conservar `SOC_BACKUP`, `SOC_CIPHER` y `SOC_CUSTODY` con las rutas verificadas. El checkpoint
solo se considera listo tras comparar todos sus componentes y registrar
`hot-local-encrypted-verified` en su fase. Los snapshots de componentes distintos no forman
una transacción global; preservar versiones de objetos y documentar el punto de recuperación.
No repetir bloques antiguos de copia fría ni detener PostgreSQL, MinIO u OpenBao para este respaldo.
El upgrade no puede garantizar cero pérdida frente a un fallo posterior al respaldo.

## Upgrade supervisado

Ejecutar únicamente tras completar y verificar el respaldo nuevo. Reservar una ventana breve:
el instalador reemplaza componentes y puede reiniciar los servicios SOC y Dashboard.
No cambiar nombre, deployment, correo institucional, direcciones ni topología durante el upgrade.
El bloque siguiente requiere las tres rutas de respaldo ya verificadas; no las inventa.

```bash
(
set -Eeuo pipefail
umask 077
: "${SOC_BACKUP:?Falta respaldo verificado}"
: "${SOC_CIPHER:?Falta respaldo cifrado verificado}"
: "${SOC_CUSTODY:?Falta custodia seal verificada}"
[[ $EUID -eq 0 && "$(hostname)" == LAUFEY ]]
for SOC_PATH in "$SOC_BACKUP" "$SOC_CIPHER" "$SOC_CUSTODY"; do
  [[ "$SOC_PATH" == /root/* && "$(realpath -e "$SOC_PATH")" == "$SOC_PATH" ]]
  [[ "$(stat -c '%u:%g %a' "$SOC_PATH")" == '0:0 700' ]]
done
grep -qx hot-local-encrypted-verified "$SOC_BACKUP/phase"
(cd "$SOC_CIPHER" && sha256sum --check --strict SHA256SUMS)
(cd "$SOC_CUSTODY" && sha256sum --check --strict SHA256SUMS)
sha256sum --check --strict "$SOC_BACKUP/seal-key-fingerprint.txt"
SOC_RELEASE=/root/soc-operations-release-0.1.173
cd "$SOC_RELEASE"
sha256sum --check --strict SHA256SUMS
printf '%s  soc-operations-install\n' c72f2347f3924cd152a06f7e21c3584ab461e5d05fce23817bfd68230e3965fd | sha256sum --check --strict -
SOC_LOG="$(mktemp "$SOC_BACKUP/upgrade-0.1.173.XXXXXX.log")"
trap 'printf "DETENER: conserve los datos y el log privado %s; no restaurar a ciegas.\n" "$SOC_LOG" >&2' ERR
env -u BASH_ENV -u ENV bash --noprofile --norc ./soc-operations-install preflight --staging-root "$SOC_RELEASE" 2>&1 | tee -a "$SOC_LOG"
env -u BASH_ENV -u ENV bash --noprofile --norc ./soc-operations-install upgrade --staging-root "$SOC_RELEASE" 2>&1 | tee -a "$SOC_LOG"
/usr/local/sbin/soc-operations-install status
printf 'UPGRADE_0173_EJECUTADO; aceptación PENDIENTE; LOG_PRIVADO=%s\n' "$SOC_LOG"
)
```

Ante un fallo, conservar archivos y log privado; diagnosticar la fase antes de reintentar.
No ejecutar `apply`, `openbao-init`, downgrade, `docker compose down -v` ni borrar estados.
La publicación no autoriza ni ejecuta una restauración.

## Aceptación

- Confirmar versiones esperadas, `phase=complete`, readiness 200 y OpenBao inicializado/no sellado.
- Verificar cuenta institucional protegida, datos, turnos, SLAs y custodia intactos.
- Confirmar inventario mTLS con `deployment_id`, `wazuh_cluster_name` y `manager_hostname` correctos.
- Abrir el consolidado del host afectado y comparar el total con el Indexer autorizado actual.
  Los 7.652 hallazgos del diagnóstico anterior no son un total fijo: el inventario puede cambiar.
- Generar un reporte nuevo, verificar agrupación/total y ausencia del error de alcance.
- Verificar acceso de usuario autorizado y rechazo de otro tenant/host, sin cambiar permisos.

Una instalación con otro hostname usa su inventario dinámico; no requiere editar el código.
Si se renombra el nodo, revisar índices antiguos antes: no hay aliases históricos automáticos.
La revisión visual Word/PDF sigue pendiente; no confundir las pruebas locales con aceptación
del navegador o del Indexer de producción.
