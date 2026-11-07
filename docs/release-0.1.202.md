# SOC Operations Installer 0.1.202

Fecha: 2026-11-07 (America/Lima).
API interna/externa, worker y agente: 0.1.145. Plugin: 0.1.123.
Esquema: f4b8cae32175. Wazuh 4.14.7-1/OSD 2.19.5 y Wazuh 4.14.8-1/OSD 2.19.6.

## SLA y Ranking Analyst Performers

- Cálculos basados en eventos verificables y objetivos históricos del caso,
  sin sustituirlos por la política vigente ni inventar fechas faltantes.
- MTTQ: creación a calificación explícita TP/FP/benigno. MTTI: calificación TP
  a investigación completada explícitamente. El playbook sigue siendo referencial.
- Desglose por severidad, AVG, objetivos históricos y categorías fully achieved,
  partially achieved, not achieved y not evaluable en el período solicitado.
- TOP 10 por menor AVG para MTTQ, MTTI, MTTR operativo y MTTC, con posición,
  nombre, duración, casos actualmente cerrados en el período y SLA Compliance.
  MTTD sigue disponible como métrica del SOC, no se atribuye a una persona.
- SLA Compliance es un número entre 0 y 100: met/(met+breached)*100. Unknown
  no entra al denominador; sin evaluables devuelve null, no 0 ni 100 ficticios.
- Por defecto se exigen cinco muestras. El porcentaje solo desempata el AVG;
  no se agregan analistas sin datos ni se redondea el promedio para ordenar.
- Corrige plazos contradictorios de primeras respuestas simultáneas, selección
  temporal del ranking y diferencias entre lectores del cierre vigente.
- Los cambios de estado con la misma hora solo se ordenan por una cadena from/to
  única y verificable; un empate irresoluble no certifica SLA ni autor por UUID.
- Los lectores conservan contexto de tenant, permisos mínimos y una misma
  transacción de solo lectura con snapshot consistente en PostgreSQL.

## Otros cambios incluidos

- Filtros personalizados de tiempo con segundos explícitos.
- Endpoints de cliente limitados al cliente solicitado, sin confundir pertenencia
  con estado del agente en la respuesta de inventario.
- Consulta externa de horarios por correo bajo permiso específico y alcance vigente.
- Activación de fuentes tecnológicas y control de ausencia confirmada de agentes;
  las fuentes efectivamente deshabilitadas dejan de listarse en la API externa.
  Un fallo de inventario no equivale a una baja confirmada.
- Nombres de agente en la UI de tecnologías, manteniendo el contrato de identidad
  de la API externa. Conserva controles de tenant y resultados por fuentes habilitadas.
- Conserva snapshots y métricas compactas de vulnerabilidades de 0.1.201, así como
  reportes con datos actuales y el último corte completo durante otra captura.

## Validación y límites

- 3324 pruebas backend/agente y 497 de interfaz aprobadas, sin fallos ni omisiones.
- 258 pruebas dirigidas con PostgreSQL real y 37 de cadena de artefactos, con
  solapamiento: no se presentan como pruebas únicas adicionales a la regresión.
- Migraciones existentes y equivalencia modelo/esquema comprobadas; RLS,
  permisos, revocación, aislamiento y concurrencia validados con datos sintéticos.
- Wheel, imagen instalada y fuentes contrastadas; pip check y arranque real de
  API externa sin red, sin root y sin credenciales productivas comprobados.
- Ambos plugins compilados y verificados con sus SDK exactos; TypeScript,
  Ruff y MyPy aprobados. ShellCheck no añade hallazgos a los 13 preexistentes.
- SAST conserva tres patrones medios revisados, sin medios/altos sin revisar.
  Persisten avisos de deprecación de pruebas y Browserslist/Babel del SDK.
- No se ejecutó aceptación autenticada en LAUFEY ni restauración/backfill de datos.
  Los casos sin hitos u objetivos verificables seguirán desconocidos/no evaluables.
- La recuperación histórica de SLA se hará después, con plan revisado y aplicación
  explícita auditada. El instalador no restaura una base antigua ni reescribe casos.
- Cifrado con el destinatario age habitual. No se usó una identidad privada;
  el operador debe comprobar el descifrado antes de instalar.

## Integridad

| Archivo | SHA-256 |
| --- | --- |
| `soc-operations-0.1.202.tar.gz.age` | `999aa01ff88b062f1266258a4e8e779ea7729cd4e4e801fd759207445c355a5e` |
| `soc-operations-0.1.202.tar.gz` | `0573963c5c443089bad45b6aa6c1ef51a8ecd07f37cff94e1286b1ea34a43228` |
| `SHA256SUMS` | `7a93ee65d91a0b5eee607202d7e8a82c280124d6ba598d04a50c4eed06e52952` |

[Actualización y aceptación](upgrade-0.1.202.md).
