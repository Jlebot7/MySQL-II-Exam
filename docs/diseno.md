# Diseño de la Tabla `Auditoria_Clientes`

Este documento describe la arquitectura y las decisiones de diseño fundamentales para la implementación de la tabla `Auditoria_Clientes`, encargada de registrar el historial de modificaciones de la tabla `clientes`.

## Esquema Propuesto

```sql
CREATE TABLE Auditoria_Clientes (
    id_auditoria BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    campo_modificado VARCHAR(50) NOT NULL,
    valor_antiguo TEXT NULL,
    valor_nuevo TEXT NULL,
    fecha_modificacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    usuario_modificacion VARCHAR(255) DEFAULT (CURRENT_USER()),
    INDEX idx_auditoria_cliente_fecha (id_cliente, fecha_modificacion),
    INDEX idx_auditoria_fecha (fecha_modificacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## Decisiones de Diseño Documentadas

1. **Sin Llave Foránea (FK) desde `Auditoria_Clientes.id_cliente` a `clientes`:**
El historial de auditoría debe sobrevivir a la eliminación del cliente de la tabla original. Si existiera una llave foránea restrictiva o con borrado en cascada, perderíamos la evidencia histórica de las acciones. Para propósitos de auditoría y cumplimiento normativo (compliance), el registro histórico debe ser permanente e inmutable.

2. **Uso de `BIGINT` para `id_auditoria`:**
Las tablas de auditoría registran cada pequeño cambio (a menudo un registro por cada campo modificado), por lo que tienden a crecer exponencialmente en sistemas de alto volumen. El uso de `BIGINT` previene el agotamiento de IDs, evitando fallos catastróficos o complejas migraciones a futuro.

3. **`VARCHAR(50)` vs `ENUM` para `campo_modificado`:**
Aunque `ENUM` restringe los valores insertados de manera más estricta, usar `VARCHAR(50)` permite flexibilidad y expansión a futuro. Si se añaden nuevas columnas a la tabla `clientes` en el futuro, no será necesario realizar un `ALTER TABLE` bloqueante en la inmensa tabla de auditoría para añadir el nuevo campo al `ENUM`. 

4. **Tipado `TEXT` para `valor_antiguo` y `valor_nuevo`:**
Las columnas de valores deben tener capacidad para el campo más extenso posible en la tabla `clientes`. Dado que `direccion_envio` es de tipo `TEXT` y `email` es `VARCHAR(200)`, usar `TEXT` para los valores de auditoría garantiza que los datos no sean truncados.

5. **Índice Compuesto en `(id_cliente, fecha_modificacion)`:**
Optimiza el rendimiento en el caso de uso más frecuente: buscar el historial de cambios de un cliente en específico de manera cronológica (Ej. seguimiento de problemas o auditoría focalizada en un usuario).

6. **Índice Individual en `(fecha_modificacion)`:**
Proporciona alta eficiencia para consultas y reportes globales basados en tiempo (Ej. extraer todos los registros alterados en el sistema durante el último trimestre para revisión de seguridad).

7. **Columna de Trazabilidad `usuario_modificacion`:**
Se utiliza `CURRENT_USER()` como valor por defecto o mediante inserción desde el trigger. Esta columna determina qué usuario (o servicio conectado a la BD) efectuó el cambio, siendo un requisito indispensable de trazabilidad de accesos.

8. **Collation Binaria en el Trigger de Inserción:**
Dado que la base de datos utiliza la codificación `utf8mb4` con una collation insensible a acentos y mayúsculas/minúsculas (como `utf8mb4_0900_ai_ci`), una comparación directa en el trigger no detectará cambios como el paso de `Juan@x.com` a `juan@x.com` o `José` a `Jose`. Es imperativo realizar comparaciones con casteo a `BINARY` dentro de la lógica del trigger para capturar estos cambios.

9. **Exclusión de la Columna `contraseña`:**
El trigger de auditoría bajo ninguna circunstancia debe registrar cambios del campo `contraseña`. Registrar contraseñas —incluso versiones cifradas o hasheadas antiguas— en tablas planas de texto expande drásticamente el riesgo de seguridad, exponiendo credenciales a personal con acceso a registros de auditoría.

10. **Nomenclatura de la Tabla (`Auditoria_Clientes`):**
Se ha optado por Mixed Case (o PascalCase/CamelCase combinados con guiones bajos). Es de vital importancia recordar que en sistemas operativos basados en Linux, los nombres de tablas MySQL son sensibles a mayúsculas y minúsculas por defecto (`lower_case_table_names=0`). Los desarrolladores y administradores deben escribir las queries utilizando la capitalización exacta.

---

## Recomendaciones para Expansión Futura

* **Auditoría Extendida (INSERT / DELETE):**
El diseño actual se orienta a cambios en los campos (`UPDATE`). Se recomienda en una fase posterior agregar soporte para registrar quién creó el cliente y cuándo fue eliminado el registro físicamente (o lógicamente).
* **Políticas de Retención de Datos:**
Se aconseja diseñar un mecanismo automatizado (como un *Event Scheduler* o una tarea programada a nivel de servidor) que archive la información de la auditoría con más de N años de antigüedad hacia bases de datos de *Cold Storage* o almacenes de registros para liberar espacio en el disco activo.
* **Particionamiento por Fechas:**
Para asegurar un óptimo rendimiento en el futuro a pesar del crecimiento constante, se recomienda implementar el particionamiento de la tabla (`PARTITION BY RANGE`) basado en la columna `fecha_modificacion`. Esto acelerará las purgas y mejorará la velocidad de consulta en reportes mensuales o anuales.

