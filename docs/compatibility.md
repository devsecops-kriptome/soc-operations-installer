# Compatibilidad

## Perfiles soportados por 0.1.194

| Perfil | Wazuh Manager/Indexer/Dashboard | OpenSearch Dashboards | Plugin |
| --- | --- | --- | --- |
| Wazuh 4.14.7 | `4.14.7-1` | `2.19.5` | `socOperations-2.19.5.zip` |
| Wazuh 4.14.8 | `4.14.8-1` | `2.19.6` | `socOperations-2.19.6.zip` |

| Componente SOC | Versión |
| --- | --- |
| Ubuntu Server | 24.04 |
| Plugin SOC Operations | `0.1.116` |
| API interna/externa, worker y agente | `0.1.137` |
| Esquema de base de datos | `c64e93b8a521` |

El perfil `aio` instala sobre un solo servidor. El perfil `distributed` exige exactamente un
Dashboard y admite uno o varios Manager de un mismo clúster y uno o varios Indexer de un mismo
clúster. SOC Operations vive en el Dashboard; el manager master ejecuta solo el agente mTLS.

El instalador verifica versiones, servicios, cantidades de nodos, endpoints TLS y la cadena
SHA-256 del release. La API externa `9443` y `soc-aio-continuity` funcionan en AIO y distribuido
desde el único Dashboard. La distribución MaxMind es opcional y admite uno o varios Indexer con
rol `ingest`; requiere un piloto canario real antes de producción.

## Wazuh 4.12

El release `0.1.194` **no es compatible con Wazuh 4.12**. Wazuh 4.12 utiliza OpenSearch
Dashboards `2.19.1`; ninguno de los dos plugins entregados fue compilado para esa plataforma.

No amplíe manualmente la expresión de versión. Para soportar 4.12 se necesita un release separado
que compile el plugin contra la plataforma exacta, genere hashes propios y valide en un AIO 4.12:

- identidad Dashboard y Security API;
- DLS, multitenancy, roles y mappings;
- índices `wazuh-alerts-*` y `wazuh-states-vulnerabilities-*`;
- enrolamiento de agentes, Decoder Studio y comandos de versión;
- backup y restauración completos.

Hasta completar esa validación, el soporte declarado permanece limitado a las dos parejas 4.14
indicadas en la tabla.

## Contactos y automatización en 0.1.194

La consulta externa de contactos requiere `contacts:read`; no se concede ese
alcance automáticamente a las claves existentes. El indicador KriptomeAPP no
crea una cuenta externa por sí mismo. Los grupos de endpoints y sus totales
respetan el cliente autorizado; los filtros `case_scope` separan dominios de casos.

La pausa conserva datos y credenciales para reactivación y detiene el trabajo
correspondiente en SOC Operations, no la recepción del manager Wazuh. El borrado
físico no está habilitado; su vista previa no ejecuta una purga.

La configuración global de reglas espera al procesamiento en curso; una edición
local coordina su tenant. Actualizar API y worker juntos con el instalador y una
ventana de mantenimiento. No mezclar componentes antiguos ni modificar las
reglas directamente por SQL. Las migraciones agregan contactos y categorías;
la regla global de vulnerabilidades nace pausada con nivel mínimo 10.
Ver [actualización y aceptación](upgrade-0.1.194.md).
