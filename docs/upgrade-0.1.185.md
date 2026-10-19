# Actualización y recuperación a SOC Operations 0.1.185

Destino: instalador 0.1.185, plugins 0.1.110, API/API externa/worker/agente 0.1.130,
esquema c8d3e902f751. Conservar Wazuh y el perfil exacto del destino. No es necesario
instalar 0.1.184 primero ni editar su paquete para aplicar la corrección.

## Preparación

Registrar versiones, esquema, Compose, topología, direcciones, conteos y cuenta protegida.
Tener respaldo vigente y verificado de PostgreSQL, OpenBao, versiones S3, reportes y
configuración; auto-unseal cifrada por separado y clave operativa intacta. Conservar los
paquetes y logs anteriores. Una copia local no protege la pérdida del host; las copias en
caliente no son una transacción global ni implican RPO cero.

Descargar el asset cifrado y SHA256SUMS de
[v0.1.185](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.185).
Verificar las [huellas](release-0.1.185.md), descifrar por el canal privado autorizado y
verificar el TAR claro. No poner identidades en argumentos, chat o historial. Retirar solo
la copia temporal de la identidad age, nunca auto-unseal.

Antes de extraer, rechazar rutas absolutas, '..', duplicados, enlaces y tipos especiales.
La raíz release-0.1.185 contiene 49 archivos regulares planos, incluido SHA256SUMS.
Usar staging privado nuevo; no sobrescribir el anterior. Verificar hashes internos,
orquestador, Compose y provisionador. No reemplazar manualmente el instalador activo.

## Preflight y actualización

Mantener topología y direcciones persistidas; adaptar al staging real:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.185
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" preflight --staging-root "$SOC_RELEASE"
```

Solo con respaldo, preflight y baseline verificados, durante una ventana autorizada:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.185
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" upgrade --staging-root "$SOC_RELEASE"
sudo /usr/local/sbin/soc-operations-install status
```

Usar upgrade, no apply ni resume. Puede haber interrupciones breves. En AIO se reconcilia
el agente colocado; en distribuido debe seguirse el flujo del agente del Manager remoto.
No cambiar hashes, Compose, certificados o claves para eludir controles. No hacer compose
down, borrar volúmenes, inicializar OpenBao ni restaurar automáticamente datos anteriores.

## Intento 0.1.184 interrumpido al generar agent.env

No asumir que todos los fallos ocurren antes del runtime. Verificar fase, servicios,
readiness, esquema efectivo, huella de Compose, cuenta protegida y conteos. Conservar logs.
Si el diagnóstico confirma agent.env válido, no editarlo: el fallo descrito está en el
archivo temporal generado. No marcar complete manualmente.

Comprobar integridad, cobertura y vigencia del respaldo existente. No borrarlo ni
sobrescribir su baseline; capturar una línea base inmediata nueva antes del siguiente
intento. Si la cobertura ya no es suficiente, preparar un respaldo nuevo. Usar únicamente
el staging 0.1.185 verificado y el comando upgrade después de revisar el punto del fallo.
Conservar los paquetes 0.1.184 y anterior hasta completar la aceptación.

Desde 0.1.166 siguen aplicándose las migraciones existentes entre 6d9f2b8c1a53 y
c8d3e902f751; desde 0.1.184 no hay migraciones nuevas. Se conserva la cuenta institucional
sin restablecer su contraseña. No programar una restauración como parte automática del retry.

## Aceptación

- Exigir phase=complete, todos los pasos y readiness 200.
- Verificar versiones objetivo, esquema, cuenta protegida, conteos y huella auto-unseal.
- Comprobar mTLS, API autenticada con alcances mínimos, navegador y reportes reales.
- Validar salida desde external-api sin ampliar redes confiables ni modificar UFW/TLS.
- No limpiar paquetes, logs o respaldos hasta completar la aceptación.

Si falla, detenerse y conservar el log privado; no reintentar o restaurar a ciegas.
Publicar y aprobar pruebas locales no ejecuta ni acredita la actualización del destino.
