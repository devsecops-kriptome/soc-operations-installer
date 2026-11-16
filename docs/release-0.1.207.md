# SOC Operations 0.1.207 — candidato AIO: Activos del cliente

**Pre-release para un servidor de pruebas.** No reemplaza la versión estable 0.1.206.
La publicación no instala ni modifica ningún servidor.

## Versiones

- Instalador 0.1.207; API, API externa, worker y agente 0.1.150.
- Plugin socOperations 0.1.127 para OpenSearch Dashboards 2.19.5 y 2.19.6.
- Compatibilidad de plataforma: Wazuh 4.14.7-1 / 4.14.8-1. Validación de destino
  pendiente; esta entrega se destina primero a un AIO de pruebas.
- Esquema PostgreSQL d8a215c963b7; sin nueva tabla SQL de inventario.

## Activos del cliente

Dashboard, consulta y administración por tenant. Administración requiere Ingeniería
o membresía SOC Manager activa del tenant; el rol admin por sí solo no basta.
El inventario usa alias `wazuh-assets-<tenant>` e índice físico versionado.

CSV con mapeo de columnas, previsualización y confirmación. Snipe-IT incluye
usuario asignado, correo, departamento y ubicación. GLPI REST v1 admite equipos
Computer de una entidad exacta sin subentidades, usuario y correo predeterminado
o único autorizado; no elige un correo ambiguo ni lo inventa sin permiso.

Coincidencia exacta por nombre normalizado o alias confirmado, sin IP/any ni
aproximaciones. Casos ambiguos se revisan manualmente. Cada agente puede asociarse
a un solo activo del mismo tenant; los cambios usan revisión y comprobación de
concurrencia. Hay menús de tres puntos y modales para las acciones administrativas.

El contexto enriquece **casos creados** después del commit. No escribe alertas o logs,
ni cambia el analista SOC, estado o SLA. El correo del usuario del activo no pasa a
ser destinatario. La asignación actual se distingue de una asignación histórica
verificada. No se reconstruyen hitos ni se ejecutan planes SLA.

Programación de Snipe-IT y GLPI optativa, inicialmente apagada, de 15 minutos a siete
días. Requiere importar y revisar manualmente el mismo origen primero. Un fallo
pausa la programación. No borra ausentes ni reescribe contextos anteriores.

La API externa añade lectura de inventario con `assets:read`; el contexto de casos
requiere también `cases:read`. No amplía permisos de claves existentes.

## Preparación y límites

Activos está deshabilitado por defecto. No se crean credenciales Indexer ni se abre
el puerto 9200 durante la instalación. Se prepara un directorio de CA públicas
montado de solo lectura y se incluyen las políticas de servicio OpenBao necesarias.
La habilitación debe realizarla el operador después de verificar identidad dedicada,
alcance de roles, TLS y conectividad desde los contenedores.

La guía `ASSETS-AIO-0207.txt` y la plantilla `assets-indexer-role.json` vienen dentro
del archivo cifrado. La plantilla no se aplica automáticamente ni constituye una
certificación de mínimo privilegio en todas las versiones del Indexer.

Límites iniciales: 5.000 activos por tenant, 250 filas por lote y 500 snapshots
vinculados por caso. Las importaciones no son transacciones entre documentos;
una interrupción puede dejar recibos parciales. Las reclamaciones `running` no
se roban por vencimiento: revisar el worker anterior y reconciliar antes de liberar.
La recuperación administrativa guiada y retención de historial siguen pendientes.

## Validación y aceptación pendientes

Compilación verificada de ambos plugins y de la imagen compartida por los servicios.
Resultados locales: **3.644 pruebas backend/agente y 534 de interfaz aprobadas**,
sin fallos ni pruebas omitidas; además, 202 comprobaciones de contratos del instalador
y transición aprobadas. Ruff, mypy y sintaxis de los helpers pasan; ShellCheck no
introduce hallazgos respecto a 0.1.206. Los análisis conservan las excepciones
preexistentes documentadas, sin afirmar ausencia total de vulnerabilidades.

Se comprueban localmente compilación, contratos, autenticación, permisos y concurrencia,
incluyendo PostgreSQL/RLS aislado. Los conectores se ejercitan con respuestas sintéticas.
**No se ha certificado el E2E completo con Wazuh Indexer, Snipe-IT y GLPI reales,
la restauración del nuevo índice ni la instalación en el AIO de destino.**
También están pendientes la aceptación visual desplegada, carga representativa,
certificados y políticas efectivas del entorno de pruebas.

Se conserva la base de seguridad y el artefacto MinIO de 0.1.206. No se vuelve a
descargar MinIO ni se promete eliminar los riesgos residuales de dependencias o
infraestructura. No se reemplazan assets de releases anteriores.

## Distribución

Solo el TAR cifrado con age y SHA256SUMS se adjuntan a la release. No se publican
código privado, TAR en claro, tokens, identidades age, respaldos ni datos de clientes.
Se utiliza el destinatario público existente; la identidad privada permanece en
el gestor autorizado. El descifrado debe verificarlo el operador.

Consultar [pruebas y actualización AIO](upgrade-0.1.207.md).
