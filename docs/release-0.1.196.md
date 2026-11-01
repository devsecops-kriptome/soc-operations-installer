# SOC Operations 0.1.196 — 2026-11-01

Instalador: 0.1.196
API interna / API externa / worker / agente: 0.1.139
Plugin: 0.1.118
Esquema: f97dc8e12543 (sin migraciones nuevas respecto a 0.1.195).
Compatibilidad: Wazuh 4.14.7-1 / OSD 2.19.5 y Wazuh 4.14.8-1 / OSD 2.19.6.
Topologías: AIO y distribuida, conservando identidad y topología existentes.

Cambios desde 0.1.195:
- Creación automática: AND dentro de cada regla y OR entre reglas alternativas.
  Los filtros positivos delimitan el ámbito personalizado; las exclusiones no
  se eluden cayendo en la regla global genérica. Las reglas del tenant tienen
  prioridad; fuera de su ámbito se evalúan las globales personalizadas y la genérica.
  Reglas pausadas, inválidas, de otros tenants o de otro dominio no reservan alertas.
- Una regla con solo exclusiones puede reservar un ámbito amplio. Para aislar
  una familia concreta se deben incluir selectores positivos como tecnología,
  rule.id o grupos incluidos. Los datos extras y claves de agrupación no son filtros.
- El formulario permite elegir categoría fija o categoría de la alerta desencadenante.
  La categoría heredada procede del primer grupo específico de la alerta.
- MITRE mantiene el orden de técnicas y tácticas de la alerta que creó el caso,
  utilizado para seleccionar un playbook compatible del tenant o global.
  La severidad procede de rule.level: 0–6 baja, 7–11 media, 12–14 alta, 15–16 crítica.
  Alertas posteriores no sustituyen la clasificación inicial ni ediciones del analista.
- Al agrupar por mitre.id, el conjunto de técnicas determina la identidad:
  cambiar su orden no duplica el caso ni cambia la clasificación inicial.
  Se reconoce metadata anterior sin reescribir evidencia, snapshots o hashes.
- Se preservan casos manuales, terminales, ventanas, claves, deduplicación por
  origen, separación entre tenants y coordinación transaccional de configuraciones.
  Los filtros solapados conservan una selección determinista de una regla ganadora.

Conserva las funciones de 0.1.195: SLA para casos automáticos, acceso En progreso,
conversión auditada a incidente, casos relacionados, copia opcional al adjuntar a
un padre cerrado y mejoras de correo, contactos externos y recordatorios agrupados.

No reprocesa receipts históricos ni reclasifica casos existentes al actualizar.
No cambia por sí solo el estado habilitado de la API externa ni activa reglas pausadas.
Actualizar API, worker, agente y plugin juntos mediante el instalador.
La validación local no sustituye respaldo nuevo ni aceptación del servidor destino.

## Validación de esta entrega

- Backend/agente: **2695 pruebas**, sin fallos ni omisiones.
- Interfaz: **419 pruebas**, sin fallos, cancelaciones ni omisiones.
- Tipos y bundles compilados para OSD 2.19.5 y 2.19.6 exactos.
- Ruff, Mypy (142 módulos), paridad migraciones/modelos, imagen y wheel verificados.
- PostgreSQL temporal con FORCE RLS y rol sin SUPERUSER/BYPASSRLS;
  pruebas de concurrencia, deduplicación, ámbitos, ventanas y claves independientes.
- API externa real sin privilegios, raíz de solo lectura y sin red: liveness 200,
  rechazo sin clave 401 y rechazo de escrituras 405.
- ShellCheck: sin errores ni hallazgos nuevos respecto a 0.1.195.
- SAST: tres patrones medios revisados y justificados; no se ocultan ni deshabilitan.

Esto es validación local sintética. La aceptación en navegador, el SMTP real y las
integraciones Wazuh/Indexer del servidor se verifican después del upgrade controlado.

## Integridad

Los únicos assets binarios son el instalador cifrado y SHA256SUMS.
La identidad privada age se obtiene del gestor autorizado y no se publica.

| Archivo | SHA-256 |
|---|---|
| `soc-operations-0.1.196.tar.gz.age` | `a5b540cf51b95094eb14d94f4cd4e2399dae5f12c9b99a94ccc344dc6630660c` |
| `soc-operations-0.1.196.tar.gz` | `0dcc531b97d37d66d42e605e2bfaeb7611f6813fa62ee79f6595a1d3e77aafb0` |
| `SHA256SUMS` | `51feda10151bad876417cc437d0449b2e3045089356d51555899ede16cca07d7` |
| `SHA256SUMS interno` | `5459f40c23a3590b21a8ade0a56abfba4335f3e872d1477f0d84c4ae75db9247` |
| `soc-operations-install` | `ad6aabb21ddd065aa852fceaa92c93cdd4f919865b761f060221aee0470a8dbc` |

[Descargar v0.1.196](https://github.com/devsecops-kriptome/soc-operations-installer/releases/tag/v0.1.196).
