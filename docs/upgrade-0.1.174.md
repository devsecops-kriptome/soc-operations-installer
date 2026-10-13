# Actualizar SOC Operations de 0.1.173 a 0.1.174

Actualizar instalador, agente y runtime juntos; para Manager remoto, actualizar primero su
agente siguiendo el procedimiento distribuido. Versiones esperadas: instalador 0.1.174,
API/API externa/worker/agente 0.1.124 y plugin 0.1.104. Esquema c17e89ab2304 sin migración nueva.

## Preparación sin detener servicios

1. Descargar el asset cifrado y SHA256SUMS de v0.1.174; verificar ambos antes de descifrar.
2. Obtener la identidad age por el canal autorizado. Descifrar, validar las rutas y tipos del
   TAR antes de extraer, y verificar todas las sumas del manifiesto interior. No sobrescribir
   un staging existente ni reutilizar una identidad temporal de otro proceso.
3. Ejecutar el preflight del instalador extraído con la topología existente. Debe finalizar
   correctamente antes de detener servicios o reemplazar el instalador activo.
4. Preparar un respaldo NUEVO en caliente: dump PostgreSQL legible, snapshot Raft OpenBao
   con token autorizado, versiones de objetos y artefactos de reportes, configuración y baseline.
   No copiar en caliente los directorios internos de PostgreSQL, MinIO u OpenBao como respaldo consistente.
5. Cifrar y comprobar por descifrado el respaldo. Custodiar auto-unseal por separado, con otra
   contraseña; mantener intacta la clave original. No exponer secretos en comandos, GitHub o chat.

Los componentes del respaldo en caliente corresponden a instantes distintos. Registrar sus
tiempos y conservar el baseline inmediatamente previo a actualizar. Un respaldo local no
protege ante pérdida del servidor ni garantiza recuperar escrituras posteriores al dump.
[Modelo de respaldo y recuperación](backup-and-restore.md).

## Ventana de actualización

Con respaldo verificado y desempaque aprobado, usar `upgrade` sobre la instalación existente
y su staging 0.1.174, conservando despliegue, dirección, proxy y cuenta institucional.
No usar `apply` para actualizar, reinicializar OpenBao ni borrar volúmenes. Guardar el log con
permisos privados; no volver a ejecutar etapas completadas si el resultado es incierto.
La actualización requiere reinicios breves y no ofrece cero interrupción.

## Aceptación y recuperación

Comprobar readiness, versiones, esquema, mTLS, servicios, reinicios y cuenta protegida.
Comparar tenants, usuarios, casos y reportes con el baseline inmediato; revisar datos y
funcionalidad, no solo conteos. Verificar filtros, automatizaciones, campos y reporte real.
Revisar el defecto conocido de IDs reutilizados en las [notas de versión](release-0.1.174.md).

Ante un fallo, conservar logs, staging anterior y respaldos; detener la actualización y
evaluar rollback de código antes de restaurar datos. Restaurar el dump/snapshot a ciegas
puede eliminar escrituras posteriores. Sin autorización explícita, no reemplazar datos ni
auto-unseal y no descartar el estado actual del servidor.
