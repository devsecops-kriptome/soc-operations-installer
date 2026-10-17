# Actualizar SOC Operations desde 0.1.176 o 0.1.177 a 0.1.178

Versiones esperadas: instalador 0.1.178; API/API externa/worker/agente 0.1.128;
socOperations 0.1.107. About conserva `0.1.107-ack-analyst-dashboard-routing-case-details`.
El esquema permanece e31a7f82c940; no hay migraciones nuevas desde estas versiones.

## Preparación sin detener servicios

1. Descargar el asset cifrado y SHA256SUMS de v0.1.178 y comparar huellas con las
   [notas de versión](release-0.1.178.md). Obtener la identidad por el canal autorizado; no
   compartirla en el chat ni registrarla en consola/logs.
2. Descifrar a un destino privado nuevo. Verificar hash del TAR, tipos y rutas antes de extraer:
   rechazar enlaces, rutas absolutas, duplicados y componentes `..`. Validar hashes interiores.
   No sobrescribir el staging anterior ni el orquestador activo antes de completar el preflight.
3. Ejecutar el preflight del staging nuevo con la topología persistida, manteniendo servicios.
4. Crear respaldo NUEVO en caliente: dump PostgreSQL legible, snapshot Raft OpenBao autorizado,
   versiones exactas de objetos, reportes, configuración y baseline. No tratar copias de los
   directorios internos de bases activas como snapshots consistentes.
5. Verificar espacio actual, hashes, lectura y estructura; cifrar y comprobar descifrado.
   Custodiar auto-unseal por separado con otra contraseña, conservando el original intacto.
   Registrar el instante de cada componente y acordar el punto de recuperación.

Consultar el [modelo de respaldo y recuperación](backup-and-restore.md). Una copia solo local
no cubre la pérdida del host; se recomienda otra copia protegida fuera del servidor. Un respaldo
caliente no garantiza instantánea atómica de todos los componentes ni captura escrituras futuras.

## Ventana de actualización

Capturar conteos y cuenta protegida inmediatamente antes de actualizar y evitar nuevas escrituras
de usuarios durante la ventana. En distribuido, actualizar primero el agente del Manager a
0.1.128 con el wheel y hashes del mismo release según el
[procedimiento distribuido](distributed-installation.md). Después ejecutar `upgrade` en el
Dashboard con el staging nuevo y la topología existente. En AIO el orquestador reconcilia el agente
local antes del runtime. La recreación de servicios puede causar una interrupción breve.

No usar instalación limpia, `apply`, inicialización de OpenBao, borrado de volúmenes ni restauración
de respaldo para una actualización normal. Conservar logs privados y staging anterior.

## Aceptación

- Verificar versiones, esquema, readiness, mTLS, servicios, fingerprint auto-unseal y cuenta protegida.
- Comparar datos con el baseline inmediato e investigar disminuciones inesperadas.
- Probar clientes/casos con la misma clave y tenant autorizado. Con `metrics:read` debe aparecer
  `stats`; sin ese alcance no debe aparecer. Un tenant ajeno debe seguir inaccesible.
- Verificar GET `/api/v2/vulnerabilities` por el gateway público autorizado, no por el Dashboard.
  El inventario debe ser real y autorizado; sin clave debe responder 401, no 404 de enrutamiento.
- Comprobar eventos/timeline del padre con procedencia del hijo, propiedad intacta y paginación;
  consultar el hijo por separado y verificar que conserva su trabajo y métricas.
- Validar SLA abierto sin casos terminales/archivados y el encabezado Bearer del 401.
- Ejecutar la aceptación funcional de notificaciones, Dashboard y reportes ya indicada en
  [0.1.177](upgrade-0.1.177.md) si se actualiza directamente desde 0.1.176.

Las copias locales de HAProxy corregidas no se aplican desde este paquete. Antes de cualquier
recarga remota, comprobar CA/SAN y validar la configuración completa del servidor.

## Si falla

Conservar estado, logs, staging y respaldos. No repetir a ciegas ni hacer downgrade automático.
Una restauración reemplaza datos y puede perder escrituras posteriores: acordar destino y punto
de recuperación antes de restaurar y proteger primero los cambios posteriores. No reemplazar ni
retirar auto-unseal. No se promete pérdida cero ni interrupción cero.
