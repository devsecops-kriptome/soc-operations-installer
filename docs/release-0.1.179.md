# SOC Operations 0.1.179

Fecha: 18 de octubre de 2026 (America/Lima). Instalador 0.1.179; API/API externa/worker/agente
0.1.129; plugin socOperations 0.1.108 para OSD 2.19.5 y 2.19.6. Build de interfaz
`0.1.108-technology-health-grouped-inventory-reports`. Esquema a6d924bc7810.
Compatible con Wazuh 4.14.7-1/OSD 2.19.5 y Wazuh 4.14.8-1/OSD 2.19.6, AIO o distribuido
con un único Dashboard. Desde 0.1.178 se aplican dos migraciones aditivas:
f3a71820c6de (tecnologías externas) y a6d924bc7810 (consolidado diario).

## Incluido

- Resumen externo `GET /api/v2/vulnerabilities/summary`: CVE únicos exactos por grupos/CVSS,
  unión sin duplicar hosts/CVE, Top 10 CVE por hosts afectados y Top 10 dispositivos con
  hasta tres CVE críticos/altos recientes y riesgo promedio de las muestras reales.
- Cortes completos por tenant cada 24 h, historial `as_of`, edad/error y último corte válido
  ante fallos. Sin corte inicial: 503, no ceros ficticios. Consultas sin nuevas lecturas a Wazuh;
  múltiples grupos calculan la unión sobre ledger local. Retención siete días configurable,
  al menos los dos últimos cortes correctos. La verificación SOC no inventa la hora de
  revisión del inventario Wazuh. El listado paginado existente sigue en directo.
- Volumen de consolidado RW para worker y RO para external-api; RLS por tenant, escritura
  exclusiva del worker y bloqueo por tenant frente a réplicas concurrentes. Recopilación
  separada de ACK/SLA/notificaciones. Se mantiene `vulnerabilities:read`, sin exigir metrics:read.
- Tecnologías externas con última actividad, tiempo transcurrido, estados y fuentes/identificadores
  configurables por Manager/Ingeniería. API interna autenticada con JWT; no se expone esta
  consulta mediante la clave externa. Lectura autorizada para analistas y configuración restringida.
- Casos por periodo de actividad, incluyendo trabajo e historial del intervalo; agrupación
  compacta de hijos con el mismo estado bajo un padre visible. Hijos de otro estado permanecen
  independientes. Creación manual con descripción amplia y evidencia autorizada.
- Eventos relacionados: listado paginado sin snapshots completos y detalle bajo demanda;
  se conservan eventos y propiedad en los hijos, con proyección autorizada en el padre.
- Reportes Word/Excel: ALL o grupos específicos, Grupo > Host > Paquete y Grupo > Paquete >
  Hosts afectados, justificaciones aprobadas excluidas por defecto con opción de incluir,
  hasta tres CVE distintos recientes por paquete, totales completos y CTI canónico. ALL tiene
  una hoja; grupos específicos, una por grupo. Tablas/hosts afectados alineados y advertencia
  de actualización estable con pruebas previas para componentes sensibles.

Ver [consulta API](vulnerability-summary-api.md) y [actualización](upgrade-0.1.179.md).
Los parámetros antiguos explícitos de agrupación siguen aceptándose por compatibilidad;
las futuras ejecuciones programadas se normalizan a los nuevos modos sin reescribir reportes
ya generados. Las métricas API de inventario incluyen justificados y no equivalen a las muestras
de un reporte que los excluya.

## Integridad

- Paquete cifrado: `97016467d91ae107ae893d1cf8461d22d349105a4feb3de7a24367ba8e449dba`.
- TAR descifrado: `4908f03d6084ec1c7baa5e4545700d2c2bc3e5af2cd3cd01b95c100fc17b94e1`.
- SHA256SUMS público: `1b5a92ef12f1bd019f5d6443141a510dd17a8b994fdd99ef7d9f998d6cbda487`.
- Orquestador: `a78d3e0f579f7adc67c052f3e0956b7ebf0ffadba8f9b48481b107f29f96a0f9`.

Solo se publican `soc-operations-0.1.179.tar.gz.age` y `SHA256SUMS`. No se publican código
privado, TAR sin cifrar, identidades age, configuraciones reales ni respaldos. Se conserva
el destinatario age autorizado existente; no se accedió a su identidad privada ni se afirma
haber descifrado con ella. Los assets anteriores permanecen inmutables.

## Validación del candidato

1165 pruebas backend/agente/HTTP y 232 de interfaz aprobadas, sin
omisiones en este conjunto. Incluye PostgreSQL real aislado, cadena completa de migraciones,
RLS con rol no superusuario, permisos, consultas históricas, fallos de recopilación, recuperación,
aislamiento del hilo y flujo HTTP real de API/worker. El transporte Wazuh usa datos sintéticos;
la consulta de inventario por scroll y el almacenamiento son reales.

TypeScript y compilación para ambas plataformas. Wheel e imagen Linux amd64 comparados con
las fuentes; `pip check`, 56 archivos de migración/configuración, autenticación 401 y permisos
del almacenamiento verificados dentro de la imagen sin red, UID no root y raíz read-only.
El TAR se extrae a un destino nuevo validando estructura y todos los hashes antes del cifrado.
Antes de publicar como vigente se verifica la descarga y las huellas de los assets GitHub.

## Límites y despliegue

- No se modificó producción ni se actualizaron Wazuh, HAProxy o firewalls. Faltan aceptación
  contra inventario real, OpenBao/mTLS/CA/SAN/edge, carga real y medición de RPO/RTO en restauración.
- La primera recopilación completa puede tardar. No aceptar la nueva consulta hasta verificar
  el primer corte; un 503 inicial no justifica desactivar RLS o ampliar permisos.
- Respaldar PostgreSQL, objetos, reportes y configuración; preservar auto-unseal con custodia
  separada. Incluir el volumen derivado si se necesita conservar el historial de cortes.
- Un respaldo en caliente de varios componentes no garantiza un único punto transaccional ni
  captura escrituras futuras. No hacer downgrade o restauración automática tras migrar.
- Persisten advertencias deprecadas de herramientas de pruebas y Browserslist/Babel de build;
  no se han actualizado dependencias fuera del alcance ni declarado una auditoría global.
- Sigue pendiente el hallazgo previo de evidencia manual inicial: si falla el registro tras
  subir un objeto cifrado puede quedar un objeto huérfano; no se afirma corregido aquí.

Publicar no instala en el servidor. Confirmar versiones, conteos, cuenta protegida, readiness,
mTLS, datos, reportes y permisos antes de dar por aceptado el upgrade.
