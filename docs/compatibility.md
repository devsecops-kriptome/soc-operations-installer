# Compatibilidad

## Perfil soportado por 0.1.142

| Componente | Versión requerida |
| --- | --- |
| Ubuntu Server | 24.04 |
| Wazuh Manager | `4.14.7-1` |
| Wazuh Indexer | `4.14.7-1` |
| Wazuh Dashboard | `4.14.7-1` |
| OpenSearch Dashboards | `2.19.5` |
| Plugin SOC Operations | `0.1.93` |
| API, worker y agente | `0.1.111` |

El instalador verifica estas versiones antes de modificar el host. También comprueba servicios,
dirección local y SHA-256 de los 24 artefactos.

## Wazuh 4.12

El release `0.1.142` **no es compatible con Wazuh 4.12**. Wazuh 4.12 utiliza OpenSearch
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
