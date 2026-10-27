# Actualización a SOC Operations 0.1.191

Versiones objetivo: instalador 0.1.191, API interna/externa, worker y agente
0.1.134; plugin 0.1.114. El esquema pasa de `c8d3e902f751` a `d0f6a3b9e214`.
Mantener el perfil Wazuh/OSD del destino y el Compose aprobado.

## Preparación

Registrar estado, topología, versiones, esquema, cuenta protegida, conteos y
numeración/jerarquía de casos. Preparar y verificar un respaldo nuevo de
PostgreSQL, OpenBao, S3, reportes y configuración. Custodiar auto-unseal cifrada
por separado sin alterar la original. Conservar el paquete previo y sus respaldos;
un respaldo caliente no es una transacción global ni garantiza RPO cero.

Descargar el paquete cifrado y SHA256SUMS de
[v0.1.191](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.191).
Verificar el cifrado, descifrar por el canal autorizado y verificar el TAR claro.
No copiar identidades privadas a chat, argumentos ni logs. Antes de extraer,
rechazar rutas absolutas, duplicados, `..`, enlaces y tipos especiales. Usar
staging privado nuevo y comprobar SHA256SUMS interno.

Revisar las reglas que usaban un decoder como `technology.id`: sustituirlo por
el ID personalizado real o por un filtro explícito `decoder.name`. No modificar
los snapshots ni hashes de alertas anteriores.

## Preflight y actualización

Sin operaciones administrativas concurrentes y con la topología persistida:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.191
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" preflight --staging-root "$SOC_RELEASE"
```

Solo con preflight, respaldo y baseline verificados, en ventana autorizada:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.191
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" upgrade --staging-root "$SOC_RELEASE"
sudo /usr/local/sbin/soc-operations-install status
```

Usar `upgrade`, no `apply` ni `resume`, en instalaciones existentes. Con Manager
remoto, actualizar primero su agente a 0.1.134 mediante el flujo distribuido.
Puede haber una interrupción breve. No mezclar helpers antiguos, cambiar hashes
ni relajar permisos. Si falla, conservar el log privado y detenerse para diagnóstico;
no eliminar volúmenes, ejecutar compose down ni inicializar OpenBao.

## Aceptación del destino

- Confirmar `phase=complete`, todas las etapas completas y versiones objetivo.
- Exigir esquema `d0f6a3b9e214`, salud/readiness de ambas API y contenedores sin
  reinicios inesperados. Comparar cuenta protegida, conteos y auto-unseal.
- Verificar que el checkpoint avanza y los reintentos no duplican casos ni vínculos.
  Un conflicto `source_conflict` requiere revisión de evidencia, no sobrescritura.
- Probar filtros por tenant, nivel y campos personalizados y confirmar que
  `technology.id` no depende de `decoder.name`.
- Verificar FORCE RLS, permisos y timer mTLS sin pedir renovación manual si no corresponde.
- Probar ausencias con turnos coincidentes, cancelación/confirmación y avisos de última hora.
- Descargar un reporte Word/Excel y comprobar fecha/hora, grupos y agrupación.
- Probar anexión autorizada de casos y preservación de ACK, historial y evidencia.
- Consultar API externa con credencial autorizada: sin clave 401, sin alcance 403,
  tenant ajeno rechazado y escrituras no admitidas. Mantener los alcances existentes.
- Verificar el navegador real, no solo readiness ni pruebas locales.

El sondeo inicial comienza en `ahora - lookback` (600 segundos por defecto).
No hay replay histórico automático. Recuperar alertas previamente omitidas requiere
autorización separada, rango explícito y datos todavía retenidos. Un checkpoint
anterior a la retención no debe adelantarse manualmente para ocultar el fallo.

Si el resumen diario de vulnerabilidades indica alcance cambiado, revisar la
recopilación: no servir un snapshot incompatible ni desactivar ese control.
