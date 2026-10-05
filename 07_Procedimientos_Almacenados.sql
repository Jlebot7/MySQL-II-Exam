USE ecommerce_db;

-- =====================================================================
-- 1. sp_RealizarNuevaVenta
-- Descripción: Registra una nueva venta con sus detalles, actualiza stock y total.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_RealizarNuevaVenta;
DELIMITER $$
CREATE PROCEDURE sp_RealizarNuevaVenta(
    IN p_id_cliente INT, 
    IN p_id_sucursal INT, 
    IN p_productos JSON
)
BEGIN
    DECLARE v_id_venta INT;
    DECLARE v_total DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_id_producto INT;
    DECLARE v_cantidad INT;
    DECLARE v_precio DECIMAL(10,2);
    DECLARE v_stock INT;
    DECLARE done INT DEFAULT FALSE;
    
    -- Cursor ordenado por id_producto ASC para garantizar adquisición determinística de bloqueos (previene deadlocks)
    DECLARE cur CURSOR FOR 
        SELECT id_producto, cantidad 
        FROM JSON_TABLE(
            p_productos,
            '$[*]' COLUMNS (
                id_producto INT PATH '$.id_producto',
                cantidad INT PATH '$.cantidad'
            )
        ) AS jt
        ORDER BY id_producto ASC;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al realizar la venta. Transacción cancelada.';
    END;

    START TRANSACTION;

    INSERT INTO ventas (id_cliente, id_sucursal, estado) 
    VALUES (p_id_cliente, p_id_sucursal, 'Pendiente de Pago');
    
    SET v_id_venta = LAST_INSERT_ID();
    
    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO v_id_producto, v_cantidad;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Validar stock y obtener precio
        SELECT precio, stock INTO v_precio, v_stock 
        FROM productos 
        WHERE id_producto = v_id_producto FOR UPDATE;
        
        IF v_stock < v_cantidad THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente para uno de los productos.';
        END IF;
        
        INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado)
        VALUES (v_id_venta, v_id_producto, v_cantidad, v_precio);
        
        UPDATE productos 
        SET stock = stock - v_cantidad 
        WHERE id_producto = v_id_producto;
        
        SET v_total = v_total + (v_precio * v_cantidad);
    END LOOP;
    CLOSE cur;

    UPDATE ventas 
    SET total = v_total 
    WHERE id_venta = v_id_venta;

    COMMIT;
END $$
DELIMITER ;

-- =====================================================================
-- 2. sp_AgregarNuevoProducto
-- Descripción: Agrega un nuevo producto validando los datos de entrada.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_AgregarNuevoProducto;
DELIMITER $$
CREATE PROCEDURE sp_AgregarNuevoProducto(
    IN p_nombre VARCHAR(200), 
    IN p_descripcion TEXT, 
    IN p_precio DECIMAL(10,2), 
    IN p_costo DECIMAL(10,2), 
    IN p_stock INT, 
    IN p_sku VARCHAR(50), 
    IN p_id_categoria INT, 
    IN p_id_proveedor INT, 
    IN p_peso DECIMAL(8,2)
)
BEGIN
    IF p_precio <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El precio debe ser positivo.';
    END IF;
    IF p_costo < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El costo no puede ser negativo.';
    END IF;
    IF p_stock < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El stock no puede ser negativo.';
    END IF;

    INSERT INTO productos (nombre, descripcion, precio, costo, stock, sku, id_categoria, id_proveedor, peso)
    VALUES (p_nombre, p_descripcion, p_precio, p_costo, p_stock, p_sku, p_id_categoria, p_id_proveedor, p_peso);
END $$
DELIMITER ;

-- =====================================================================
-- 3. sp_ActualizarDireccionCliente
-- Descripción: Actualiza la dirección, ciudad y región de un cliente.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_ActualizarDireccionCliente;
DELIMITER $$
CREATE PROCEDURE sp_ActualizarDireccionCliente(
    IN p_id_cliente INT, 
    IN p_nueva_direccion TEXT, 
    IN p_nueva_ciudad VARCHAR(100), 
    IN p_nueva_region VARCHAR(100)
)
BEGIN
    UPDATE clientes 
    SET direccion_envio = p_nueva_direccion, 
        ciudad = p_nueva_ciudad, 
        region = p_nueva_region
    WHERE id_cliente = p_id_cliente;
