# Release 0.1.167 — programación SOC y disponibilidad global L3

Instalador `0.1.167`; API/worker/agente `0.1.118`; plugin `0.1.98`;
build `0.1.98-global-engineer-workforce`. Perfiles Wazuh/OSD admitidos sin cambios.

Ingeniería global aparece en la planificación de todos los tenants. SOC Manager e ingenieros
pueden gestionar su disponibilidad compartida desde su ámbito autorizado. No se crean
membresías sintéticas ni permisos sobre cuentas o credenciales. Las políticas PostgreSQL
limitan este acceso a los registros de planificación global; las notificaciones de otro
tenant permanecen privadas y los avisos de vacaciones obsoletos no se envían.

Invitados de Analista, Analista Junior, SOC Manager e Ingeniería pueden programarse antes
de aceptar la invitación, sin activar sus cuentas ni habilitar login. Auditores excluidos.
Desactivación/bloqueo oculta la agenda futura, impide asignaciones nuevas y conserva el
historial concluido. La migración aditiva `a2c8e4f719b6` sigue a `6d9f2b8c1a53` y conserva
la protección del administrador institucional. Guarda la zona horaria histórica de los turnos.

Validación: 564 pruebas backend aprobadas, cinco omitidas por dependencias de integración,
dos avisos de deprecación; 21 pruebas frontend aprobadas con EUI real. Incluye cinco pruebas
de programación global y cinco de protección institucional sobre PostgreSQL desechable con
RLS forzada y usuario sin BYPASSRLS. Ruff, sintaxis Bash, los 48 hashes internos, versiones
de los dos plugins, JS/JS.gz y correspondencia fuentes/wheel/imagen verificados.
39 artefactos de 0.1.166 conservados byte a byte; 0.1.166 no se reemplaza.

SHA-256 del TAR: `59ff558ef1432f54675c32adf0093b8a3c888509be1103bb5afa406d2d8bac02`.
Asset cifrado: `514cb96f7cdba3c4d133d6fa62fb2919854ceedd54057d97f0cddaae813205d9`.
Manifiesto externo: `3ff87fea7dad6ac3729a344fa941d180221e09afb1d1e2000e9cc462cfb9be00`.
Instalador: `c268b127270c6ff63e1c2f0adaf66cb5d579697ce30b85a3be3566d9fd17f2f4`.

Solo se distribuye el paquete cifrado; claves privadas, datos operativos y respaldos no se
publican. La publicación no acredita despliegue ni aceptación en LAUFEY. Seguir la
[guía de actualización supervisada](upgrade-0.1.167-laufey.md), con respaldo NUEVO antes
de migrar. No cambia Wazuh, CSP, WAF ni activa servicios opcionales automáticamente.
