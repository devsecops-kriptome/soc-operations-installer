# Actualizar SOC Operations de 0.1.180 a 0.1.181

Objetivo: instalador 0.1.181, API/API externa/worker/agente 0.1.130, plugin 0.1.109 y esquema
c8d3e902f751. Se conservan topología, identidades y configuración. No es una reinstalación:
no usar apply ni inicializar OpenBao. Si persiste el fallo parcial de 0.1.179, resolver primero
según la [recuperación 0.1.180](upgrade-0.1.180.md), sin omitir guardas.

## Respaldo y baseline

Confirmar versión instalada, pasos completos, servicios, readiness, cuenta institucional y
datos. Preparar respaldo NUEVO y verificado de PostgreSQL, OpenBao, objetos/versiones, reportes
y configuración; custodia auto-unseal separada y huella operativa conservada. El respaldo usado
para recuperar 0.1.180 puede tener nombre de otra versión y no contiene escrituras posteriores.
No elegirlo ni eliminarlo únicamente por el nombre. Una copia local no protege la pérdida del host.

Registrar un baseline inmediato además del baseline del respaldo. Un conjunto de copias en
caliente de varios servicios no garantiza una única transacción global ni RPO cero. Mantener
el staging anterior y sus puntos de recuperación hasta completar la aceptación.

## Descargar y verificar sin detener servicios

Descargar solo el asset cifrado y SHA256SUMS de
[v0.1.181](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.181)
en un directorio privado nuevo; comprobar las [huellas](release-0.1.181.md). Recuperar la identidad
age del gestor autorizado, nunca de GitHub ni del historial del shell. Descifrar hacia otro
directorio nuevo; tras verificar el TAR, retirar solo la identidad temporal, sin tocar auto-unseal.

Antes de extraer, rechazar rutas absolutas, segmentos .., duplicados, enlaces y tipos especiales.
La raíz única release-0.1.181 contiene 49 archivos regulares planos, incluido SHA256SUMS.
Comprobar todos los hashes internos y el orquestador antes de ejecutarlo. No sobrescribir
el staging anterior ni reemplazar todavía el instalador activo.

Ejemplo después de completar esas comprobaciones:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.181
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" preflight --staging-root "$SOC_RELEASE"
```

En topología distribuida, actualizar primero el agente del Manager remoto al wheel 0.1.130
de esta release, usando el flujo existente y conservando mTLS/identidades. Si Manager y runtime
están colocados, el instalador reconcilia el agente. No renovar claves/certificados para eludir
fallas de versión o de Compose.

## Actualización en una ventana

Después del respaldo, baseline, preflight y agente verificados:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.181
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" upgrade --staging-root "$SOC_RELEASE"
sudo /usr/local/sbin/soc-operations-install status
```

Puede haber interrupciones breves al recrear servicios. Las migraciones b7c2d891e640 y
c8d3e902f751 añaden lecturas externas de tecnologías y tablas de conectividad. El historial
es prospectivo; no reconstruye desconexiones anteriores al primer sondeo.

## Aceptación y retención

- Exigir versiones y esquema objetivo, pasos completos, salida sin errores y readiness;
  un marcador complete aislado no sustituye la reconciliación efectiva.
- Comprobar servicios, agente mTLS, misma cuenta protegida, huella auto-unseal y conteos
  frente al baseline inmediato. Investigar disminuciones; los conteos no prueban integridad total.
- Probar API autenticada con mínimos alcances: metrics:read, customers:read y technologies:read
  según la consulta. Las claves existentes no reciben permisos nuevos automáticamente.
- Probar navegador, cambio de tenant en Usuarios, tecnologías activas/deshabilitadas, reportes
  Word/Excel y eliminación autorizada. Revisar observaciones reales del primer sondeo.
- Conservar versión vigente, previa y respaldos/custodias asociados. Antes de limpiar,
  inventariar rutas, referencias de staging y montajes. No borrar una copia solo por su número
  ni eliminar volúmenes, directorios activos, claves operativas o puntos de recuperación necesarios.

Si falla, conservar estado y logs privados. No reintentar a ciegas, hacer downgrade ni restaurar
automáticamente bases, OpenBao u objetos. Publicar no ejecuta estos comandos ni elimina releases
de GitHub o paquetes del servidor.
