# Actualización a SOC Operations Installer 0.1.203

Desde 0.1.202: instalador 0.1.203; API interna/externa, worker y agente 0.1.146;
plugin 0.1.123 sin cambios; esquema a5d9e2c73086.

## Antes de actualizar

Registrar estado, versiones, salud, conteos y configuración. Crear un respaldo
nuevo verificado de PostgreSQL, OpenBao, objetos S3 versionados, reportes,
snapshots publicados y configuración. Custodiar auto-unseal cifrada por separado.
Conservar también planes, confirmaciones y evidencias anteriores. No eliminar
respaldos, volúmenes ni estado del instalador. Un respaldo en caliente de varios
componentes no equivale a una captura atómica entre sistemas ni a un ensayo de restauración.

Descubrir los montajes Docker reales: las rutas de almacenamiento dentro del
contenedor pueden ser volúmenes con nombre y no existir en la misma ruta del host.
Los snapshots completos pertenecen al volumen compartido del worker y API externa;
la ausencia de ese montaje en la API interna no prueba pérdida de snapshots.

Descargar los dos assets del tag v0.1.203. Fijar primero la huella del manifiesto
de las notas, validar el cifrado, descifrar con identidad autorizada sin mostrarla
ni pasarla como argumento y validar el TAR en claro. Antes de extraer, validar
tipos y rutas del TAR en un staging nuevo protegido. Comprobar los 52 archivos
regulares con SHA256SUMS interno y ejecutar preflight contra la topología persistida.

## Actualización y esquema

Usar `upgrade`, no `apply`, instalación limpia ni inicialización de OpenBao.
Conservar deployment_id, direcciones, proxy autorizado, credenciales y TLS propios
del destino. En distribuido, actualizar/verificar el agente del Manager a 0.1.146
antes del runtime; en AIO se reconcilia el agente local. No mezclar versiones.

La migración a5d9e2c73086 parte de f4b8cae32175 y crea la tabla vacía de objetivos
suplementarios con FORCE RLS y controles append-only. **No aplica ningún plan**,
no reconstruye hitos ni modifica snapshots originales o filas de casos.
El plugin 0.1.123 y su marcador UI se conservan sin cambios.

Si una fase falla, conservar la evidencia y revisar antes de reintentar. No
restaurar una base antigua ni hacer downgrade directo para deshacer suplementos:
evaluar el esquema, la auditoría, los datos nuevos y el respaldo con un plan separado.

## Aceptación antes de aplicar datos históricos

- Verificar phase=complete, API/externa/worker/agente 0.1.146, plugin 0.1.123,
  esquema a5d9e2c73086 y UI build 0.1.123-sla-ranking-and-tenant-isolation.
- Confirmar readiness, gateway, OpenBao, auto-unseal, cuenta protegida, conservación
  de conteos/configuración y las recuperaciones de alerta inicial ya existentes.
- Confirmar que `case_sla_target_supplements` sigue vacía y sus controles están activos.
- Probar acceso autenticado, scopes y denegaciones entre dos tenants; los controles
  estructurales no sustituyen las pruebas funcionales con credenciales reales.
- Comparar lectores detalle/agregado y métricas previas: antes de aplicar un plan,
  los casos sin objetivos o hitos no deben cambiar a cumplimiento supuesto.

## Aplicación histórica posterior, explícita y separada

Primero revisar el plan congelado, su SHA-256 canónico, tenant, cantidad, snapshot
base y confirmación del operador. Distinguir esa confirmación de evidencia histórica
de la base. Consultar `RECUPERACION-OBJETIVOS-SLA.txt` del paquete verificado y
`soc-sla-target-supplements --help` para la interfaz de la herramienta.

Ejecutar primero la validación de solo lectura con `--plan`, `--tenant`,
`--expected-sha256` y `--expected-count`. No confundir el hash canónico interno del
plan con el SHA-256 del archivo. Aplicar solo con autorización de esa etapa,
`--apply` y responsable `--approved-by`, usando el usuario restringido de aplicación.
Conservar el resultado de commit y verificar una repetición exacta idempotente.

Después comparar casos/eventos/snapshots originales, filas de suplementos y auditoría,
lectores de detalle/agregado, objetivos, procedencia y porcentajes. La respuesta
debe distinguir objetivos nativos de `operator_confirmed_supplement`; un suplemento
obsoleto/alterado no debe utilizarse. Los relojes MTTR/ACK/resolución se preservan.

MTTQ/MTTI sin hitos explícitos permanecen sin dato aunque exista objetivo.
No derivar fechas de playbooks, cierre, comentarios o ACK. No registrar hitos nuevos
con fechas históricas ni ejecutar SQL directo para saltar los controles.

Publicar o instalar esta versión no autoriza por sí solo la aplicación de un plan.