END $$
DELIMITER ;

-- =====================================================================
-- 4. sp_ProcesarDevolucion
-- Descripción: Procesa la devolución de un producto, ajusta stock y venta.
-- =====================================================================
-- 4. sp_ProcesarDevolucion
-- Descripción: Procesa la devolución de un producto, ajusta stock y venta sin violar CHECK (cantidad > 0).
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_ProcesarDevolucion;
DELIMITER $$
CREATE PROCEDURE sp_ProcesarDevolucion(
    IN p_id_venta INT, 
    IN p_id_producto INT, 
    IN p_cantidad INT
)
BEGIN
    DECLARE v_cantidad_vendida INT;
    DECLARE v_precio_unitario DECIMAL(10,2);
    DECLARE v_total_actual DECIMAL(12,2);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al procesar la devolución.';
    END;

    IF p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad a devolver debe ser mayor a cero.';
    END IF;

    START TRANSACTION;

    SELECT cantidad, precio_unitario_congelado 
    INTO v_cantidad_vendida, v_precio_unitario 
    FROM detalle_ventas 
    WHERE id_venta = p_id_venta AND id_producto = p_id_producto
    FOR UPDATE;

    IF v_cantidad_vendida IS NULL OR v_cantidad_vendida < p_cantidad THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cantidad inválida para devolución o producto no encontrado en la venta.';
    END IF;

    -- Ajustar la línea de detalle_ventas respetando CHECK (cantidad > 0)
    -- Los triggers trg_adjust_stock_after_update_detalle / trg_restore_stock_after_delete_detalle
    -- se encargarán de restaurar el stock automáticamente de forma coherente.
    IF v_cantidad_vendida = p_cantidad THEN
        DELETE FROM detalle_ventas WHERE id_venta = p_id_venta AND id_producto = p_id_producto;
    ELSE
        UPDATE detalle_ventas 
        SET cantidad = cantidad - p_cantidad 
        WHERE id_venta = p_id_venta AND id_producto = p_id_producto;
    END IF;

    -- Descontar del total de la venta
    UPDATE ventas SET total = total - (p_cantidad * v_precio_unitario) WHERE id_venta = p_id_venta;

    SELECT total INTO v_total_actual FROM ventas WHERE id_venta = p_id_venta;
    
    IF v_total_actual <= 0 THEN
        UPDATE ventas SET total = 0.00, estado = 'Devuelto' WHERE id_venta = p_id_venta;
    END IF;

    COMMIT;
END $$
DELIMITER ;

-- =====================================================================
-- 5. sp_ObtenerHistorialComprasCliente
-- Descripción: Obtiene el historial de compras detallado de un cliente.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_ObtenerHistorialComprasCliente;
DELIMITER $$
CREATE PROCEDURE sp_ObtenerHistorialComprasCliente(IN p_id_cliente INT)
BEGIN
    SELECT v.id_venta, v.fecha_venta, v.estado, v.total, 
           dv.cantidad, dv.precio_unitario_congelado, p.nombre AS producto
    FROM ventas v
    JOIN detalle_ventas dv ON v.id_venta = dv.id_venta
    JOIN productos p ON dv.id_producto = p.id_producto
    WHERE v.id_cliente = p_id_cliente
    ORDER BY v.fecha_venta DESC;
END $$
DELIMITER ;

-- =====================================================================
-- 6. sp_AjustarNivelStock
-- Descripción: Ajusta el nivel de stock de un producto y registra alerta.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_AjustarNivelStock;
DELIMITER $$
CREATE PROCEDURE sp_AjustarNivelStock(
    IN p_id_producto INT, 
    IN p_nuevo_stock INT, 
    IN p_motivo VARCHAR(255)
)
BEGIN
    UPDATE productos SET stock = p_nuevo_stock WHERE id_producto = p_id_producto;
    
    INSERT INTO alertas (tipo, mensaje, id_producto, stock_actual)
    VALUES ('Ajuste de Stock', CONCAT('Motivo: ', p_motivo), p_id_producto, p_nuevo_stock);
