# Actualización controlada a SOC Operations 0.1.184

Destino: instalador 0.1.184, plugin 0.1.110, runtime/API/API externa/worker/agente 0.1.130 y
esquema c8d3e902f751. Esta release cubre el Compose histórico verificado utilizado por
0.1.166; no exige instalar 0.1.183 primero ni reemplazar el Compose a mano.
No actualiza Wazuh: conservar el perfil compatible del destino y su topología registrada.

## Preparar respaldo y staging

Registrar estado/versiones, huella del Compose, esquema, direcciones y baseline de datos.
Inventariar espacio. Preparar respaldo NUEVO verificado de PostgreSQL, OpenBao, objetos/
versiones, reportes y configuración. Custodia auto-unseal separada y clave operativa intacta.
Conservar el paquete anterior y el baseline inmediato. Las copias en caliente no acreditan
una transacción global ni RPO cero; una copia local no protege la pérdida del host.

Descargar el asset cifrado y SHA256SUMS de
[v0.1.184](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.184)
hacia un directorio privado nuevo. Verificar las [huellas](release-0.1.184.md), descifrar por
el mecanismo privado autorizado y comprobar el TAR claro. Nunca introducir la identidad en
chat o historial. Retirar solo su copia temporal, nunca auto-unseal.

Antes de extraer, rechazar rutas absolutas, .., duplicados, enlaces y tipos especiales.
La única raíz release-0.1.184 contiene 49 archivos regulares planos incluido SHA256SUMS.
Usar un staging nuevo protegido y verificar los hashes internos y el orquestador. No
sobrescribir el staging anterior ni reemplazar todavía el instalador activo.

## Preflight y upgrade

Después de verificar staging y respaldo, adaptar la ruta a la extracción real:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.184
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" preflight --staging-root "$SOC_RELEASE"
```

Solo con preflight, respaldo y baseline verificados, durante una ventana autorizada:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.184
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" upgrade --staging-root "$SOC_RELEASE"
sudo /usr/local/sbin/soc-operations-install status
```

Usar upgrade, no apply ni resume. Puede haber interrupciones breves. En un AIO se reconcilia
el agente colocado; en distribuido, verificar el agente del Manager remoto según el flujo
existente. No rotar certificados o claves para eludir errores de identidad.

Desde 0.1.166 se aplican las migraciones existentes de 6d9f2b8c1a53 a c8d3e902f751. Desde
0.1.183 no hay migraciones nuevas. Conservar configuración e identidad institucional, sin
restablecer passwords. No hacer compose down, borrar volúmenes o inicializar OpenBao.
Si falla, detenerse y conservar logs privados; no reintentar o restaurar a ciegas ni marcar
complete a mano. Un hash desconocido sigue siendo motivo de rechazo, no de bypass.

## Aceptación real

- Exigir phase=complete, pasos terminados, versiones objetivo y readiness 200.
- Verificar esquema, cuenta protegida, custodia y conteos frente al baseline; investigar bajas.
- Comprobar mTLS, API autenticada con alcances mínimos y tenant/fechas válidos, navegador
  y reportes reales. El historial de conectividad comienza tras activar el recopilador;
  no se reconstruyen desconexiones anteriores.
- Revisar salida de external-api y listas proxy personalizadas, sin abrir puertos o confiar
  subredes completas. El correctivo de conectividad 0.1.183 sigue incluido.
- Conservar paquetes, respaldos y custodias hasta completar la aceptación. No limpiar rutas
  activas, montajes, staging referenciado ni puntos de recuperación necesarios.

Las pruebas locales no validan el perímetro o los datos reales. Publicar no ejecuta estos pasos.
