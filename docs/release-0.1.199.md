# SOC Operations Installer 0.1.199

Fecha: 2026-11-03 (America/Lima)
Componentes: API, API externa, worker y agente 0.1.142; plugin socOperations 0.1.121.
UI build: 0.1.121-vulnerability-dashboard-and-host-reports.
Esquema: a08ed9f23654; migracion nueva desde f97dc8e12543.

Vulnerabilidades
- Dos pestanas: Dashboard por defecto y Hosts para el inventario actual.
- Dashboard disponible para todos los roles del tenant, incluidos observadores,
  auditores y analistas junior. La lectura no concede permisos de modificacion.
- Metricas compactas por host de cada snapshot correcto durante tres meses
  calendario, independientes de la retencion de los inventarios completos.
- Evolucion diaria por criticidad y distribucion por grupo. Filtros compartidos
  de grupo, sistema operativo y nombre; seleccion de un host por UUID exacto.
- Los dias sin captura aparecen sin datos. Se usa la ultima captura del dia en
  America/Lima; no se suman varias capturas ni se duplican hosts entre grupos.
- Abrir o actualizar Dashboard consulta datos guardados y no crea un snapshot.
  El historico comienza con las nuevas capturas; no reconstruye datos ausentes.
- Hosts se carga al abrir esa pestana. Los filtros se conservan entre pestanas
  y se limpian al cambiar de tenant. Se descartan respuestas y filtros obsoletos.

Reportes de un host
- Menu de tres puntos con detalle, evolucion y descarga directa Excel o Word.
- Todos los roles de lectura del tenant pueden solicitar el reporte de un host
  autorizado y descargar su propio trabajo; se comprueban host, tenant y actor.
- El resumen por host incluye total, criticas, altas, medias, bajas y sin severidad,
  tanto en descargas directas como en reportes de Ingenieria y SOC Manager.
- Se conservan los conteos completos y las muestras de CVE por paquete existentes.
- Las descargas rechazan artefactos vencidos, ajenos o fuera del directorio del
  reporte. La administracion general de reportes conserva sus permisos actuales.

Compatibilidad
- AIO y distribuido: Wazuh 4.14.7-1 / OpenSearch Dashboards 2.19.5.
- AIO y distribuido: Wazuh 4.14.8-1 / OpenSearch Dashboards 2.19.6.
- Paquete cifrado age, con manifiestos SHA-256 externo e interno.

Limites de la entrega
- Publicar el instalador no actualiza servidores. La aceptacion del destino y
  las integraciones reales se realizan despues del upgrade con respaldo previo.
- Se mantienen las limitaciones de paginacion de familias de casos de 0.1.198.
- Una disminucion del historico puede incluir cambios de alcance y no demuestra
  por si sola una remediacion. Los subtotales de grupos pueden solaparse.

## Validación de la distribución

- 2809 pruebas de backend/agente y 469 de interfaz aprobadas.
- Migraciones completas y equivalencia modelo/esquema verificadas en PostgreSQL temporal.
- Autenticación RS256, FORCE RLS, permisos de lectura de todos los roles, revocación
  de membresías, usuarios deshabilitados y rechazo de otros tenants comprobados.
- Imagen, wheel, migraciones, ambos plugins, fuentes y gzip coinciden; Ruff, Mypy,
  sintaxis Bash y ShellCheck verificados. SAST conserva tres patrones medios
  preexistentes revisados, sin hallazgos medios o altos nuevos sin revisar.
- La aceptación en LAUFEY/AIO, el SMTP y Wazuh reales se realizan tras actualizar.

## Integridad

| Archivo | SHA-256 |
|---|---|
| `soc-operations-0.1.199.tar.gz.age` | `75cdd8098293b75fbf9d8b91f4c4a08aa7e996dbd42a437b0de36f627f8bddb0` |
| `soc-operations-0.1.199.tar.gz` | `c8d887c6e929a48e6d35da4e7f5e2a288905113da951780feb9d4bc6ad478f26` |
| `SHA256SUMS` | `fe96bc8c94556e62a9e564a537f40cf6bfde2eff2dd6b048f4d59fd69fcb4f2a` |

[Descargar v0.1.199](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.199).
