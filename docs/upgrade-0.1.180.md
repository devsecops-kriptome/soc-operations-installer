# Actualizar o recuperar SOC Operations con 0.1.180

Usar este correctivo si 0.1.179 se detuvo al reconciliar el agente por una huella de Compose
distinta, aunque `phase` muestre `complete` y readiness responda 200. También admite la
actualización desde 0.1.178. No repetir el paquete 0.1.179 ni realizar instalación limpia.

El objetivo es instalador 0.1.180, API/API externa/worker/agente 0.1.129, plugin 0.1.108 y
esquema a6d924bc7810. No hay nuevas migraciones respecto a 0.1.179.

## Conservar el respaldo y comprobar el estado

Conservar intactos el respaldo cifrado, sus hashes, el snapshot OpenBao, la copia separada
de auto-unseal y los logs privados del intento anterior. No publicar ni pegar secretos.
Comprobar nuevamente sus hashes y la huella de la clave operativa, sin reemplazarla.

Registrar versiones, esquema, estado de los servicios, readiness, cuenta protegida y conteos
inmediatamente antes de intervenir. El respaldo anterior sigue siendo un punto de recuperación
anterior, no una captura del estado actual: no incluye las escrituras posteriores. Preparar
un checkpoint actualizado si esas escrituras deben poder recuperarse. Si se acepta reutilizar
la copia existente, registrar expresamente ese límite y no prometer recuperación sin pérdida.
Una copia solo local no cubre la pérdida del host.

Para una recuperación parcial, comprobar que el Compose local y el del staging 0.1.179 tienen
la huella `23255542c7cfd45b1e82ba0d45efa3e0c72e875150ea0421669908176a85116c`.
Si la huella local es otra, detenerse e investigar antes de sustituir archivos.

## Descargar y preparar un staging nuevo

Descargar únicamente `soc-operations-0.1.180.tar.gz.age` y `SHA256SUMS` de
[v0.1.180](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.180).
Usar un directorio nuevo y privado, sin sobrescribir los archivos del intento anterior.
Comprobar las huellas públicas de las [notas del correctivo](release-0.1.180.md), recuperar
la identidad age del canal autorizado y descifrar a otro directorio privado nuevo.
Retirar solo la identidad temporal tras verificar el TAR; no retirar la clave operativa OpenBao.

Antes de extraer, rechazar rutas absolutas, `..`, nombres duplicados, enlaces y tipos especiales.
El único directorio raíz es `release-0.1.180`, con 49 archivos regulares planos y sin subdirectorios.
Verificar SHA256SUMS interno y la huella del orquestador antes de ejecutarlo.
Mover el resultado a un staging nuevo, por ejemplo `/root/soc-operations-release-0.1.180`.
No reemplazar todavía el instalador activo ni reutilizar el staging de 0.1.179.

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.180
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" preflight --staging-root "$SOC_RELEASE"
```

## Completar la actualización en una ventana

Evitar cambios manuales de usuarios durante la intervención y registrar un baseline inmediato
distinto al del respaldo. Puede haber una interrupción breve al recrear servicios.
En un Manager remoto, asegurar primero el agente 0.1.129; si está en el mismo host que el
runtime, el instalador lo reconcilia automáticamente. No renovar certificados ni claves para
resolver este error de Compose.

Solo después de los controles anteriores, ejecutar desde el nuevo staging:

```bash
SOC_RELEASE=/root/soc-operations-release-0.1.180
sudo env -u BASH_ENV -u ENV bash --noprofile --norc \
  "$SOC_RELEASE/soc-operations-install" upgrade --staging-root "$SOC_RELEASE"
sudo /usr/local/sbin/soc-operations-install status
```

La topología y las direcciones persistidas se conservan. Este comando instala el helper
corregido desde el paquete verificado y vuelve a reconciliar los componentes sin repetir
la ceremonia de custodia ni cambiar la contraseña institucional. Usar `upgrade`, no `apply`
ni `reconcile-external-api` desde el staging antiguo, que reinstalaría el helper defectuoso.

## Aceptación

- Confirmar instalador 0.1.180, componentes 0.1.129, plugin 0.1.108 y esquema a6d924bc7810.
- Exigir que el comando termine sin errores, todos los pasos completos y readiness 200;
  un `phase=complete` aislado del intento 0.1.179 no prueba la finalización.
- Confirmar dashboard, API externa, agente mTLS, identidad y provisioning efectivos.
- Comparar conteos con el baseline inmediato y verificar la misma cuenta protegida y
  huella auto-unseal. Investigar disminuciones; los conteos no prueban toda la integridad.
- Comprobar el volumen del consolidado RW en worker y RO en API externa, y el primer corte.
  Las consultas requieren `vulnerabilities:read`; hasta un corte válido puede haber 503.
- Probar navegador, casos/eventos y un Word/Excel real sin ampliar permisos ni aceptar
  inventarios parciales. Guardar borradores antes de recargar voluntariamente el navegador.

Si falla, conservar logs privados y estado y detenerse. No hacer downgrade, restaurar bases
ni borrar datos automáticamente después de migrar. La recuperación de archivos no sustituye
la restauración coordinada de PostgreSQL, OpenBao y objetos.
