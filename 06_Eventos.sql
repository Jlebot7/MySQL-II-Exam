USE ecommerce_db;
SET GLOBAL event_scheduler = ON;

-- ==============================================================================
-- CREACIÓN DE TABLAS AUXILIARES NECESARIAS
-- ==============================================================================

CREATE TABLE IF NOT EXISTS reporte_ventas_semanales (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    fecha_inicio DATE,
    fecha_fin DATE,
    total_ventas DECIMAL(14,2),
    num_transacciones INT,
    fecha_generacion DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS resumen_ventas_diarias (
    id_resumen INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATE NOT NULL,
    total_ventas DECIMAL(14,2),
    num_transacciones INT,
    num_productos_vendidos INT,
    fecha_generacion DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ranking_productos (
    id_ranking INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    total_vendido INT,
    ingresos_generados DECIMAL(14,2),
    posicion INT,
    fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS kpis_mensuales (
    id_kpi INT AUTO_INCREMENT PRIMARY KEY,
    anio INT,
    mes INT,
    ventas_totales DECIMAL(14,2),
    num_ventas INT,
    nuevos_clientes INT,
    ticket_promedio DECIMAL(10,2),
    margen_promedio DECIMAL(5,2),
    fecha_calculo DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS log_tamano_bd (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    nombre_tabla VARCHAR(100),
    tamano_datos_mb DECIMAL(10,2),
    tamano_indice_mb DECIMAL(10,2),
    num_filas BIGINT,
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS actividad_sospechosa (
    id_actividad INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT,
    tipo_actividad VARCHAR(100),
    descripcion TEXT,
    fecha_deteccion DATETIME DEFAULT CURRENT_TIMESTAMP,
    revisada BOOLEAN DEFAULT FALSE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS reporte_rendimiento_proveedores (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    id_proveedor INT,
    nombre_proveedor VARCHAR(150),
    total_productos INT,
    total_unidades_vendidas INT,
    ingresos_generados DECIMAL(14,2),
    mes INT,
    anio INT,
    fecha_generacion DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS nivel_lealtad_clientes (
    id_cliente INT PRIMARY KEY,
    nivel VARCHAR(50),
    fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_lealtad_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS backup_clientes (
    id_cliente INT,
    nombre VARCHAR(100),
    email VARCHAR(200),
    fecha_backup DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ==============================================================================
-- 20 EVENTOS PROGRAMADOS
-- ==============================================================================

-- 1. evt_generate_weekly_sales_report
-- Generar reporte de ventas semanales cada semana a partir del próximo lunes.
DROP EVENT IF EXISTS evt_generate_weekly_sales_report;
DELIMITER $$
CREATE EVENT evt_generate_weekly_sales_report
ON SCHEDULE EVERY 1 WEEK
STARTS CURRENT_DATE + INTERVAL (7 - WEEKDAY(CURRENT_DATE)) DAY -- Próximo lunes
ON COMPLETION PRESERVE
DO
BEGIN
    INSERT INTO reporte_ventas_semanales (fecha_inicio, fecha_fin, total_ventas, num_transacciones)
    SELECT 
        DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY),
        CURRENT_DATE,
        COALESCE(SUM(total), 0),
        COUNT(*)
    FROM ventas
    WHERE fecha_venta >= DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)
      AND fecha_venta < CURRENT_DATE;
END$$
DELIMITER ;

-- 2. evt_cleanup_temp_tables_daily
-- Limpiar tablas temporales diariamente.
DROP EVENT IF EXISTS evt_cleanup_temp_tables_daily;
DELIMITER $$
CREATE EVENT evt_cleanup_temp_tables_daily
ON SCHEDULE EVERY 1 DAY
ON COMPLETION PRESERVE
DO
BEGIN
    -- Ejemplo de limpieza de tablas usadas de forma temporal en la lógica de negocio.
    DROP TABLE IF EXISTS temp_reporte_ventas;
END$$
DELIMITER ;

-- 3. evt_archive_old_logs_monthly
-- Archivar o eliminar logs con más de 6 meses de antigüedad mensualmente.
DROP EVENT IF EXISTS evt_archive_old_logs_monthly;
DELIMITER $$
CREATE EVENT evt_archive_old_logs_monthly
ON SCHEDULE EVERY 1 MONTH
ON COMPLETION PRESERVE
DO
BEGIN
    DELETE FROM log_cambios_precio WHERE fecha_cambio < DATE_SUB(NOW(), INTERVAL 6 MONTH);
    DELETE FROM log_nuevos_clientes WHERE fecha_registro < DATE_SUB(NOW(), INTERVAL 6 MONTH);
    DELETE FROM log_cambios_estado_pedido WHERE fecha_cambio < DATE_SUB(NOW(), INTERVAL 6 MONTH);
END$$
DELIMITER ;

-- 4. evt_deactivate_expired_promotions_hourly
-- Desactivar promociones expiradas cada hora.
DROP EVENT IF EXISTS evt_deactivate_expired_promotions_hourly;
DELIMITER $$
CREATE EVENT evt_deactivate_expired_promotions_hourly
ON SCHEDULE EVERY 1 HOUR
ON COMPLETION PRESERVE
DO
BEGIN
    UPDATE promociones 
    SET activa = FALSE 
    WHERE fecha_fin < CURDATE() AND activa = TRUE;
END$$
DELIMITER ;

-- 5. evt_recalculate_customer_loyalty_tiers_nightly
-- Recalcular niveles de lealtad de clientes cada noche.
DROP EVENT IF EXISTS evt_recalculate_customer_loyalty_tiers_nightly;
DELIMITER $$
CREATE EVENT evt_recalculate_customer_loyalty_tiers_nightly
ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 2 HOUR)
ON COMPLETION PRESERVE
DO
BEGIN
    INSERT INTO nivel_lealtad_clientes (id_cliente, nivel)
    SELECT 
        id_cliente,
        CASE 
            WHEN total_gastado >= 5000 THEN 'Platino'
            WHEN total_gastado >= 2000 THEN 'Oro'
            WHEN total_gastado >= 500 THEN 'Plata'
            ELSE 'Bronce'
        END
    FROM clientes
    ON DUPLICATE KEY UPDATE nivel = VALUES(nivel);
END$$
DELIMITER ;

-- 6. evt_generate_reorder_list_daily
-- Generar alertas para productos con stock bajo el umbral, cada mañana.
DROP EVENT IF EXISTS evt_generate_reorder_list_daily;
DELIMITER $$
CREATE EVENT evt_generate_reorder_list_daily
ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 6 HOUR)
ON COMPLETION PRESERVE
DO
BEGIN
    INSERT INTO alertas (tipo, mensaje, id_producto, stock_actual)
    SELECT 
        'Reorden',
        CONCAT('El producto ', nombre, ' necesita ser reordenado.'),
        id_producto,
        stock
    FROM productos
    WHERE stock < umbral_minimo_stock;
END$$
DELIMITER ;

-- 7. evt_rebuild_indexes_weekly
-- Optimizar y analizar las tablas principales cada semana.
DROP EVENT IF EXISTS evt_rebuild_indexes_weekly;
DELIMITER $$
CREATE EVENT evt_rebuild_indexes_weekly
ON SCHEDULE EVERY 1 WEEK
ON COMPLETION PRESERVE
DO
BEGIN
    ANALYZE TABLE productos, ventas, detalle_ventas, clientes;
END$$
DELIMITER ;

-- 8. evt_suspend_inactive_accounts_quarterly
-- Suspender cuentas de clientes inactivos por más de 1 año cada trimestre.
DROP EVENT IF EXISTS evt_suspend_inactive_accounts_quarterly;
DELIMITER $$
CREATE EVENT evt_suspend_inactive_accounts_quarterly
ON SCHEDULE EVERY 3 MONTH
ON COMPLETION PRESERVE
DO
BEGIN
    UPDATE clientes 
    SET activo = FALSE 
    WHERE fecha_ultimo_pedido < DATE_SUB(NOW(), INTERVAL 1 YEAR) 
       OR (fecha_ultimo_pedido IS NULL AND fecha_registro < DATE_SUB(NOW(), INTERVAL 1 YEAR));
END$$
DELIMITER ;

-- 9. evt_aggregate_daily_sales_data
-- Agregar datos de ventas diarias al final de cada día.
DROP EVENT IF EXISTS evt_aggregate_daily_sales_data;
DELIMITER $$
CREATE EVENT evt_aggregate_daily_sales_data
ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 23 HOUR + INTERVAL 59 MINUTE)
ON COMPLETION PRESERVE
DO
BEGIN
    INSERT INTO resumen_ventas_diarias (fecha, total_ventas, num_transacciones, num_productos_vendidos)
    SELECT 
        CURRENT_DATE,
        COALESCE(SUM(v.total), 0),
        COUNT(DISTINCT v.id_venta),
        COALESCE(SUM(d.cantidad), 0)
    FROM ventas v
    LEFT JOIN detalle_ventas d ON v.id_venta = d.id_venta
    WHERE DATE(v.fecha_venta) = CURRENT_DATE;
END$$
DELIMITER ;

-- 10. evt_check_data_consistency_nightly
-- Revisar consistencia de datos (por ejemplo, ventas sin detalles) cada madrugada.
DROP EVENT IF EXISTS evt_check_data_consistency_nightly;
DELIMITER $$
CREATE EVENT evt_check_data_consistency_nightly
ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 3 HOUR)
ON COMPLETION PRESERVE
DO
BEGIN
    INSERT INTO alertas (tipo, mensaje)
    SELECT 
        'Inconsistencia',
        CONCAT('La venta ID ', v.id_venta, ' no tiene detalles registrados.')
    FROM ventas v
    LEFT JOIN detalle_ventas d ON v.id_venta = d.id_venta
    WHERE d.id_detalle IS NULL;
END$$
DELIMITER ;

-- 11. evt_send_birthday_greetings_daily
-- Generar alertas para clientes que cumplen años el día de hoy.
DROP EVENT IF EXISTS evt_send_birthday_greetings_daily;
DELIMITER $$
CREATE EVENT evt_send_birthday_greetings_daily
ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 8 HOUR)
ON COMPLETION PRESERVE
DO
BEGIN
    INSERT INTO alertas (tipo, mensaje)
    SELECT 
        'Cumpleaños',
        CONCAT('Hoy es el cumpleaños de ', nombre, ' ', apellido, ' (', email, ').')
    FROM clientes
    WHERE MONTH(fecha_nacimiento) = MONTH(CURRENT_DATE) 
      AND DAY(fecha_nacimiento) = DAY(CURRENT_DATE);
END$$
DELIMITER ;

-- 12. evt_update_product_rankings_hourly
-- Actualizar el ranking de los productos más vendidos cada hora.
DROP EVENT IF EXISTS evt_update_product_rankings_hourly;
DELIMITER $$
CREATE EVENT evt_update_product_rankings_hourly
ON SCHEDULE EVERY 1 HOUR
ON COMPLETION PRESERVE
DO
BEGIN
    TRUNCATE TABLE ranking_productos;
    
    SET @pos := 0;
    
    INSERT INTO ranking_productos (id_producto, total_vendido, ingresos_generados, posicion)
    SELECT 
        id_producto,
        total_qty,
        total_rev,
        @pos := @pos + 1
    FROM (
        SELECT 
            d.id_producto,
            SUM(d.cantidad) AS total_qty,
            SUM(d.cantidad * d.precio_unitario_congelado) AS total_rev
        FROM detalle_ventas d
        GROUP BY d.id_producto
        ORDER BY total_qty DESC
    ) AS tmp;
END$$
DELIMITER ;

-- 13. evt_backup_critical_tables_daily
-- Simular respaldo diario a tablas de backup de información crítica.
DROP EVENT IF EXISTS evt_backup_critical_tables_daily;
DELIMITER $$
CREATE EVENT evt_backup_critical_tables_daily
ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 1 HOUR)
ON COMPLETION PRESERVE
DO
BEGIN
    TRUNCATE TABLE backup_clientes;
    
    INSERT INTO backup_clientes (id_cliente, nombre, email)
    SELECT id_cliente, nombre, email FROM clientes;
END$$
DELIMITER ;

-- 14. evt_clear_abandoned_carts_daily
-- Limpiar carritos abandonados (más de 72 horas) diariamente.
DROP EVENT IF EXISTS evt_clear_abandoned_carts_daily;
DELIMITER $$
CREATE EVENT evt_clear_abandoned_carts_daily
ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 4 HOUR)
ON COMPLETION PRESERVE
DO
BEGIN
    DELETE FROM carritos 
    WHERE completado = FALSE 
      AND fecha_agregado < DATE_SUB(NOW(), INTERVAL 72 HOUR);
