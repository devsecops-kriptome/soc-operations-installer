# Actualización a SOC Operations 0.1.190

Instalador 0.1.190; API interna/externa, worker y agente 0.1.133; plugin 0.1.113.
El esquema c8d3e902f751 y el Compose aprobado no cambian desde 0.1.189. Conservar
el perfil Wazuh/OSD del destino: 4.14.7-1/2.19.5 o 4.14.8-1/2.19.6.
Esta guía actualiza instalaciones existentes; no repetir apply ni inicializar OpenBao.

## Preparación

Registrar topología, versiones, salud, Compose, cuenta protegida y conteos.
Crear y verificar un respaldo vigente de PostgreSQL, OpenBao, S3, reportes y
configuración. Custodiar auto-unseal cifrada por separado sin alterar la original.
El respaldo anterior a 0.1.189 no cubre los datos creados después; conservarlo
y preparar uno nuevo. Un respaldo en caliente no es una transacción global ni RPO cero.
Mantener el paquete previo, baselines y logs hasta completar la aceptación.

Descargar el paquete cifrado y SHA256SUMS de
[v0.1.190](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.190).
Verificar las [huellas](release-0.1.190.md), descifrar por el canal autorizado y
verificar el TAR claro. No copiar identidades a chat, argumentos ni logs.
Antes de extraer, rechazar rutas absolutas, '..', duplicados, enlaces y tipos
especiales. Son 49 archivos regulares bajo release-0.1.190. Usar staging privado
nuevo y verificar SHA256SUMS interno; no sobrescribir archivos activos a mano.

## Preflight y actualización

Sin operaciones administrativas concurrentes, con topología y direcciones persistidas:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.190
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" preflight --staging-root "$SOC_RELEASE"
```

Solo con preflight, respaldo y baseline verificados, en ventana autorizada:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.190
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" upgrade --staging-root "$SOC_RELEASE"
sudo /usr/local/sbin/soc-operations-install status
```

Usar upgrade, no apply ni resume. Con Manager remoto, actualizar primero su agente
a 0.1.133 por el flujo distribuido. Puede haber una interrupción breve. No ejecutar
helpers antiguos en paralelo ni cambiar hashes, Compose o permisos para eludir rechazos.
Si falla, conservar el log privado y detenerse; no restaurar a ciegas, hacer compose
down, eliminar volúmenes ni inicializar OpenBao.

## Aceptación del destino

- Exigir phase=complete, todas las etapas completas, versiones objetivo y readiness
  200 de ambas API; contenedores sin reinicios inesperados.
- Comparar esquema, cuenta protegida, conteos y huella de auto-unseal.
- Confirmar reportes compartidos API/worker, temporales de consulta aislados de la
  API externa y consolidados compartidos worker RW / API externa RO.
- Consultar GET /api/v2/technologies/status con tenant_id y technologies:read;
  view=granular entrega data.items[].identity["technology.name"] y no agent.name.
- view=global entrega data.groups[].technology_names del ámbito completo, sin
  depender de la primera página; technology_name conserva la categoría.
- view=both entrega ambos niveles coherentes, incluidos seriales configurados.
- Sin credencial: 401. Sin alcance: 403. Tenant ajeno: 404. Escritura: 405.
  Tecnologías desactivadas y fuentes con 30 días sin actividad quedan excluidas.
- Un nombre ausente queda null, nunca el nombre del colector. Las observaciones
  anteriores se enriquecen al recibir eventos nuevos y ser recopiladas.
- Validar navegador real: nombres globales truncados con hover completo y detalle
  anidado. Configurar exige SOC Manager/Ingeniería; analistas conservan lectura.
- Generar y descargar un reporte Word/Excel, comprobar correo autorizado y edición
  de programaciones para regresión, conservando grupos, agrupación y reportes históricos.

Si el resumen diario de vulnerabilidades devuelve "scope changed; refresh pending",
diagnosticar el estado de recopilación del worker. Esta release no garantiza resolver
esa incidencia y no permite servir un corte de otro alcance ni omitir la validación.

## Controles mTLS conservados

Verificar tls-status, timer, Result/ExecMainStatus y vencimiento como indica la
[guía mTLS de 0.1.188](upgrade-0.1.188.md#mtls-interno). La renovación coordinada
requiere Manager/agente y runtime colocados; no distribuye claves entre hosts.
No equivale a renovar TLS público, Wazuh, Indexer o GeoIP. No borrar diarios de
renovación ni pending.json ante un fallo. No solicitar rotación manual si no corresponde.
