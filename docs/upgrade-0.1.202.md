# Actualización a SOC Operations Installer 0.1.202

Destino: instalador 0.1.202; API interna/externa, worker y agente 0.1.145;
plugin 0.1.123; esquema f4b8cae32175. AIO o distribuido con un único Dashboard.

## Alcance y respaldo

Esta entrega actualiza los lectores y cálculos de SLA, los rankings por analista,
los filtros temporales y la gestión de fuentes de tecnologías externas. No restaura
una base de datos anterior ni ejecuta reconstrucción histórica de hitos SLA.

Antes de actualizar, registrar versiones, topología, direcciones, salud, conteos y
configuración, y verificar un respaldo nuevo de PostgreSQL, OpenBao, objetos,
reportes, snapshots y configuración. Custodiar auto-unseal separadamente. No borrar
respaldos, estados del instalador ni volúmenes para completar esta actualización.

Descargar exclusivamente el archivo age y SHA256SUMS del tag v0.1.202. Comparar
primero el hash del manifiesto publicado en las notas. Verificar el paquete cifrado,
descifrar con la identidad age autorizada sin mostrarla ni pasarla en argumentos,
y verificar el hash del TAR en claro. El TAR no es un asset público descargable.
Validar rutas y tipos del TAR antes de extraerlo en un staging nuevo protegido;
verificar SHA256SUMS interno y ejecutar preflight para el destino exacto.

## Actualización

Usar upgrade, no apply ni instalación limpia. Conservar deployment_id, topología,
direcciones, credenciales, TLS y configuración persistida propios del destino.
En distribuido se debe actualizar/verificar el agente del Manager a 0.1.145 antes
del runtime; en AIO se reconcilia el agente local. No actualizar componentes sueltos.

Desde 0.1.201 se aplican e3a7b9c21064 y f4b8cae32175: autorización externa acotada
para horarios y persistencia de activación/presencia de fuentes tecnológicas.
No se crean hitos históricos MTTQ/MTTI ni se sustituyen objetivos por la política actual.
Si falla una fase, conservar evidencia y revisar el estado antes de reintentar.
No realizar downgrade ni restauración sin evaluar el esquema y el respaldo vigente.

## Aceptación

- Confirmar phase=complete, componentes 0.1.145, plugin 0.1.123, esquema
  f4b8cae32175 y UI build 0.1.123-sla-ranking-and-tenant-isolation.
- Comprobar readiness, gateway, OpenBao, auto-unseal, cuenta protegida, conservación
  de datos y configuración; validar el acceso autenticado con los roles del destino.
- Probar dos tenants y credenciales diferentes: sin acceso a casos, identidades,
  horarios, fuentes ni métricas ajenas. Los scopes nuevos no se conceden a claves antiguas.
- Contrastar SLA en detalle y agregado con casos conocidos, objetivos históricos,
  límites con segundos, pausas, reaperturas y fuentes de fecha verificadas.
- MTTQ exige calificación explícita TP/FP/benigno; MTTI exige investigación explícita
  vinculada a TP. Un playbook referencial o un veredicto final no inventa esas fechas.
- Verificar TOP 10 por menor AVG, mínimo de muestras, actor correcto y SLA Compliance
  numérico de 0 a 100. Unknown no entra al denominador; sin evaluables devuelve null.
  MTTD sigue siendo métrica del SOC, no un ranking individual de creación automática.
- Comprobar cierres con igual hora: se usa solo una cadena from/to única y verificable;
  los empates irresolubles no certifican cumplimiento ni autor por orden de UUID.
- Validar activación/desactivación de fuentes tecnológicas y ausencia confirmada del
  agente; un error al consultar el inventario no equivale a una baja confirmada.
- En la UI se muestra agent.name; la identidad de la API externa mantiene su contrato.
- Confirmar filtros de endpoints por cliente, filtros temporales con segundos,
  reportes actuales y conservación del último snapshot completo mientras se genera otro.

## Datos históricos de SLA: trabajo posterior separado

La actualización recalcula al leer usando los datos verificables ya disponibles.
No ejecuta recuperación, restauración de bases antiguas ni backfill masivo. Los casos
sin hitos u objetivos suficientes seguirán como desconocidos o no evaluables.

La adaptación histórica se preparará después de aceptar el upgrade: inventario por
caso/tenant, evidencia original, plan de solo lectura revisado, respaldo verificado,
aplicación explícita idempotente y auditada, y comparación posterior de lectores.
No usar el endpoint de registro de hitos nuevos para introducir fechas antiguas.
No utilizar SQL directo para eludir RLS, auditoría o controles append-only.

Publicar esta versión no instala ni modifica ningún servidor.
