# SOC Operations Installer 0.1.198

Fecha: 2026-11-02 (America/Lima)
Componentes: API, API externa, worker y agente 0.1.141; plugin socOperations 0.1.120.
UI build: 0.1.120-family-activity-and-evidence-consistency.
Esquema: f97dc8e12543; sin migraciones nuevas respecto a 0.1.197.

Actividad de familias de casos
- La fecha de modificación presentada por las API considera la actividad más
  reciente del caso y de sus hijos directamente vinculados dentro del mismo tenant.
- El período de actividad incluye al padre cuando existe trabajo de un hijo en
  ese período, incluso si el padre fue creado antes. El orden descendente por
  modificación presenta al padre antes de sus hijos cuando comparten esa fecha.
- La consola, el detalle/listado de la API externa, el orden por modificación y
  las métricas con time_basis=worked comparten el criterio de actividad familiar.
- La serie diaria conserva el trabajo histórico y cuenta cada caso una vez por día.
- Los eventos, el analista de origen, las asignaciones, los estados y los relojes
  SLA propios se conservan. Las consultas no reescriben marcas históricas de la BD.

Confirmación de evidencias
- La transición a evidencia disponible se confirma de forma atómica. Dos solicitudes
  simultáneas válidas generan un solo evento evidence_uploaded y conservan la
  versión del objeto confirmada por la solicitud ganadora.
- La verificación del objeto no mantiene un bloqueo de fila durante la E/S externa.
- Se comprueban el caso y el tenant de la evidencia antes de confirmar la subida.
- Una verificación fallida no deja un estado disponible ni una actividad falsa.
- La evidencia confirmada se muestra en el historial como Evidencia adjuntada.

Compatibilidad
- AIO y distribuido; Wazuh 4.14.7-1 / OpenSearch Dashboards 2.19.5.
- AIO y distribuido; Wazuh 4.14.8-1 / OpenSearch Dashboards 2.19.6.
- Instalador, wheel, imagen y plugins se verifican mediante SHA-256.

Alcance pendiente
- Los límites y la paginación continúan contando casos individuales; no son
  paginación por familias completas. Los filtros de estado, severidad, búsqueda,
  asignación y archivado siguen aplicándose al caso consultado.
- Kanban compacto agrupa hijos del mismo estado cuando ambos registros están
  cargados; esta entrega no traslada hijos entre columnas ni cambia sus estados.
- La aceptación del servidor destino y del correo real se realiza tras actualizar.

## Validación e integridad

- Backend/agente: **2749 pruebas**; interfaz: **440**.
  Sin fallos ni omisiones. PostgreSQL temporal con FORCE RLS y rol sin SUPERUSER/BYPASSRLS.
- Pruebas simultáneas con dos sesiones reales, repetición de confirmación y conservación
  de la versión ganadora; almacenamiento de objetos simulado en esas pruebas.
- Equivalencia de detalle/listado externo, orden, período trabajado y serie diaria,
  con pruebas autenticadas y marcadores de otros tenants que deben ignorarse.
- Ambos plugins compilados para su SDK exacto; wheel, fuentes de imagen, migraciones,
  integridad JavaScript/gzip, Ruff, Mypy de 145 módulos y ShellCheck comprobados.
- SAST mantiene visibles tres patrones medios preexistentes revisados; sin hallazgos nuevos.
- Entrada real de API externa en contenedor aislado: liveness 200, sin clave 401 y POST 405.

La aceptación del servidor, del almacenamiento, Wazuh/Indexer y del navegador real
se realiza tras actualizar. Esta publicación no despliega ni envía correos reales.

| Archivo | SHA-256 |
|---|---|
| `soc-operations-0.1.198.tar.gz.age` | `31ed4e0ee04dafab14ac4af50bdd9add12b8abdfb8710845cd36a261236ad601` |
| `soc-operations-0.1.198.tar.gz` | `6746e2acd6c11336702b80e11b9a9594d9bbc2de434ccee11c8cf4f8adc9d16c` |
| `SHA256SUMS` | `f94a34b4801e667707945b071424b747991201d3667d3e247840b2f5d09a64a5` |
| `SHA256SUMS interno` | `cda73e1defc725da2a007dd1c0afc4ffc33db2cf53212ac07e06109a8439847f` |
| `soc-operations-install` | `02dfc8092be891d1bf79b38bd56238675eba48f0bf6f1bcf7c200e9e52d5bb41` |

[Descargar v0.1.198](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.198).
