# Release 0.1.168 — paginación de vulnerabilidades

Instalador `0.1.168`; API/worker/agente `0.1.118`; plugin `0.1.99`;
build `0.1.99-vulnerability-cursor-pagination`. Desde 0.1.167 el esquema permanece
en `a2c8e4f719b6`, sin migración nueva. Los perfiles Wazuh/OSD admitidos no cambian.

Vulnerability Triage consulta una página del servidor mediante cursor, con 50 hallazgos
por defecto y opciones 25/50/100. Anterior/Siguiente conserva el total del tenant sin
descargar todo el inventario con `all_current=true`. La selección y creación de casos
se limita a la página visible y la API conserva la revalidación de cada hallazgo.
Actualizar reinicia los cursores y vuelve a la primera página. El refresco automático
no se solapa; solo opera en la primera página, sin selección, modal ni acciones pendientes.
Cambiar de tenant o cerrar la vista cancela la petición y descarta respuestas obsoletas.

Conserva el límite de respuesta de 25 MiB del proxy, TLS, RBAC, la protección institucional
y la planificación L3/global e invitados de 0.1.167. No modifica HAProxy, Coraza ni CSP.
El 401 de `/api/request`, los avisos CSP y la telemetría son diagnósticos separados;
esta release no afirma corregirlos ni acredita aceptación en LAUFEY antes de comprobarla.

Validación local: 562 pruebas backend aprobadas, 15 omitidas por requisitos de integración,
dos avisos de deprecación; 31 pruebas frontend con EUI real aprobadas. Los 26 controles
de pins/contrato también pasan. Los dos plugins se compilaron con los SDK exactos; JS/JS.gz,
metadatos, fuentes/wheel sin cambios y los 48 hashes internos fueron verificados.
El chequeo global TypeScript mantiene nueve diagnósticos en código ajeno a la lógica
de paginación; no es un chequeo completamente limpio. La paginación no registra diagnósticos.
43 artefactos de 0.1.167 se conservan byte a byte, incluida la imagen y el wheel de API/agente.
La release y los activos de 0.1.167 permanecen intactos.

SHA-256 del TAR: `38b99f43104bd980a5fb406d60913c5f483c5073207c1d6e2647138c5ad59d73`.
Asset cifrado: `1d5f9f80b27523fd02d7ec23c3ab2195fe51ed57d5687b1977ccf1bf5d9ef8f3`.
Manifiesto externo: `2a488df9e9fe32f128a87e3a42a70cb3836ecc384d0595db8f2f48bfef5c62c7`.
Instalador: `d4591949716aaafa8cb93d52800434d6a9b97345ebcba079ecce88684f538c70`.

Se publica solo el paquete cifrado y su manifiesto, nunca código fuente sin cifrar,
claves privadas, credenciales ni respaldos operativos. Seguir la
[guía supervisada de actualización](upgrade-0.1.168-laufey.md) con respaldo NUEVO del
estado 0.1.167, custodia de seal separada y ventana de mantenimiento. El checkpoint
previo a 0.1.167 no representa el estado posterior a esa actualización.
