# Actualización a SOC Operations 0.1.188

Instalador 0.1.188; API/API externa/worker/agente 0.1.131; plugin 0.1.111;
esquema c8d3e902f751 sin nuevas migraciones. Conservar el perfil exacto del destino.
No es necesario instalar los candidatos locales 0.1.186/0.1.187.

## Preparación

Registrar versiones, topología, servicios, Compose, cuenta protegida y conteos. Preparar
respaldo vigente y verificado de PostgreSQL, OpenBao, objetos S3, reportes y configuración;
auto-unseal cifrada por separado, clave original intacta. Conservar baselines y logs.
Un respaldo local no protege la pérdida del host; la copia en caliente no es una transacción
global ni implica RPO cero. No reutilizar un respaldo antiguo sin revisar cobertura y vigencia.

Descargar de [v0.1.188](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.188)
el asset cifrado y SHA256SUMS, verificar las [huellas](release-0.1.188.md), descifrar por el
canal autorizado y verificar el TAR claro. No exponer identidades en argumentos, chat o logs.
Antes de extraer, rechazar rutas absolutas, '..', duplicados, enlaces y tipos especiales.
Son 49 archivos regulares planos bajo release-0.1.188. Usar staging privado nuevo y verificar
SHA256SUMS interno; no sobrescribir el staging ni el instalador activo a mano.

## Preflight y upgrade

Sin operaciones administrativas concurrentes, con las direcciones/topología persistidas:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.188
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" preflight --staging-root "$SOC_RELEASE"
```

Solo si preflight, respaldo y baseline están verificados, en ventana autorizada:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.188
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" upgrade --staging-root "$SOC_RELEASE"
sudo /usr/local/sbin/soc-operations-install status
```

Usar upgrade, no apply ni resume. No ejecutar helpers antiguos en paralelo: usan otros
bloqueos. No editar hashes, Compose, certificados o permisos para eludir rechazos.
Con Manager remoto seguir su flujo de agente: se requiere 0.1.131 antes del nuevo runtime.
Las transiciones aprobadas de versiones antiguas se conservan, no se acepta Compose arbitrario.
Puede haber una interrupción breve. Si el intento anterior quedó incompleto, revisar punto
de fallo, estado efectivo, respaldo y nueva línea base antes de reintentar; no restaurar a ciegas.

## Aceptación

- Exigir phase=complete, todas las etapas y versiones objetivo; readiness HTTP 200.
- Contrastar cuenta protegida, conteos, esquema y huella auto-unseal sin disminuciones indebidas.
- Probar API externa autenticada con alcances mínimos, navegador, inventario y reportes reales.
- Validar la exclusión != con alertas nuevas sin el campo, manteniendo los demás requisitos.
- Los recibos históricos no se reprocesan automáticamente; no se amplían tenant ni alcances.

## mTLS interno

```bash
sudo /usr/local/sbin/soc-lab-tenant-provisioner tls-status
sudo systemctl is-active soc-deploy-tls-renew.timer
sudo systemctl list-timers soc-deploy-tls-renew.timer --all --no-pager
sudo systemctl show soc-deploy-tls-renew.service -p Result -p ExecMainStatus
sudo journalctl -u soc-deploy-tls-renew.service -n 80 --no-pager
```

Timer cada seis horas, anticipación siete días, vigencia 30 días. Antes del umbral informa
not due sin recrear contenedores. Un oneshot exitoso puede quedar inactive (dead): revisar
Result=success y ExecMainStatus=0; no exigir que permanezca ejecutándose. Configurar alertas
del timer, fallo y vencimiento: el timer no envía notificaciones por sí solo.

La coordinación automática requiere Manager/agente y runtime colocados, Compose y montajes
aprobados. **Si están en hosts separados no se distribuyen credenciales automáticamente**:
no realizar rotación parcial, coordinar antes de vencer. No es renovación global del TLS
público, Wazuh, Indexer ni GeoIP. La actualización no fuerza rotación fuera del umbral.

Verificar cadena/propósito y cada identidad con openssl verify, usando -verify_ip y
-verify_hostname por separado y los valores reales. No usar solo el exit code de
x509 -checkip/-checkhost. Clave cliente root:gid 10001 modo 440; servidor root:www-data 440.
El nombre UNKNOWN con gid 10001 no exige cambiar el propietario. Bloqueos privados:
/run/soc-operations-locks root:root 700, archivos regulares root:root 600.

Si falla, detenerse y conservar log, copias y diario privado en
/var/lib/soc-deploy-agent-installer/tls-renewals/. No borrar pending.json, inicializar
OpenBao, hacer compose down, borrar volúmenes ni desactivar mTLS. Conservar paquetes y
respaldos hasta completar la aceptación. Publicar no ejecuta la actualización del destino.
