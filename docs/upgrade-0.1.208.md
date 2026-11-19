# Actualización controlada a 0.1.208

No ejecutar un candidato sobre producción sin revisar versión actual, topología,
respaldos recientes, espacio, ventana y procedimiento de reversión. Publicar el
instalador no actualiza servicios. No usar esta entrega para degradar un servidor
con el prototipo 0.1.207 sin analizar primero sus configuraciones y datos.

1. Recopilar estado actual y readiness; confirmar host y topología.
2. Crear y verificar un respaldo nuevo de PostgreSQL, OpenBao, objetos, reportes,
   snapshots y configuración. Custodiar aparte auto-unseal y cifrar el respaldo.
   Un dump en caliente no equivale a una instantánea atómica entre servicios.
3. Descargar de la release 0.1.208 únicamente `SHA256SUMS` y
   `soc-operations-0.1.208.tar.gz.age`; comprobar el hash antes de descifrar.
4. Descifrar con la identidad autorizada mediante entrada oculta, sin guardarla
   en argumentos, historial ni archivos. Verificar también el hash del TAR claro.
5. Inspeccionar rutas y tipos del TAR antes de extraer. Usar un staging nuevo;
   no sobrescribir el instalador activo hasta pasar hashes y preflight.
6. Ejecutar el flujo guiado correspondiente a la topología real; conservar sus
   salidas y detenerse ante cualquier error, sin reparaciones automáticas.
7. Verificar instalador 0.1.208, runtime/agente 0.1.151 y plugin 0.1.128,
   identidad de imagen, esquema, readiness y conservación de configuración/datos.
8. Con una clave `cases:read` autorizada, consultar el detalle de casos con
   fecha original, recuperación verificada y sin evidencia. Confirmar
   `soc.initial_alert`, `soc.analysis_metrics` y rechazo de tenants no autorizados.
   Comprobar Calendario con Ingeniería, SOC Manager y analista del tenant.

No aplicar otra vez planes de recuperación ni suplementos SLA. No es necesario
repetir la aceptación histórica agregada de versiones antiguas. La prueba de
esta corrección se limita a evidencia individual, permisos y conservación.

Si falla la aceptación, detener el cierre de la actualización y revisar registros
privados. La reversión debe usar el respaldo y las imágenes previas verificados,
sin borrar evidencia ni improvisar SQL sobre eventos históricos.
