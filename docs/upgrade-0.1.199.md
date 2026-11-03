# Actualizacion a SOC Operations Installer 0.1.199

Destino: instalador 0.1.199; API/worker/agente 0.1.142; plugin 0.1.121.
Topologias: AIO y distribuido. Esquema destino a08ed9f23654.

Preparacion
1. Registrar hostname, topologia, deployment_id, direccion de servicio, proxy,
   versiones, salud, conteos y configuracion actuales. Resolver readiness antes
   de actualizar; no usar el upgrade para ocultar un problema de credenciales.
2. Crear y verificar un respaldo nuevo de PostgreSQL, OpenBao, objetos versionados,
   reportes, snapshots y configuracion. Custodiar auto-unseal por separado.
3. Descargar el paquete age y SHA256SUMS de v0.1.199. Verificar hashes antes y
   despues del descifrado. No poner identidades privadas ni tokens en registros.
4. Validar la estructura del tar, extraer en un staging nuevo propiedad de root,
   verificar el manifiesto interno y ejecutar preflight para el destino exacto.
5. En distribuido, actualizar el agente del manager a 0.1.142 antes del runtime
   siguiendo el procedimiento oficial. Conservar endpoints y parametros vigentes.

Ejecucion
Ejecutar upgrade desde el staging verificado 0.1.199, con --staging-root,
--service-address y --external-proxy-cidr del despliegue. El instalador aplica
la migracion a08ed9f23654, que crea la tabla de metricas con FORCE RLS y permite
escrituras solo al worker. No ejecutar una instalacion nueva sobre datos existentes.

Aceptacion
- Confirmar phase=complete, componentes 0.1.142, plugin 0.1.121 y esquema a08ed9f23654.
- Comprobar API, gateway, OpenBao sin sellar, auto-unseal, cuenta protegida y datos.
- Abrir Vulnerabilidades: Dashboard debe ser la pestana inicial. No debe lanzar
  una captura nueva ni la consulta completa del inventario por abrir esa vista.
- Esperar una captura correcta del worker. Las metricas anteriores no se reconstruyen;
  hasta la primera captura nueva el Dashboard puede indicar que aun no hay historico.
- Probar filtros y evolucion de un host, cambio de tenant y respuestas pendientes.
  Cada tenant debe mantener sus propios datos y opciones de filtro.
- Comprobar lectura con todos los roles del tenant, sin habilitar modificaciones
  a observadores, auditores ni analistas junior por el acceso al Dashboard.
- Descargar Excel y Word de un host autorizado y revisar sus totales por criticidad.
  Confirmar que un host o reporte de otro tenant no se puede descargar.
- Verificar UI build 0.1.121-vulnerability-dashboard-and-host-reports tras recargar.

Si falla una fase, conservar evidencia y revisar el estado antes de repetirla.
No restaurar datos ni regresar al runtime anterior sin evaluar la nueva migracion
y el punto recuperable. Publicar esta version no ejecuta el upgrade del servidor.
