# SOC Operations 0.1.208 — MTTD, MTTQ, MTTI y Calendario

Candidato de actualización basado en la versión estable 0.1.206, sin incorporar
el módulo experimental Activos de 0.1.207. Se publica como pre-release hasta
completar la instalación controlada y aceptación del destino.

- Instalador 0.1.208; runtime y agente 0.1.151; plugin 0.1.128.
- Wazuh 4.14.7 / OSD 2.19.5 y Wazuh 4.14.8 / OSD 2.19.6.
- Esquema sin cambios respecto a 0.1.206: `d8a215c963b7`.

## Evidencia de tiempos por caso

`GET /api/v2/cases/{id}` agrega `data.soc.initial_alert`: fecha de la alerta
inicial, procedencia original/recuperada/no disponible, evento de creación,
fecha de creación y MTTD en segundos. La recuperación verificada se usa solo
cuando falta la fecha original, nunca para reemplazar una fecha original inválida.

`data.soc.analysis_metrics` agrega MTTQ y MTTI con fechas, duración, eventos,
calidad de evidencia, objetivo guardado y motivo de evaluación. MTTQ usa creación
hasta calificación explícita; MTTI usa calificación true-positive hasta su hito
referenciado de investigación completa. Los hitos ausentes producen `null`;
los inválidos requieren revisión. Falso positivo y benigno no requieren MTTI.
No se infieren hitos de ACK, resolución, cierre o tareas de playbook.

Son cálculos individuales, no lecturas de resúmenes agregados. Requieren
`cases:read` y acceso al tenant. Las duraciones son naturales e incluyen pausas;
no se inventa cumplimiento con calendarios de cobertura o pausas no reproducibles.
No se modifican eventos, relojes, recuperaciones ni objetivos históricos.

## Calendario

Ingeniería no ve Calendario operativo, incluso si además tiene rol de analista.
Calendario Admin permanece disponible para Ingeniería SOC y SOC Manager.
Los enlaces restringidos comienzan ocultos, revalidan tenant/permisos al recuperar
el foco y cada 30 segundos, y se ocultan ante una revalidación fallida.
Las API compartidas de turnos conservan los permisos administrativos existentes.

## Límites de validación y seguridad

Validación local: 3574 casos backend/agente validados; la ejecución inicial
registró seis fallos de fixtures (referencias ausentes y fechas vencidas),
corregidos y repetidos con los resultados originales conservados. También
pasaron las 531 pruebas de interfaz y las comprobaciones de compilación en
ambas plataformas. No equivale a una aceptación del servidor de destino.

La aceptación autenticada, el despliegue y la restauración en el destino siguen
pendientes. No se certifica ausencia de vulnerabilidades de toda la plataforma.
Se mantienen MinIO y los artefactos de infraestructura de la base estable.
La revisión completa de tipos de esa base detecta siete errores en dos archivos
de Threat Radar sin cambios en esta entrega; los módulos productivos modificados
se validan aparte. Los hallazgos SAST/ShellCheck previos permanecen registrados.

Ver [actualización controlada](upgrade-0.1.208.md).
