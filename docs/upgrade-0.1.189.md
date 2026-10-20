# Actualización a SOC Operations 0.1.189

Instalador 0.1.189; API interna/externa, worker y agente 0.1.132; plugin 0.1.112.
El esquema c8d3e902f751 y el Compose aprobado no cambian. Mantener el perfil
Wazuh/OSD del destino. Esta guía es para instalaciones existentes, no para
repetir apply o inicializar OpenBao.

## Preparación

Registrar topología, versiones, salud, Compose, cuenta protegida y conteos.
Verificar un respaldo vigente de PostgreSQL, OpenBao, S3, reportes y configuración;
custodiar auto-unseal cifrada por separado sin alterar la clave original.
Un respaldo en caliente no es una transacción global ni implica RPO cero.
Conservar el paquete previo, baselines y logs hasta completar la aceptación.

Descargar el paquete cifrado y SHA256SUMS de
[v0.1.189](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.189).
Verificar las [huellas](release-0.1.189.md), descifrar por el canal autorizado y
verificar el TAR claro. No copiar identidades a chat, argumentos o logs.
Antes de extraer, rechazar rutas absolutas, '..', duplicados, enlaces y tipos
especiales. Son 49 archivos regulares bajo release-0.1.189. Usar staging privado
nuevo y verificar SHA256SUMS interno; no sobrescribir archivos activos a mano.

## Preflight y actualización

Sin operaciones administrativas concurrentes, con topología/direcciones persistidas:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.189
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" preflight --staging-root "$SOC_RELEASE"
```

Solo con preflight, respaldo y baseline verificados, en ventana autorizada:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.189
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" upgrade --staging-root "$SOC_RELEASE"
sudo /usr/local/sbin/soc-operations-install status
```

Usar upgrade, no apply ni resume. No ejecutar helpers antiguos en paralelo,
editar hashes/Compose ni desactivar controles para eludir un rechazo. Con Manager
remoto se requiere primero agente 0.1.132 mediante su flujo de actualización.
Puede haber una interrupción breve. Si falla, detenerse y conservar el log privado;
no restaurar a ciegas, hacer compose down, borrar volúmenes ni inicializar OpenBao.

## Aceptación del destino

- Exigir phase=complete, todas las etapas y versiones objetivo, readiness 200
  y contenedores sin reinicios inesperados.
- Comparar esquema, cuenta protegida, conteos y huella de auto-unseal.
- Probar la API externa con credencial y alcances mínimos existentes.
- En Reportes de Vulnerabilidades, confirmar columnas Generado, Grupos,
  Agrupación, Acciones y Estado; lista completa de grupos al pasar el cursor.
- Editar desde el menú de tres puntos y reabrir: grupos, agrupación, destinatarios,
  CC, frecuencia, fecha/hora, zona y habilitación deben conservarse.
- Cambiar solo grupos/destinatarios no debe descartar una ejecución pendiente.
  Cancelar no escribe; eliminar exige confirmar y conserva reportes históricos.
- Generar un reporte nuevo y probar correo autorizado: Word/Excel, grupos,
  agrupación y corte deben corresponder al reporte guardado. CC sigue sujeto
  a la configuración SMTP. El DELETE 204 no debe causar errores de JSON.
- Los reportes anteriores mantienen su alcance y corte. No se habilitan otros
  canales de entrega automáticamente ni se agregan alcances API externos.

## Controles mTLS conservados

Verificar tls-status, timer, Result/ExecMainStatus y vencimiento como indica
la [guía mTLS de 0.1.188](upgrade-0.1.188.md#mtls-interno). La renovación coordinada
requiere Manager/agente y runtime colocados; no distribuye claves entre hosts.
No equivale a renovar el TLS público de Wazuh/Indexer/GeoIP. No borrar diarios
de renovación ni pending.json ante un fallo. Conservar respaldo y paquete previo.
