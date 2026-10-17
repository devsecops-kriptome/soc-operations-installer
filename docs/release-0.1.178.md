# SOC Operations 0.1.178

Fecha: 16 de octubre de 2026 (America/Lima). Instalador 0.1.178; API/API externa/worker/agente
0.1.128; plugin socOperations 0.1.107 para OSD 2.19.5 y 2.19.6. El esquema permanece
e31a7f82c940: no hay migraciones nuevas desde 0.1.176 o 0.1.177.

## Correcciones de API externa

- El gateway permite GET en la ruta exacta `/api/v2/vulnerabilities`. Conserva restricciones
  de origen y métodos; no publica administración, documentación ni rutas internas.
- `/manage/customers/{id}/cases` solo devuelve `data.stats` con `metrics:read`, igual que las
  métricas de la lista general. Una clave con `cases:read` mantiene la consulta de casos.
- Detalle, eventos y timeline del padre incluyen los eventos de sus hijos directos del mismo
  tenant. Cada evento indica `case_soc_id` y `tenant_id`. Los eventos permanecen en el hijo;
  no se modifican su trabajo ni sus métricas. Al desvincularlo deja de aparecer en el padre.
- Los contadores de ACK y resolución vencidos abiertos excluyen resueltos, cerrados y
  archivados. No sustituyen el historial de asignaciones ACK no atendidas del Dashboard.
- El manejador de errores conserva los headers de la excepción, incluido
  `WWW-Authenticate: Bearer` en el 401. Se conserva el formato de error y los controles HTTP.
- Orden estable de eventos con desempate e identificación del número/parentesco del caso.

Las rutas, parámetros y claves existentes no cambian. Consumidores que usen `stats` necesitan
`metrics:read`; los casos padre pueden devolver más eventos y páginas. El plugin se conserva
byte por byte desde 0.1.177; no se aumenta su versión artificialmente.

## Integridad

- Paquete cifrado: `b9bcf0c1554bd1a5d9c39c62cac76c6ba96a18d508126151c367c60b0a7d3c2b`.
- TAR descifrado: `835703ab368649625933508d093ea3a480aa9bf33ef38635bfaf009c7cb0096b`.
- SHA256SUMS público: `cfb0dd117f1048b2e6d5b860a4da49ab6d8d2e7d0d1d092cc3c80e02233f2890`.
- Orquestador: `a949d07fd32e0c435285ac53bf97084547339b530c14049286d9ac9ce92d5c7c`.

Se publican únicamente `soc-operations-0.1.178.tar.gz.age` y `SHA256SUMS`. El TAR sin cifrar,
código privado, identidades age, configuraciones reales y respaldos no se publican. Se usa el
destinatario age autorizado existente; la identidad se obtiene por el canal autorizado.
Los assets anteriores permanecen inmutables.

## Validación

1.340 pruebas distintas aprobadas: 997 de la suite general backend/agente, las 20 omitidas
ejecutadas y aprobadas con PostgreSQL real aislado, 109 HTTP/ASGI de API externa con PostgreSQL
y RLS, y 214 frontend. Sin xfail ni omisiones pendientes dentro de este conjunto combinado.
TypeScript comprobado nuevamente para OSD 2.19.5 y 2.19.6. Se reutilizan los ZIP del plugin
sin cambios desde 0.1.177, verificando sus hashes, fuentes, manifiestos y bundles.

Wheel e imagen Linux amd64 se comparan con el código fuente y con 54 archivos de migración y
configuración. `pip check`, smoke de alcance de inventario y autenticación externa 401 en la
imagen sin red. El paquete se extrae a un destino nuevo validando tipos, rutas y todos los
hashes internos antes de cifrar. La descarga desde GitHub se verifica por SHA-256 antes de
publicar la release como vigente. No se afirma un descifrado con identidad privada del receptor.

## Límites y despliegue

- No se contactó ni actualizó producción. Faltan aceptación con inventario real, DNS, WAF,
  firewall, CA/SAN de servicio, carga real y ensayo de recuperación con RPO/RTO medidos.
- Las correcciones de las dos copias locales de HAProxy no se distribuyen ni recargan por este
  instalador. Antes de aplicarlas verificar la CA y el nombre real; no usar `verify none`.
- El transporte de vulnerabilidades en pruebas HTTP es sintético; autenticación, selección
  de tenant y RLS se probaron contra PostgreSQL. El gateway/TLS se verificó en un entorno aislado.
- Persisten los pendientes estáticos y visuales de reportes documentados en 0.1.177; no se declara
  una nueva auditoría global de seguridad ni aprobación visual de Word.
- El listado de eventos aún materializa enlaces antes de paginar; no se declara capacidad
  ilimitada ni prueba de carga masiva.

Seguir la [guía de actualización](upgrade-0.1.178.md). Publicar no instala en el servidor.
