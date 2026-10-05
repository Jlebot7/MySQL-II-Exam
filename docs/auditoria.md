# Reporte de Auditoría de Código y Seguridad: `08_auditoria_clientes.sql`

**Archivo analizado:** `sql/08_auditoria_clientes.sql`  
**Documentos de referencia:** `docs/diseno.md`, `docs/evidencia_pruebas.md`  
**Veredicto final:** **APROBADO CON OBSERVACIONES**  
**Fecha de Auditoría:** 2026-10-05  

---

## 1. Resumen Ejecutivo y Matriz de Hallazgos

| Nivel de Severidad | Cantidad | Estado | Descripción Resumida |
|---|:---:|:---:|---|
| 🔴 **Crítico** | 0 | - | Sin vulnerabilidades que comprometan datos o ejecución |
| 🟠 **Alto** | 0 | - | Sin bloqueantes de seguridad o arquitectura |
| 🟡 **Medio** | 3 | Mitigado / Documentado | Exposición de PII en log, crecimiento por `TEXT`, portabilidad en mayúsculas |
| 🟢 **Bajo** | 1 | Recomendación | Ausencia de `DEFINER` explícito en la creación del trigger |

---

## 2. Evaluación Dimensional Detallada

### 2.1. Corrección Lógica
- **Detección de Falsos Positivos y Negativos:** La implementación basada en `NOT (CAST(OLD.campo AS BINARY) <=> CAST(NEW.campo AS BINARY))` es excepcionalmente precisa. Los casos de prueba 15, 16 y 17 confirman la detección exitosa de cambios sutiles (espacios finales, acentos y mayúsculas/minúsculas).
- **Manejo de Valores Nulos (NULL):** El operador *NULL-safe* (`<=>`) garantiza un tratamiento correcto de comparaciones `NULL <=> valor`, `valor <=> NULL` y `NULL <=> NULL` sin producir comportamientos inesperados, comprobado por los casos de prueba 7 y 8.
- **Independencia en Cambios Simultáneos:** El uso de bloques `IF` independientes para cada columna evaluada (`email`, `direccion_envio`) es una decisión excelente, asegurando granularidad atómica (2 filas generadas si ambos cambian simultáneamente).

### 2.2. Seguridad y Privacidad
- **Exclusión Absoluta de Contraseña:** El diseño excluye explícitamente el campo `contraseña`, protegiendo eficazmente las credenciales del usuario de ser almacenadas o leídas en texto plano (Prueba 18).
- **Manejo de PII (Personally Identifiable Information):** Los campos `email` y `direccion_envio` constituyen PII sensible. Almacenarlos en texto plano en la tabla de auditoría expande la superficie de exposición. Es imprescindible aplicar las políticas de privilegios mínimos sugeridas en el script mediante `GRANT/REVOKE`.
- **Principio de Menor Privilegio:** Se valida positivamente la inclusión de sentencias `GRANT/REVOKE` como plantilla de endurecimiento (hardening) para roles de aplicación.

### 2.3. Integridad de Datos
- **Inmutabilidad del Log:** La ejecución `AFTER UPDATE` y la política de revocar permisos `UPDATE/DELETE` garantizan que la bitácora funcione como registro de solo anexado (*append-only*).
- **Ausencia de Foreign Key (FK):** La decisión de NO utilizar una FK restrictiva hacia la tabla `clientes` es técnicamente sólida. Permite que el historial de auditoría persista incluso si se borra el cliente de forma física (Prueba 20).
- **Consistencia Transaccional (ACID):** Soportado nativamente al usar el motor `InnoDB`. El trigger está ligado a la transacción de la actualización del cliente, por lo que el caso 11 demuestra que un `ROLLBACK` anula correctamente la inserción en el log.

### 2.4. Rendimiento e Impacto Operativo
- **Sobrecarga de UPDATE Masivo:** Cada actualización genera hasta 2 sentencias `INSERT` por fila afectada. En operaciones transaccionales muy densas, puede representar un costo de I/O medible.
- **Crecimiento de Almacenamiento:** El uso de tipo `TEXT` sin límite estricto para valores antiguos y nuevos garantiza no truncar datos (Prueba 14), pero implica un crecimiento acelerado del disco en caso de grandes volúmenes de auditoría. Se sugiere monitorear el consumo del disco.
- **Eficiencia de Índices y Particionamiento:** Los índices `(id_cliente, fecha_modificacion)` y `(fecha_modificacion)` están adecuadamente planteados para búsquedas por cliente y reportes cronológicos.

### 2.5. Compatibilidad y Portabilidad
- **Compatibilidad MySQL 8:** El uso del charset `utf8mb4` y `utf8mb4_0900_ai_ci` es el estándar oficial para MySQL 8+.
- **Nombres de Tablas (lower_case_table_names):** El script nombra la tabla de forma mixta (`Auditoria_Clientes`). Esto supone un requerimiento de consistencia entre sistemas (ej., migración de Windows a Linux) donde `lower_case_table_names=0` distingue mayúsculas.
- **Cláusula DEFINER:** Se recomienda en producción especificar un `DEFINER` explícito (ej. `DEFINER='admin'@'localhost'`) para evitar heredar el usuario de conexión temporal.

### 2.6. Calidad de Código y Estilo
- **Nombres Estándar:** Convenciones legibles y fácilmente comprensibles.
- **Cobertura de Comentarios:** Excelente justificación técnica en el encabezado y en línea con el código. Las decisiones de diseño están completamente sustentadas.
- **Idempotencia:** El script utiliza correctos mecanismos defensivos (`IF NOT EXISTS`, `DROP TRIGGER IF EXISTS`), facilitando un despliegue sin conflictos en diferentes entornos.

---

## 3. Detalle de Observaciones (Severidad Media y Baja)

### Hallazgo M-01: Exposición de PII en Bitácora (Media)
- **Impacto:** La tabla contiene correos y direcciones de envío en texto claro.
- **Mitigación:** Aplicar rigurosamente permisos de acceso donde solo roles de auditoría puedan consultar `Auditoria_Clientes`. La aplicación regular solo debe tener permisos para disparar el trigger.

### Hallazgo M-02: Sensibilidad de Mayúsculas en Nombres de Tabla (Media)
- **Impacto:** En Linux, `Auditoria_Clientes` != `auditoria_clientes`.
- **Mitigación:** Documentar formalmente en el `README.md` que la tabla se llama `Auditoria_Clientes` y que las consultas deben respetar la capitalización exacta.

### Hallazgo M-03: Crecimiento de Espacio en Disco por Duplicación TEXT (Media)
- **Impacto:** Direcciones extensas generan duplicados de hasta varios kilobytes por modificación.
- **Mitigación:** Implementar una política de retención y particionamiento por rangos de fecha (`PARTITION BY RANGE (TO_DAYS(fecha_modificacion))`) para purga ágil en el mediano plazo.

### Hallazgo B-01: Ausencia de DEFINER Explícito (Baja)
- **Impacto:** El trigger adopta el usuario creador de la sesión.
- **Mitigación:** Definir un usuario de servicio administrativo seguro al desplegar en producción.

---

## 4. Veredicto Final

**ESTADO: APROBADO CON OBSERVACIONES**  
El script cumple con el 100% de los criterios funcionales, de seguridad e integridad requeridos. No existen defectos críticos o altos que impidan su despliegue.

