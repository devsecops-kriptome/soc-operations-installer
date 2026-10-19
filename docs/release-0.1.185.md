# SOC Operations 0.1.185

Instalador **0.1.185**, plugins **0.1.110**, API/API externa/worker/agente **0.1.130**,
esquema **c8d3e902f751**. Compatible con Wazuh 4.14.7-1/OSD 2.19.5 o
Wazuh 4.14.8-1/OSD 2.19.6, AIO o distribuido según el perfil instalado.

## Corrección

Al reconciliar el agente antes del runtime, el predicado que reconoce un Compose anterior
aprobado imprimía un mensaje por stdout. Cuando se invocaba dentro del renderizador de
variables, el mensaje entraba en el archivo temporal agent.env. El validador rechazaba esa
línea con `Invalid or duplicate agent setting; upgrade refused`, aunque el archivo operativo
fuera válido. También podía contaminar una captura por sustitución de comandos.

El mensaje ahora se envía exclusivamente a stderr. La prueba anterior del predicado con
logs silenciados no cubría su interacción con el renderizador; esta release agrega esa
regresión con las funciones reales y el mismo parser, sin silenciar el diagnóstico.
No se necesita borrar entradas válidas de agent.env ni desactivar el validador.

## Alcance y controles

La corrección no es específica de una versión, hostname o dirección. Cubre las transiciones
que el instalador ya admite. **No incorpora compatibilidad universal con versiones o
Compose arbitrarios**. Conserva las huellas exactas actual, previa e histórica:

- Actual: `321c80c77b83debfd1bd934fad9871c850dd4bdd81d9980d36337828e1537445`.
- Previa: `23255542c7cfd45b1e82ba0d45efa3e0c72e875150ea0421669908176a85116c`.
- Histórica: `74fe74aed0953fff64c843643d1fe67052eb4d3f05f266a7827bfd8be8a7406d`.

Las huellas anteriores solo se aceptan con Manager/runtime colocados, autorización explícita
del orquestador durante upgrade y fase upgrade_incomplete en archivo regular root:root 0444.
Runtime.env debe ser regular root:root 0600 y Compose regular con propietario/modo aprobado.
Se siguen rechazando hashes desconocidos, alteraciones, metadatos inseguros, líneas inválidas
y claves duplicadas. Un Manager remoto no obtiene control del runtime por esta corrección.
No cambian RBAC, alcances API, TLS/mTLS, credenciales, puertos ni UFW.

Solo cambian el orquestador y el provisionador frente a 0.1.184. Los otros 46 artefactos
son byte a byte iguales: imagen, wheel, plugins y Compose incluidos. No se agregan migraciones.
Desde versiones antiguas siguen aplicándose las ya existentes hasta c8d3e902f751. Incluye
las funciones de [0.1.184](release-0.1.184.md) y [0.1.183](release-0.1.183.md).

## Integridad

- Asset cifrado SHA-256: `a062a501511888dd0bacb7a7b070b1d0cb9d61825ad59d7ce444f675442d0627`.
- TAR descifrado: `4b43a32462e9507c8fe5e2230124262bed4b9d9684615987b7d0a332a1b4635d`.
- Orquestador: `44cfb89e34111564c49b5b3a43eb7de074bb39c5729077ee5d3d8d33a9b43aac`.
- Provisionador: `6bab637264d6c698f6cc031f388fdd60b86901cd424cb0e5169e77ade145577d`.

El TAR contiene 49 archivos regulares planos bajo release-0.1.185, incluido SHA256SUMS,
sin enlaces ni rutas ajenas. Solo se publican el asset cifrado, hashes y documentación
pública. Se conserva el destinatario age autorizado. No se publican código privado,
TAR claro, identidades, configuraciones reales, respaldos ni logs del destino.
Los hashes no sustituyen la autenticidad del canal.

## Validación y límites

1544 pruebas backend/agente y 318 de interfaz:
**1862 aprobadas**, sin fallos ni omisiones. Incluye renderizador y
parser reales junto con el predicado, Compose actual/previo/histórico, AIO/distribuido,
captura de stdout limpia y rechazo conservado de configuraciones inválidas o duplicadas.
También se ejecuta la matriz de hash/contexto/metadatos y la migración PostgreSQL desde el
esquema 6d9f2b8c1a53 con usuario protegido, tenant, caso y evento sintéticos conservados.

Mypy en 123 archivos y Ruff aprobados. Runtime y wheel contrastados con 122 archivos Python
y 58 de migración/configuración; entry point externo real aislado: liveness 200, 24 rutas
sin clave 401 y escrituras 405, sin red externa, no root y raíz read-only. No se recompilan
plugins sin cambios: se hereda la validación TypeScript previa para ambos SDK. Las pruebas
enfocadas o finales que repiten un subconjunto no se suman dos veces.

No se ha ejecutado el upgrade del AIO real con esta release. Las pruebas usan datos sintéticos
y simulan operaciones privilegiadas; no certifican el estado ni el perímetro del destino.
El descifrado final requiere la identidad del destinatario autorizado, no utilizada durante
la construcción. Ver [actualización y recuperación](upgrade-0.1.185.md).
Publicar no actualiza servidores ni elimina paquetes o respaldos anteriores.
