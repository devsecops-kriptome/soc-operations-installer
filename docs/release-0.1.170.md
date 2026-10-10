# SOC Operations 0.1.170

Instalador 0.1.170, API/worker/agente 0.1.120, plugin 0.1.101; build
`0.1.101-events-host-vulnerabilities-calendar-toolbar`. Esquema `a2c8e4f719b6`, sin migración nueva.

## Cambios

- Bandeja sin tarjetas ni columna Selección, columnas compactas y acciones ⋮.
- Importador Discover en ambas vistas, con consulta, periodo UTC y request_id para diagnóstico.
- Detalle completo, copia en texto, un scroll, enlace Discover cuando existe origen seguro y
  navegación Anterior/Siguiente entre eventos relacionados.
- Contraste del calendario y barra CSV al lado derecho del tenant; exportación autorizada para
  lectores. Ingeniería L3 comparte disponibilidad entre tenants sin ampliar permisos.
- Ingeniería activa autorizada en responsables y destinatarios, CC validado y deduplicado.
- Casos automáticos asignados a personal elegible de turno; sin cobertura, sin responsable ni menciones.
- Vulnerabilidades por host con severidades y consolidado por paquete: total de inventario y Top 10
  CVE recientes con score como desempate. Automatización en modal, informes por host o grupo con
  paquetes/hosts anidados y recomendación inicial. Descripciones truncadas con texto completo disponible.
- Reportes y simulaciones leen snapshots completos por lotes con límites, verificación de tenant,
  shards y unicidad. El límite de reconciliación del worker se conserva; no se aceptan snapshots parciales.

## Validación y límites

630 backend aprobadas, 5 omitidas; 77 frontend. Diez pruebas con PostgreSQL real de cuenta protegida,
RLS de personal global, invitaciones y ausencias. Nueve diagnósticos de tipos preexistentes persisten.
Plugins 2.19.5/2.19.6, fuentes, wheel, imagen, pip check, gzip y cadena de hashes verificados.
Pantallas sintéticas revisadas localmente; producción y revisión visual de Word/PDF pendientes.
No cambia Wazuh, custodia, cuenta institucional, topología ni reglas HAProxy/Coraza/CSP.
No corrige automáticamente caché externa o `/api/request` 401; no incluye rollback global ni prueba DR.

## SHA-256

| Artefacto | SHA-256 |
| --- | --- |
| SHA256SUMS externo | `9eb7de588a555b6ae431597e1ad3e690321c5cf6d2dbd81fde8fba0110d99e76` |
| TAR cifrado | `7077015f01633e2c0ed1661d4d8674bf941f81cbca11b53ceefea14e31620c58` |
| TAR descifrado | `fd60148e5ba6264ac878bae36f55131183b726c509d6cdea0032c0e7976b53d4` |
| soc-operations-install | `8a6ea7832b24c4b77a0e1f828daa44b22dd16070261cb0130b6bd6b6126f0952` |

Distribución cifrada con el mismo destinatario age. Solo TAR cifrado y manifiesto en GitHub;
no fuente privada, identidades, configuraciones reales ni respaldos. 48 artefactos internos.
0.1.169 se conserva. [Actualización LAUFEY](upgrade-0.1.170-laufey.md): checkpoint nuevo obligatorio,
ventana y aceptación funcional. Publicar no actualiza el servidor.
