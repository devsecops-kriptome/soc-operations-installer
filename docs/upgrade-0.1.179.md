# Actualizar SOC Operations de 0.1.178 a 0.1.179

Versiones esperadas: instalador **0.1.179**, API/API externa/worker/agente **0.1.129**,
plugin **0.1.108**, build `0.1.108-technology-health-grouped-inventory-reports` y esquema
**a6d924bc7810**. Desde 0.1.178 se agregan `f3a71820c6de` y `a6d924bc7810`.
No actualizar Wazuh para aplicar esta release.

## 1. Preparación y respaldo sin detener servicios

1. Confirmar versión instalada, `phase=complete`, readiness, servicios, espacio e inodos.
   Resolver los mounts Docker reales: `/var/lib/soc-operations/reports` es una ruta dentro
   del contenedor y puede no existir en el host. No crear otra carpeta ni asumir que faltan datos.
2. Descargar el asset cifrado y SHA256SUMS de esta misma release, verificar sus hashes y
   descifrar a un directorio nuevo y privado con la identidad obtenida del canal autorizado.
   Rechazar enlaces, rutas absolutas, duplicados y `..` antes de extraer; verificar hashes internos.
3. Ejecutar el preflight desde el staging verificado sin reemplazar el instalador activo.
4. Crear un respaldo NUEVO: dump PostgreSQL legible, snapshot Raft OpenBao autorizado,
   versiones de objetos y marcadores, reportes y configuración completa. Registrar conteos,
   esquema, imágenes, volúmenes, cuenta protegida y fingerprint auto-unseal.
5. Verificar contenido y hashes; cifrar y comprobar descifrado. Custodiar auto-unseal por
   separado con otra contraseña y conservar intacta la clave operativa. No compartir tokens,
   contraseñas, identidad age ni claves en chat, Git, argumentos o registros.

Un respaldo caliente de varios componentes no garantiza un único punto transaccional ni
captura escrituras futuras. Acordar punto de recuperación, ventana y conservación de cambios
posteriores. Una copia solo local no cubre la pérdida del host; ver
[respaldo y recuperación](backup-and-restore.md).

## 2. Ventana de actualización

Evitar nuevas escrituras de usuarios y recopilar un baseline inmediatamente antes del upgrade.
En Manager remoto actualizar primero el agente mTLS a 0.1.129 con el wheel y las huellas de
esta release, siguiendo la [guía distribuida](distributed-installation.md). No mezclar wheel,
imagen, helper o ZIP de versiones diferentes.

Solo después del respaldo verificado, y adaptando la ruta al staging real:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.179
sudo bash "$SOC_RELEASE/soc-operations-install" preflight --staging-root "$SOC_RELEASE"
sudo bash "$SOC_RELEASE/soc-operations-install" upgrade --staging-root "$SOC_RELEASE"
sudo /usr/local/sbin/soc-operations-install status
```

El instalador utiliza la topología persistida y puede recrear servicios: prever una
interrupción breve. No usar instalación limpia, `apply`, inicialización de OpenBao,
`docker compose down -v` ni eliminación de datos para una actualización normal.

## 3. Aceptación

- Verificar versiones, esquema, `phase=complete`, readiness, mTLS, servicios y reinicios.
- Confirmar fingerprint auto-unseal y misma cuenta institucional protegida; comparar con
  conteos inmediatos e investigar cualquier disminución, sin asumir que un conteo prueba
  por sí solo la integridad de todos los datos.
- Recargar voluntariamente el navegador tras guardar borradores y confirmar el nuevo build.
- Validar casos por actividad, hijos compactos y detalles de eventos con paginación;
  comprobar creación manual y adjuntos autorizados sin reutilizar datos de otro tenant.
- Generar un Word y Excel de inventario en ambos modos, con ALL y grupos específicos;
  verificar las justificaciones, muestras, totales, CTI, hojas y alineación.
- Verificar Tecnologías externas con usuario autorizado y que un analista no pueda editar
  identificadores; esa consulta usa JWT interno, no la clave de la API externa.
- Consultar el [resumen de vulnerabilidades](vulnerability-summary-api.md) con la misma clave
  que tenga `vulnerabilities:read` y tenant autorizado. Hasta completar el primer corte,
  `503` con `Retry-After: 900` es esperado; comprobar avance y errores antes de aceptarlo.
  Los totales pueden incluir justificados y no deben compararse con una muestra de un reporte.
- Confirmar volumen `vulnerability-summary-data` RW en worker y RO en external-api.
  El listado `/api/v2/vulnerabilities` debe continuar funcionando en directo.

El worker revisa tareas cada cinco minutos y recopila por defecto cada 24 h tras un corte
correcto; los fallos reintentan en quince minutos preservando el último corte. Los nuevos
ledgers son derivados, no un respaldo del inventario Wazuh. Respaldar este volumen junto con
las tablas nuevas si se quiere conservar su historial al restaurar.

## Si falla

Conservar logs privados, staging, respaldos y estado. No repetir a ciegas ni restaurar o
hacer downgrade automáticamente después de migrar. Una restauración puede reemplazar datos
y perder cambios posteriores: protegerlos primero y acordar destino y punto de recuperación.
El rollback de archivos o servicios no equivale a restaurar PostgreSQL, OpenBao y objetos.
No reemplazar ni retirar la clave auto-unseal. No se promete pérdida cero ni interrupción cero.
