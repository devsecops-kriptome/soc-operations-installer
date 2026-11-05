# SOC Operations Installer 0.1.201

Fecha: 2026-11-05 (America/Lima).
API, API externa, worker y agente: 0.1.144. Plugin: 0.1.122 para OSD 2.19.5 y 2.19.6.
Esquema: f2c6a8d90173.

## Recuperación controlada de la alerta inicial

- Verifica el hash original o los formatos históricos exactos de cinco y seis
  campos, sin cambiar el recibo, el vínculo ni el snapshot original.
- Exige tenant, índice, ID y timestamp con zona horaria válidos; el timestamp
  no puede ser posterior a la creación del caso. No se consulta una alerta ajena.
- Los JSON malformados se excluyen por caso sin detener otros candidatos.
  La aplicación relee los datos actuales y rechaza sesiones con cambios pendientes.
- Requiere plan nuevo revisado, hash y cantidad exactos. Conserva RLS forzada,
  bloqueo por tenant, registros append-only, idempotencia y auditoría.
- No cambia ACK, respuesta, cierre, pausas, estado ni objetivos históricos.
  Recuperar una duración no inventa un objetivo SLA ni certifica cumplimiento.
- La migración NO recupera casos automáticamente. No existe una reparación
  automática al arrancar, leer la API o ejecutar el worker.
- Desde 0.1.199 se agregan b7d3e9f21a60 y f2c6a8d90173. Esta última amplía
  únicamente el CHECK del método histórico de seis campos, sin rellenar filas
  ni alterar las políticas RLS, los permisos o el trigger append-only.

## Vulnerabilidades

- Dashboard muestra siete días inicialmente; filtros de grupo, SO y host.
  Grupos estándar: Servers-Windows, Servers-Linux, Servers-MacOS,
  Endpoints-Windows, Endpoints-Linux y Endpoints-MacOS; se omiten los vacíos.
- Hosts usa por defecto métricas compactas del último corte confirmado,
  limitado al inventario actualmente autorizado. Expone fecha y procedencia;
  no presenta hosts pendientes como cero ni cambia silenciosamente a datos en vivo.
- Durante otra captura se mantiene el corte confirmado anterior; no se sirve
  una captura incompleta. Detalles y reportes siguen consultando el Indexer actual.
- Seis snapshots completos, capturas a las 00:00 y 12:00 America/Lima, métricas
  compactas durante 90 días de forma independiente. Los días ausentes no se inventan.
- API externa de historial con filtros y permisos del tenant. Consultar no genera
  snapshots ni concede permisos de escritura. Se mantienen los alcances existentes.

## Compatibilidad y validación

- AIO y distribuido: Wazuh 4.14.7-1 / OSD 2.19.5 o Wazuh 4.14.8-1 / OSD 2.19.6.
- 3015 pruebas backend/agente y 478 de interfaz aprobadas, sin fallos ni omisiones.
- 245 comprobaciones específicas de seguridad con solapamiento con la regresión;
  no se presentan como 245 pruebas únicas adicionales.
- Migraciones y equivalencia modelo/esquema verificadas en PostgreSQL desechable.
  Aislamiento, permisos, concurrencia, rollback y revalidación comprobados localmente.
- Imagen, wheel, migraciones, fuentes y ambos plugins verificados; Ruff y MyPy
  aprobados. ShellCheck sin errores ni hallazgos nuevos; conserva 13 hallazgos previos.
  SAST conserva tres patrones medios revisados, sin nuevos medios/altos sin revisar.
- Dos avisos de deprecación de dependencias de prueba; no son fallos de las pruebas.
- La aceptación autenticada contra el destino, Wazuh/Indexer y SMTP reales sigue
  pendiente. Publicar no instala ni repara datos productivos.
- Cifrado con el destinatario age habitual. No se usó una identidad privada;
  el operador debe verificar el descifrado con la identidad autorizada antes de instalar.

## Integridad

| Archivo | SHA-256 |
| --- | --- |
| `soc-operations-0.1.201.tar.gz.age` | `d51b9ffe1303bd6cb61b8e913150ccec6c656a84f6ef314d28b73944603627f7` |
| `soc-operations-0.1.201.tar.gz` | `20328951b25fddc3ccf56b1efc578661d7ba9b63778877c276cdaa69c3f9d5ba` |
| `SHA256SUMS` | `4bebc3c4cd4379026553621f36c6cd66318af5a52bb67766f5ba85727c65471b` |

[Actualización y aceptación](upgrade-0.1.201.md).
