# SOC Operations 0.1.172

Instalador `0.1.172`; API, API externa, worker y agente `0.1.122`; plugin `0.1.103`.
Interfaz en About: `0.1.103-audit-lock-scroll-routing-week-filter-future-shifts-multiple-responsibles`. Esquema `c17e89ab2304`, sin nuevas migraciones
desde 0.1.171. Actualización para Wazuh 4.14.7/OSD 2.19.5 y Wazuh 4.14.8/OSD 2.19.6.

## Correcciones incluidas

- El worker difiere la inserción encadenada de auditorías hasta el commit; no mantiene el bloqueo
  global durante consultas externas. Auditoría y cambios de negocio confirman o revierten juntos.
- Nginx admite únicamente POST/DELETE sobre `/opensearch-query/_search/scroll`, con mTLS,
  autenticación del lector y verificación TLS al Indexer. Corrige la ruta ausente que podía causar
  HTTP 404 en inventarios paginados. No amplía patrones de índices, DLS o permisos de escritura.
  Los fallos de lectura siguen siendo errores, nunca un consolidado parcial o vacío exitoso.
- Casos e incidentes añade «Últimos 7 días» sin recargar la página.
- Turnos fijos permite editar fechas futuras de la programación seleccionada, no el histórico.
  En asignaciones antiguas sin grupo, muestra las futuras compatibles antes de confirmarlas;
  no une grupos verificados ni omite controles de ausencias, solapamientos y autorización.
- Dos o más responsables por día. Selección automática y avisos priorizan Analista, SOC Manager
  e Ingeniería; usan elegibilidad y orden del equipo. Junior puede tener turno, pero no ser
  responsable ni recibir asignación automática. El autoescalamiento no reinicia el plazo ACK.
- Carga solo los datos de la sección administrativa activa, cancela consultas obsoletas del
  calendario y conserva borradores SLA cuando se refresca el mismo tenant.

## Validación y aceptación

734 pruebas backend: 717 de la suite general y 17 con PostgreSQL real. 130 pruebas de interfaz.
Ambos plugins compilados y TypeScript sin diagnósticos. Wheel y código instalado en la imagen
comparados con la fuente; pip check, 52 archivos de migración/configuración, JS/gzip, sintaxis
Bash y las huellas de los 48 artefactos comprobados.

Con FORCE RLS y un rol NOBYPASSRLS, un guardado SLA terminó en 0,047 s mientras el worker
esperaba; la cadena quedó consistente. Es un resultado local, no una garantía de latencia real.
Nginx real con certificados de prueba recuperó 1.001 hallazgos completos por paginación,
liberó el cursor y rechazó métodos/certificados no permitidos. El upstream fue sintético:
esta comprobación no sustituye la aceptación contra OpenSearch y su DLS reales.

Conserva las funciones y límites de 0.1.171. No cambia Wazuh, Coraza, CSP, topología, TLS,
credenciales ni custodia OpenBao. Publicar no actualiza LAUFEY. Requiere respaldo NUEVO,
ventana de mantenimiento y aceptación del host, reporte, guardados y responsables en producción.
La revisión visual Word/PDF continúa pendiente y no se declara aprobada por estas pruebas.

## SHA 256

| Artefacto | SHA-256 |
| --- | --- |
| SHA256SUMS externo | `23c490e80340b0536c1a52132bcec57ad29363acbb7e4f1be6a1d22fb04c5529` |
| TAR cifrado | `8f7de44e14ee9fcf70e57d1c525278c4c0c84a7d065390ce6547f583d9ec08d8` |
| TAR descifrado | `b8826b6d70a2cc6b0e549e5d870c4e9eca954e0c5057b618524e1f4ac0724004` |
| soc-operations-install | `9d7ad62dccc6e1a4b3994fa3757045ce0adf3b4aae0348fc81e8ff1534daab80` |

Solo se publican el TAR cifrado para el destinatario age existente y el manifiesto externo.
No se publica código privado en claro, identidades, configuraciones del servidor ni respaldos.
El release 0.1.171 y sus activos permanecen intactos.
[Actualizar LAUFEY desde 0.1.171](upgrade-0.1.172-laufey.md).
No usar instalación limpia, `apply`, inicialización de OpenBao ni eliminación de volúmenes.
