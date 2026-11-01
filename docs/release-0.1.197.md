# SOC Operations 0.1.197 — 2026-11-01

Instalador: 0.1.197
API interna / API externa / worker / agente: 0.1.140
Plugin: 0.1.119
Esquema: f97dc8e12543 (sin migraciones nuevas respecto a 0.1.196).
Compatibilidad: Wazuh 4.14.7-1 / OSD 2.19.5 y Wazuh 4.14.8-1 / OSD 2.19.6.
Topologías: AIO y distribuida, conservando identidad y topología existentes.

Cambios desde 0.1.196:
- Casos e incidentes: cabecera reorganizada, acciones y controles de vista agrupados.
- Gestión del caso: secciones como pestañas, navegación horizontal y por teclado;
  botón Volver a gestión de casos en la cabecera para aprovechar el espacio.
- Buscar y vincular alertas o eventos y Anexar casos existentes están disponibles
  tanto en Eventos relacionados como en Casos relacionados, con los mismos permisos.
- Actividad elimina el resumen duplicado de correos. El indicador Escalamiento
  abre el detalle; cada actividad conserva una sola acción Ver detalle.
- Historial de escalamiento con vista de correo de solo lectura, último primero,
  navegación anterior/más reciente y actualización que vuelve al último correo.
  Conserva asunto, remitente, destinatarios, copias, fecha y cuerpo preparado.
  Los correos antiguos sin copia original se identifican como no disponibles;
  no se reconstruyen con una plantilla posterior.
- Adjuntos del escalamiento: XLS, XLSX, CSV, DOCX, TXT/MD UTF-8, PNG, JPEG,
  GIF, WEBP, BMP y TIFF. Máximo combinado de 25.000.000 bytes (25 MB),
  validado en cliente y API; hasta 100 archivos no vacíos.
  Se guardan como evidencia del caso, con versión y SHA-256. Para y CC comparten
  el mismo mensaje. Los reintentos conservan el contenido y los archivos y solo
  envían a destinatarios que aún no fueron aceptados por SMTP.
- Modal de escalamiento adaptable, hasta 1.000 px de ancho; destinatarios y CC
  a todo el ancho y motivo ampliable de diez líneas. Muestra progreso y evita
  cerrar mientras se registra el envío. Cambiar de canal limpia destinatarios,
  copias y adjuntos. Operaciones antiguas no muestran avisos en otro tenant.

Se conserva la correlación global y por tenant de 0.1.196, incluida clasificación
por la primera alerta, exclusiones, ventanas y deduplicación. No se reprocesa
el histórico, no se reclasifican casos y no se activan reglas pausadas al actualizar.
El estado de la API externa y la topología persistida se conservan.

La aceptación SMTP no confirma llegada a bandeja. Revisar el Message-ID de una
entrega incierta antes de reenviar. El límite de archivos usa bytes originales;
el mensaje MIME y el POST codificado son mayores. Verificar los límites del
proveedor SMTP y del proxy del destino al aceptar adjuntos grandes.
Actualizar API, worker, agente y plugin juntos mediante el instalador.
La validación local no sustituye un respaldo nuevo ni la aceptación del destino.

## Validación de esta entrega

- Backend y agente: **2728 pruebas**, sin fallos ni omisiones.
- Interfaz: **439 pruebas**, sin fallos, cancelaciones ni omisiones.
- PostgreSQL temporal con FORCE RLS, rol de aplicación sin SUPERUSER/BYPASSRLS y
  paridad migraciones/modelos; no hay migraciones nuevas desde 0.1.196.
- Pruebas del protocolo SMTP con servidor local: MIME, adjuntos, Para/CC,
  rechazos parciales, reintento selectivo y rechazo por tamaño.
- Tipos y bundles compilados para OSD 2.19.5 y 2.19.6 exactos; wheel, imagen,
  fuentes instaladas y pares JavaScript/gzip verificados.
- Ruff, Mypy de 145 módulos y ShellCheck sin errores ni hallazgos nuevos.
- SAST: tres patrones medios preexistentes revisados y justificados, sin ocultarlos.
- API externa real con usuario sin privilegios, raíz de solo lectura y sin red:
  liveness 200, sin clave 401 y escrituras rechazadas con 405.

La validación local no sustituye la aceptación del SMTP, Wazuh/Indexer y navegador
del servidor destino. Publicar no ejecuta el instalador en ningún servidor.

## Integridad

Los únicos assets binarios son el instalador cifrado y SHA256SUMS.
La identidad privada age se obtiene del gestor autorizado y no se publica.

| Archivo | SHA-256 |
|---|---|
| `soc-operations-0.1.197.tar.gz.age` | `d99fdaabf2585b71532b387cd175a0e94c8e692b0426f035f902d3f2b15cdb5d` |
| `soc-operations-0.1.197.tar.gz` | `23a311e082ef2183fdfabbc57143352baf1228dd39e9bc19998d18b2ff458e2f` |
| `SHA256SUMS` | `8401132eb2c462c2075506c05a7f68d65022a8a2265849fedead28c5950bc369` |
| `SHA256SUMS interno` | `ff11da896c1511fab84d3711eed8a5faa3548877181f97807f82f253bb57d2e4` |
| `soc-operations-install` | `93d4891f88d1eb11803ce0cfb69a7689cd31343cd50b6edafe6f811dbc087336` |

[Descargar v0.1.197](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.197).
