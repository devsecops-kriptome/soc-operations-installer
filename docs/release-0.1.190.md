# SOC Operations 0.1.190

Instalador 0.1.190; API interna, API externa, worker y agente 0.1.133;
plugin socOperations 0.1.113 para OSD 2.19.5 y 2.19.6. Esquema c8d3e902f751,
sin nuevas migraciones. Perfiles Wazuh 4.14.7-1 y 4.14.8-1 respectivamente.

El colector incorpora el nombre de producto del evento mas reciente de cada
fuente: technology.name, con alternativa data.technology.name en eventos
decodificados de Wazuh. No usa el hostname del colector como nombre de producto.
Si el campo falta, su valor publico es null y se indica como identificador ausente.

GET /api/v2/technologies/status conserva technologies:read, tenant obligatorio
y views global, granular y both. El detalle entrega identity["technology.name"];
el global incorpora groups[].technology_names: nombres unicos y ordenados de
todas las fuentes visibles del ambito, no solo de la primera pagina.
technology_name conserva la categoria, por ejemplo WAF o Firewall.

agent.name deja de mostrarse y publicarse en las identidades de las fuentes.
Se conservan manager.name, agent.id y los identificadores configurados, como
data.device_serial_id para un firewall cuyo evento incluya ese campo.
Las claves internas previas permanecen estables: enriquecer o cambiar el nombre
de producto no duplica fuentes ni borra las observaciones existentes.
Los datos antiguos se enriquecen al observar nuevos eventos; no se inventan nombres.

El dashboard muestra los nombres en la categoria y en las fuentes desplegadas,
con texto completo al pasar el cursor por la lista global truncada. Conserva los
permisos existentes para configurar, activar o desactivar cada tecnologia.

Imagen, wheel y ambos plugins se recompilan y se verifican sus versiones y hashes.
Se conserva el Compose aprobado de 0.1.189 y sus controles de aislamiento,
red, mTLS, renovacion y permisos. No se modifican auto-unseal ni alcances de claves.

Este paquete no acredita la resolucion de errores de recopilacion del resumen
diario de vulnerabilidades en un destino. Si el alcance de agentes cambia,
ese endpoint sigue rechazando un corte incompatible hasta una recopilacion
correcta. La comprobacion autenticada en el destino sigue siendo necesaria.


## Integridad

- Instalador cifrado SHA-256: `6d35a7d09e25d583eacae499bac88f3bf4d534924cbe5d872f45a1e3904595de`.
- TAR claro: `c46516426cb9b3c689454d809a6ed4bf2a436c7e0c60c9a52e2e360eb6555f49`.
- Orquestador: `7fb5cf6602d1bde8e4945b03636120f1c485e665ad010e7599d6be88b4ec69b6`.
- Compose: `321c80c77b83debfd1bd934fad9871c850dd4bdd81d9980d36337828e1537445`.
- Imagen config ID: `sha256:fb564f4681dac5c05a5fe36813d51671ac9dfffdb9752a33333d8ed9d7fcef7f`.
- Imagen OCI manifest ID: `sha256:db98662c4247264ae3d63caf014c46e40eb1503b01593d8e7be86283e1e1284e`.

El TAR contiene 49 archivos regulares bajo release-0.1.190, incluido SHA256SUMS.
Solo se distribuyen el paquete cifrado, hashes y documentación pública; la identidad
privada age permanece en el gestor autorizado. Los hashes no sustituyen la autenticidad
del canal de distribución. No se utiliza la identidad privada para construir el paquete.

## Validación local

2073 pruebas aprobadas: 1722 backend/agente, 330 del plugin y 21 adicionales de
PostgreSQL/RLS y mensajes. Sin fallos ni omisiones en la ejecución final.
Las 387 regresiones de pines finales repetidas no se suman por segunda vez.
La primera ejecución completa utilizó un puerto de PostgreSQL incompatible con
la guarda explícita de una prueba; se repitió toda la suite en una base desechable
nueva con el puerto requerido, sin modificar esa guarda ni el producto.

Ambos perfiles se compilan y verifican con TypeScript. Mypy revisa 123 archivos
y Ruff aprueba. Imagen, wheel y fuentes coinciden en 122 archivos Python;
58 archivos de migración/configuración coinciden y pip check aprueba.
La imagen empaquetada conserva config ID y manifest ID enlazados y verificados.

Las pruebas cubren nombres canónicos y alternativos, ausencia de nombre sin
sustitución por agent.name, observaciones antiguas, nombres globales del ámbito
completo y paginación, fuentes desactivadas y aislamiento tenant/RBAC.
Las 21 comprobaciones adicionales incluyen PostgreSQL real sintético con RLS
y bloqueo de fila del reporte; los canales de mensajes usan transporte simulado.
La API externa real se inicia aislada como UID 10001 y raíz read-only, sin red
externa: salud 200, ocho rutas sin clave 401 y escrituras 405. La interfaz usa
DOM automatizado; la aceptación en navegador y la API autenticada del destino
se completan después del despliegue.

La implementación TLS se mantiene salvo constantes de release. Las pruebas Linux
reales previas se referencian desde 0.1.188, no como una nueva instalación completa.
Sintaxis de 13 helpers y ShellCheck sin errores ni hallazgos nuevos; se conservan
13 advertencias o avisos preexistentes. No se modifica UFW, puertos ni auto-unseal.

## Actualización

Seguir la [guía de actualización](upgrade-0.1.190.md), con respaldo vigente,
baseline y ventana autorizada. Mantener el paquete previo y sus respaldos hasta
completar la aceptación. Con Manager remoto, actualizar primero su agente a
0.1.133 mediante el flujo de la topología. Publicar no actualiza LAUFEY.
