# Actualización a SOC Operations Installer 0.1.198

Versión destino: instalador 0.1.198; componentes 0.1.141; plugin 0.1.120.
Topologías: AIO y distribuido. Esquema f97dc8e12543, sin migraciones nuevas desde 0.1.197.

Preparación
1. Identificar hostname, topología, deployment_id, dirección de servicio y proxy.
   Registrar el estado y la salud actuales con soc-operations-install status.
2. Medir la capacidad para el paquete y un respaldo nuevo de PostgreSQL, OpenBao,
   objetos versionados, reportes, snapshots y configuración. Conservar una copia
   de recuperación validada y la custodia separada de la clave auto-unseal.
3. Descargar el paquete cifrado y SHA256SUMS desde la release v0.1.198. Verificar
   hashes antes y después del descifrado con la identidad age autorizada. No
   introducir identidades privadas o tokens en argumentos, registros o GitHub.
4. Revisar la estructura del tar y extraer en un staging nuevo, propiedad de root.
   Verificar SHA256SUMS interno y ejecutar preflight con la dirección del destino.
5. Mantener las rutas, certificados y parámetros del despliegue existente. En
   distribuido, el agente del manager debe estar en 0.1.141 antes del runtime;
   seguir el orden y los controles del instalador oficial.

Ejecución
Ejecutar el subcomando upgrade desde el staging verificado 0.1.198, indicando
--staging-root, --service-address y el --external-proxy-cidr existentes. No ejecutar
una instalación nueva sobre el despliegue ni restaurar datos tras un error sin
revisar primero el estado, la fase y el registro privado de la actualización.

Aceptación
- Confirmar instalador 0.1.198 y phase=complete; API/worker/agente 0.1.141 y
  plugin 0.1.120 para la plataforma exacta del dashboard.
- Revisar salud de API y gateway, OpenBao inicializado y sin sellar, huella de
  auto-unseal y conservación de topología, API externa y cuenta protegida.
- Comparar tenants, usuarios, casos y reportes con la línea base del destino.
- Sobre una familia de prueba autorizada, registrar trabajo en un hijo y
  comprobar fecha del padre, visibilidad por actividad y orden padre/hijo.
- Contrastar el detalle/listado externo, order_by=case_modification_date y las
  métricas time_basis=worked. Comprobar que otros tenants no influyen ni se muestran.
- Confirmar una evidencia y su historial; repetir la confirmación debe conservar
  el objeto/versionado y un solo evento. Validar el almacenamiento real del destino.
- Si el navegador mantiene un bundle anterior, recargar y comprobar UI build
  0.1.120-family-activity-and-evidence-consistency.

La paginación por familias completas sigue pendiente. Esta guía no sustituye la
revisión del estado y de los respaldos del servidor concreto antes del upgrade.
