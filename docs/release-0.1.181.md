# SOC Operations 0.1.181

19 de octubre de 2026. Instalador 0.1.181; API, API externa, worker y agente 0.1.130;
plugin socOperations 0.1.109; esquema c8d3e902f751. Compatible con Wazuh 4.14.7-1/OSD 2.19.5
y Wazuh 4.14.8-1/OSD 2.19.6, AIO o distribuido con un único Dashboard.

## Incluido

- Métricas externas de casos, eventos, SLA y analistas. Requieren `metrics:read`; el detalle
  por analista exige además `customers:read`.
- Estado e historial persistente de conectividad con `customers:read`: observaciones cada
  300 segundos y retención de 30 días por defecto, configurables. La historia comienza tras
  el upgrade; los errores de colección no se convierten en desconexiones ficticias y el
  muestreo no acredita disponibilidad continua exacta.
- Tecnologías externas con vista global, granular o ambas, protegidas por `technologies:read`.
  Fuentes/identificadores, agrupación y activación por tecnología. Las deshabilitadas no se
  consultan ni se incluyen en la API externa. Configuración restringida a Manager/Ingeniería.
- Edición de alcances de credenciales por Ingeniería, con auditoría y control de concurrencia,
  sin rotar secretos. Las claves existentes no reciben alcances nuevos automáticamente.
- Ajustes del Excel de vulnerabilidades con URL CTI completa, manejo de respuestas DELETE
  vacías y retirada de la etiqueta de recarga automática que ya no correspondía.
- Usuarios: menú de tres puntos y descarte de respuestas obsoletas al cambiar tenant,
  objetivo de asignación o permisos. Se mantienen las guardas de cuenta protegida.
- Corrección de recordatorios antiguos y errores de tipado del backend.

Se mantienen las correcciones de [0.1.180](release-0.1.180.md). El resumen de vulnerabilidades
sigue usando `vulnerabilities:read`; no exige el nuevo alcance de tecnologías. Las métricas
mantienen duraciones transcurridas. No se añaden hitos explícitos nuevos de MTTQ/MTTI/MTTR
ni se deducen veredictos de triage a partir de simples cambios de estado.

Desde 0.1.180 se aplican b7c2d891e640 (RLS de lectura externa de tecnologías) y c8d3e902f751
(historial de conectividad). API, external-api y worker usan la misma imagen y el wheel del
agente tiene la misma versión. PostgreSQL, MinIO, OpenBao y Compose conservan sus versiones
y huellas aprobadas. No se inventan observaciones anteriores ni se reescriben reportes generados.

## Integridad y procedencia

- Asset cifrado SHA-256: `3ab1cd8823f729b6945da877ac6c265e3e5fc5d6e6813ec1b5d4cf86b7a94607`.
- TAR descifrado: `026910be2b17b61ae45a7ca0788ad61a411855b41a2bdbdf1b60d02b9e57f87d`.
- SHA256SUMS público: `3a252cb4b6bfd35b46302adcb5b7b4e8ee3f9f57079dc233685150d1c05b1e91`.
- Orquestador: `019b8f4b3205918cd080a39ef67439de959a8a9ec5b74836728b6eafb0fc2543`.
- Compose: `23255542c7cfd45b1e82ba0d45efa3e0c72e875150ea0421669908176a85116c`.
- SDK Wazuh 4.14.7: `a406a787c442c4f29387223fdc7bfe90df7869c0`.
- SDK Wazuh 4.14.8: `42db785a5bc758527b4471b74d5298358855e40d`.

Se comprobó la correspondencia entre perfiles, SDK, manifiestos, marcadores, wheel, código
instalado en la imagen, entrypoints, Compose y hashes de helpers. La variante 2.19.5 se
reconstruyó contra el commit Wazuh fijado; se descartó el ZIP provisional upstream. En 2.19.6
se normalizó el texto del descriptor a Wazuh 4.14.8 sin modificar el código compilado.

Solo se publican el asset cifrado, SHA256SUMS y documentación pública. No se suben código
privado, TAR claro, identidad age, configuraciones reales ni respaldos. Se mantiene el
destinatario age autorizado; no se accedió a su identidad privada. El TAR contiene 49 archivos
regulares planos bajo release-0.1.181, incluido SHA256SUMS, sin enlaces ni rutas ajenas.

## Validación y límites

1.464 pruebas backend/agente y 291 del plugin aprobadas, sin omisiones. Se repitieron 40
pruebas de integridad y upgrade con los hashes finales: están incluidas en la suite, no son
40 pruebas únicas adicionales. TypeScript aprobado en ambos SDK; mypy en 123 archivos y Ruff
sin errores. Se verificaron 122 archivos Python y 58 de migración/configuración, pares JS/JS.gz,
estructura del TAR, extracción completa y todos los hashes internos.

La imagen se probó sin red externa, con UID no root y raíz read-only: entrypoint de API
externa operativo con material exclusivamente sintético, liveness 200, ocho rutas sin clave
401 y POST 405. PostgreSQL de pruebas usa RLS real y datos sintéticos; no se presenta como
aceptación del inventario productivo. Persisten avisos deprecados de herramientas de pruebas
y de Browserslist/Babel, no errores de compilación. No se declara una auditoría global nueva;
se mantienen los límites documentados en [0.1.179](release-0.1.179.md).

Publicar no despliega ni limpia el servidor. Quedan pendientes descifrado autorizado,
aceptación real de Wazuh, OpenBao, mTLS, navegador, API autenticada y reportes productivos.
Preparar respaldo vigente antes de migrar y comprobar referencias antes de limpiar paquetes
o copias anteriores. Consultar [upgrade 0.1.181](upgrade-0.1.181.md).
