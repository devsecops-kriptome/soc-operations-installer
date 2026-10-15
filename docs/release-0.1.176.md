# SOC Operations 0.1.176

Fecha: 15 de octubre de 2026. Instalador 0.1.176; API, API externa, worker y agente 0.1.126;
plugin socOperations 0.1.106 para OSD 2.19.5 y 2.19.6. Esquema e31a7f82c940.

## Cambios incluidos

- Reportes de vulnerabilidades: Excel en lugar de nuevos CSV masivos, con hasta 10 CVE
  distintos más recientes por host y paquete; una hoja por grupo en agrupación por grupos.
  Los CSV históricos conservan descarga explícita como archivos anteriores.
- Eliminación de reportes con confirmación, RBAC, auditoría y protección de ejecuciones o
  envíos activos. Se eliminan los archivos del reporte, no evidencias S3 ni datos de casos.
- Vulnerabilidades presentes sin recarga automática de 30 segundos. La selección de grupos
  usa un inventario mTLS reducido; listar o descargar reportes evita cargar su contrato grande.
- Word: una tabla por paquete en las vistas agrupadas; nombres originales para trazabilidad.
  Se unifican exclusivamente variantes conocidas de ASP.NET Core que difieren por el separador
  antes de Shared Framework, conservando versión y arquitectura. Cada paquete muestra el total
  de hallazgos y advierte si los CVE de la tabla son una muestra limitada a 10. No se confunde
  el total de hallazgos con los CVE distintos ni se inventa una unión exacta a partir de muestras.
- Asignar turnos no selecciona automáticamente el primer analista en una asignación general.
  Casos e incidentes inicia en vista compacta. Los casos nuevos basados en eventos anteponen
  agent.name o la tecnología externa; no se renombran casos históricos automáticamente.
- Los eventos permanecen en el caso hijo. El padre consulta eventos y timeline con procedencia,
  sin apropiarse de sus vínculos. Los cambios de estado, severidad, prioridad, categoría y
  encargado del padre se propagan a hijos con justificación y auditoría. El hijo conserva su
  ACK, sus SLA, notas y trabajo propio. El cierre del padre se propaga a sus hijos.
- La migración restaura únicamente vínculos antiguos cuya procedencia de hijo está probada
  y sigue siendo compatible con la relación y el tenant actuales. No reasigna vínculos ambiguos
  ni cambia hashes, snapshots, ACK o SLA. El downgrade no revierte esa corrección de datos.

## Integridad

- Paquete cifrado: `08f504c2d2f76856da969128a67f87e0b9e2e47e0a6678c6c3775bfa68529a02`.
- TAR descifrado: `122685c0efc8f7a588f3dfc38a15d426338eff44981e402e8779a79a50850eed`.
- SHA256SUMS público: `00edf7b625b5e8c6f971216aa3a2b0a15e78d7e63f335f809103eb0d94f3fe7d`.
- Orquestador: `a790c776594f05022620088a7c006b1c78e1a8fcc63bf8685dd7775698b1d488`.

En GitHub se publican únicamente el TAR cifrado con age y SHA256SUMS. La identidad privada se
obtiene por el canal autorizado existente; no se incluye código privado ni respaldos en el Git público.

## Validación

863 pruebas backend/agente aprobadas en la suite general, más 20 omitidas allí y aprobadas con PostgreSQL real desechable; 883 pruebas backend distintas. 163 pruebas frontend aprobadas. Sin fallos en estas pasadas.

Se verifica correspondencia de fuentes, wheel e imagen Linux amd64, pip check, migraciones,
compilación y TypeScript de ambas variantes OSD, integridad interior y desempaquetado seguro.
Los tests de reportes usan inventario sintético; no son una aceptación de datos de producción.

## Límites y pendientes

- Persisten cuatro defectos visuales del Word: recorte de un gráfico de CVE, encabezados
  estrechos, una descripción antigua que menciona CSV y orden de apartados del contenido.
  La agrupación y el texto de totales/muestra se revisaron con LibreOffice local autorizado;
  no se declara aprobación visual completa del documento.
- La aceptación en producción y un ensayo de restauración del respaldo vigente son pendientes.
  Las pruebas locales no garantizan cero interrupción ni cero pérdida de escrituras posteriores
  a un respaldo. Esta publicación no instala ni actualiza LAUFEY.
- No se declara un MyPy global limpio: se conservan diagnósticos previos fuera del alcance
  modificado. Los módulos de reporte revisados sí pasaron su comprobación acotada.
- La aceptación adicional de identidades con agent.id reutilizado dentro del mismo tenant
  permanece pendiente; esta entrega no afirma resolver todos esos escenarios históricos.

Seguir la [guía de actualización](upgrade-0.1.176.md). La versión 0.1.175 y sus activos se conservan.
