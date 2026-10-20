# SOC Operations 0.1.189


Instalador 0.1.189; API interna, API externa, worker y agente 0.1.132;
plugin socOperations 0.1.112 para OSD 2.19.5 y 2.19.6. Esquema c8d3e902f751,
sin nuevas migraciones. Perfiles Wazuh 4.14.7-1 y 4.14.8-1 respectivamente.

Reportes de vulnerabilidades: el historial presenta Generado, Grupos,
Agrupacion, Acciones y Estado. Se retira solo la columna Instantanea;
la fecha real del corte se conserva. Los grupos largos se truncan en una
linea y se muestran completos al pasar el cursor. ALL es explicito.
No se reconstruye el alcance historico desde el inventario actual.

Programaciones: se sustituye la columna CC por Grupos y Agrupacion.
Un menu de tres puntos permite Editar o Eliminar con confirmacion.
CC se conserva en el formulario y en el flujo de entrega, sujeto a la
configuracion SMTP existente. Se precargan las opciones guardadas,
frecuencia, dias/fecha, hora, zona horaria, destinatarios y estado.
Cancelar no escribe. Eliminar una programacion conserva reportes anteriores.

Nuevo PUT interno /api/v1/operations/report-schedules/{id}, protegido por
SOC Manager del tenant o Ingenieria global, bloqueo de fila y auditoria.
Tenant, dominio, autor y datos historicos no son editables. Un cambio de
grupos o destinatarios conserva la ejecucion pendiente, incluso atrasada;
un cambio de calendario o reactivacion recalcula la siguiente fecha.
No se agrega un endpoint de escritura a la API externa ni nuevos alcances.

Los mensajes de correo manuales y programados incluyen los grupos,
agrupacion y corte guardados en el reporte, no las selecciones actuales.
El formato comun de otros canales representa estos datos sin habilitar
nuevas entregas o fan-out. Se conserva el DELETE 204 sin cuerpo.
Se corrigen los caracteres mal codificados del aviso de reporte en espera.

Imagen, wheel y ambos plugins se recompilan. Se conserva el Compose
aprobado y las correcciones de TLS, renovacion, permisos y filtros de
0.1.188. No cambian RBAC existente, puertos, UFW, claves ni auto-unseal.

Solo publicar TAR cifrado, hashes y documentacion publica. El destinatario
age no cambia; el descifrado requiere su identidad autorizada. Publicar no
actualiza servidores. Las notas publicas de la version contienen las huellas
y la guia de actualizacion con sus condiciones de aceptacion.

## Integridad

- Instalador cifrado SHA-256: `e384ada0f0906aff25be5ef0e26e4da72def143f368e5e053a35d69eef3b2698`.
- TAR claro: `656c25323742edb8361d61345218ab19011b1f1cbaea8302091638b50e66de37`.
- Orquestador: `06fb20c760a9a2446def3b6efca5e66be6121c355e630228f7b46a939673a838`.
- Compose: `321c80c77b83debfd1bd934fad9871c850dd4bdd81d9980d36337828e1537445`.
- Imagen config ID: `sha256:fd4730e9b6588ade15737fcffc3582f425fc915d5f31206f6c5e0a8e911e174a`.
- Imagen OCI manifest ID: `sha256:8a9cd0fed5c97283404c797472bc9b5c905213452a4aa5ce34bbc1f0aa9633e3`.

El TAR contiene 49 archivos regulares bajo release-0.1.189, incluido SHA256SUMS.
Se publican el paquete cifrado, hashes y documentación; la identidad privada de
descifrado permanece en el gestor autorizado. Los hashes no sustituyen la
autenticidad del canal de distribución.

## Validación local

2058 pruebas aprobadas: 1709
backend/agente, 328 del plugin y 21 comprobaciones adicionales de PostgreSQL/RLS
y mensajes. Sin fallos ni omisiones. Los subconjuntos repetidos no se suman dos veces.
Ambos perfiles se compilan y verifican con TypeScript; mypy revisa 123 archivos
y Ruff aprueba. Imagen, wheel y fuentes coinciden en 122 archivos Python;
58 archivos de migración/configuración coinciden y pip check aprueba.

Las pruebas adicionales ejercitan el PUT real con un rol PostgreSQL NOBYPASSRLS:
Manager e Ingeniería autorizados, lectores/admin/auditor rechazados y tenant
ajeno no visible. La edición espera el bloqueo de fila del worker y conserva
su próxima ejecución. Los formatos de Slack/Discord/Telegram/Jira/Trello se
comprueban con transporte simulado, sin habilitar entregas nuevas.

La API externa real se inicia aislada, como UID 10001, con raíz read-only y sin
red externa: salud 200, ocho rutas sin clave 401 y escrituras rechazadas 405.
PostgreSQL y SMTP usan datos sintéticos/transporte simulado; la interfaz usa
DOM automatizado, no aceptación en el navegador productivo.

La implementación TLS se conserva byte a byte salvo constantes de release del
provisionador. Sus pruebas Linux reales se referencian desde 0.1.188; no se
presentan como una nueva instalación completa. La sintaxis de 13 helpers y
ShellCheck se repiten sin errores ni hallazgos nuevos; persisten avisos previos.

## Actualización

Seguir la [guía 0.1.189](upgrade-0.1.189.md), con respaldo vigente y ventana
autorizada. Publicar no actualiza LAUFEY ni sustituye la aceptación del destino.
No es necesario instalar 0.1.188 como paso intermedio. Con Manager remoto,
actualizar primero su agente a 0.1.132 mediante el flujo de la topología.
