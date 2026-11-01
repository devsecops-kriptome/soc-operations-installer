# SOC Operations 0.1.195 — 2026-11-01

Instalador: 0.1.195
API interna / API externa / worker / agente: 0.1.138
Plugin: 0.1.117
Esquema: f97dc8e12543
Compatibilidad: Wazuh 4.14.7-1 / OSD 2.19.5 y Wazuh 4.14.8-1 / OSD 2.19.6.
Topologías: AIO y distribuida, conservando la identidad y topología existentes.

Cambios desde 0.1.194:
- SLA y métricas de casos automáticos: MTTD desde la alerta de origen, MTTR
  hasta el primer En progreso explícito y MTTC hasta Cerrado. Resuelto y Cerrado
  mantienen hitos distintos. Los casos proactivos quedan fuera de estos SLA.
  Se conservan las políticas personalizadas por tenant y los objetivos registrados.
  MTTQ/MTTI sin hitos suficientes permanecen sin dato; no se inventan tiempos.
- Acceso directo Marcar En progreso sin comentario obligatorio y recordatorio
  cinco minutos naturales después del ACK; indicación visual del estado pendiente.
- Conversión reversible a incidente con confirmación, clasificación Crítica/P1
  y restauración auditada, respetando restricciones de casos relacionados.
- Casos relacionados en una pestaña propia: páginas de diez y área desplazable.
  Los hijos conservan sus eventos e historial al vincularlos o desvincularlos.
- Copia opcional de clasificación y cierre al adjuntar un caso a un padre cerrado,
  atribuida al analista que adjunta, sin sustituir la trazabilidad histórica del padre.
- Escalamiento por correo con destinatarios y copias seleccionados explícitamente,
  incluyendo contactos externos del mismo tenant; actividad y estado de entrega visibles.
  El correo manual queda disponible inmediatamente aunque el SLA esté pausado.
- Recordatorios agrupados por familia, instante, canal y analista responsable,
  sin perder la trazabilidad individual ni mezclar tenants o responsables.
- Intención de entrega persistente antes del transporte, reclamación concurrente
  y recuperación segura. Una entrega incierta requiere revisión y no se reenvía
  automáticamente. La aceptación SMTP no acredita llegada a la bandeja.
- Verificación de tenant/caso y de la relación entre reporte, entrega, destinatario
  y adjuntos antes del transporte; actualización de resultados con el mismo alcance.

Migraciones desde c64e93b8a521:
  d75fa6b90321 — objetivos y umbrales de cumplimiento por tenant.
  e86ab7c01432 — vencimiento independiente de cierre, sin reescribir históricos.
  f97dc8e12543 — selección de contactos del tenant para escalamiento por analistas.

No se activa replay histórico ni se cambia el estado habilitado de la API externa.
La validación local no sustituye respaldo nuevo ni aceptación del servidor destino.

## Validación de esta entrega

- Backend/agente: **2.625 pruebas** aprobadas en una ejecución completa, sin fallos ni omisiones.
- Interfaz: **418 pruebas** aprobadas, sin fallos, cancelaciones ni omisiones.
- Ruff y Mypy: sin incidencias; 142 archivos comprobados por Mypy.
- Tipos y bundles del plugin: aprobados para OSD 2.19.5 y 2.19.6.
- PostgreSQL temporal con RLS y rol de aplicación sin SUPERUSER/BYPASSRLS;
  migraciones completas y paridad de modelos aprobadas.
- Imagen, wheel, fuentes, migraciones y referencias inmutables verificados.
  Arranque real de la API externa con usuario sin privilegios, raíz de solo lectura
  y sin red; rechazo sin clave y rechazo de escrituras comprobados.
- ShellCheck: sin errores ni hallazgos nuevos respecto a 0.1.194.
- SAST: tres patrones de severidad media revisados y justificados (URLs de configuración
  administrativa y acceso de grupo a configuración Wazuh); no se ocultaron los avisos.

Esto es validación local sintética. La entrega SMTP real, la aceptación en navegador y
las integraciones Wazuh/Indexer del destino se verifican después de un upgrade controlado.

## Integridad y descarga

Los únicos assets binarios de la release son el instalador cifrado y SHA256SUMS.
La identidad privada age sigue en el gestor autorizado y no se publica.

| Archivo | SHA-256 |
|---|---|
| `soc-operations-0.1.195.tar.gz.age` | `a2308f2fa863d5575a9fe8ca6b082787f0cbbf3a2f6bed31516071383d767122` |
| `soc-operations-0.1.195.tar.gz` | `a71dc3803e4949d0bef942da66c122fee8c1a71c6206db13965c991bda135ac3` |
| `SHA256SUMS` | `fa7000209948365d2c32d28feae11533790c380dd6657508b4c5afbeced30be4` |
| `SHA256SUMS interno` | `86d1e048ffa9c507ec8afb9fcf032938763ac2d3f45571e12ba8e58a9046515b` |
| `soc-operations-install` | `9d927686a65c27c7dbf07fc7a3e6a5ed8b7e4eb00304dba58340a6835d2e07ad` |

[Descargar la release v0.1.195](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.195).
