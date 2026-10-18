# SOC Operations 0.1.180

Correctivo del instalador, 18 de octubre de 2026. Resuelve la actualización parcial
de 0.1.179 detenida por `local SOC Compose differs from the approved artifact`.
Debe usarse tanto para recuperar ese estado como para nuevas actualizaciones desde 0.1.178.

## Versiones y compatibilidad

- Instalador 0.1.180; API, API externa, worker y agente 0.1.129.
- Plugin socOperations 0.1.108 para OSD 2.19.5 y 2.19.6.
- Esquema a6d924bc7810, sin migraciones nuevas respecto a 0.1.179.
- Wazuh 4.14.7-1/OSD 2.19.5 o Wazuh 4.14.8-1/OSD 2.19.6, AIO o distribuido con un Dashboard.

La imagen, el wheel, ambos plugins, el Compose y las dependencias son idénticos a 0.1.179.
Solo cambian `soc-operations-install` y `soc-lab-tenant-provisioner`, más sus manifiestos.
Las funciones de [0.1.179](release-0.1.179.md) se conservan. Desde 0.1.178 siguen siendo
necesarias las dos migraciones ya incluidas en 0.1.179; no realizar downgrade automático.

## Correcciones

El provisionador valida ahora la huella del Compose vigente, igual que el runtime y el
orquestador. El Compose predecesor fijado solo se admite durante la transición explícita
del instalador, con fase `upgrade_incomplete` y estado root-only validado. Un archivo
desconocido o una administración normal con el Compose antiguo sigue rechazándose.
No se desactivan validaciones de huella, TLS, permisos o custodia.

La fase `complete` se mantiene pendiente hasta terminar las reconciliaciones de agente,
identidad, provisioning y API externa, así como readiness. Un fallo posterior a la
instalación del runtime conserva la fase incompleta, aunque existan marcadores antiguos.
La cuenta institucional y su contraseña no se recrean.

## Huellas del paquete

- Asset cifrado: `ef6eea0e7bda508721c70123cc3537ad1df6e517c264eaaf47558dd57ccffa9d`.
- TAR descifrado: `eeaa44601b116d9094772d5ed151e8cfe122530e64e544cca2f2a504c12915bc`.
- SHA256SUMS público: `e6a75bd4eb9636fb2b24933e906f6bf35de533155f20e4093db36d06c2e5e976`.
- SHA256SUMS interno: `6c4215793fd2d86e400f0c47a42fcda31cd8c8a1ec7708799ccc28ab4290f407`.
- Orquestador: `2b544c61330fdffee4293aa256b8d3fa29904dcb85eeb8c06b2a6720f110b942`.
- Provisionador: `742dce414d45caa3f8d268bdfb3b952de6b9b5d4def66133a5c9e2300d08666a`.

Solo se distribuyen públicamente el asset cifrado y SHA256SUMS, con el destinatario age
autorizado existente. El TAR contiene 49 archivos regulares bajo `release-0.1.180`,
incluido su manifiesto interno; no contiene enlaces ni rutas fuera de ese directorio.

## Validación

1.187 pruebas de backend/agente/HTTP y 232 de interfaz aprobadas, sin omisiones.
Las 99 pruebas focalizadas forman parte de ese conjunto, no son un total adicional.
Incluyen el Compose actual, el predecesor permitido solo durante la transición, archivos
desconocidos y fallos posteriores en agente, identidad, provisioning, API externa y readiness.
La suite general usa PostgreSQL real aislado y transporte Wazuh controlado con datos sintéticos.

Se comprobaron sintaxis Bash, hashes cruzados, desempaque completo, 110 archivos Python del
wheel frente a fuentes y 138 comparaciones de fuentes del plugin con sus contextos de build.
Los artefactos de runtime reutilizados permanecen idénticos a los ya verificados de 0.1.179.
El descifrado con la identidad privada y la aceptación contra el entorno productivo deben
completarse en el host autorizado; las pruebas locales no sustituyen esa aceptación.

## Recuperación y conservación de datos

Seguir la [guía 0.1.180](upgrade-0.1.180.md). Conservar el respaldo existente y los logs
de 0.1.179; no modificar su staging ni parchear el helper instalado a mano.
Un respaldo anterior no contiene escrituras posteriores. Si se reutiliza, acordar ese
punto de recuperación y proteger los cambios posteriores antes de cualquier restauración.
No sustituir el Compose nuevo por el antiguo, inicializar OpenBao, borrar volúmenes ni
restaurar automáticamente. Publicar este correctivo no modifica ningún servidor.
