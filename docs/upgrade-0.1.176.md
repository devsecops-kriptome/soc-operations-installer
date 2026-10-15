# Actualizar SOC Operations de 0.1.175 a 0.1.176

Actualizar instalador, agente y runtime juntos. Versiones esperadas: instalador 0.1.176,
API/API externa/worker/agente 0.1.126 y plugin 0.1.106. El esquema pasa de d29f63a710bc
a e31a7f82c940 para recuperar únicamente eventos de hijos con procedencia probada.

## Preparación con servicios activos

1. Descargar el paquete cifrado y SHA256SUMS de v0.1.176 y comparar las huellas de las
   [notas de versión](release-0.1.176.md). Obtener la identidad age por el canal autorizado.
2. Validar rutas y tipos del TAR antes de extraer. Usar un directorio nuevo y verificar todas
   las sumas interiores. No sobrescribir un staging anterior ni imprimir secretos.
3. Ejecutar el preflight del instalador extraído con la topología existente, sin reemplazar
   todavía el orquestador activo ni reiniciar servicios.
4. Generar respaldo NUEVO en caliente: dump PostgreSQL legible, snapshot Raft OpenBao,
   versiones exactas de objetos, archivos de reportes, configuración y baseline inmediato.
   No copiar directorios internos activos como si fueran una copia consistente. Incluir el
   volumen de reportes y comprobar que caben el respaldo, su cifrado y la verificación.
5. Cifrar y comprobar por descifrado. Custodiar auto-unseal por separado con otra contraseña,
   conservar intacta la clave original y guardar una copia protegida fuera del servidor.

Los componentes calientes corresponden a instantes distintos. Registrar sus tiempos y acordar
el punto de recuperación: un respaldo no recupera escrituras posteriores a su captura.
Consultar el [modelo de respaldo y recuperación](backup-and-restore.md).

## Ventana de actualización

En distribución, actualizar primero el agente del Manager con el mismo release según el
[procedimiento distribuido](distributed-installation.md). Con respaldo y release verificados,
capturar el baseline inmediato y ejecutar upgrade con el staging nuevo y la topología persistida.
Evitar escrituras de usuarios durante la ventana. Migraciones y reinicios pueden interrumpir servicio.

No ejecutar instalación limpia, apply, inicialización de OpenBao, eliminación de volúmenes ni
restauración de datos para una actualización normal. Conservar logs con permisos privados.

## Aceptación

Comprobar versiones, esquema e31a7f82c940, readiness, mTLS, servicios, cuenta protegida y
conteos respecto del baseline inmediato. Revisar eventos propios del hijo y procedencia en el
padre, ACK/SLA conservados y propagación justificada de cambios. Probar un reporte real Word
y Excel, sus límites de muestra y descarga por el proxy. Verificar que los grupos siguen
respetando RBAC y que eliminar un reporte no afecta evidencias ni una entrega activa.

Los cuatro pendientes visuales conocidos se enumeran en las notas; no confundirlos con una
aprobación visual completa. Mantener los respaldos hasta concluir la aceptación.

## Recuperación ante fallos

Conservar logs, estado, ambos stagings y respaldos. No reintentar a ciegas ni ejecutar downgrade:
esta migración de corrección no vuelve a trasladar eventos al padre. Antes de volver a código
anterior, evaluar compatibilidad del esquema y proteger todas las escrituras posteriores.

Restaurar un dump o snapshot reemplaza datos y puede perder cambios posteriores. Una
restauración requiere autorización, destino exacto y punto de recuperación acordado; ensayarla
en un entorno aislado. No reemplazar ni retirar la clave original de auto-unseal.
