# SOC Operations Installer 0.1.206

Instalador 0.1.206; API interna/externa, worker y agente 0.1.149;
plugin 0.1.126; esquema d8a215c963b7. Perfiles Wazuh 4.14.7-1/OSD 2.19.5
y Wazuh 4.14.8-1/OSD 2.19.6, AIO o distribuido con un Dashboard.

## Cambios de Threat Radar

- Alertas y resumen de estado con HTML y alternativa de texto. Usa el SMTP de
  SOC Operations con nombre de remitente Threat Radar.
- Cruces de tecnologías destacados para evaluar aviso al cliente; no confirman
  afectación ni agregan contactos de la cartera como destinatarios o CC.
- Contenido de correo reconstruido desde datos vigentes antes del envío;
  cambios de permisos, fuentes, destinatarios o deshabilitación invalidan envíos obsoletos.
- Estados en español y fechas legibles. Los nuevos HTTP 403 se identifican como
  acceso denegado por la fuente; los errores antiguos genéricos no se reinterpretan.
- Enlace Actualizar bajo la frecuencia, período seleccionado resaltado,
  Último mes y rango personalizado mediante modal, sin desplazar el dashboard.
- Slack opcional con controles independientes para alertas y resumen, inicialmente
  deshabilitados. No incluye cartera privada ni menciones de guardia.
- Módulo deshabilitado por defecto en instalaciones nuevas; conserva el estado
  existente al actualizar. Solo Ingeniería cambia la habilitación; Ingeniería y
  SOC Manager activo administran. Lectores autenticados ven publicaciones compartidas,
  no contactos ni configuración privada. PostgreSQL JSONB conserva hasta 12 meses calendario.
- Correcciones de tipado de etiquetas de errores y estado, sin modificar sus reglas.

No elimina el bloqueo HTTP 403 remoto de CISA, no cambia URLs para eludirlo ni
envía automáticamente alertas históricas en la primera recopilación.
No aplica planes, recalcula datos ni reconstruye hitos SLA de versiones previas.
No se requiere repetir la aceptación histórica SLA de aquellas entregas.

## Base de seguridad y límites

Incluye el candidato local 0.1.205, que no fue publicado. Los artefactos anteriores
se conservan sin sobrescribir. Actualiza la base Python 3.12.16 y las dependencias
fijadas del candidato; OpenBao pasa a 2.7.2 y PostgreSQL mantiene su versión mayor
17 con pgvector 0.8.7. No ejecuta ALTER EXTENSION automáticamente.

El preflight verifica paquetes Ubuntu/Nginx y backports aprobados; puede bloquear
un host desactualizado antes de cambiar servicios. No parchea el host automáticamente.
No actualiza Wazuh ni certifica versiones nuevas del stack Wazuh/OSD.

**No se presenta como una pila libre de vulnerabilidades.** MinIO y mc se conservan
como artefactos offline existentes de julio de 2025: no se descargan ni sustituyen.
Mantienen riesgos propios y de Go, pendientes de una reconstrucción mantenida o
migración S3 autorizada. Persisten avisos en dependencias de OpenBao, paquetes base
sin corrección disponible y el Go antiguo de gosu en la imagen PostgreSQL; su
alcanzabilidad debe revisarse, no equivale automáticamente a exposición del motor.
No se agregaron exclusiones generales para ocultar esos riesgos.

La actualización sintética del candidato base validó Raft, tokens, cifrado,
auto-unseal y restauración del snapshot anterior en OpenBao 2.7.2. No validó volver
al binario antiguo sobre datos ya migrados; rollback requiere el respaldo original.

## Validación local

3.563 pruebas backend/agente, 192 de cadena de artefactos y 525 de interfaz
aprobadas, sin fallos ni omisiones finales. La primera ejecución de interfaz
agotó un timeout bajo carga de compilación; la ejecución final con concurrencia
limitada aprobó sin cambiar las pruebas ni ampliar sus timeouts.

Ambos plugins compilados para su plataforma exacta; wheel, imagen y fuentes
coinciden. Ruff/MyPy aprobados; sin hallazgos SAST medios/altos nuevos sin revisar
y sin hallazgos ShellCheck nuevos. Los patrones preexistentes revisados permanecen
visibles. Se probaron migraciones y controles con PostgreSQL desechable y arranque
de la API externa sin red, como usuario no root y con raíz de solo lectura.
La regresión amplia conserva pruebas de contratos generales; no equivale a
recalcular o aceptar SLA históricos productivos.

Outlook real, SMTP/Slack reales, fuentes desde la red del destino y aceptación
autenticada del servidor siguen pendientes. Publicar no despliega.

## Artefactos públicos

Solo el instalador cifrado y SHA256SUMS, nunca el TAR en claro, código privado,
respaldos, datos de clientes o identidad de descifrado.

| Archivo | SHA-256 |
| --- | --- |
| SHA256SUMS | `0e3826c66ff55621d74fc4ca6ea93db87c9a10d14cc17ab29330e665eac14576` |
| soc-operations-0.1.206.tar.gz.age | `daf51ee033729784b71971b99a5372e11ace1d22ffd7a261dade0fb3b60113c4` |
| soc-operations-0.1.206.tar.gz, tras descifrar | `ee1716c44d0109c3a26bfc6ef1820e418398266fe77acf389bde3f20158f6ad5` |

Paquete cifrado: 352523459 bytes. TAR interno: 56 archivos regulares, incluido SHA256SUMS.

La identidad privada continúa en el gestor autorizado, entrada SOC Operations
Installer Descifrado. No se utilizó para construir ni se publica; la comprobación
de descifrado por el operador queda pendiente. Antes de instalar, seguir la
[guía de actualización](upgrade-0.1.206.md) y verificar un respaldo nuevo.
