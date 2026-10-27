# Actualización a SOC Operations 0.1.192

1. Confirmar host, topología persistida, versión instalada, esquema y baseline.
2. Crear y verificar un respaldo NUEVO de PostgreSQL, OpenBao, objetos, reportes y
   configuración. Custodiar auto-unseal cifrada por separado, con otra contraseña.
   Conservar instalador y respaldo anteriores. Un respaldo caliente no es RPO cero.
3. Obtener soc-operations-0.1.192.tar.gz.age y SHA256SUMS desde el destino autorizado.
   Verificar primero el cifrado; descifrar con la identidad autorizada y verificar
   también el hash del TAR claro. No compartir identidades, tokens ni contraseñas.
4. Validar rutas, duplicados, tipos de archivo y ausencia de enlaces antes de extraer
   en un staging nuevo y privado. Verificar SHA256SUMS interno completo.
5. Ejecutar preflight con el instalador del staging y la topología persistida.
6. Solo con respaldo, baseline y preflight verificados y ventana autorizada, ejecutar
   upgrade --staging-root RUTA_VERIFICADA. No usar apply ni resume en una instalación
   existente. Con Manager remoto, actualizar antes su agente a 0.1.135 mediante el
   flujo distribuido. No copiar helpers individuales ni omitir controles.
7. Confirmar phase=complete; runtime/API/worker/agente 0.1.135, plugin 0.1.115 y
   esquema a42f71c6e309. El instalador aplica las migraciones pendientes en orden;
   no ejecutar el runtime nuevo sobre el esquema antiguo.
8. Comparar cuenta protegida, conteos, numeración, jerarquía y auto-unseal. Verificar
   readiness de ambas API, aislamiento de volúmenes y permisos mTLS/timer.
9. Probar agrupación por hostname, límite de 10 hosts, selección por tenant y hojas
   de Excel Host > paquete, incluido un host sin vulnerabilidades. Probar Word,
   correo, programación y edición; verificar métricas e historial coherentes.
10. Confirmar que un reintento con el mismo send_request_id no duplica entregas,
    que otro envío explícito sí es posible y que eliminar una programación no
    elimina reportes históricos ni bloquea envíos concurrentes.
11. Verificar avance del checkpoint, aislamiento de tenants y ausencia de duplicados.
    No avanzar checkpoints manualmente ni reprocesar alertas sin rango y autorización.
12. Probar API externa autenticada, rechazo sin clave/alcance y navegador real.

No hay migración automática de nombres de grupos existentes ni replay de reportes
o alertas históricas. Si falla el upgrade, conservar logs, staging y respaldos y
detenerse para diagnóstico. No borrar volúmenes, inicializar OpenBao ni restaurar
a ciegas. Los tokens reparados deben incluirse en el nuevo respaldo de configuración.