END$$
DELIMITER ;

-- 15. evt_calculate_monthly_kpis
-- Calcular e insertar KPIs del mes anterior cada día 1 del mes.
DROP EVENT IF EXISTS evt_calculate_monthly_kpis;
DELIMITER $$
CREATE EVENT evt_calculate_monthly_kpis
ON SCHEDULE EVERY 1 MONTH STARTS CURRENT_DATE - INTERVAL DAYOFMONTH(CURRENT_DATE)-1 DAY
ON COMPLETION PRESERVE
DO
BEGIN
    DECLARE mes_ant INT;
    DECLARE anio_ant INT;
    
    SET mes_ant = MONTH(CURRENT_DATE - INTERVAL 1 MONTH);
    SET anio_ant = YEAR(CURRENT_DATE - INTERVAL 1 MONTH);
    
    INSERT INTO kpis_mensuales (anio, mes, ventas_totales, num_ventas, nuevos_clientes, ticket_promedio)
    SELECT 
        anio_ant,
        mes_ant,
        (SELECT COALESCE(SUM(total), 0) FROM ventas WHERE MONTH(fecha_venta) = mes_ant AND YEAR(fecha_venta) = anio_ant),
        (SELECT COUNT(*) FROM ventas WHERE MONTH(fecha_venta) = mes_ant AND YEAR(fecha_venta) = anio_ant),
        (SELECT COUNT(*) FROM clientes WHERE MONTH(fecha_registro) = mes_ant AND YEAR(fecha_registro) = anio_ant),
        (SELECT COALESCE(AVG(total), 0) FROM ventas WHERE MONTH(fecha_venta) = mes_ant AND YEAR(fecha_venta) = anio_ant);
