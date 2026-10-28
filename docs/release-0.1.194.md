# SOC Operations 0.1.194

Publicación del 28 de octubre de 2026 para Wazuh 4.14.7 y 4.14.8, en AIO o
distribuido. El instalador es 0.1.194, el runtime/agente 0.1.137 y el plugin 0.1.116.
El esquema final es c64e93b8a521. La publicación no despliega ningún servidor.

## Cambios incluidos

- Contactos de cliente y consulta externa con `contacts:read`. El indicador de
  KriptomeAPP es un dato de contacto, no un alta automática en otro sistema.
- Clasificación en seis grupos estándar de endpoints y resumen de grupos con
  estados de conectividad, dentro del cliente autorizado.
- Métricas por tipo de detección y niveles medium/high/critical. El rango de
  `rule.id` es una convención de clasificación, no prueba del origen del XML.
- Pausa/reactivación de tenants y vista previa de eliminación. La pausa afecta
  a SOC Operations, no a la recepción Wazuh; el borrado físico no está habilitado.
- Categorías explícitas de automatización y filtros de dominio en la API externa.
  La nueva regla global de vulnerabilidades queda pausada con nivel mínimo 10.
- Correcciones de aislamiento por índice/tenant, recibos, checkpoints, contadores,
  categorías y ediciones concurrentes. La configuración de reglas permanece
  estable durante cada lote y conserva el orden transaccional de auditoría.

Las migraciones nuevas son b53d82a7f410, contactos y acceso externo, y c64e93b8a521,
categorías y regla global opt-in. No hay replay histórico ni activación automática
de la API externa. Se preservan identidad del despliegue, cuenta protegida y seal.
API y worker deben actualizarse juntos mediante el instalador.

## Validación local

2.779 pruebas únicas aprobadas: 2.404 de backend/agente y 375 de interfaz, sin
fallos ni omitidas en la ejecución final. Otras 54 comprobaciones focalizadas
se repitieron sin contarlas dos veces. Se corrigieron expectativas de QA sobre
el esquema actual, el estado activo del tenant y el trabajo de otros tenants
activos; no se cambiaron los controles de autorización para hacerlas pasar.

Ruff y MyPy aprueban sobre 134 archivos fuente. Ambas variantes del plugin
pasan TypeScript y compilación para OSD 2.19.5 y 2.19.6. Imagen y wheel coinciden
con las fuentes en 133 archivos Python y las 62 fuentes de migración/configuración.
La comprobación de dependencias pasa. La imagen arranca sin red, con UID 10001
y raíz de solo lectura: salud 200, ocho rutas protegidas sin clave 401 y escrituras
405. Los 13 scripts pasan sintaxis; ShellCheck no agrega errores ni avisos frente
al paquete anterior. Persisten avisos no fatales de herramientas de compilación
y deprecaciones de las dependencias de pruebas.

La aceptación en lab02 AIO sigue pendiente: respaldo nuevo, descifrado, preflight,
API autenticada, reporte real y navegador. La prueba de concurrencia no es una
medición de capacidad del destino. Ver [actualización](upgrade-0.1.194.md).

## Integridad

- Archivo cifrado SHA-256: `aefc20ea2320057d0c89efb5af864a4b4338e55490bc18a6c33f8176b369ff64`.
- TAR claro SHA-256: `33fdb5fe41faf7d28ca10542a6c2d6cf1ef28918d5bd130327560dd9d5e4e071`.
- Orquestador SHA-256: `fe26501df024acb34ee1dc9953bb253fd0256bd5bf985e72d1efbfe9913f26cc`.
- Compose SHA-256: `321c80c77b83debfd1bd934fad9871c850dd4bdd81d9980d36337828e1537445`.
- Imagen config ID: `sha256:e3eed42d400470c77733b804cb7a30d89fbfe335097ae89d3f676e00ccb2738c`.
- Imagen manifest ID: `sha256:6eb0e3b412283392c18b8c8afdb3648c0e57cfc3f33ee2e1b58ad262dc554d36`.

El TAR contiene 49 archivos regulares bajo release-0.1.194, incluido SHA256SUMS.
Solo se publican el instalador cifrado, hashes y documentación. La identidad
privada age se mantiene en el gestor autorizado y no se utiliza para publicar.
