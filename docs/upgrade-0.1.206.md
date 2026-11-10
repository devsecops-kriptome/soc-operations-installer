# Actualización a SOC Operations Installer 0.1.206

Desde 0.1.204: runtime y agente 0.1.149, plugin 0.1.126,
esquema d8a215c963b7. Incluye la base del candidato local 0.1.205.
No ejecutar una instalación limpia sobre datos existentes.

## Antes de actualizar

1. Registrar versiones, salud, topología, configuración y estado habilitado/deshabilitado
   de Threat Radar. Conservar deployment_id, direcciones, proxy autorizado, TLS y secretos.
2. Crear un respaldo nuevo verificado de PostgreSQL, OpenBao, versiones S3, reportes,
   snapshots publicados y configuración. Custodiar la clave auto-unseal cifrada por
   separado. Descubrir montajes reales; no asumir que rutas internas existen en el host.
   Un respaldo en caliente no es una captura atómica entre sistemas ni prueba restauración.
3. Revisar el alcance de seguridad y los riesgos residuales descritos en las
   [notas](release-0.1.206.md). El preflight ahora comprueba el baseline aprobado
   de paquetes Ubuntu/Nginx. Si lo rechaza, detener; no omitir el control ni cambiar
   paquetes del host sin una tarea autorizada específica.
4. Descargar únicamente los dos assets del tag v0.1.206 y verificar SHA256SUMS
   contra la huella de las notas antes de comprobar el archivo cifrado.
5. Descifrar con identidad autorizada, sin mostrarla, guardarla ni pasarla como
   argumento. Validar el TAR en claro, tipos, rutas y hashes antes de extraerlo
   en un staging nuevo protegido. No reemplazar el instalador activo todavía.
6. Ejecutar el preflight del paquete con la topología persistida y conservar evidencia.

## Actualización controlada

Usar `upgrade`, no `apply`, inicialización de OpenBao, borrado de volúmenes ni
reinstalación limpia. El agente del Manager debe reconciliarse antes del runtime.
Registrar salida, código de retorno y horas de inicio/fin en evidencia privada.
No mezclar helpers, hashes, plugin o wheel de releases diferentes.

OpenBao pasa de 2.6.2 a 2.7.2; la actualización sintética y restauración de snapshot
anterior se probaron en el candidato base. No se validó ejecutar el binario antiguo
contra datos Raft ya migrados: rollback requiere el respaldo original coordinado.
PostgreSQL mantiene la versión mayor 17 y no ejecuta ALTER EXTENSION automático.
MinIO se conserva con su artefacto offline, sin descarga ni reemplazo.

Actualizar no habilita Threat Radar ni debe deshabilitar una activación manual
previa. Solo Ingeniería cambia esa opción. Las opciones Slack son independientes
de las de correo y no usan menciones de guardia.

## Aceptación posterior

- Instalador phase=complete; API/externa/worker/agente 0.1.149, plugin 0.1.126,
  esquema d8a215c963b7 y UI build 0.1.126-threat-radar-mail-period-and-source-errors.
- Readiness, gateway, OpenBao no sellado, auto-unseal, cuenta protegida, datos,
  configuración, montajes y controles de acceso conservados. Revisar la rotación
  esperada del marcador proxy sin mostrar secretos.
- Ingeniería puede cambiar habilitación; SOC Manager activo puede administrar;
  lectores ven solo publicaciones compartidas, no cartera/configuración privada.
  Deshabilitado, el módulo no debe exponer contenido a ninguno de esos perfiles.
- Probar período activo, Último mes, modal personalizado y actualización del panel.
- Probar alertas/resumen HTML y alternativa de texto en Outlook/SMTP con destinatarios
  autorizados. Los contactos de la cartera no se agregan a destinatarios ni CC.
  Slack no recibe cartera privada. No activar envíos reales sin autorización.
- Una respuesta nueva HTTP 403 debe mostrar acceso denegado por la fuente.
  No esperar que el cambio resuelva el bloqueo de red ni reinterprete errores antiguos.
- No repetir recuperación, recálculo ni validación histórica SLA de versiones previas.
  No aplicar planes otra vez ni reconstruir hitos. La protección general del respaldo
  y la integridad de los datos siguen siendo necesarias.

Si hay diferencias no justificadas, detener y conservar evidencia; no reparar ni
reiniciar automáticamente. La publicación no despliega ni cambia Wazuh o la red.
