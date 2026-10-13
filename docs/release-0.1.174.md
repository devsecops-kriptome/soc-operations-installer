# SOC Operations 0.1.174

Instalador `0.1.174`; API, API externa, worker y agente `0.1.124`; plugin `0.1.104`.
Esquema `c17e89ab2304`, sin migraciones nuevas desde `0.1.173`.
Compatible con Wazuh 4.14.7-1 / OSD 2.19.5 y Wazuh 4.14.8-1 / OSD 2.19.6.

## Casos y automatizaciones

Casos e incidentes abre con los últimos 7 días y conserva el refresco de 30 segundos.
El Dashboard permite fechas personalizadas, con fin exclusivo, hasta 31 días y un máximo
de 5.000 casos; pide acotar el rango antes de presentar indicadores parciales.

Las automatizaciones permiten editar nombre, ventana, claves, condiciones y campos del
detalle con motivo auditable. La columna Acciones usa un menú ⋮ con Editar y Pausar/Activar.
La autorización por tenant y la protección de reglas globales permanecen vigentes.

Los filtros adicionales usan `[campo] [operador] [valor]` y se combinan mediante AND con
las condiciones existentes. Admite `=`, `!=`, `>`, `<` y `~`; este último significa texto
contenido sin distinguir mayúsculas, no regex ni un intérprete WQL completo. Los campos
ausentes no coinciden, tampoco con `!=`. Máximo de 32 filtros y 32 campos adicionales.

Los nuevos eventos asociados conservan campos configurados como `data.event.FalconHostLink`.
Los valores ausentes muestran No disponible y los enlaces admitidos se presentan de forma
segura. Las modificaciones no reescriben las evidencias históricas.

## Vulnerabilidades y almacenamiento

Vulnerabilidades presentes permite combinar grupo, sistema operativo y nombre del host.
Los filtros se aplican antes de paginar y calcular totales completos. El nombre busca texto
literal sin distinguir mayúsculas. Escribir no consulta por tecla; se usa Aplicar o Enter.
El SO se obtiene del inventario Wazuh mediante una consulta de solo lectura sin claves internas.

La ordenación del inventario del reporte mantiene un índice durante la ingesta y evita copiar
los documentos JSON completos al ordenador temporal. `SQLITE_TMPDIR` en API y worker apunta
al volumen de reportes. Se conservan read-only, /tmp de 64 MiB, mínimo de 1 GiB libre,
presupuesto de 16 GiB y rechazo de inventarios/reportes parciales. Los errores de capacidad
distinguen el almacenamiento de trabajo del espacio libre de la raíz del servidor.

## Validación

792 pruebas backend/agente y 17 adicionales con PostgreSQL real desechable aprobadas;
144 pruebas frontend. Plugins compilados y TypeScript aprobado para ambas plataformas.
Wheel e imagen comparados con las fuentes, pip check correcto y 52 archivos de migración
verificados. Sintaxis Bash, pins, desempaque real y todas las sumas internas comprobados.
La prueba de inventario conserva 250.001 filas completas y una ordenación sin TEMP B-TREE.

## Límites y pendientes

- Defecto conocido: al reutilizar un ID con un nombre de agente distinto dentro del mismo
  tenant, la lista puede aceptar SO/IP del reemplazo bajo el nombre anterior. Este release
  no corrige ese caso; revisar y reconciliar la identidad antes de usar esos metadatos.
- Mypy conserva 33 diagnósticos previos en el alcance comparado, sin nuevos; no está globalmente limpio.
- Las imágenes de revisión son locales y sintéticas; no certifican una aceptación en LAUFEY.
- El diagnóstico real de espacio/inodos del worker, el reporte en producción y la revisión
  visual Word con el renderizador requerido siguen pendientes.

## Distribución y actualización

Solo se publican `soc-operations-0.1.174.tar.gz.age` y `SHA256SUMS`. El destinatario age es el
existente; no se publican identidades privadas, código en claro ni respaldos. Las versiones
anteriores permanecen intactas. [Actualizar desde 0.1.173](upgrade-0.1.174.md).
Publicar no modifica LAUFEY, Wazuh, OpenBao, HAProxy, Coraza ni CSP.

## SHA 256

- Paquete cifrado: `1f68a75645e30a06552c2f2492f084d8bf482ce31fdc5c5e4c8aaec028dc987c`.
- TAR descifrado: `9d167fcdea850328708f0a309b76e9268ba532115258d4e4d44a4a31cedb8ba8`.
- SHA256SUMS público: `1f441c37dc09f4e5e93c49ea746af1b496ded5ef212840135aa7b2609e3c9546`.
- Orquestador soc-operations-install: `dd862205c4396150b49af84ffff5bca730d0a314e8fdcd471dc90f6397329272`.
