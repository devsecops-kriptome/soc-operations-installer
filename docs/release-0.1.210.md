# SOC Operations 0.1.210 — activos, evidencia y enriquecimiento

Pre-release; no sustituye la estable 0.1.206. Publicar no despliega en servidores.

| Componente | Versión |
| --- | --- |
| Instalador | 0.1.210 |
| Runtime, worker y agente | 0.1.152 |
| Plugin | 0.1.130 |
| Esquema | f0c437e185d9 |
| Plataformas | Wazuh 4.14.7 / OSD 2.19.5 y Wazuh 4.14.8 / OSD 2.19.6 |

## Contenido

- Inventario de activos por tenant, CSV y sincronización Snipe-IT/GLPI por lotes;
  asociación de agentes y contexto de activos para casos.
- Evidencia histórica individual SLA mediante API externa, también para Low.
  No aplica recuperaciones ni reescribe automáticamente históricos.
- Refresco de datos en dashboard, casos y tecnologías, con alcance del tenant
  seleccionado y protección contra respuestas tardías de otro contexto.
- Notificaciones opcionales de tecnologías externas: canales configurados,
  guardia y seguimiento. Se habilitan explícitamente por tenant.
- Reputación AbuseIPDB de IP públicas: registro canónico común, vigencia de
  15 días, control de concurrencia y presupuesto diario. Solo se comparte la
  reputación pública; casos, clientes y analistas permanecen separados por tenant.

La clave AbuseIPDB se configura en Administración → Integraciones → AbuseIPDB y
se custodia en OpenBao. El proveedor se consulta mediante GET verificado;
no se reportan IP, bloquea tráfico ni envía evidencia de clientes.
Una IP vencida se actualiza cuando un caso nuevo la necesita, no al refrescar
el navegador. No hay backfill histórico ni actualización periódica de toda la caché.

## Activación y actualización

Activos y reputación permanecen desactivados por defecto. Requieren identidades
dedicadas de Indexer y TLS verificado. El paquete incluye las plantillas
`assets-indexer-role.json` e `ip-reputation-indexer-role.json`; no crea cuentas
Indexer administrativas. Las políticas OpenBao de los workloads están incluidas.
El upgrade conserva custodias conocidas y refresca políticas antiguas sin repetir
bootstrap ni rotar tokens. Puede solicitar una vez un token OpenBao autorizado,
mediante entrada oculta; no solicita la clave AbuseIPDB en la terminal.

## Validación local

- 3.865 pruebas backend únicas aprobadas: 3.864 en la ejecución completa y el
  escenario opcional restante ejecutado con PostgreSQL real por separado.
- 652 pruebas frontend aprobadas; TypeScript y compilación para ambas plataformas.
- 94 pruebas de la cadena final del instalador y 5 escenarios adicionales de
  conservación de custodia y refresco de políticas aprobados.
- Ruff y MyPy aprobados. Sin hallazgos nuevos/no revisados de severidad media o
  alta en Bandit; se conservan tres hallazgos anteriores revisados.
- Imagen, wheel, fuentes instaladas, migraciones, archivos de plugins, pins y
  hashes internos contrastados. Arranque no root de solo lectura, liveness,
  rechazo de consultas sin autorización y de escrituras externas comprobados.

## Límites y aceptación pendiente

No se certifica todavía la actualización productiva, el descifrado con la
identidad privada del operador, las integraciones reales ni la aceptación
autenticada por rol/tenant en el navegador. Las rutas nuevas de escritura deben
validarse a través del proxy/WAF del destino; Coraza no fue modificado ni
certificado por esta entrega. No desactivar CSP, validación de cuerpos o WAF
globalmente para habilitar una integración.

No es una actualización integral de seguridad: persisten riesgos heredados de
imagen base y componentes auxiliares. Se conserva el artefacto MinIO anterior.
Los límites finales de período siguen siendo exclusivos: octubre completo en
America/Lima es desde 01/10 00:00 hasta 01/11 00:00 exclusivo.

Solo se distribuyen el TAR cifrado age y SHA256SUMS. Código privado, TAR claro,
identidades, respaldos y configuraciones reales no se publican.
Consultar la [actualización controlada](upgrade-0.1.210.md).
