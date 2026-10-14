# Actualizar SOC Operations de 0.1.174 a 0.1.175

Actualizar instalador, agente y runtime juntos. Versiones esperadas: instalador `0.1.175`,
API/API externa/worker/agente `0.1.125` y plugin `0.1.105`.
Esta entrega migra el esquema de `c17e89ab2304` a `d29f63a710bc` para números y jerarquía de casos.

## Preparación con servicios activos

1. Descargar el paquete cifrado y SHA256SUMS de v0.1.175. Comparar las huellas publicadas antes
   de descifrar. Obtener la identidad age por el canal autorizado, nunca por GitHub o chat.
2. Validar rutas y tipos del TAR antes de extraer, desempaquetar en un directorio nuevo y
   comprobar todas las sumas del manifiesto interior. No sobrescribir un staging existente.
3. Ejecutar el preflight del instalador extraído con la topología existente antes de reemplazar
   el orquestador activo o reiniciar servicios.
4. Generar un respaldo nuevo en caliente: dump PostgreSQL legible, snapshot Raft OpenBao,
   versiones exactas de objetos y artefactos de reportes, configuración y baseline. No copiar
   directorios internos activos de PostgreSQL, MinIO u OpenBao como respaldo consistente.
5. Cifrar y verificar por descifrado el respaldo. Custodiar la copia auto-unseal por separado,
   con otra contraseña; conservar intacta la clave original y no registrar tokens.

Los componentes del respaldo corresponden a instantes distintos. Registrar sus tiempos;
un respaldo en caliente no garantiza recuperar escrituras posteriores al dump. Conservar una
copia protegida fuera del servidor y acordar la ventana y el punto de recuperación.
[Modelo de respaldo y recuperación](backup-and-restore.md).

## Ventana de actualización

Si el Manager es remoto, actualizar primero su agente con el mismo release mediante el
[procedimiento distribuido](distributed-installation.md). Con respaldo y release verificados,
capturar el baseline inmediato y ejecutar `upgrade` sobre la instalación existente, indicando
el staging nuevo y conservando la topología, cuenta protegida, dirección y proxy.

No ejecutar `apply`, inicializar OpenBao, borrar volúmenes ni restaurar datos para una actualización
normal. Guardar el log con permisos privados. La migración y los reinicios requieren una ventana;
no se ofrece cero interrupción. Evitar cambios de usuarios durante la ventana acordada.

## Aceptación

Comprobar readiness, versiones, esquema `d29f63a710bc`, mTLS, servicios y cuenta protegida.
Comparar tenants, usuarios, casos y reportes con el baseline inmediato, además de revisar registros.
Verificar números históricos, creación de casos, controles de anexado, permisos, reporte real y
descarga CSV mediante el proxy publicado. Revisar las [notas de versión](release-0.1.175.md).

## Recuperación ante fallos

Conservar logs, estado, staging anterior y respaldos. No reintentar a ciegas ni ejecutar downgrade
de esquema: puede eliminar las nuevas relaciones y numeración. Antes de volver a 0.1.174,
evaluar compatibilidad del código con el esquema actual y proteger los cambios posteriores.

Restaurar un dump o snapshot reemplaza datos y puede perder escrituras posteriores al respaldo.
Una recuperación de datos requiere autorización, destino exacto y un punto de recuperación
acordado; preferir ensayarla en un entorno aislado. No reemplazar la clave auto-unseal original.
