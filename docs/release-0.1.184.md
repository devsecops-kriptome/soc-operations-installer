# SOC Operations 0.1.184

Release correctiva general del instalador: **0.1.184**. Se conservan el plugin **0.1.110**,
API/API externa/worker/agente **0.1.130** y esquema **c8d3e902f751**.
Compatible con Wazuh 4.14.7-1/OSD 2.19.5 o Wazuh 4.14.8-1/OSD 2.19.6.

## Corrección y límites de autorización

Un AIO con el Compose histórico de 0.1.166 podía detener el upgrade a 0.1.183 al reconciliar
el agente antes del runtime: la huella era legítima pero no pertenecía al predecesor inmediato
admitido por ese helper. La 0.1.184 añade exclusivamente esa huella histórica verificada:

`74fe74aed0953fff64c843643d1fe67052eb4d3f05f266a7827bfd8be8a7406d`

No es una variante para un hostname ni una dirección particular. No acepta todos los Compose
antiguos. El hash debe coincidir exactamente, y además deben cumplirse simultáneamente:

- Manager/runtime colocados; no concede control del runtime a un Manager remoto.
- Señal explícita del instalador durante `upgrade` y fase `upgrade_incomplete`.
- Archivo de fase regular, no enlace, `root:root` y `0444`.
- Runtime.env regular, no enlace, `root:root` y `0600`.
- Compose regular, no enlace, `root:root` y uno de los modos ya aprobados.

La operación normal y los archivos alterados o desconocidos siguen rechazados. El
predecesor inmediato conserva las mismas restricciones. No se omiten validaciones de
mTLS, custodia, cuenta protegida, readiness ni reconciliación del agente antes del runtime.
No cambian RBAC, alcances, puertos, UFW o TLS. No se debe sustituir el Compose manualmente
ni cambiar un hash para eludir controles. Esta release incluye todo lo de [0.1.183](release-0.1.183.md).

Solo cambian el orquestador y el helper del provisionador. Imagen runtime, wheel, plugins,
Compose y restantes artefactos son byte a byte iguales a 0.1.183. No se agrega una migración
nueva respecto a esa versión. Desde 0.1.166 sí se ejecutan las migraciones existentes entre
`6d9f2b8c1a53` y `c8d3e902f751`; es necesario un respaldo nuevo antes del upgrade.

## Integridad

- Asset cifrado SHA-256: `db3ba2bb576b82d591c8e24ba283bb6126becb877af1ca32c39ba80332552f46`.
- TAR descifrado: `23ea120602ef564e38924a86fa3b8f200eedeb167600c11b20f9d91cb157a665`.
- Orquestador: `d8c649bec571bd3436e00a45b78b862eabb900f9690d1d35722227a83adb170e`.
- Compose: `321c80c77b83debfd1bd934fad9871c850dd4bdd81d9980d36337828e1537445`.
- Provisionador: `7b86f097b72587b96bbd959cd14e41890eacf4cebbda21e9fe9efb75f770af0c`.

El TAR tiene 49 archivos regulares planos bajo release-0.1.184 incluido SHA256SUMS, sin enlaces
ni rutas ajenas. Se publican solo el asset cifrado, hashes y documentación pública. No se
publican código privado, TAR claro, identidad age, configuraciones reales ni respaldos.
Los hashes no sustituyen la autenticidad del canal. Se conserva el destinatario age autorizado.

## Validación y límites

1528 pruebas backend/agente y 318 de interfaz aprobadas
(1846 en total), sin omisiones. Archivo canónico histórico comprobado
por SHA-256; matriz de contexto/estado/permisos, rechazo de alteraciones y metadatos inseguros.
Una prueba de PostgreSQL migra desde el esquema exacto 0.1.166 conservando usuario protegido,
tenant, caso y evento sintéticos. Se verifica coherencia de los 35 artefactos fijados.

Mypy en 123 archivos y Ruff aprobados. Los dos plugins no se recompilan porque sus fuentes
y binarios permanecen intactos: se conserva la validación TypeScript previa para ambos SDK.
Imagen/wheel comprobados contra 122 archivos Python y 58 archivos de migración/configuración;
entry point real aislado: liveness 200, 24 rutas sin clave 401 y escrituras 405, no root y
raíz read-only. Las pruebas finales de pins repiten un subconjunto; no se suman dos veces.

Pruebas locales con datos sintéticos y servicios privilegiados simulados: no se ejecutó un
upgrade del AIO real. Persisten avisos deprecados de dependencias de pruebas. No se certifica
el perímetro productivo ni ausencia universal de errores. El descifrado final requiere la
identidad del destinatario autorizado, a la que no se accedió durante la construcción.
Consultar la [actualización controlada](upgrade-0.1.184.md). Publicar no actualiza servidores.
