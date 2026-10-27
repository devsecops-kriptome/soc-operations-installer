# SOC Operations 0.1.193

Versiones: API interna/externa, worker y agente 0.1.136; plugin 0.1.115 sin cambios.
Perfiles: AIO y distribuido; Wazuh 4.14.7-1 / OSD 2.19.5 y
Wazuh 4.14.8-1 / OSD 2.19.6. Esquema a42f71c6e309, sin migraciones nuevas.
El instalador no actualiza los paquetes de Wazuh.

Corrige la autorización del origen del inventario de vulnerabilidades en reportes
y resúmenes que alimentan la API externa. Los nombres del sistema operativo,
manager y clúster son variables; no se fija un nombre de laboratorio o producción.
El inventario autenticado aporta el hostname actual y la identidad local única
del manager 000. Los nombres históricos ausentes requieren aprobación explícita
del administrador mediante SOC_DEPLOY_VULNERABILITY_STATE_ALIASES en agent.env.
La reconciliación conserva esa opción root y el UUID del endpoint.

Toda fuente exige prueba vigente de despliegue, endpoint, tenant y grupo, además
del índice exacto autorizado. Un clúster coincidente o ausente en el documento
no permite saltar esos controles. No se aprende confianza de los documentos ni
se atribuyen datos ajenos por coincidir únicamente el ID numérico del agente.

Si un endpoint aparece en dos fuentes autorizadas, se rechaza el resultado como
ambiguo: no se elige el índice por su nombre ni se suman fuentes históricas.
Una sola fuente conserva hallazgos de versiones y arquitecturas diferentes.
No se renombran ni eliminan índices y no se publican reportes parciales.

Las instantáneas previas a esta política requieren una recolección nueva; la API
externa puede responder 503 refresh pending hasta completarla. Un refresco fallido
conserva el último corte válido de la política actual, sin publicar uno mezclado.
No se migran las claves históricas de hallazgos ni todos los endpoints API legados.

El plugin se reutiliza con los mismos hashes verificados para ambas plataformas.
No se cambian Compose, firewall, auto-unseal, permisos ni política de renovación TLS.
Generar este paquete no significa publicarlo o desplegarlo. La aceptación del
reporte real, navegador, mTLS y API externa autenticada queda a cargo del destino.
No se autoriza automáticamente un alias histórico sin confirmar su procedencia.

## Integridad

- Instalador cifrado SHA-256: `c1bd19bcf3498182c0edbc6540177e34b030af8e33a43e37523e78763ce5ee7d`.
- TAR claro SHA-256: `f8d84737d2cfb2f0c1b029217755a8417db58ffc30f2cb8dcccf7902bdf320b6`.
- Orquestador SHA-256: `d3cb0b734a520d3db4d9cda1a8bf489e507377b57e6bbe457c04d7ec983df237`.
- Compose SHA-256: `321c80c77b83debfd1bd934fad9871c850dd4bdd81d9980d36337828e1537445`.
- Imagen config ID: `sha256:c0aa55b945212fbd9c0e9b46a3f1f647d4e6c9cd234cd2c5cba4b6a4e2dd00ab`.
- Imagen manifest ID: `sha256:9be486e2ff6503cb55c31ad6c1c6df495cafe8f02f28187e35e627bd438bb762`.

El TAR contiene 49 archivos regulares bajo release-0.1.193, incluido SHA256SUMS.
Solo se publican el instalador cifrado, hashes y documentación pública. No se usa
ni publica la identidad privada age. El descifrado debe verificarse en el destino.

## Validación local y límites

2407 pruebas únicas aprobadas: 1987 de backend/agente, 340 de frontend y 80
adicionales de integración/identidad variable. Sin fallos ni omisiones en la
ejecución final. PostgreSQL desechable cubre RLS y concurrencia. Se repiten además
40 comprobaciones de versiones/pins, sin contarlas dos veces. Ruff y MyPy aprueban
(126 archivos fuente). Imagen, wheel y fuentes coinciden en 125 archivos Python;
las 60 fuentes de migración/configuración también coinciden. pip check aprobado.

Los plugins no se recompilan: se verifica su igualdad con la fuente preparada
anterior, las dos plataformas exactas, marcadores compilados y pares JS/JS.gz.
La imagen arranca sin red como UID 10001 con raíz read-only: salud 200, ocho rutas
sin clave 401 y escrituras 405. ShellCheck conserva 13 avisos previos y no agrega
errores ni avisos. Persisten dos deprecaciones de dependencias de pruebas.

El primer intento de QA usó otro puerto local; una guarda de seguridad de la
prueba de latencia lo rechazó. Se repitió la suite completa en el puerto esperado,
sin relajar la guarda ni cambiar código funcional para aprobarla.

El piloto será primero lab02 AIO. Faltan aceptación del reporte real, origen de
los índices históricos, mTLS, SMTP, navegador y API externa autenticada. No se
garantiza corregir la demora observada en producción únicamente con pruebas
locales: medir nuevamente los guardados y, si persiste, capturar esperas SQL.
LAUFEY no se actualiza mediante esta publicación. Ver [aceptación](upgrade-0.1.193.md).
