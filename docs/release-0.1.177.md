# SOC Operations 0.1.177

Fecha: 16 de octubre de 2026. Instalador 0.1.177; API/API externa/worker/agente 0.1.127;
plugin socOperations 0.1.107 para OSD 2.19.5 y 2.19.6.
Interfaz: `0.1.107-ack-analyst-dashboard-routing-case-details`.
Esquema e31a7f82c940, sin migraciones nuevas respecto de 0.1.176.

## Cambios incluidos

- Dashboard: cuadro de atención por analista, criticidad, SLA y ACK no atendidos situado
  inmediatamente debajo de «Casos creados». Usa los mismos filtros de periodo, tenant y archivados.
  La cohorte son casos creados en [inicio, fin), no la fecha en que ocurrió cada ACK.
- Los casos tomados se atribuyen al autor del primer ACK persistido, no al encargado actual.
  Cada asignación vencida que provoca escalamiento cuenta para su responsable original, incluso
  si otra persona toma el caso después. No se duplica por canal; los históricos incompletos se
  señalan sin inventar autor, vencimiento ni métricas.
- Notificaciones: responsables Analista → SOC Manager → Ingeniería; después el resto del turno
  activo en ese mismo orden. Se excluyen personas fuera de turno, ausentes, inactivas y Junior
  como responsables. Tras agotar disponibles se encola un único aviso general por canal, sin
  menciones; no se reinicia el ciclo. Se revalida la elegibilidad y vigencia al entregar avisos.
- Calendario y Calendario Admin resaltan el día actual. Kanban mantiene límites y totales por
  columna, orden por última modificación e identificadores de padre/hijo.
- Casos relacionados: opciones de copiar datos al anexar, conservar eventos propios del hijo,
  consultar eventos heredados con procedencia y desvincular con autorización y motivo.
- Detalle compartido de eventos en timeline y relacionados, acciones de original/copia en el
  encabezado y navegación inferior. Descripción y full_log largos se pliegan sin perder el texto
  completo; incluye full_log presente en la descripción del caso.
- Los campos extra de automatizaciones se leen del documento original de alerta. No se ejecuta
  una reparación masiva de casos históricos. Cambios operativos también aparecen en comentarios.
- Las respuestas inmediatas de escritura conservan el contexto RLS al materializar datos antes
  del commit: evita conteos de hijos o identidades incompletas tras guardar. No desactiva RLS ni
  modifica los permisos productivos.

## Integridad y publicación

- Paquete cifrado: `70c6b0628a7552bbbbcfd2fc4d49e67606cb6f93f3e28d60007c8289a87b6a98`.
- TAR descifrado: `2dd6b1c4544d920cea21d7d2c71d166d52bb195a1fc1cb9565103135f73bc192`.
- SHA256SUMS público: `e376d966c6ab9c2f13429685835cbdf0d5f385de5e4ab1809b38986d2f72c29d`.
- Orquestador: `58be525bcf4fad2027de568d3ffb7dd12b4ffa15f13b3df8e67e0bf78c0e2df3`.

Se publican únicamente `soc-operations-0.1.177.tar.gz.age` y `SHA256SUMS`. No se publica el TAR
sin cifrar, código privado, identidades age, datos productivos ni respaldos. La identidad se obtiene
por el canal autorizado existente. Los activos de 0.1.176 se conservan inmutables.

## Validación

Recompilación de ambos plugins y 214 pruebas frontend aprobadas. Suite de release: 977 pruebas backend/agente aprobadas; las 20 pruebas PostgreSQL omitidas en la pasada general se ejecutaron nuevamente y aprobaron con PostgreSQL real desechable. La validación funcional anterior documentó 1.272 pruebas distintas aprobadas, incluidos HTTP/JWT/RLS y el ciclo de escalamiento. No se suman nuevamente sus subconjuntos ni se presenta esa evidencia como una aceptación productiva de este instalador.

Wheel, código instalado en imagen Linux amd64 y fuentes de migración se comparan byte/hash;
pip check en imagen sin red, smoke de alcance de inventario, compilación y TypeScript de ambos
plugins, hashes fijados, desempaque seguro y hashes interiores. Se comprueba que los nuevos
indicadores existen en los bundles, no solo que el ZIP o la versión sean válidos.
Los recorridos HTTP y de escalamiento usan PostgreSQL local/JWT y datos sintéticos, sin enviar
Slack/SMTP ni arrancar el worker real contra integraciones productivas.

## Pendientes y límites

- Bandit: 31 alertas bajas y 3 medias pendientes de triage formal; no equivalen a vulnerabilidades
  confirmadas. Una observación Ruff E501 preexistente. No se declara MyPy global limpio ni una
  auditoría nueva de CVE. Estas advertencias no se silenciaron al empaquetar.
- Persisten pendientes visuales Word documentados en 0.1.176 y la aceptación del caso histórico
  de agent.id reutilizado dentro del mismo tenant. No se declara aprobación visual completa.
- Faltan aceptación productiva, entrega real de notificaciones, carga/latencias reales y ensayo
  integral de recuperación con RPO/RTO medidos. Un respaldo caliente no cubre escrituras posteriores
  a su captura ni garantiza una instantánea atómica entre todos los componentes.
- Publicar esta versión no instala ni actualiza el servidor y no garantiza interrupción cero.

Seguir la [guía de actualización desde 0.1.176](upgrade-0.1.177.md).
