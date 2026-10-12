# SOC Operations 0.1.171

Instalador `0.1.171`; API/API externa/worker/agente `0.1.121`; plugin `0.1.102`.
Build de interfaz (solo en About): `0.1.102-sla-escalation-streamed-vulnerabilities-case-refresh-periods-absence-colors-outside-month-custom-shifts-type-edit-scope-routing-hourly-matrix-grouped-absence-report`.
Esquema `a2c8e4f719b6` → `b8a71e05c2d9` → `c17e89ab2304`.

## Cambios incluidos

- Consolidado de vulnerabilidades y reportes por host/grupo, simulación y agrupación usan
  inventario completo con spool en disco, no el anterior techo en memoria de 250.000.
  Preservan tenant/RBAC, shards, unicidad, tiempos de consulta y presupuestos de seguridad;
  no entregan un inventario parcial como si fuera completo. Worker/reconciliación conserva límites.
- Progreso vivo de lectura y generación del reporte en el volumen compartido; resultado final y
  descarga siguen sujetos a commit, autorización y estado final. Consultar progreso no bloquea
  el perfil por una inserción prolongada de valores predeterminados.
- Rol lector incorpora únicamente `indices:data/read/scroll/clear` para liberar cursores;
  sin ampliar índices, DLS ni escritura.
- Calendarios Admin/lector: preparación de datos solo para la vista activa y caché acotada
  de formato horario. Matriz por horas agrupa analistas coincidentes, muestra responsables/huecos
  y resumen al hover. Colores de turnos/ausencias, días de otro mes atenuados, reporte de ausencias
  y duración inclusiva; turnos personalizados y edición de día/programación sin borrar/recrear.
- SLA separa ACK y autoescalamiento (5 minutos iniciales), canales con switches según integración
  habilitada para notificaciones, reset por severidad y guardar grupo/todo con detección de cambios.
- Casos: Timeline/eventos antes de ACK, confirmación Aceptar/Rechazar sin texto, acciones ⋮,
  actualización cada 30 segundos con contador y periodos 24h/mes/3 meses/personalizado.
  Identificador de interfaz retirado del resto de pantallas. Conserva cambios de 0.1.170.
- TypeScript corregido: cero diagnósticos contra ambos SDK exactos.

## Validación y límites

Código validado localmente: 722 backend + 128 frontend (850), 97 comprobaciones RBAC,
17 pruebas de calendario y paridad del evaluador en 16 combinaciones. Se repiten las suites de
código y los gates de instalador/imagen para este paquete. Wheel/código instalado/pip check,
52 archivos de migración/configuración, plugins JS/gzip, cadena de hashes y sintaxis Bash verificados.
Upgrade sintético `a2c8e4f719b6` → head con FORCE RLS conserva campos previos, identidad protegida,
fechas SLA, turnos y conteos; segunda ejecución no cambia datos. No demuestra restauración DR.

Volumen sintético completo: 1.943.324 hallazgos; agrupación, simulación y reporte completos,
CSV de 1.943.324 filas, fallos cerrados ante inconsistencias. La generación concurrente local
tardó aproximadamente 26 minutos: no es un benchmark ni una garantía de tiempos de producción.
Las salidas de resumen todavía dependen de la cardinalidad de grupos; no se afirma memoria
constante para millones de grupos únicos. Presupuesto predeterminado de streaming: 5.000.000
hallazgos, espacio libre y spool limitados. No modificar límites para evitar un error sin diagnóstico.

Calendario local: guardado de tipo sintético 3,47 s → 136 ms; no es medida INP ni garantía de
latencia del servidor real. Un aviso de inline esperado por bootstrap y telemetría Cloudflare
bloqueada por CSP no justifican habilitar `unsafe-inline` o relajar la política.

**Pendiente:** revisión visual Word/PDF con el renderizador exigido; OpenSearch/DLS/proxy reales,
aceptación funcional y despliegue en LAUFEY. Las pruebas de estructura no aprueban presentación.
No se cambia Wazuh, HAProxy/Coraza/CSP, TLS, topología, identidad ni custodia OpenBao.
Los avisos de telemetría y `/api/request` 401 requieren diagnóstico independiente.

## SHA-256

| Artefacto | SHA-256 |
| --- | --- |
| SHA256SUMS externo | `9f5968ca6e4aecb011978eaa8d9aae9c8cd23707e1de36b628cea5b1ed25fd30` |
| TAR cifrado | `6082b7b3ae13771f4f88f334ceb5d1d1be4afb3ca4320167611505e9e9c9c53d` |
| TAR descifrado | `f7b10486f3abbc81f1a6e154e0abcd46b0a407de576bb1512f29747759f2482c` |
| soc-operations-install | `31cdc1460d5f4938e54c3aef569ca538472c4b8c7c3ccb4227e76b3f6100c2df` |

48 artefactos internos. Solo TAR cifrado con el destinatario age original y manifiesto en GitHub;
no fuente privada, identidades, configuraciones reales o backups. Se conserva 0.1.170 inmutable.
[Actualizar LAUFEY](upgrade-0.1.171-laufey.md): respaldo nuevo obligatorio y ejecución por etapas,
solo en el Dashboard .117 con Manager local; no en Indexers. No usar instalación limpia, `apply`,
inicialización OpenBao, downgrade o borrado de volúmenes. Publicar no actualiza el servidor.
