# SOC Operations Installer 0.1.204

Instalador 0.1.204; API interna/externa, worker y agente 0.1.147;
plugin 0.1.124; esquema c7f104b952a8. Perfiles Wazuh 4.14.7-1/OSD 2.19.5
y Wazuh 4.14.8-1/OSD 2.19.6, AIO o distribuido con un Dashboard.

## Threat Radar

- Módulo opcional situado antes de Vulnerabilidades, deshabilitado por defecto.
  Solo Ingeniería puede habilitarlo desde Administrador, Integraciones.
- Dashboard compartido accesible desde los tenants cuando el módulo está habilitado.
  Deshabilitado no expone publicaciones ni cartera privada.
- Períodos rápidos, actualización cada 15 minutos, tarjetas de prioridad coherentes,
  publicaciones y estado independiente por fuente. Sin novedades no significa error.
- PostgreSQL con proyección JSONB y retención de hasta 12 meses calendario desde
  la publicación oficial. No inventa publicaciones anteriores ni horas ausentes.
- Administración con subpestañas Fuentes, Clientes y tecnologías, Notificaciones;
  menús de tres puntos y modales. Solo Ingeniería y SOC Manager con membresía activa.
- Cartera independiente de los clientes/tenants del SOC. Sus contactos y las
  notificaciones no se exponen a los lectores del dashboard.
- Cruces tecnológicos orientativos, normalizando mayúsculas, acentos e invisibles;
  validar producto, versión y exposición antes de avisar al cliente.
- SMTP existente con nombre de remitente Threat Radar. Envía a destinatarios SOC
  configurados, no automáticamente a los contactos de clientes. La primera
  recopilación no envía alertas históricas. Slack no forma parte de esta entrega.

No reemplaza clientes, agentes, tecnologías ni casos del SOC. No aplica planes
históricos SLA, no altera suplementos existentes ni reconstruye hitos ausentes.

## Alcance y límites

Esta publicación corresponde al paquete congelado anterior a las correcciones
de vulnerabilidades posteriores. Conserva MinIO sin sustituir su imagen recuperada.
No certifica que MinIO, OpenBao, PostgreSQL, Python, Nginx u otras dependencias
estén libres de vulnerabilidades. La revisión de seguridad y su remediación
continúan por separado; no actualiza Wazuh ni certifica perfiles nuevos.

Validación local: 3473 pruebas backend/agente, 23 de cadena de artefactos y 517
de interfaz aprobadas, sin fallos ni omisiones finales. Ambos plugins compilados;
Ruff, MyPy, RLS y pruebas PostgreSQL de Radar verificados. Permanecen visibles los
hallazgos estáticos preexistentes revisados; esto no equivale a una auditoría
de dependencias sin hallazgos ni a aceptación en producción.

## Artefactos públicos

Solo se publican el paquete cifrado y SHA256SUMS, nunca el TAR en claro,
código privado, respaldos, datos de clientes ni identidades de descifrado.

| Archivo | SHA-256 |
| --- | --- |
| SHA256SUMS | `df5f637ea27bfae29be070aa636773c1dd25d2f470458352c2b1499ce4740c34` |
| soc-operations-0.1.204.tar.gz.age | `002fff1b4685bbd6b6cc14ea1fa38de9cfcb4f04097539e71dd922ceb35b0ac2` |
| soc-operations-0.1.204.tar.gz, tras descifrar | `6be11c38acd1e18aa616c477afc161398d0eae6d1111aedd0d9e38dd6eb6449f` |

Paquete cifrado: 352153211 bytes. TAR interno: 53 archivos regulares, incluido
SHA256SUMS. La identidad privada solo se obtiene del gestor autorizado bajo
SOC Operations Installer Descifrado; no se comparte por GitHub ni por el chat.

Publicar no despliega. Antes de instalar, seguir la
[guía de actualización](upgrade-0.1.204.md), verificar un respaldo nuevo y
conservar las evidencias previas. Descifrado, accesos reales y entrega SMTP
deben aceptarse en el destino antes de habilitar notificaciones.
