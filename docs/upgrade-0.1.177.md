# Actualizar SOC Operations de 0.1.176 a 0.1.177

Versiones esperadas: instalador 0.1.177; API/API externa/worker/agente 0.1.127;
socOperations 0.1.107. About debe indicar `0.1.107-ack-analyst-dashboard-routing-case-details`.
El esquema permanece e31a7f82c940; no hay una migración nueva desde 0.1.176.

## Preparación sin detener servicios

1. Descargar el asset cifrado y SHA256SUMS de v0.1.177. Comparar las huellas con las
   [notas de versión](release-0.1.177.md) antes de obtener y usar la identidad por el canal autorizado.
2. Descifrar a un directorio privado nuevo; verificar el hash del TAR y sus tipos/rutas antes
   de extraer, rechazando enlaces, rutas absolutas y componentes `..`. Validar todos los hashes
   interiores. No sobrescribir el staging 0.1.176 ni imprimir claves o tokens.
3. Ejecutar el preflight del nuevo staging con la topología persistida, sin reemplazar todavía
   el orquestador activo ni reiniciar servicios.
4. Preparar un respaldo NUEVO en caliente: dump PostgreSQL legible, snapshot Raft OpenBao,
   versiones exactas de objetos, archivos de reportes, configuración y baseline. No copiar
   directorios internos de bases/volúmenes activos como si fueran snapshots consistentes.
5. Verificar capacidad actual, hashes, lectura y estructura; cifrar y comprobar descifrado.
   Custodiar auto-unseal por separado con otra contraseña y conservar intacta la clave original.
   Registrar los instantes de cada componente y el punto de recuperación acordado.

Consultar el [modelo de respaldo y recuperación](backup-and-restore.md). Conservar una copia
protegida fuera del host es recomendable; un respaldo solo local no cubre la pérdida de ese host.

## Ventana de actualización

Con respaldo y release verificados, capturar conteos y cuenta protegida inmediatamente antes
de actualizar. Evitar escrituras de usuarios durante esta ventana. En distribución, actualizar
primero el agente del Manager con el wheel y hashes del mismo release según el
[procedimiento distribuido](distributed-installation.md); después usar upgrade sobre el
Dashboard con el staging nuevo y la topología existente.

No ejecutar instalación limpia/apply, inicializar OpenBao, eliminar volúmenes ni restaurar
respaldos para una actualización normal. La recreación de contenedores y el plugin puede
interrumpir el servicio. Mantener logs privados y ambos stagings hasta terminar la aceptación.

## Aceptación

Comprobar versiones, About, esquema sin cambio, readiness, mTLS, servicios y cuenta protegida.
Comparar datos con el baseline inmediato; investigar cualquier disminución inesperada. Validar:

- indicadores por analista debajo de Casos creados y filtros compartidos;
- asignaciones ACK vencidas atribuidas al responsable aunque otro usuario tome el caso;
- responsables primero, resto del turno después y un único aviso terminal sin menciones;
- anexar/desvincular, procedencia de eventos, métricas propias y propagación justificada;
- descripción/full_log completos al expandir/copiar y datos extra de nuevas automatizaciones;
- generación/descarga de un reporte real y alcance tenant/RBAC.

Los pendientes de seguridad/visuales constan en las notas; no confundir estas comprobaciones
con una aprobación de producción completa.

## Si falla

Conservar estado, logs, staging anterior y respaldos. No repetir a ciegas ni ejecutar downgrade
automático. Aunque no cambie el esquema, una restauración reemplaza datos y puede perder
escrituras posteriores a la captura. Acordar destino, punto de recuperación y autorización antes
de restaurar; proteger primero los cambios posteriores y ensayar en un entorno aislado.
No retirar ni reemplazar la clave original de auto-unseal.
