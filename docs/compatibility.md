# Compatibilidad

## Perfiles soportados por 0.1.147

| Componente | Versión requerida |
| --- | --- |
| Ubuntu Server | 24.04 |
| Wazuh Manager | `4.14.7-1` |
| Wazuh Indexer | `4.14.7-1` |
| Wazuh Dashboard | `4.14.7-1` |
| OpenSearch Dashboards | `2.19.5` |
| Plugin SOC Operations | `0.1.93` |
| API, worker y agente | `0.1.111` |

El perfil `aio` instala sobre un solo servidor. El perfil `distributed` exige exactamente un
Dashboard y admite uno o varios Manager de un mismo clúster y uno o varios Indexer de un mismo
clúster. SOC Operations vive en el Dashboard; el manager master ejecuta solo el agente mTLS.

El instalador verifica versiones, servicios, cantidades de nodos, endpoints TLS y la cadena
SHA-256 del release. La API externa `9443` y `soc-aio-continuity` funcionan en AIO y distribuido
desde el único Dashboard. La distribución MaxMind es opcional y admite uno o varios Indexer con
rol `ingest`; requiere un piloto canario real antes de producción.

## Wazuh 4.12

El release `0.1.147` **no es compatible con Wazuh 4.12**. Wazuh 4.12 utiliza OpenSearch
Dashboards `2.19.1`, mientras que el plugin entregado fue compilado específicamente para `2.19.5`.
El instalador también fija paquetes y contratos a `4.14.7-1`.

No amplíe manualmente la expresión de versión. Para soportar 4.12 se necesita un release separado
que compile el plugin contra la plataforma exacta, genere hashes propios y valide en un AIO 4.12:

- identidad Dashboard y Security API;
- DLS, multitenancy, roles y mappings;
- índices `wazuh-alerts-*` y `wazuh-states-vulnerabilities-*`;
- enrolamiento de agentes, Decoder Studio y comandos de versión;
- backup y restauración completos.

Hasta completar esa validación, el soporte declarado permanece limitado a Wazuh `4.14.7-1`.