END$$
DELIMITER ;

-- 16. evt_refresh_materialized_views_nightly
-- Actualizar la vista materializada simulada (resumen_ventas_diarias acumulado).
DROP EVENT IF EXISTS evt_refresh_materialized_views_nightly;
DELIMITER $$
CREATE EVENT evt_refresh_materialized_views_nightly
ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 2 HOUR + INTERVAL 30 MINUTE)
ON COMPLETION PRESERVE
DO
BEGIN
    DELETE FROM resumen_ventas_diarias WHERE fecha >= DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY);
    
    INSERT INTO resumen_ventas_diarias (fecha, total_ventas, num_transacciones, num_productos_vendidos)
    SELECT 
        DATE(v.fecha_venta),
        COALESCE(SUM(v.total), 0),
        COUNT(DISTINCT v.id_venta),
        COALESCE(SUM(d.cantidad), 0)
    FROM ventas v
    LEFT JOIN detalle_ventas d ON v.id_venta = d.id_venta
    WHERE v.fecha_venta >= DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY)
    GROUP BY DATE(v.fecha_venta);
END$$
DELIMITER ;

-- 17. evt_log_database_size_weekly
-- Registrar tamaño de las tablas de la base de datos semanalmente.
DROP EVENT IF EXISTS evt_log_database_size_weekly;
DELIMITER $$
CREATE EVENT evt_log_database_size_weekly
ON SCHEDULE EVERY 1 WEEK
ON COMPLETION PRESERVE
DO
BEGIN
    INSERT INTO log_tamano_bd (nombre_tabla, tamano_datos_mb, tamano_indice_mb, num_filas)
    SELECT 
        table_name,
        ROUND(((data_length) / 1024 / 1024), 2),
        ROUND(((index_length) / 1024 / 1024), 2),
        table_rows
    FROM information_schema.tables 
    WHERE table_schema = 'ecommerce_db';
