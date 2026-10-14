# SOC Operations 0.1.175

Instalador `0.1.175`; API, API externa, worker y agente `0.1.125`; plugin `0.1.105`.
Compatible con Wazuh 4.14.7-1 / OSD 2.19.5 y Wazuh 4.14.8-1 / OSD 2.19.6.
Incluye los cambios de casos, automatizaciones, reportes y alineación posteriores a 0.1.174.

## Casos y datos extras

Las automatizaciones configuran Datos extras del caso, visibles en Detalles del caso, un campo
por línea. Los campos ausentes muestran No disponible y la evidencia original conserva su copia y hash.

Cada caso recibe un número diario por tenant, como `20261014-1`, sin reemplazar su UUID. La vista
compacta muestra número y título; la extendida conserva el resto de la información.
La unión manual está disponible en el menú de eventos y casos. Traslada los eventos al principal
con su procedencia, sin reiniciar sus SLA ni reanudar una pausa. Un hijo nuevo recibe ACK y
asignación al usuario de la unión con la hora real; un ACK anterior no se sobrescribe. El hijo
conserva su vencimiento y puede cerrarse por separado. El cierre del principal permite decidir
si cerrar también sus hijos abiertos con un comentario que referencia el principal y su razón.
No sobrescribe cierres previos. Se rechazan uniones entre tenants, ciclos, anidamiento y actores
sin autorización.

## Reportes de vulnerabilidades

Los reportes usan el inventario vigente, sin fuentes alternativas ni filtro de período. Permiten
seleccionar grupos y agrupar host → paquete, paquete → hosts o grupo → paquete → hosts; esta
última opción requiere uno o más grupos. Los grupos se combinan sin duplicar hosts.
Se consolidan encabezados de paquetes en Word. La descarga CSV utiliza un proxy de transmisión
para archivos grandes, conservando los límites de las respuestas JSON. Envío programado está
junto a Generar reporte y no solicita un perfil adicional.

## Interfaz

Los filtros de reportes, bandeja y búsqueda de vínculos quedan alineados aunque incluyan textos
de ayuda. SLA separa el título de severidad y coloca Autoescalamiento sin ACK bajo Calendario.
Eventos relacionados y anexado usan menús verticales de tres puntos. El playbook abre plegado
y tiene un botón vertical que admite teclado. Se mantienen los permisos y bloqueos existentes.

## Migración y actualización

Esta entrega incorpora `d29f63a710bc`, posterior a `c17e89ab2304`: agrega números diarios,
contadores por tenant y relaciones padre/hijo. Los casos históricos se numeran por su fecha de
creación y zona horaria configurada. El backfill mantiene RLS; no elimina casos.
Preparar un respaldo nuevo antes de aplicar la migración.
[Actualizar desde 0.1.174](upgrade-0.1.175.md).

## Validación y límites

810 pruebas backend/agente aprobadas en la suite general, más 19 omitidas allí y aprobadas con PostgreSQL real desechable; 829 pruebas backend distintas. 162 pruebas frontend aprobadas. Sin fallos en estas pasadas.
Los dos plugins se recompilaron y TypeScript pasó para OSD 2.19.5 y 2.19.6. Wheel e imagen se
compararon con las fuentes, pip check pasó y se verificaron 53 archivos de migración/configuración.
El TAR se desempacó en un directorio nuevo y se comprobaron sus rutas, tipos y hashes internos.
La revalidación visual local midió seis áreas con 0 px de desnivel y comprobó menús, playbook y
reset SLA. Las capturas usan datos sintéticos; no certifican el rendimiento o la aceptación de LAUFEY.

Quedan pendientes la aceptación real Word/CSV a través del proxy externo, envío SMTP y capacidad
del worker con el inventario de producción. Word tiene pruebas estructurales, no aprobación visual
con el renderizador requerido. La última comparación MyPy conserva 69 diagnósticos previos;
esta publicación no afirma limpieza global de MyPy. También persiste el caso conocido de un ID
de agente reutilizado con metadatos SO/IP del reemplazo bajo el nombre anterior en el mismo tenant.

## Distribución

Solo se publican `soc-operations-0.1.175.tar.gz.age` y `SHA256SUMS`. Se conserva el destinatario
age existente y los activos de versiones anteriores. No se publican código privado en claro,
identidades, respaldos ni secretos. Publicar no instala en el servidor ni modifica Wazuh, OpenBao,
HAProxy, Coraza o CSP.

## SHA 256

- Paquete cifrado: `da237bca19445bff5f2eb060bfc487ed1e98d8c14bfcbe9936f44316313bc657`.
- TAR descifrado: `a392396627c60915df6e68bda1c844d299e88937c1bd5855ad1108354a1820dc`.
- SHA256SUMS público: `3f04e0d3af6aa7cd53467df3b981d5b160a3d87c3970c61df151f0bbdf13ffcb`.
- Orquestador: `9665d90a319270a4822400fd34633c18a9144022878b29473924f2cab44c4a8a`.
