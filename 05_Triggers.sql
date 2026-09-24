-- ============================================================
-- SCRIPT DE TRIGGERS
-- Base de datos: ecommerce_db
-- ============================================================

USE ecommerce_db;

-- ============================================================
-- CREACIÓN DE TABLAS AUXILIARES (SI NO EXISTEN)
-- ============================================================

CREATE TABLE IF NOT EXISTS log_cambios_precio (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    precio_anterior DECIMAL(10,2),
    precio_nuevo DECIMAL(10,2),
    fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP,
    usuario VARCHAR(100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS log_nuevos_clientes (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    nombre_completo VARCHAR(200),
    email VARCHAR(200),
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS log_cambios_estado_pedido (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    estado_anterior VARCHAR(50),
    estado_nuevo VARCHAR(50),
    fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP,
    usuario VARCHAR(100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS alertas (
    id_alerta INT AUTO_INCREMENT PRIMARY KEY,
    tipo VARCHAR(50),
    mensaje TEXT,
    id_producto INT,
    stock_actual INT,
    fecha_alerta DATETIME DEFAULT CURRENT_TIMESTAMP,
    leida BOOLEAN DEFAULT FALSE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ventas_archivo (
    id_venta INT,
    id_cliente INT,
    fecha_venta DATETIME,
    estado VARCHAR(50),
    total DECIMAL(12,2),
    fecha_archivado DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS log_permisos (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    usuario VARCHAR(100),
    accion VARCHAR(200),
    fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- CREACIÓN DE TRIGGERS
-- ============================================================

-- 1. Trigger para registrar los cambios en el precio de los productos
DROP TRIGGER IF EXISTS trg_audit_precio_producto_after_update;
DELIMITER $$
CREATE TRIGGER trg_audit_precio_producto_after_update
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF OLD.precio != NEW.precio THEN
        INSERT INTO log_cambios_precio (id_producto, precio_anterior, precio_nuevo, fecha_cambio, usuario)
        VALUES (NEW.id_producto, OLD.precio, NEW.precio, NOW(), CURRENT_USER());
    END IF;
END $$
DELIMITER ;

-- 2. Trigger para verificar que hay suficiente stock antes de insertar un detalle de venta
DROP TRIGGER IF EXISTS trg_check_stock_before_insert_venta;
DELIMITER $$
CREATE TRIGGER trg_check_stock_before_insert_venta
BEFORE INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    DECLARE stock_actual INT;
    SELECT stock INTO stock_actual FROM productos WHERE id_producto = NEW.id_producto;
    IF stock_actual < NEW.cantidad THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente';
    END IF;
END $$
DELIMITER ;

-- 3. Trigger para descontar el stock después de insertar un detalle de venta
DROP TRIGGER IF EXISTS trg_update_stock_after_insert_venta;
DELIMITER $$
CREATE TRIGGER trg_update_stock_after_insert_venta
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE productos 
    SET stock = stock - NEW.cantidad 
    WHERE id_producto = NEW.id_producto;
END $$
DELIMITER ;

-- 4. Trigger para evitar la eliminación de una categoría si tiene productos asignados
DROP TRIGGER IF EXISTS trg_prevent_delete_categoria_with_products;
DELIMITER $$
CREATE TRIGGER trg_prevent_delete_categoria_with_products
BEFORE DELETE ON categorias
FOR EACH ROW
BEGIN
    DECLARE num_prod INT;
    SELECT COUNT(*) INTO num_prod FROM productos WHERE id_categoria = OLD.id_categoria;
    IF num_prod > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede eliminar la categoría porque tiene productos asignados';
    END IF;
END $$
DELIMITER ;

-- 5. Trigger para registrar los nuevos clientes
DROP TRIGGER IF EXISTS trg_log_new_customer_after_insert;
DELIMITER $$
CREATE TRIGGER trg_log_new_customer_after_insert
AFTER INSERT ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO log_nuevos_clientes (id_cliente, nombre_completo, email, fecha_registro)
    VALUES (NEW.id_cliente, CONCAT(NEW.nombre, ' ', NEW.apellido), NEW.email, NOW());
END $$
DELIMITER ;

-- 6. Trigger para actualizar el total gastado por un cliente después de una venta
DROP TRIGGER IF EXISTS trg_update_total_gastado_cliente;
DELIMITER $$
CREATE TRIGGER trg_update_total_gastado_cliente
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    DECLARE cliente_id INT;
    SELECT id_cliente INTO cliente_id FROM ventas WHERE id_venta = NEW.id_venta;
    UPDATE clientes 
    SET total_gastado = total_gastado + (NEW.cantidad * NEW.precio_unitario_congelado) 
    WHERE id_cliente = cliente_id;
END $$
DELIMITER ;

-- 7. Trigger para establecer la fecha de modificación del producto
DROP TRIGGER IF EXISTS trg_set_fecha_modificacion_producto;
DELIMITER $$
CREATE TRIGGER trg_set_fecha_modificacion_producto
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    SET NEW.fecha_modificacion = NOW();
END $$
DELIMITER ;

-- 8. Trigger para evitar un stock negativo
DROP TRIGGER IF EXISTS trg_prevent_negative_stock;
DELIMITER $$
CREATE TRIGGER trg_prevent_negative_stock
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock < 0 THEN 
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El stock no puede ser negativo';
    END IF;
END $$
DELIMITER ;

-- 9. Trigger para capitalizar nombres y apellidos de clientes antes de insertarlos
DROP TRIGGER IF EXISTS trg_capitalize_nombre_cliente;
DELIMITER $$
CREATE TRIGGER trg_capitalize_nombre_cliente
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    SET NEW.nombre = CONCAT(UPPER(LEFT(NEW.nombre, 1)), LOWER(SUBSTRING(NEW.nombre, 2)));
    SET NEW.apellido = CONCAT(UPPER(LEFT(NEW.apellido, 1)), LOWER(SUBSTRING(NEW.apellido, 2)));
END $$
DELIMITER ;

-- 10. Trigger para recalcular el total de la venta cuando se modifica un detalle de venta
DROP TRIGGER IF EXISTS trg_recalculate_total_venta_on_detalle_change;
DELIMITER $$
CREATE TRIGGER trg_recalculate_total_venta_on_detalle_change
AFTER UPDATE ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE ventas 
    SET total = (SELECT COALESCE(SUM(cantidad * precio_unitario_congelado), 0) FROM detalle_ventas WHERE id_venta = NEW.id_venta) 
    WHERE id_venta = NEW.id_venta;
END $$
DELIMITER ;

-- 11. Trigger para registrar el cambio de estado de un pedido
DROP TRIGGER IF EXISTS trg_log_order_status_change;
DELIMITER $$
CREATE TRIGGER trg_log_order_status_change
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF OLD.estado != NEW.estado THEN 
        INSERT INTO log_cambios_estado_pedido (id_venta, estado_anterior, estado_nuevo, fecha_cambio, usuario)
        VALUES (NEW.id_venta, OLD.estado, NEW.estado, NOW(), CURRENT_USER());
    END IF;
END $$
DELIMITER ;

-- 12. Triggers para evitar precios menores o iguales a cero en productos
DROP TRIGGER IF EXISTS trg_prevent_price_zero_or_less_insert;
DELIMITER $$
CREATE TRIGGER trg_prevent_price_zero_or_less_insert
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.precio <= 0 THEN 
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El precio no puede ser menor o igual a cero';
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_prevent_price_zero_or_less_update;
DELIMITER $$
CREATE TRIGGER trg_prevent_price_zero_or_less_update
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.precio <= 0 THEN 
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El precio no puede ser menor o igual a cero';
    END IF;
END $$
DELIMITER ;

-- 13. Trigger para enviar alerta cuando el stock es bajo
DROP TRIGGER IF EXISTS trg_send_stock_alert_on_low_stock;
DELIMITER $$
CREATE TRIGGER trg_send_stock_alert_on_low_stock
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock < NEW.umbral_minimo_stock AND NEW.stock > 0 THEN 
        INSERT INTO alertas (tipo, mensaje, id_producto, stock_actual, fecha_alerta, leida)
        VALUES ('Stock Bajo', CONCAT('El producto con ID ', NEW.id_producto, ' tiene un stock bajo.'), NEW.id_producto, NEW.stock, NOW(), FALSE);
    END IF;
END $$
DELIMITER ;

-- 14. Trigger para archivar una venta antes de eliminarla
DROP TRIGGER IF EXISTS trg_archive_deleted_venta;
DELIMITER $$
CREATE TRIGGER trg_archive_deleted_venta
BEFORE DELETE ON ventas
FOR EACH ROW
BEGIN
    INSERT INTO ventas_archivo (id_venta, id_cliente, fecha_venta, estado, total, fecha_archivado)
    VALUES (OLD.id_venta, OLD.id_cliente, OLD.fecha_venta, OLD.estado, OLD.total, NOW());
END $$
DELIMITER ;

-- 15. Triggers para validar el formato de email del cliente
DROP TRIGGER IF EXISTS trg_validate_email_format_on_customer_insert;
DELIMITER $$
CREATE TRIGGER trg_validate_email_format_on_customer_insert
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    IF NEW.email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN 
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Formato de correo electrónico no válido';
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_validate_email_format_on_customer_update;
DELIMITER $$
CREATE TRIGGER trg_validate_email_format_on_customer_update
BEFORE UPDATE ON clientes
FOR EACH ROW
BEGIN
    IF NEW.email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN 
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Formato de correo electrónico no válido';
    END IF;
END $$
DELIMITER ;

-- 16. Trigger para actualizar la fecha del último pedido de un cliente
DROP TRIGGER IF EXISTS trg_update_last_order_date_customer;
DELIMITER $$
CREATE TRIGGER trg_update_last_order_date_customer
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    UPDATE clientes 
    SET fecha_ultimo_pedido = NEW.fecha_venta 
    WHERE id_cliente = NEW.id_cliente;
END $$
DELIMITER ;

-- 17. Triggers para evitar que un cliente se refiera a sí mismo
DROP TRIGGER IF EXISTS trg_prevent_self_referral_insert;
DELIMITER $$
CREATE TRIGGER trg_prevent_self_referral_insert
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    IF NEW.id_referido IS NOT NULL AND NEW.id_referido = NEW.id_cliente THEN 
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un cliente no puede referirse a sí mismo';
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_prevent_self_referral_update;
DELIMITER $$
CREATE TRIGGER trg_prevent_self_referral_update
BEFORE UPDATE ON clientes
FOR EACH ROW
BEGIN
    IF NEW.id_referido IS NOT NULL AND NEW.id_referido = NEW.id_cliente THEN 
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un cliente no puede referirse a sí mismo';
    END IF;
END $$
DELIMITER ;

-- 18. Nota: MySQL no soporta triggers en las tablas del sistema (mysql.*).
-- A continuación se proporciona un procedimiento almacenado para registrar cambios de permisos manualmente.
DROP PROCEDURE IF EXISTS sp_log_permission_change;
DELIMITER $$
CREATE PROCEDURE sp_log_permission_change(IN p_usuario VARCHAR(100), IN p_accion VARCHAR(200))
BEGIN
    INSERT INTO log_permisos (usuario, accion, fecha_cambio)
    VALUES (p_usuario, p_accion, NOW());
END $$
DELIMITER ;

-- 19. Trigger para asignar una categoría por defecto si es nula al insertar un producto
DROP TRIGGER IF EXISTS trg_assign_default_category_on_null;
DELIMITER $$
CREATE TRIGGER trg_assign_default_category_on_null
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria IS NULL THEN 
        SET NEW.id_categoria = (SELECT id_categoria FROM categorias WHERE nombre = 'General' LIMIT 1);
    END IF;
END $$
DELIMITER ;

-- 20. Triggers para actualizar el conteo de productos en las categorías
DROP TRIGGER IF EXISTS trg_update_cat_count_after_insert_producto;
DELIMITER $$
CREATE TRIGGER trg_update_cat_count_after_insert_producto
AFTER INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria IS NOT NULL THEN
        UPDATE categorias SET num_productos = num_productos + 1 WHERE id_categoria = NEW.id_categoria;
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_update_cat_count_after_delete_producto;
DELIMITER $$
CREATE TRIGGER trg_update_cat_count_after_delete_producto
AFTER DELETE ON productos
FOR EACH ROW
BEGIN
    IF OLD.id_categoria IS NOT NULL THEN
        UPDATE categorias SET num_productos = num_productos - 1 WHERE id_categoria = OLD.id_categoria;
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_update_cat_count_after_update_producto;
DELIMITER $$
CREATE TRIGGER trg_update_cat_count_after_update_producto
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF OLD.id_categoria != NEW.id_categoria OR (OLD.id_categoria IS NULL AND NEW.id_categoria IS NOT NULL) OR (OLD.id_categoria IS NOT NULL AND NEW.id_categoria IS NULL) THEN
        IF OLD.id_categoria IS NOT NULL THEN
            UPDATE categorias SET num_productos = num_productos - 1 WHERE id_categoria = OLD.id_categoria;
        END IF;
        IF NEW.id_categoria IS NOT NULL THEN
            UPDATE categorias SET num_productos = num_productos + 1 WHERE id_categoria = NEW.id_categoria;
        END IF;
    END IF;
END $$
DELIMITER ;
