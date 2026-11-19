# SOC Operations 0.1.209 — navegación y permisos del menú

Pre-release sobre 0.1.208. No sustituye la estable 0.1.206 ni despliega en servidores.

| Componente | Versión |
| --- | --- |
| Instalador | 0.1.209 |
| Plugin | 0.1.129 |
| Runtime y agente, sin cambios | 0.1.151 |
| Esquema, sin cambios | d8a215c963b7 |
| Plataformas del plugin | OSD 2.19.5 y 2.19.6 |

## Corrección

Los refrescos independientes de permisos y Threat Radar publicaban decisiones
parciales. OpenSearch Dashboards vuelve a aplicar cada actualización sobre las
aplicaciones registradas originalmente, por lo que otros enlaces retornaban a
su estado inicial oculto. Ahora se publica una decisión completa y coherente
para todos los enlaces restringidos.

El menú y las vistas usan los mismos controles. Las vistas operativas no toman
permisos de otro tenant ni aceptan un tenant desconocido. Las respuestas tardías
no pueden recuperar accesos revocados ni sobrescribir decisiones más recientes.
Calendario operativo sigue excluido para Ingeniería y SOC Manager; la
administración central del calendario conserva sus permisos específicos.

La aplicación se incluye de forma anticipada en el bundle principal del plugin;
permanecen chunks de terceros. Esto mitiga los errores de montaje tardío. La causa
exacta del desajuste previo entre bundles servidos no está certificada y debe
validarse en el navegador del destino. No se modifica ni debilita CSP, TLS o RBAC.

## Validación local

- 593 pruebas de interfaz aprobadas, sin fallos ni omisiones.
- 80 comprobaciones de autorización backend, sin cambios en ese código.
- 36 escenarios con el actualizador real de OSD por plataforma: 72 en total.
- TypeScript aprobado en ambas plataformas y ambos plugins compilados.
- Fuentes contrastadas con los stages de compilación; ZIP y pares Gzip/Brotli verificados.
- Paquete completo, hashes internos y pins del instalador verificados.

No se afirma una nueva ejecución integral del backend ni una aceptación E2E
productiva. Runtime, wheel, infraestructura, MinIO, configuración de despliegue y
demás artefactos no afectados se reutilizan idénticos a 0.1.208.

## Límites y conservación

No incluye el prototipo Activos de 0.1.207. No reescribe históricos, aplica planes
de recuperación ni exige repetir la aceptación histórica agregada de SLA.
Threat Radar conserva su estado existente; una instalación nueva mantiene el
valor predeterminado deshabilitado.

No es una actualización de dependencias o seguridad. Persisten los riesgos
residuales y limitaciones de las versiones base, incluida la evaluación de MinIO.
No se certifica que esta corrección elimine restricciones remotas HTTP 403 de fuentes.

Se publican únicamente el TAR cifrado con age y SHA256SUMS; no se publica código
privado, TAR claro, identidades, respaldos ni configuraciones reales.
El descifrado autorizado y la aceptación autenticada por rol/tenant siguen pendientes.
Consultar la [actualización controlada](upgrade-0.1.209.md).
