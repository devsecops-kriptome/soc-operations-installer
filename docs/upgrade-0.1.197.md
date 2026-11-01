# Actualización a SOC Operations 0.1.197 — AIO y distribuido

1. Registrar hostname, instalador, phase=complete, topología, deployment_id,
   direcciones persistidas, versiones Wazuh/OSD, esquema, servicios y espacio.
2. Crear un respaldo NUEVO de PostgreSQL, OpenBao, objetos/versiones, reportes,
   snapshots publicados y configuración. Verificar integridad y descifrado.
   Custodiar auto-unseal por separado y conservar el original y el respaldo anterior.
   Registrar baseline de cuenta protegida, conteos y reglas de automatización.
3. Descargar SHA256SUMS y soc-operations-0.1.197.tar.gz.age desde la release oficial.
   Verificar hashes, descifrar en un directorio privado nuevo y verificar el TAR claro.
   La identidad autorizada se obtiene del gestor de secretos; no se publica.
4. Inspeccionar rutas, tipos, duplicados y ausencia de enlaces antes de extraer.
   Verificar SHA256SUMS interno y usar staging privado release-0.1.197.
5. Ejecutar preflight con identidad y direcciones existentes. Comprobar respaldo,
   espacio y ventana de mantenimiento antes de upgrade. No sustituir upgrade por
   apply/resume. En distribuido el agente del manager debe quedar en 0.1.140
   antes del runtime; el instalador reconcilia el agente cuando es local.
6. Ejecutar soc-operations-install upgrade --staging-root RUTA_VERIFICADA,
   conservando service-address, external-proxy-cidr y topología del destino.
   No copiar direcciones, rutas privadas ni baseline de otro servidor.
7. Confirmar phase=complete, instalador 0.1.197, runtime/agente 0.1.140,
   plugin 0.1.119, build 0.1.119-case-ui-and-escalation-attachments y esquema
   f97dc8e12543. Comparar cuenta protegida, conteos, reglas, topología y API externa;
   comprobar auto-unseal, readiness, TLS/timer, versiones y reinicios.
   Desde 0.1.196 no hay migraciones nuevas. Desde versiones anteriores se aplican
   las pendientes; no se reconstruyen hitos ni se reprocesan alertas históricas.
8. Abrir la gestión de casos y verificar cabecera, Volver y pestañas. Probar ambos
   enlaces de vinculación desde Eventos relacionados y Casos relacionados,
   incluyendo usuario de lectura, caso hijo, archivado y restricciones de ACK.
9. En un caso controlado, registrar escalamiento por correo con destinatario
   y copias autorizados, incluidos contactos externos del tenant cuando corresponda.
   Probar adjuntos admitidos y rechazo del total mayor de 25.000.000 bytes.
   Verificar que el proxy permita un POST JSON de hasta 36.000.000 bytes en el
   endpoint de escalamiento y que el SMTP admita el tamaño del mensaje MIME.
10. Verificar correo recibido, Para/CC y adjuntos. Abrir Escalamiento: último correo
    primero, contenido de solo lectura, anterior/más reciente y estado de envío.
    Los correos previos sin copia original no pueden recuperarse desde la plantilla.
    La aceptación SMTP no confirma llegada a bandeja; revisar Message-ID antes de
    reenviar entregas inciertas. No ejecutar reenvíos o jobs a ciegas.
11. Completar aceptación de permisos y aislamiento, API externa autenticada,
    polling y un reporte real. Conservar logs privados, staging y respaldos hasta aceptar.

El paquete no modifica servidores hasta ejecutar expresamente el instalador.
