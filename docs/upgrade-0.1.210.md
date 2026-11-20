# Actualización controlada a 0.1.210

Usar upgrade para la instalación existente; no ejecutar instalación limpia.
Estas instrucciones no ejecutan cambios ni sustituyen una ventana autorizada.

1. Confirmar host, versión instalada, topología, readiness, espacio disponible,
   ventana y plan de reversión. Conservar la cuenta institucional protegida.
2. Crear un respaldo nuevo verificado de PostgreSQL y roles, OpenBao, objetos S3,
   reportes, snapshots y configuración. Cifrar y custodiar auto-unseal por separado.
   Un respaldo en caliente no es una instantánea atómica entre servicios;
   respaldo solo local y restauración no probada son riesgos explícitos.
3. Descargar SHA256SUMS y `soc-operations-0.1.210.tar.gz.age` de esta release.
   SHA-256 del archivo cifrado:
   `75ac9d04ef14a0b1ee0e8c968d11cdf8fdf37a9f078859b22e074a30422ecf1b`.
4. Descifrar con la identidad age autorizada existente, usando entrada oculta.
   Nunca enviar la identidad, contraseñas o tokens al chat, argumentos o historial.
   Comprobar el hash del TAR claro antes de inspeccionarlo o extraerlo.
5. Revisar rutas, tipos y duplicados del TAR. Extraer en un staging nuevo y
   verificar todos los hashes internos. Conservar el instalador activo hasta
   completar el preflight y guardar un baseline inmediato de datos/configuración.
6. Ejecutar upgrade según la topología real con confirmación y logs privados.
   Puede reiniciar componentes; no interrumpir. Si se requiere actualizar políticas
   OpenBao, introducir el token autorizado solo en el prompt oculto del servidor.
   No repetir bootstrap, desellar con otra clave ni reinicializar OpenBao.
7. Confirmar instalador 0.1.210 completo, runtime/agente 0.1.152, plugin 0.1.130,
   esquema f0c437e185d9, plataforma correcta, identidad de imagen y readiness.
   Según Docker, contrastar el ID de configuración o de manifiesto correspondiente.
8. Comparar datos e integridad entre tenants, huellas de históricos, cuenta
   protegida, configuración crítica y estado previo de Threat Radar. No aplicar
   recuperaciones ni recalcular métricas SLA como requisito de instalación.
9. Validar menú, rutas y refresco autenticados por rol, Global/tenant y acceso
   denegado a tenants no autorizados. Mantener las vistas abiertas varios ciclos
   y cambiar tenant para comprobar que respuestas antiguas no mezclan datos.
10. Mantener Activos, reputación y notificaciones sin activar hasta revisar sus
    identidades dedicadas, canales, TLS y permisos. Usar las plantillas Indexer
    incluidas, no una cuenta administrativa general. Configurar AbuseIPDB después
    desde Administración → Integraciones; la clave se almacena en OpenBao.
11. Probar lectura y guardado autorizado a través del proxy/WAF real. Si se
    rechazan rutas nuevas, conservar el diagnóstico y revisar reglas específicas
    de método/ruta. No desactivar WAF, CSP ni validación global.

Si falla un control, detener la aceptación, conservar evidencia y revisar la
reversión con respaldos e imágenes previos. No borrar volúmenes ni improvisar
cambios de roles. No se afirma que restauración o integraciones reales estén
validadas por la publicación de esta release.
