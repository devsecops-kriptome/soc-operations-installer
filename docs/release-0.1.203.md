# SOC Operations Installer 0.1.203

Instalador 0.1.203; API interna/externa, worker y agente 0.1.146; esquema
a5d9e2c73086. Plugin 0.1.123 conservado byte a byte desde 0.1.202 para OSD
2.19.5 y 2.19.6. Wazuh 4.14.7-1 o 4.14.8-1, AIO o distribuido con un Dashboard.

## Objetivos suplementarios, sin alterar evidencia original

La nueva tabla `case_sla_target_supplements` conserva objetivos de detección,
calificación, investigación y cierre para casos automáticos elegibles. Los
snapshots originales, eventos, duración observada y relojes de respuesta,
ACK y resolución permanecen intactos.

La autoridad se identifica como `operator_attestation`: una confirmación del
operador no se convierte en prueba de vigencia histórica recuperada de la base.
Los lectores de detalle, agregado SLA y rankings aplicables comparten la misma
validación de tenant, caso, severidad, fecha y hash del snapshot base.
Un suplemento obsoleto o inválido se ignora; no sustituye un objetivo nativo.

La respuesta identifica `target_source`, grupos por procedencia y
`data.target_provenance`. La procedencia aplicada no implica cumplimiento.
Objetivos numéricamente iguales pueden tener procedencias distintas sin
dejar de ser uniformes. No cambian los scopes ni se agrega un endpoint de escritura.

## Aplicación controlada, separada del instalador

El instalador solo migra el esquema: la tabla comienza vacía.
No ejecuta planes históricos al instalar, arrancar o consultar métricas.

La herramienta local `soc-sla-target-supplements` valida un plan congelado con
tenant, SHA-256 canónico y cantidad esperada. Por defecto trabaja en solo lectura
y revierte la transacción. Aplicar exige `--apply` y `--approved-by`, mediante el
usuario restringido de la aplicación, sin eludir RLS. Comprueba cambios concurrentes,
rechaza aplicaciones parciales o conflictivas y confirma filas y auditoría en una
transacción. Una repetición exacta es idempotente.

La tabla tiene FORCE RLS, permisos mínimos y controles append-only, incluido
rechazo de UPDATE, DELETE y TRUNCATE. Conservar plan, confirmación y resultado
en evidencia privada; no subir datos de casos ni respaldos a este repositorio.

## Límites del cálculo histórico

Los objetivos suplementarios no recuperan fechas de calificación ni investigación.
MTTQ exige una calificación explícita y MTTI una investigación explícita vinculada
a TP. Un veredicto al cerrar, ACK, comentario, playbook referencial, Resuelto o
Cerrado no inventa esos hitos. Sin evidencia suficiente el resultado sigue
desconocido/no evaluable, no cero ni cumplimiento supuesto.

## Validación local y aceptación pendiente

- 3354 pruebas backend/agente y 497 de interfaz aprobadas, sin fallos ni omisiones.
- 49 comprobaciones de cadena de artefactos con solapamiento, no adicionales únicas.
- PostgreSQL real desechable: RLS con usuario restringido, separación de tenants,
  controles append-only, CLI de solo lectura/aplicación/idempotencia y lectores.
- Cohorte sintética de 274 casos: 216 suplementos, 864 objetivos, 58 casos completos
  preservados y cero hitos inventados; no se conectó a producción.
- Ruff, MyPy y alineación modelo/migraciones aprobados. Imagen y wheel comparados
  contra la fuente; entrypoint externo probado con raíz de solo lectura y UID no root.
- Tres hallazgos medios preexistentes de análisis estático y 13 avisos preexistentes
  de ShellCheck revisados; ningún medio/alto nuevo sin revisar ni error nuevo de shell.

La publicación no instala en servidores. El descifrado con la identidad autorizada,
la aceptación del destino, los accesos autenticados reales y el ensayo de restauración
siguen pendientes. Consulte la [guía de actualización](upgrade-0.1.203.md).

## Artefactos y huellas

Solo se publican `soc-operations-0.1.203.tar.gz.age` y `SHA256SUMS`.
El TAR en claro, código privado, identidades y evidencias privadas no son assets.

| Archivo | SHA-256 |
| --- | --- |
| SHA256SUMS | `0d4fd88795863ce054ee92e94bbaf40064c510ae07794ab410a63543853983a8` |
| soc-operations-0.1.203.tar.gz.age | `b5c000e4e5ec0c7cf94bd5b514eaf4bd265694f0ca3a8b6fddacd5efe6cd834b` |
| soc-operations-0.1.203.tar.gz, después de descifrar | `52e54cb6f075651d010a7841e9e34ef4e2fa152dd0298385adefb464d5b542c2` |

El archivo cifrado contiene 351984029 bytes. Después del descifrado, verificar
estructura y hashes internos: 52 archivos regulares, incluido SHA256SUMS.
La identidad privada se obtiene únicamente del gestor autorizado bajo
`SOC Operations Installer Descifrado`; nunca de GitHub ni del chat.
