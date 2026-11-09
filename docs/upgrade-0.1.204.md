# Actualización a SOC Operations Installer 0.1.204

Desde 0.1.203: runtime y agente 0.1.147, plugin 0.1.124,
esquema c7f104b952a8. No ejecutar una instalación limpia sobre datos existentes.
Esta versión no incluye las correcciones de vulnerabilidades posteriores ni Slack.

## Preparación

1. Registrar versiones, salud, topología y configuración reales del destino.
   Mantener deployment_id, direcciones, proxy autorizado, TLS y credenciales.
2. Crear un respaldo nuevo verificado: PostgreSQL, OpenBao, versiones S3,
   reportes, snapshots publicados, configuración, planes y auditorías SLA.
   Custodiar la clave auto-unseal cifrada por separado. No borrar respaldos,
   volúmenes ni estado anterior. Un respaldo en caliente de varios componentes
   no es una captura atómica entre sistemas ni prueba una restauración completa.
3. Descubrir los montajes Docker reales. Los snapshots publicados pertenecen
   al volumen del worker compartido con la API externa; no asumir que la ruta
   interna del contenedor existe en el host o está montada en la API interna.
4. Descargar los dos assets del tag v0.1.204. Fijar la huella de SHA256SUMS
   indicada en las notas antes de usarlo. Validar el archivo cifrado.
5. Descifrar con identidad autorizada, sin mostrarla, guardarla ni pasarla como
   argumento. Verificar el TAR en claro, tipos y rutas antes de extraer a un
   staging nuevo protegido. Validar los 53 archivos y hashes internos.
6. Ejecutar preflight con el instalador del paquete y la topología persistida.
   No reemplazar el instalador activo antes de superar las comprobaciones.

## Actualización controlada

Usar `upgrade`, no `apply`, reinstalación limpia ni inicialización de OpenBao.
En distribuido, verificar la reconciliación del agente del Manager antes del
runtime; en AIO se reconcilia el agente local. No mezclar versiones.
Registrar salida, código de retorno y horas de inicio/fin en evidencia privada.
Si falla una fase, detener y revisar; no borrar el estado para forzar reintentos.

Las migraciones agregan las tablas de Threat Radar y su proyección JSONB.
El módulo permanece deshabilitado por defecto. No recopila publicaciones ni
envía alertas mientras está deshabilitado; actualizar no lo habilita.
No ejecutar planes SLA otra vez: conservar y verificar los suplementos y
recuperaciones previas. No inventar fechas MTTQ/MTTI a partir de cierres o ACK.

## Aceptación

- phase=complete, API/externa/worker/agente 0.1.147 y plugin 0.1.124.
- Esquema c7f104b952a8 y UI build
  0.1.124-threat-radar-jsonb-and-semantic-cards.
- Readiness, gateway, OpenBao y auto-unseal; cuenta protegida, conteos,
  integridad por tenant, configuración y suplementos previos conservados.
- Comparar detalle, agregado SLA y rankings con la misma cohorte y fecha de
  evaluación. No esperar duraciones nuevas de hitos históricos inexistentes.
- Radar inicialmente deshabilitado: menú y endpoints de contenido no disponibles.
  Solo Ingeniería puede habilitar/deshabilitar. Al habilitar, probar dashboard
  desde tenants autorizados y denegación de administración/cartera a lectores.
- Probar fuentes y SMTP con destinatarios autorizados antes de activar envíos.
  Primera recopilación sin alertas históricas; no contactar clientes automáticamente.
- Conservar evidencias y backups. No hacer downgrade binario ni restaurar una
  base antigua sin evaluar las migraciones y datos posteriores al respaldo.

La publicación no despliega, no cambia permisos, no actualiza Wazuh y no autoriza
por sí sola pruebas que envíen correos reales o modifiquen datos de clientes.
