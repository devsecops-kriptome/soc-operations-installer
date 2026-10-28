# Actualización a SOC Operations 0.1.194

El piloto es lab02 AIO. Una instalación existente debe usar `upgrade`, no
instalación limpia, `apply` ni `resume`. El mismo paquete admite distribuido,
pero conserva la identidad y topología propias del destino.

## Preparación y respaldo

1. Confirmar hostname, versión, `phase=complete`, topología, deployment_id,
   dirección de servicio, esquema, estado de servicios y espacio disponible.
   No reutilizar baseline, rutas ni parámetros de otra instalación.
2. Medir datos y configuración. Reservar espacio para descarga, TAR descifrado,
   staging, carga de imagen y respaldo claro/cifrado. No ejecutar `docker prune`
   ni borrar volúmenes o respaldos anteriores para forzar la actualización.
3. Descargar desde el tag v0.1.194 el archivo cifrado y SHA256SUMS. Verificar el
   manifiesto y el archivo contra las huellas de las notas de esta versión.
4. Descifrar en un directorio privado nuevo con la identidad age autorizada,
   sin compartirla ni imprimirla. Verificar el hash del TAR claro. Antes de
   extraer, validar rutas, tipos, duplicados y ausencia de enlaces. Verificar
   el SHA256SUMS interno completo y ejecutar el preflight del nuevo instalador.
5. Crear un respaldo NUEVO de PostgreSQL, OpenBao, objetos/versiones, reportes
   y configuración. Cifrarlo y comprobar el descifrado. Custodiar auto-unseal
   por separado, con otra contraseña, sin alterar la original. Registrar
   baseline, cuenta protegida, imágenes, servicios y fingerprint de seal.

## Ejecutar la actualización

Solo después de aprobar respaldo, capacidad, preflight y ventana, ejecutar el
nuevo instalador con `upgrade --staging-root RUTA_VERIFICADA`. No copiar helpers
aislados ni mezclar API/worker de versiones distintas. En AIO el instalador
reconcilia el agente local. En distribuido actualizar primero el agente remoto
a 0.1.137 mediante el flujo previsto y verificar el contrato mTLS.

El proceso puede recrear contenedores y reiniciar Dashboard/agente. Si falla,
conservar logs, staging y respaldos y detenerse para diagnóstico. No inicializar
OpenBao, eliminar volúmenes ni restaurar a ciegas.

## Aceptación de lab02

- Confirmar instalador 0.1.194, runtime/agente 0.1.137, plugin 0.1.116, esquema
  c64e93b8a521, `phase=complete`, readiness y servicios sin reinicios repetidos.
- Comparar baseline y cuenta protegida, fingerprint de seal, permisos, TLS/timer
  y avance de checkpoints. Revisar los dos pasos de migración nuevos.
- Comprobar contactos con `contacts:read`, ausencia de acceso sin alcance y
  rechazo de otro tenant. La clave existente no recibe permisos nuevos sola.
- Comprobar grupos/estados, métricas de eventos, filtros `case_scope`, categorías
  y separación por índices. Confirmar la regla global de vulnerabilidades pausada.
- Validar suspensión y reactivación con un tenant de prueba autorizado. La pausa
  no debe detener el trabajo de otros tenants activos. No ejecutar borrado físico.
- Probar edición y lote controlado sin activar reglas globales ni disparar
  notificaciones masivas. Confirmar recibos, contadores y auditoría sin duplicados.
- Ejecutar reporte real y revisar navegador, enlaces, menús y permisos. Verificar
  resumen externo fresco: un 503 refresh pending no equivale a cero hallazgos.

Conservar instaladores y respaldos anteriores hasta aceptar el destino. Una
actualización posterior de LAUFEY requiere otro respaldo y otra ventana; esta
publicación no autoriza ni ejecuta ese despliegue.