END$$
DELIMITER ;

-- 18. evt_detect_fraudulent_activity_hourly
-- Detectar posible actividad fraudulenta cada hora (ej: múltiples órdenes canceladas).
DROP EVENT IF EXISTS evt_detect_fraudulent_activity_hourly;
DELIMITER $$
CREATE EVENT evt_detect_fraudulent_activity_hourly
ON SCHEDULE EVERY 1 HOUR
ON COMPLETION PRESERVE
DO
BEGIN
    INSERT INTO actividad_sospechosa (id_cliente, tipo_actividad, descripcion)
    SELECT 
        id_cliente,
        'Múltiples Cancelaciones',
        CONCAT('El cliente ha cancelado ', COUNT(*), ' pedidos en las últimas 24 horas.')
    FROM ventas
    WHERE estado = 'Cancelado' 
      AND fecha_venta >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
    GROUP BY id_cliente
    HAVING COUNT(*) > 5;
END$$
DELIMITER ;

-- 19. evt_generate_supplier_performance_report_monthly
-- Generar reporte de rendimiento de proveedores mensualmente.
DROP EVENT IF EXISTS evt_generate_supplier_performance_report_monthly;
DELIMITER $$
CREATE EVENT evt_generate_supplier_performance_report_monthly
ON SCHEDULE EVERY 1 MONTH STARTS CURRENT_DATE - INTERVAL DAYOFMONTH(CURRENT_DATE)-1 DAY
ON COMPLETION PRESERVE
DO
BEGIN
    DECLARE mes_ant INT;
    DECLARE anio_ant INT;
    
    SET mes_ant = MONTH(CURRENT_DATE - INTERVAL 1 MONTH);
    SET anio_ant = YEAR(CURRENT_DATE - INTERVAL 1 MONTH);

    INSERT INTO reporte_rendimiento_proveedores (id_proveedor, nombre_proveedor, total_productos, total_unidades_vendidas, ingresos_generados, mes, anio)
    SELECT 
        pr.id_proveedor,
        pr.nombre,
        COUNT(DISTINCT p.id_producto),
        COALESCE(SUM(d.cantidad), 0),
        COALESCE(SUM(d.cantidad * d.precio_unitario_congelado), 0),
        mes_ant,
        anio_ant
    FROM proveedores pr
    LEFT JOIN productos p ON pr.id_proveedor = p.id_proveedor
    LEFT JOIN detalle_ventas d ON p.id_producto = d.id_producto
    LEFT JOIN ventas v ON d.id_venta = v.id_venta AND MONTH(v.fecha_venta) = mes_ant AND YEAR(v.fecha_venta) = anio_ant
    GROUP BY pr.id_proveedor, pr.nombre;
END$$
DELIMITER ;

-- 20. evt_purge_soft_deleted_records_weekly
-- Limpiar permanentemente registros marcados para borrado suave con más de 30 días.
DROP EVENT IF EXISTS evt_purge_soft_deleted_records_weekly;
DELIMITER $$
CREATE EVENT evt_purge_soft_deleted_records_weekly
ON SCHEDULE EVERY 1 WEEK
ON COMPLETION PRESERVE
DO
BEGIN
    DELETE FROM ventas_archivo 
    WHERE fecha_archivado < DATE_SUB(NOW(), INTERVAL 30 DAY);
END$$
DELIMITER ;