END $$
DELIMITER ;

-- =====================================================================
-- 7. sp_EliminarClienteDeFormaSegura
-- Descripción: Anonimiza y desactiva un cliente de forma transaccional en lugar de borrarlo físicamente.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_EliminarClienteDeFormaSegura;
DELIMITER $$
CREATE PROCEDURE sp_EliminarClienteDeFormaSegura(IN p_id_cliente INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al anonimizar el cliente.';
    END;

    START TRANSACTION;

    UPDATE clientes 
    SET nombre = 'ELIMINADO', 
        apellido = 'ELIMINADO', 
        email = CONCAT('deleted_', id_cliente, '@removed.com'), 
        `contraseña` = '', 
        direccion_envio = NULL, 
        activo = FALSE 
    WHERE id_cliente = p_id_cliente;

    COMMIT;
END $$
DELIMITER ;

-- =====================================================================
-- 8. sp_AplicarDescuentoPorCategoria
-- Descripción: Aplica un descuento porcentual a todos los productos activos de una categoría.
-- Nota: La auditoría se delega al trigger trg_audit_precio_producto_after_update para evitar duplicados.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_AplicarDescuentoPorCategoria;
DELIMITER $$
CREATE PROCEDURE sp_AplicarDescuentoPorCategoria(
    IN p_id_categoria INT, 
    IN p_porcentaje DECIMAL(5,2)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al aplicar el descuento.';
    END;

    IF p_porcentaje <= 0.00 OR p_porcentaje > 100.00 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El porcentaje debe ser mayor a 0 y menor o igual a 100.';
    END IF;

    START TRANSACTION;

    UPDATE productos 
    SET precio = precio * (1 - p_porcentaje / 100) 
    WHERE id_categoria = p_id_categoria AND activo = TRUE;

    COMMIT;
END $$
DELIMITER ;

-- =====================================================================
-- 9. sp_GenerarReporteMensualVentas
-- Descripción: Genera un reporte completo de ventas para un mes y año específicos.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_GenerarReporteMensualVentas;
DELIMITER $$
CREATE PROCEDURE sp_GenerarReporteMensualVentas(IN p_anio INT, IN p_mes INT)
BEGIN
    -- Ventas totales y cantidad
    SELECT COUNT(*) AS num_transacciones, SUM(total) AS total_ventas, AVG(total) AS ticket_promedio
    FROM ventas 
    WHERE YEAR(fecha_venta) = p_anio AND MONTH(fecha_venta) = p_mes;
    
    -- Productos top
    SELECT p.nombre, SUM(dv.cantidad) AS cantidad_vendida
    FROM detalle_ventas dv
    JOIN ventas v ON dv.id_venta = v.id_venta
    JOIN productos p ON dv.id_producto = p.id_producto
    WHERE YEAR(v.fecha_venta) = p_anio AND MONTH(v.fecha_venta) = p_mes
    GROUP BY p.id_producto
    ORDER BY cantidad_vendida DESC
    LIMIT 10;
END $$
DELIMITER ;

-- =====================================================================
-- 10. sp_CambiarEstadoPedido
-- Descripción: Cambia el estado de una venta validando máquina de estados completa y bloqueos concurrentes.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_CambiarEstadoPedido;
DELIMITER $$
CREATE PROCEDURE sp_CambiarEstadoPedido(
    IN p_id_venta INT, 
    IN p_nuevo_estado VARCHAR(50)
)
BEGIN
    DECLARE v_estado_actual VARCHAR(50);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al cambiar estado de la venta.';
    END;

    START TRANSACTION;

    SELECT estado INTO v_estado_actual 
    FROM ventas 
    WHERE id_venta = p_id_venta 
    FOR UPDATE;
    
    IF v_estado_actual IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta especificada no existe.';
    END IF;

    -- Validaciones de máquina de estados
    IF v_estado_actual = 'Cancelado' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una venta cancelada no puede cambiar de estado.';
    END IF;
    IF v_estado_actual = 'Devuelto' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una venta devuelta no puede cambiar de estado.';
    END IF;
    IF v_estado_actual = 'Entregado' AND p_nuevo_estado != 'Devuelto' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una venta entregada solo puede pasar a estado Devuelto.';
    END IF;
    IF v_estado_actual = 'Pagado' AND p_nuevo_estado = 'Pendiente de Pago' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede revertir una venta pagada a Pendiente de Pago.';
    END IF;

    UPDATE ventas SET estado = p_nuevo_estado WHERE id_venta = p_id_venta;

    COMMIT;
END $$
DELIMITER ;

-- =====================================================================
-- 11. sp_RegistrarNuevoCliente
-- Descripción: Registra un cliente con hash en contraseña y validación de correo.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_RegistrarNuevoCliente;
DELIMITER $$
CREATE PROCEDURE sp_RegistrarNuevoCliente(
    IN p_nombre VARCHAR(100), 
    IN p_apellido VARCHAR(100), 
    IN p_email VARCHAR(200), 
    IN p_contrasena VARCHAR(255), 
    IN p_direccion TEXT, 
    IN p_ciudad VARCHAR(100), 
    IN p_region VARCHAR(100), 
    IN p_fecha_nacimiento DATE
)
BEGIN
    IF p_email NOT LIKE '%@%.%' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Formato de email inválido.';
    END IF;

    IF EXISTS (SELECT 1 FROM clientes WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El email ya está registrado.';
    END IF;

    INSERT INTO clientes (nombre, apellido, email, `contraseña`, direccion_envio, ciudad, region, fecha_nacimiento)
    VALUES (p_nombre, p_apellido, p_email, SHA2(p_contrasena, 256), p_direccion, p_ciudad, p_region, p_fecha_nacimiento);
END $$
DELIMITER ;

-- =====================================================================
-- 12. sp_ObtenerDetallesProductoCompleto
-- Descripción: Obtiene toda la información cruzada de un producto (proveedor, categoría, reseñas).
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_ObtenerDetallesProductoCompleto;
DELIMITER $$
CREATE PROCEDURE sp_ObtenerDetallesProductoCompleto(IN p_id_producto INT)
BEGIN
    SELECT p.*, c.nombre AS categoria, pr.nombre AS proveedor,
           (SELECT COUNT(*) FROM resenas WHERE id_producto = p_id_producto) AS num_resenas,
           (SELECT AVG(calificacion) FROM resenas WHERE id_producto = p_id_producto) AS calificacion_promedio
    FROM productos p
    LEFT JOIN categorias c ON p.id_categoria = c.id_categoria
    LEFT JOIN proveedores pr ON p.id_proveedor = pr.id_proveedor
    WHERE p.id_producto = p_id_producto;
END $$
DELIMITER ;

-- =====================================================================
-- 13. sp_FusionarCuentasCliente
-- Descripción: Fusiona dos cuentas de cliente transfiriendo ventas, carritos y reseñas sin violar restricciones UNIQUE.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_FusionarCuentasCliente;
DELIMITER $$
CREATE PROCEDURE sp_FusionarCuentasCliente(
    IN p_id_cliente_principal INT, 
    IN p_id_cliente_duplicado INT
)
BEGIN
    DECLARE v_total_gastado_duplicado DECIMAL(12,2);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al fusionar las cuentas.';
    END;

    START TRANSACTION;

    SELECT total_gastado INTO v_total_gastado_duplicado FROM clientes WHERE id_cliente = p_id_cliente_duplicado;

    -- Transferir ventas
    UPDATE ventas SET id_cliente = p_id_cliente_principal WHERE id_cliente = p_id_cliente_duplicado;
    
    -- Manejar carritos: eliminar del duplicado los artículos que el principal ya tenga en su carrito
    DELETE c_dup FROM carritos c_dup 
    JOIN carritos c_pri ON c_dup.id_producto = c_pri.id_producto AND c_pri.id_cliente = p_id_cliente_principal
    WHERE c_dup.id_cliente = p_id_cliente_duplicado;
    UPDATE carritos SET id_cliente = p_id_cliente_principal WHERE id_cliente = p_id_cliente_duplicado;

    -- Manejar reseñas: eliminar del duplicado las reseñas sobre productos que el principal ya reseñó
    DELETE r_dup FROM resenas r_dup 
    JOIN resenas r_pri ON r_dup.id_producto = r_pri.id_producto AND r_pri.id_cliente = p_id_cliente_principal
    WHERE r_dup.id_cliente = p_id_cliente_duplicado;
    UPDATE resenas SET id_cliente = p_id_cliente_principal WHERE id_cliente = p_id_cliente_duplicado;
    
    UPDATE clientes 
    SET total_gastado = total_gastado + IFNULL(v_total_gastado_duplicado, 0) 
    WHERE id_cliente = p_id_cliente_principal;

    CALL sp_EliminarClienteDeFormaSegura(p_id_cliente_duplicado);

    COMMIT;
END $$
DELIMITER ;

-- =====================================================================
-- 14. sp_AsignarProductoAProveedor
-- Descripción: Asigna o reasigna un producto a un proveedor.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_AsignarProductoAProveedor;
DELIMITER $$
CREATE PROCEDURE sp_AsignarProductoAProveedor(
    IN p_id_producto INT, 
    IN p_id_proveedor INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM productos WHERE id_producto = p_id_producto) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Producto no existe.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM proveedores WHERE id_proveedor = p_id_proveedor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Proveedor no existe.';
    END IF;

    UPDATE productos SET id_proveedor = p_id_proveedor WHERE id_producto = p_id_producto;
END $$
DELIMITER ;

-- =====================================================================
-- 15. sp_BuscarProductos
-- Descripción: Búsqueda dinámica de productos con filtros opcionales.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_BuscarProductos;
DELIMITER $$
CREATE PROCEDURE sp_BuscarProductos(
    IN p_nombre VARCHAR(200), 
    IN p_id_categoria INT, 
    IN p_precio_min DECIMAL(10,2), 
    IN p_precio_max DECIMAL(10,2), 
    IN p_solo_disponibles BOOLEAN
)
BEGIN
    SELECT * FROM productos
    WHERE (p_nombre IS NULL OR nombre LIKE CONCAT('%', p_nombre, '%'))
      AND (p_id_categoria IS NULL OR id_categoria = p_id_categoria)
      AND (p_precio_min IS NULL OR precio >= p_precio_min)
      AND (p_precio_max IS NULL OR precio <= p_precio_max)
      AND (p_solo_disponibles IS NULL OR p_solo_disponibles = FALSE OR stock > 0)
      AND activo = TRUE;
END $$
DELIMITER ;

-- =====================================================================
-- 16. sp_ObtenerDashboardAdmin
-- Descripción: Obtiene métricas clave para un panel de administración.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_ObtenerDashboardAdmin;
DELIMITER $$
CREATE PROCEDURE sp_ObtenerDashboardAdmin()
BEGIN
    SELECT 
        (SELECT SUM(total) FROM ventas WHERE DATE(fecha_venta) = CURDATE()) AS ventas_hoy,
        (SELECT SUM(total) FROM ventas WHERE MONTH(fecha_venta) = MONTH(CURDATE()) AND YEAR(fecha_venta) = YEAR(CURDATE())) AS ventas_mes,
        (SELECT COUNT(*) FROM clientes WHERE YEARWEEK(fecha_registro) = YEARWEEK(CURDATE())) AS nuevos_clientes_semana,
        (SELECT COUNT(*) FROM productos WHERE stock <= umbral_minimo_stock) AS productos_bajo_stock,
        (SELECT COUNT(*) FROM ventas WHERE estado = 'Pendiente de Pago') AS pedidos_pendientes;
END $$
DELIMITER ;

-- =====================================================================
-- 17. sp_ProcesarPago
-- Descripción: Valida que una venta esté pendiente, cambia su estado a Pagado y registra el pago.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_ProcesarPago;
DELIMITER $$
CREATE PROCEDURE sp_ProcesarPago(
    IN p_id_venta INT, 
    IN p_metodo_pago VARCHAR(50)
)
BEGIN
    DECLARE v_estado VARCHAR(50);
    DECLARE v_total DECIMAL(12,2);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al procesar el pago.';
    END;

    START TRANSACTION;

    SELECT estado, total INTO v_estado, v_total 
    FROM ventas 
    WHERE id_venta = p_id_venta 
    FOR UPDATE;
    
    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta especificada no existe.';
    END IF;

    IF v_estado != 'Pendiente de Pago' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta no está pendiente de pago.';
    END IF;

    UPDATE ventas SET estado = 'Pagado' WHERE id_venta = p_id_venta;
    
    -- Registrar formalmente la transacción en la tabla pagos
    INSERT INTO pagos (id_venta, metodo_pago, monto, fecha_pago)
    VALUES (p_id_venta, p_metodo_pago, v_total, NOW());

    COMMIT;
END $$
DELIMITER ;

-- =====================================================================
-- 18. sp_AnadirResenaProducto
-- Descripción: Agrega una reseña a un producto validando compra previa y rango de calificación.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_AnadirResenaProducto;
DELIMITER $$
CREATE PROCEDURE sp_AnadirResenaProducto(
    IN p_id_producto INT, 
    IN p_id_cliente INT, 
    IN p_calificacion INT, 
    IN p_comentario TEXT
)
BEGIN
    -- Validación temprana de rango de calificación
    IF p_calificacion < 1 OR p_calificacion > 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La calificación debe estar entre 1 y 5.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM detalle_ventas dv
        JOIN ventas v ON dv.id_venta = v.id_venta
        WHERE v.id_cliente = p_id_cliente AND dv.id_producto = p_id_producto
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no ha comprado este producto.';
    END IF;

    IF EXISTS (SELECT 1 FROM resenas WHERE id_producto = p_id_producto AND id_cliente = p_id_cliente) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente ya ha reseñado este producto.';
    END IF;

    INSERT INTO resenas (id_producto, id_cliente, calificacion, comentario)
    VALUES (p_id_producto, p_id_cliente, p_calificacion, p_comentario);
END $$
DELIMITER ;

-- =====================================================================
-- 19. sp_ObtenerProductosRelacionados
-- Descripción: Obtiene productos frecuentemente comprados con el producto dado.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_ObtenerProductosRelacionados;
DELIMITER $$
CREATE PROCEDURE sp_ObtenerProductosRelacionados(
    IN p_id_producto INT, 
    IN p_limite INT
)
BEGIN
    SELECT p.id_producto, p.nombre, COUNT(*) AS frecuencia
    FROM detalle_ventas dv1
    JOIN detalle_ventas dv2 ON dv1.id_venta = dv2.id_venta AND dv1.id_producto != dv2.id_producto
    JOIN productos p ON dv2.id_producto = p.id_producto
    WHERE dv1.id_producto = p_id_producto
    GROUP BY p.id_producto, p.nombre
    ORDER BY frecuencia DESC
    LIMIT p_limite;
END $$
DELIMITER ;

-- =====================================================================
-- 20. sp_MoverProductosEntreCategorias
-- Descripción: Mueve todos los productos de una categoría a otra delegando conteos a triggers.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_MoverProductosEntreCategorias;
DELIMITER $$
CREATE PROCEDURE sp_MoverProductosEntreCategorias(
    IN p_id_categoria_origen INT, 
    IN p_id_categoria_destino INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al mover productos.';
    END;

    IF NOT EXISTS (SELECT 1 FROM categorias WHERE id_categoria = p_id_categoria_origen) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Categoría origen no existe.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM categorias WHERE id_categoria = p_id_categoria_destino) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Categoría destino no existe.';
    END IF;

    START TRANSACTION;

    -- Los triggers trg_update_cat_count_after_update_producto ajustan num_productos automáticamente
    UPDATE productos SET id_categoria = p_id_categoria_destino WHERE id_categoria = p_id_categoria_origen;

    COMMIT;
END $$
DELIMITER ;
