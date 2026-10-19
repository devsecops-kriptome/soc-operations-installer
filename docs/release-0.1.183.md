# SOC Operations 0.1.183

Instalador **0.1.183**, plugin **0.1.110** para OSD 2.19.5 y 2.19.6, runtime/API/API externa/
worker/agente **0.1.130**. Esquema **c8d3e902f751**, sin nuevas migraciones desde 0.1.181.
Compatible con los perfiles exactos Wazuh 4.14.7-1/OSD 2.19.5 y Wazuh 4.14.8-1/OSD 2.19.6.

## Cambios incluidos

- Credenciales de API y Playbooks: acciones por fila mediante menú de tres puntos.
- Revocar/eliminar credenciales: bloqueo síncrono de solicitudes repetidas, progreso,
  confirmación deshabilitada y cierre impedido mientras se procesa. Permite reintento tras error.
- Exportación de playbooks según los permisos existentes del servidor. Un SOC Manager del
  tenant no exporta los globales ni los de otro tenant. «Exportar autorizados» filtra la
  descarga conjunta a los permitidos y comunica ese alcance. No se amplían permisos.
- Correctivo de API externa incluido desde el paquete local 0.1.182, no publicado por separado:
  external-api conserva tres redes y usa frontend como salida predeterminada (`gw_priority: 1`).
  La confianza gestionada se limita a gateways del host, `172.19.0.1/32` y `172.21.0.1/32`;
  se preservan las listas personalizadas. La aceptación valida readiness e inventario desde
  external-api. No se abre 8443 indiscriminadamente ni se modifica UFW o desactiva TLS/mTLS.

Las rutas, parámetros, claves y alcances existentes se conservan. El correctivo puede resolver
timeouts de vulnerabilidades, métricas de eventos y estado actual de agentes que requieren
salida hacia el agente mTLS. Los permisos de OpenSearch y el perímetro real se deben comprobar.
La imagen runtime y el wheel siguen byte a byte iguales a los aprobados, verificados contra
el código actual; la nueva interfaz está en los plugins recompilados, no en una imagen renombrada.

## Integridad

- Asset cifrado SHA-256: `21d4a0e9f45734aebb4ef35f8d42f56e1c0fc447b9bc411a8e339053d70fb2ea`.
- TAR descifrado: `7510e3b1459802883880ce846b708e9dd0ef7a4c0bb78ef91624239018ba949e`.
- Orquestador: `06a3bad431763c4b47a270e3cda2c8b33e97ce0d997c6346268e8a229afd0436`.
- Compose: `321c80c77b83debfd1bd934fad9871c850dd4bdd81d9980d36337828e1537445`.
- Plugin OSD 2.19.5: `7ccd1cb4838c5b27f311a0b982423245d6597125a89bc5a346ed78129800a649`.
- Plugin OSD 2.19.6: `eda9a0d27a75b8fd2904c58acaa8c7dc2f8ee06a89e37fbb1953d6ee71fec770`.

Solo se publican el asset cifrado, SHA256SUMS y documentación pública. No se publica código
privado, TAR claro, identidad age, configuraciones reales ni respaldos. Se mantiene el
destinatario age autorizado. El TAR tiene 49 archivos regulares planos bajo release-0.1.183,
incluido SHA256SUMS, sin enlaces ni rutas ajenas. Los hashes no sustituyen la autenticidad
del canal por el que se obtienen. No se accedió a la identidad privada age.

## Validación y límites

1.509 pruebas backend/agente y 318 frontend aprobadas (1.827 en total), sin omisiones.
La matriz HTTP incluye permisos de exportación global/tenant. TypeScript aprobado en ambos
SDK, mypy en 123 archivos y Ruff sin errores. Se verifican fuentes, wheel e imagen: 122
archivos Python y 58 de migración/configuración. Entry point real aislado: liveness 200,
24 rutas de datos sin clave 401 y escrituras rechazadas con 405; raíz read-only y UID no root.
Ambos ZIP contienen la nueva UI y pares JS/JS.gz consistentes. Se verifica la cadena de hashes
del instalador, Compose y helpers. Las pruebas finales de pins repiten una parte de la suite,
no se suman como pruebas únicas adicionales.

Pruebas con datos sintéticos y PostgreSQL desechable, no aceptación de producción. Persisten
avisos deprecados de dependencias de pruebas, Browserslist y Babel, no errores de compilación.
El descifrado final exige la identidad del destinatario autorizado y no se certifica aquí.
No se declara una auditoría de seguridad universal ni ausencia absoluta de errores.

Publicar no instala ni elimina datos del servidor. Conservar la versión previa y respaldos.
Ver [actualización controlada](upgrade-0.1.183.md) para respaldo nuevo, upgrade y aceptación
autenticada desde el consumidor real.
