# Compatibilidad

## Perfiles soportados por 0.1.196

| Perfil | Wazuh Manager/Indexer/Dashboard | OpenSearch Dashboards | Plugin |
| --- | --- | --- | --- |
| Wazuh 4.14.7 | `4.14.7-1` | `2.19.5` | `socOperations-2.19.5.zip` |
| Wazuh 4.14.8 | `4.14.8-1` | `2.19.6` | `socOperations-2.19.6.zip` |

| Componente SOC | Versión |
| --- | --- |
| Ubuntu Server | 24.04 |
| Plugin SOC Operations | `0.1.118` |
| API interna/externa, worker y agente | `0.1.139` |
| Esquema de base de datos | `f97dc8e12543` |

El perfil `aio` instala sobre un solo servidor. El perfil `distributed` exige exactamente un
Dashboard y admite uno o varios Manager de un mismo clúster y uno o varios Indexer de un mismo
clúster. SOC Operations vive en el Dashboard; el manager master ejecuta solo el agente mTLS.

El instalador verifica versiones, servicios, cantidades de nodos, endpoints TLS y la cadena
SHA-256 del release. La API externa `9443` y `soc-aio-continuity` funcionan en AIO y distribuido
desde el único Dashboard. La distribución MaxMind es opcional y admite uno o varios Indexer con
rol `ingest`; requiere un piloto canario real antes de producción.

## Wazuh 4.12

El release `0.1.196` **no es compatible con Wazuh 4.12**. Wazuh 4.12 utiliza OpenSearch
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

## Contactos y automatización en 0.1.196

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
Ver [actualización y aceptación](upgrade-0.1.196.md).

## Casos, SLA y entrega en 0.1.196

Los SLA de este flujo se aplican a casos automáticos. MTTD usa la alerta de origen,
MTTR el primer En progreso explícito y MTTC el cierre; Resuelto no equivale a Cerrado.
MTTQ/MTTI sin hitos suficientes permanecen sin dato. Las personalizaciones por tenant
se conservan; los datos históricos no se reconstruyen inventando marcas de tiempo.

El correo manual queda disponible de inmediato aunque el SLA esté pausado. Los
destinatarios y copias se seleccionan explícitamente entre usuarios elegibles y contactos
del mismo tenant. Una aceptación SMTP no acredita entrega en bandeja. Los envíos
inciertos requieren revisión de su referencia y no se reenvían automáticamente.

Antes del upgrade debe existir un respaldo nuevo verificado, incluyendo snapshots
publicados. En AIO se reconcilia el agente local; en distribuido se verifica el agente
0.1.139 antes del runtime. Ver [actualización 0.1.196](upgrade-0.1.196.md).

## Correlación y primera alerta en 0.1.196

Los selectores positivos de cada regla personalizada se combinan con AND;
los ámbitos y las reglas alternativas se combinan con OR. La regla global
genérica no elude exclusiones de un ámbito personalizado aplicable. Las reglas
del tenant tienen prioridad; fuera de su ámbito se evalúan las globales.
Una regla con solo exclusiones puede abarcar muchas alertas: acotarla con
tecnología, rule.id u otro selector positivo cuando corresponda.

El formulario permite categoría fija o derivada de la alerta desencadenante.
Se conserva la clasificación inicial y las ediciones del analista al añadir
evidencia. Al agrupar por mitre.id se compara el conjunto de técnicas;
su orden inicial se mantiene para elegir playbook. Las reglas solapadas
seleccionan una ganadora por prioridad; no crean un caso por regla para la misma alerta.
No se reproduce automáticamente el histórico ni se reclasifican casos existentes.
Ver [aceptación 0.1.196](upgrade-0.1.196.md).
