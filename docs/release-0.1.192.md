# SOC Operations 0.1.192

Versiones: API interna/externa, worker y agente 0.1.135; plugin 0.1.115.
Perfiles: Wazuh 4.14.7-1 / OSD 2.19.5 y Wazuh 4.14.8-1 / OSD 2.19.6.
Esquema objetivo: a42f71c6e309, con migración desde d0f6a3b9e214.
La actualización de SOC Operations no actualiza los paquetes de Wazuh.

Reportes de vulnerabilidades: primero se elige Agrupación del inventario y después
Grupos de endpoints o Hosts. El modo hostname permite seleccionar de 1 a 10 hosts
del tenant; no se mezcla con grupos ni con ALL. Los UUID y las etiquetas se validan
en el servidor y se revalida el alcance al ejecutar una programación. Un host
inactivo, ajeno o ambiguo no amplía silenciosamente el informe.
Excel genera una hoja por host, con estructura Host > paquete; conserva los hosts
seleccionados sin hallazgos. Word, correo e historial muestran el alcance coherente.

Cada ejecución programada se identifica por su instante scheduled_for, no solo
por el período del informe. Se conserva el historial previo con scheduled_for NULL;
no se inventan fechas ni se generan ejecuciones históricas automáticamente.
Las métricas de remediación respetan tenant, cluster y host; las identidades ambiguas
no se mezclan. Los snapshots de comparación deben ser estrictamente anteriores.

Los reintentos del mismo envío manual usan send_request_id y no duplican correos;
otro envío explícito requiere otro identificador. Reutilizar el identificador con
destinatarios distintos devuelve conflicto. Se corrigen carreras en la creación
inicial del perfil de reportes y el orden de bloqueo al eliminar programaciones,
preservando la transacción, auditoría y FORCE RLS.

Grupos predeterminados para nuevas instalaciones/reconciliación:
Endpoints-Windows, Servers-Windows, Endpoints-Linux, Servers-Linux,
Endpoints-MacOS, Servers-MacOS, Prod, Dev y APPs.
Los grupos antiguos siguen siendo reconocidos. No se renombran, eliminan ni
reasignan automáticamente grupos o miembros existentes, ni se cambia el tenant.

Conserva las correcciones de correlación de 0.1.191: checkpoint persistente,
Scroll completo, transacciones pequeñas, deduplicación y aislamiento por tenant.
technology.id conserva su origen en los campos personalizados; decoder.name es
independiente. El primer sondeo usa ahora menos lookback; no hay replay histórico.

Se recompilan imagen, wheel y plugins de ambas plataformas y se verifican sus pins.
No se cambian Compose, firewall, auto-unseal ni la política de TLS.
Generar o subir el instalador no significa desplegarlo. La aceptación autenticada,
el navegador real, el reporte real y el descifrado corresponden al destino autorizado.

## Integridad

- Instalador cifrado SHA-256: `833bc637c2561e79045d3fe53a46c34a6fecae441dddbbc76eecbebe649dc223`.
- TAR claro SHA-256: `629e2417b98276f5be28e0e4215fcc06c24aba0d7d8c66b76f7a15c7e05a9a3c`.
- Orquestador SHA-256: `f3ea0f6a730c8c0eb14f9df845c26f1f28ecf80cf0408bd300f75f48cb362e84`.
- Compose SHA-256: `321c80c77b83debfd1bd934fad9871c850dd4bdd81d9980d36337828e1537445`.
- Imagen config ID: `sha256:cba40753327d59ed6cde2bb5d2e3942383c4f663e3274efb425b96f7ea0e8b97`.
- Imagen manifest ID: `sha256:b2a67ab5dd3758d48f483fc1b748b934c8942e0e4727ba63fe9c795ca755f40b`.

El TAR contiene 49 archivos regulares bajo release-0.1.192, incluido SHA256SUMS.
Solo se publican el instalador cifrado, hashes y documentación pública. La identidad
privada age no se usa ni se publica. El receptor debe verificar el descifrado.

## Validación local

2259 pruebas únicas aprobadas: 1912 de backend/agente,
340 del frontend y 7 adicionales. Sin fallos ni omisiones. Ruff y MyPy aprueban
(126 archivos fuente); TypeScript y plugins exactos 2.19.5/2.19.6 aprueban.
La suite completa usa PostgreSQL desechable con FORCE RLS y pruebas de concurrencia.
Los pins finales se revalidan después de compilar ambos plugins.

Imagen y wheel coinciden con las fuentes en 125 archivos Python; 60 archivos de
migración/configuración coinciden. pip check aprueba. La API externa real arranca
sin red, como UID 10001 y raíz read-only: salud 200, ocho rutas sin clave 401 y
escrituras 405. ShellCheck no tiene errores ni avisos nuevos; conserva 13 previos.
Persisten avisos de deprecación de dependencias de pruebas, Browserslist del SDK
y Babel por el tamaño de app.tsx; no se omiten comprobaciones por estos avisos.

La validación local no sustituye el Indexer, SMTP, navegador, reporte real y aceptación
autenticada del destino. No se ha instalado en ningún servidor ni se han reproducido
alertas históricas. Ver [actualización y aceptación](upgrade-0.1.192.md).
