# Actualizar SOC Operations de 0.1.181 a 0.1.183

Destino: instalador 0.1.183, plugin 0.1.110, runtime/API/API externa/worker/agente 0.1.130 y
esquema c8d3e902f751. Sin nuevas migraciones desde 0.1.181. Incluye el correctivo local
0.1.182; no se requiere instalarlo primero. No es instalación limpia: no usar apply,
reinicializar OpenBao ni reemplazar la topología registrada por un ejemplo.

## Preparar respaldo y descarga

Registrar status, servicios y baseline. Preparar un respaldo NUEVO verificado de PostgreSQL,
OpenBao, objetos/versiones, reportes y configuración, con custodia auto-unseal separada.
Conservar también el baseline inmediato antes del upgrade. Las copias en caliente no
acreditan una transacción global ni RPO cero; una copia local no protege la pérdida del host.

Descargar el asset cifrado y SHA256SUMS de
[v0.1.183](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.183)
hacia un directorio privado nuevo. Comparar las [huellas](release-0.1.183.md), verificar el
.age y descifrar con la identidad del gestor autorizado mediante el mecanismo privado
existente. Nunca introducir su valor en chat o historial. Verificar el TAR y retirar solo
la identidad temporal; conservar intacta la clave auto-unseal operativa.

Antes de extraer, rechazar rutas absolutas, segmentos .., duplicados, enlaces y tipos
especiales. La única raíz release-0.1.183 contiene 49 archivos regulares planos incluido
SHA256SUMS. Extraer en un staging nuevo protegido y verificar todos los hashes internos
y el orquestador. No sobrescribir el staging anterior ni el instalador activo todavía.

## Preflight y ventana de actualización

Después de esas verificaciones, ajustar la ruta al staging real:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.183
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" preflight --staging-root "$SOC_RELEASE"
```

Confirmar Compose/provisionador coherentes y agente mTLS remoto 0.1.130. Desde 0.1.181
no cambia el wheel; no es necesario rotar identidades/certificados ni cambiar al Compose
anterior. Para otras versiones anteriores, revisar primero sus migraciones y procedimiento.

Solo con respaldo, baseline y preflight satisfactorios, durante una ventana autorizada:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.183
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" upgrade --staging-root "$SOC_RELEASE"
sudo /usr/local/sbin/soc-operations-install status
```

Usar upgrade, no resume ni apply. Puede haber interrupciones breves. No hacer compose down,
borrar volúmenes, inicializar OpenBao, editar el Compose instalado o marcar complete a mano.
Si falla, detenerse y conservar logs privados; no reintentar ni restaurar a ciegas.

## Aceptación en el destino

- Exigir versiones objetivo, todos los pasos completos, readiness 200 y servicios activos.
- Comparar cuenta protegida, huella auto-unseal y conteos con el baseline; investigar bajas.
- Comprobar salida de external-api hacia el agente desde frontend. Las listas proxy
  personalizadas se preservan: verificar su gateway efectivo sin confiar subredes completas.
- Probar API autenticada: vulnerabilidades, métricas de eventos y estado de agentes, con
  alcances, tenant y fechas válidos. Repetir desde la IP real de la aplicación consumidora.
- Verificar la nueva UI 0.1.110 en navegador: menús por fila, una sola solicitud de revocar/
  eliminar, reintento tras error y exportación individual/conjunta según rol y tenant.
- Conservar paquetes previos, respaldos y custodias hasta terminar la aceptación. No limpiar
  rutas activas ni referencias de staging, montajes o puntos de recuperación necesarios.

Las pruebas locales no validan el firewall, certificados ni datos del destino. Publicar en
GitHub no ejecuta este procedimiento y no modifica LAUFEY.
