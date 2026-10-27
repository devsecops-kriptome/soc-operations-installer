# SOC Operations 0.1.191

Instalador 0.1.191; API interna/externa, worker y agente 0.1.134;
plugin 0.1.114 para OSD 2.19.5 y 2.19.6. Se conservan las parejas
Wazuh 4.14.7-1/OSD 2.19.5 y Wazuh 4.14.8-1/OSD 2.19.6.

## Correlación y recuperación

El worker lee todas las páginas de cada intervalo mediante Scroll, incluidos
empates de timestamp y más de 10 000 resultados. Conserva el parámetro inicial
de Scroll y no envía parámetros de búsqueda incompatibles a su continuación.
El checkpoint persiste por tenant y avanza solo al terminar el intervalo.
Los lotes confirmados se conservan ante un fallo; los receipts evitan duplicados
al reintentar el mismo intervalo.

La migración `d0f6a3b9e214`, posterior a `c8d3e902f751`, incorpora el checkpoint
con FORCE RLS y acceso exclusivo del worker, además del índice de vínculos por
tenant/fecha. La correlación y las operaciones de cierre, unión y vinculación
de casos comparten un bloqueo transaccional por tenant sin ampliar permisos.
Los conflictos de hash quedan auditados y no sustituyen evidencia ni bloquean
las alertas siguientes; otros errores de servicio dejan pendiente el intervalo.

Dentro de una regla las condiciones usan AND; entre reglas se usa OR.
Una exclusión de una regla no veta las demás. `technology.id` se resuelve
desde los campos personalizados `technology.id` y `data.technology.id`;
`decoder.name` sigue siendo un campo independiente. Los snapshots y hashes
antiguos permanecen intactos. Las condiciones que usaban un nombre de decoder
como ID de tecnología deben revisarse antes de activar el worker nuevo.

El primer sondeo cubre únicamente los 600 segundos anteriores por defecto.
La actualización no recupera automáticamente las alertas históricas omitidas.
Tras ese inicio, el worker recupera interrupciones desde su checkpoint y realiza
una reconciliación amplia periódica. No puede recuperar datos eliminados del
Indexer ni garantiza cubrir alertas anteriores al límite inicial.

## Otros cambios incluidos

- Las ausencias que coinciden con turnos requieren confirmación antes de sustituirlos.
- Los avisos de ausencia se adaptan a la antelación para evitar enviar juntos
  recordatorios de plazos ya vencidos.
- Los nombres de descarga de reportes de vulnerabilidades incluyen fecha y hora
  de finalización, respetando la zona horaria del reporte.
- Se permite anexar casos a un principal resuelto/cerrado sin copiar sus datos.
  Las uniones manuales autorizadas registran el ACK cuando corresponde.

Se recompilan imagen, wheel y ambos plugins. El Compose aprobado, el aislamiento
de volúmenes, los alcances de API externa, el firewall y auto-unseal no cambian.

## Actualización

Seguir la [guía de actualización](upgrade-0.1.191.md) con respaldo nuevo y baseline
verificados. Publicar no actualiza LAUFEY ni elimina versiones o respaldos anteriores.
La aceptación en el destino incluye API externa autenticada, navegador real y
un reporte Word/Excel. La recuperación histórica requiere autorización y rango explícitos.

## Integridad

- Instalador cifrado SHA-256: `d7ba7245865e438b9469f7521c6ad63334d78b14ce7518d6045f63b0116ca4cb`.
- TAR claro SHA-256: `00e7b3eade279803644e52f157e53c46b56b352a2c49d9383cc89259ce24af0d`.
- Orquestador SHA-256: `cc47e07be112a2e6bcd9fec4a37ae04425730043315946e70e30a518a719a2fc`.
- Compose SHA-256: `321c80c77b83debfd1bd934fad9871c850dd4bdd81d9980d36337828e1537445`.
- Imagen config ID: `sha256:03cab69fb7d9928c34aa13330e93bf124142f5df545ae6f83764e48a584228ec`.
- Imagen manifest ID: `sha256:f9c7464de59e65e87c82911866e1a8db3a622d06fe0e7c8d8686e4eb04300131`.

El TAR contiene 49 archivos regulares bajo release-0.1.191, incluido SHA256SUMS.
Solo se publican el instalador cifrado, hashes y documentación pública. La identidad
privada age no se utiliza durante la construcción ni se publica. El receptor
autorizado debe verificar el descifrado y el hash del TAR claro antes de instalar.

## Validación local

2138 pruebas únicas aprobadas: 1797 de backend/agente,
334 del frontend y 7 adicionales de recuperación/aislamiento. Sin fallos ni pruebas
omitidas en las ejecuciones finales. Las repeticiones de pruebas no se suman otra vez.
Ruff y mypy aprueban; mypy revisa 125 archivos fuente. TypeScript y las compilaciones
exactas para ambas plataformas aprueban. Persisten avisos de deprecación de dependencias
de pruebas y la advertencia Browserslist del SDK.

La imagen instalada y el wheel coinciden con las fuentes en 124 archivos Python;
59 archivos de migración/configuración coinciden y pip check aprueba. La API externa
real arranca aislada como UID 10001, raíz read-only y sin red: salud 200, ocho rutas
sin clave 401 y escrituras 405. Los controles PostgreSQL/RLS usan datos sintéticos;
las pruebas de interfaz usan DOM y no sustituyen el navegador del destino.

Sintaxis de 13 helpers aprobada. ShellCheck sin errores ni hallazgos nuevos respecto
a 0.1.190; se conservan 13 avisos o advertencias anteriores. El Compose se conserva
byte a byte y no se cambia la política de certificados, firewall o auto-unseal.
