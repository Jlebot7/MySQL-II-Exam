USE ecommerce_db;

-- ============================================================
-- FUNCIONES DEFINIDAS POR EL USUARIO
-- ============================================================

DELIMITER $$
-- 1. Calcula el total de una venta sumando (cantidad * precio_unitario_congelado) del detalle
DROP FUNCTION IF EXISTS fn_CalcularTotalVenta$$
CREATE FUNCTION fn_CalcularTotalVenta(p_id_venta INT) RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2) DEFAULT 0.00;
    SELECT COALESCE(SUM(cantidad * precio_unitario_congelado), 0.00) INTO v_total
    FROM detalle_ventas
    WHERE id_venta = p_id_venta;
    RETURN v_total;
END$$
DELIMITER ;


DELIMITER $$
-- 2. Verifica si un producto tiene suficiente stock para la cantidad solicitada
DROP FUNCTION IF EXISTS fn_VerificarDisponibilidadStock$$
CREATE FUNCTION fn_VerificarDisponibilidadStock(p_id_producto INT, p_cantidad INT) RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_stock INT DEFAULT 0;
    SELECT stock INTO v_stock
    FROM productos
    WHERE id_producto = p_id_producto;
    
    IF v_stock >= p_cantidad THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END$$
DELIMITER ;


DELIMITER $$
-- 3. Obtiene el precio actual de un producto
DROP FUNCTION IF EXISTS fn_ObtenerPrecioProducto$$
CREATE FUNCTION fn_ObtenerPrecioProducto(p_id_producto INT) RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_precio DECIMAL(10,2) DEFAULT 0.00;
    SELECT precio INTO v_precio
    FROM productos
    WHERE id_producto = p_id_producto;
    RETURN v_precio;
END$$
DELIMITER ;


DELIMITER $$
-- 4. Calcula la edad del cliente usando su fecha de nacimiento
DROP FUNCTION IF EXISTS fn_CalcularEdadCliente$$
CREATE FUNCTION fn_CalcularEdadCliente(p_id_cliente INT) RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_edad INT DEFAULT 0;
    DECLARE v_fecha_nacimiento DATE;
    SELECT fecha_nacimiento INTO v_fecha_nacimiento
    FROM clientes
    WHERE id_cliente = p_id_cliente;
    
    IF v_fecha_nacimiento IS NOT NULL THEN
        SET v_edad = TIMESTAMPDIFF(YEAR, v_fecha_nacimiento, CURDATE());
    END IF;
    
    RETURN v_edad;
END$$
DELIMITER ;


DELIMITER $$
-- 5. Formatea el nombre completo del cliente como 'Apellido, Nombre'
DROP FUNCTION IF EXISTS fn_FormatearNombreCompleto$$
CREATE FUNCTION fn_FormatearNombreCompleto(p_id_cliente INT) RETURNS VARCHAR(255)
READS SQL DATA
BEGIN
    DECLARE v_nombre_completo VARCHAR(255);
    SELECT CONCAT(apellido, ', ', nombre) INTO v_nombre_completo
    FROM clientes
    WHERE id_cliente = p_id_cliente;
    RETURN v_nombre_completo;
END$$
DELIMITER ;


DELIMITER $$
-- 6. Retorna verdadero si la primera compra del cliente fue en los últimos 30 días
DROP FUNCTION IF EXISTS fn_EsClienteNuevo$$
CREATE FUNCTION fn_EsClienteNuevo(p_id_cliente INT) RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_primera_compra DATETIME;
    SELECT MIN(fecha_venta) INTO v_primera_compra
    FROM ventas
    WHERE id_cliente = p_id_cliente;
    
    IF v_primera_compra IS NOT NULL AND v_primera_compra >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END$$
DELIMITER ;


DELIMITER $$
-- 7. Calcula el costo de envío basado en el peso total de los productos en la venta
DROP FUNCTION IF EXISTS fn_CalcularCostoEnvio$$
CREATE FUNCTION fn_CalcularCostoEnvio(p_id_venta INT) RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_peso_total DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_costo DECIMAL(10,2) DEFAULT 0.00;
    
    SELECT COALESCE(SUM(p.peso * dv.cantidad), 0.00) INTO v_peso_total
    FROM detalle_ventas dv
    JOIN productos p ON dv.id_producto = p.id_producto
    WHERE dv.id_venta = p_id_venta;
    
    SET v_costo = 50.00 + (v_peso_total * 5.00);
    IF v_costo > 500.00 THEN
        SET v_costo = 500.00;
    END IF;
    
    RETURN v_costo;
END$$
DELIMITER ;


DELIMITER $$
-- 8. Aplica un porcentaje de descuento a un monto
DROP FUNCTION IF EXISTS fn_AplicarDescuento$$
CREATE FUNCTION fn_AplicarDescuento(p_monto DECIMAL(12,2), p_porcentaje DECIMAL(5,2)) RETURNS DECIMAL(12,2)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_resultado DECIMAL(12,2);
    IF p_porcentaje < 0.00 OR p_porcentaje > 100.00 THEN
        SET p_porcentaje = 0.00;
    END IF;
    SET v_resultado = p_monto - (p_monto * p_porcentaje / 100.00);
    RETURN v_resultado;
END$$
DELIMITER ;


DELIMITER $$
-- 9. Obtiene la fecha de la última compra del cliente
DROP FUNCTION IF EXISTS fn_ObtenerUltimaFechaCompra$$
CREATE FUNCTION fn_ObtenerUltimaFechaCompra(p_id_cliente INT) RETURNS DATETIME
READS SQL DATA
BEGIN
    DECLARE v_ultima_compra DATETIME;
    SELECT MAX(fecha_venta) INTO v_ultima_compra
    FROM ventas
    WHERE id_cliente = p_id_cliente;
    RETURN v_ultima_compra;
END$$
DELIMITER ;


DELIMITER $$
-- 10. Valida que el email tenga un formato correcto usando expresión regular
DROP FUNCTION IF EXISTS fn_ValidarFormatoEmail$$
CREATE FUNCTION fn_ValidarFormatoEmail(p_email VARCHAR(200)) RETURNS BOOLEAN
DETERMINISTIC
NO SQL
BEGIN
    IF p_email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END$$
DELIMITER ;


DELIMITER $$
-- 11. Retorna el nombre de la categoría a la que pertenece un producto
DROP FUNCTION IF EXISTS fn_ObtenerNombreCategoria$$
CREATE FUNCTION fn_ObtenerNombreCategoria(p_id_producto INT) RETURNS VARCHAR(100)
READS SQL DATA
BEGIN
    DECLARE v_nombre_categoria VARCHAR(100);
    SELECT c.nombre INTO v_nombre_categoria
    FROM productos p
    JOIN categorias c ON p.id_categoria = c.id_categoria
    WHERE p.id_producto = p_id_producto;
    RETURN v_nombre_categoria;
END$$
DELIMITER ;


DELIMITER $$
-- 12. Cuenta el total de compras completadas por un cliente excluyendo 'Cancelado' y 'Devuelto'
DROP FUNCTION IF EXISTS fn_ContarVentasCliente$$
CREATE FUNCTION fn_ContarVentasCliente(p_id_cliente INT) RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_cantidad INT DEFAULT 0;
    SELECT COUNT(*) INTO v_cantidad
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado NOT IN ('Cancelado', 'Devuelto');
    RETURN v_cantidad;
END$$
DELIMITER ;


DELIMITER $$
-- 13. Calcula los días transcurridos desde la última compra del cliente
DROP FUNCTION IF EXISTS fn_CalcularDiasDesdeUltimaCompra$$
CREATE FUNCTION fn_CalcularDiasDesdeUltimaCompra(p_id_cliente INT) RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_dias INT DEFAULT NULL;
    DECLARE v_ultima_compra DATETIME;
    
    SELECT MAX(fecha_venta) INTO v_ultima_compra
    FROM ventas
    WHERE id_cliente = p_id_cliente;
    
    IF v_ultima_compra IS NOT NULL THEN
        SET v_dias = DATEDIFF(NOW(), v_ultima_compra);
    END IF;
    
    RETURN v_dias;
END$$
DELIMITER ;


DELIMITER $$
-- 14. Asigna el nivel de lealtad basado en el total gastado
DROP FUNCTION IF EXISTS fn_DeterminarEstadoLealtad$$
CREATE FUNCTION fn_DeterminarEstadoLealtad(p_id_cliente INT) RETURNS VARCHAR(10)
READS SQL DATA
BEGIN
    DECLARE v_total_gastado DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_lealtad VARCHAR(10);
    
    SELECT COALESCE(total_gastado, 0.00) INTO v_total_gastado
    FROM clientes
    WHERE id_cliente = p_id_cliente;
    
    IF v_total_gastado > 10000.00 THEN
        SET v_lealtad = 'Oro';
    ELSEIF v_total_gastado > 5000.00 THEN
        SET v_lealtad = 'Plata';
    ELSE
        SET v_lealtad = 'Bronce';
    END IF;
    
    RETURN v_lealtad;
END$$
DELIMITER ;


DELIMITER $$
-- 15. Genera un SKU combinando las iniciales de categoría, producto y un número aleatorio
DROP FUNCTION IF EXISTS fn_GenerarSKU$$
CREATE FUNCTION fn_GenerarSKU(p_nombre_producto VARCHAR(200), p_id_categoria INT) RETURNS VARCHAR(50)
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_cat_nombre VARCHAR(100) DEFAULT '';
    DECLARE v_sku VARCHAR(50);
    
    SELECT nombre INTO v_cat_nombre
    FROM categorias
    WHERE id_categoria = p_id_categoria;
    
    SET v_sku = UPPER(CONCAT(
        LEFT(COALESCE(v_cat_nombre, 'XXX'), 3), 
        '-', 
        LEFT(p_nombre_producto, 3), 
        '-', 
        LPAD(FLOOR(RAND() * 10000), 4, '0')
    ));
    
    RETURN v_sku;
END$$
DELIMITER ;


DELIMITER $$
-- 16. Calcula el 16% de IVA sobre un monto
DROP FUNCTION IF EXISTS fn_CalcularIVA$$
CREATE FUNCTION fn_CalcularIVA(p_monto DECIMAL(12,2)) RETURNS DECIMAL(12,2)
DETERMINISTIC
NO SQL
BEGIN
    RETURN p_monto * 0.16;
END$$
DELIMITER ;


DELIMITER $$
-- 17. Suma el stock de todos los productos activos en una categoría
DROP FUNCTION IF EXISTS fn_ObtenerStockTotalPorCategoria$$
CREATE FUNCTION fn_ObtenerStockTotalPorCategoria(p_id_categoria INT) RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_total_stock INT DEFAULT 0;
    
    SELECT COALESCE(SUM(stock), 0) INTO v_total_stock
    FROM productos
    WHERE id_categoria = p_id_categoria AND activo = TRUE;
    
    RETURN v_total_stock;
END$$
DELIMITER ;


DELIMITER $$
-- 18. Estima la fecha de entrega basada en la región del cliente de la venta
DROP FUNCTION IF EXISTS fn_EstimarFechaEntrega$$
CREATE FUNCTION fn_EstimarFechaEntrega(p_id_venta INT) RETURNS DATE
READS SQL DATA
BEGIN
    DECLARE v_region VARCHAR(100);
    DECLARE v_fecha_venta DATETIME;
    DECLARE v_fecha_entrega DATE;
    
    SELECT c.region, v.fecha_venta INTO v_region, v_fecha_venta
    FROM ventas v
    JOIN clientes c ON v.id_cliente = c.id_cliente
    WHERE v.id_venta = p_id_venta;
    
    IF v_fecha_venta IS NULL THEN
        RETURN NULL;
    END IF;
    
    IF v_region = 'CDMX' THEN
        SET v_fecha_entrega = DATE_ADD(DATE(v_fecha_venta), INTERVAL 3 DAY);
    ELSEIF v_region IN ('Estado de México', 'Estado de Mexico', 'EdoMex', 'Estado de Méx.', 'Edomex') THEN
        SET v_fecha_entrega = DATE_ADD(DATE(v_fecha_venta), INTERVAL 5 DAY);
    ELSE
        SET v_fecha_entrega = DATE_ADD(DATE(v_fecha_venta), INTERVAL 7 DAY);
    END IF;
    
    RETURN v_fecha_entrega;
END$$
DELIMITER ;


DELIMITER $$
-- 19. Convierte un monto a otra moneda usando la tabla tasas_cambio
DROP FUNCTION IF EXISTS fn_ConvertirMoneda$$
CREATE FUNCTION fn_ConvertirMoneda(p_monto DECIMAL(12,2), p_moneda_destino VARCHAR(3)) RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_tasa DECIMAL(10,4) DEFAULT 1.0000;
    
    IF p_moneda_destino = 'USD' THEN
        RETURN p_monto;
    END IF;
    
    SELECT tasa INTO v_tasa
    FROM tasas_cambio
    WHERE moneda_destino = p_moneda_destino
    ORDER BY fecha_actualizacion DESC
    LIMIT 1;
    
    RETURN p_monto * v_tasa;
END$$
DELIMITER ;


DELIMITER $$
-- 20. Valida que la contraseña tenga longitud >= 8, al menos una mayúscula, una minúscula, un dígito y un carácter especial
DROP FUNCTION IF EXISTS fn_ValidarComplejidadContrasena$$
CREATE FUNCTION fn_ValidarComplejidadContrasena(p_contrasena VARCHAR(255)) RETURNS BOOLEAN
DETERMINISTIC
NO SQL
BEGIN
    IF LENGTH(p_contrasena) < 8 THEN
        RETURN FALSE;
    END IF;
    
    IF p_contrasena REGEXP BINARY '[A-Z]' AND 
       p_contrasena REGEXP BINARY '[a-z]' AND 
       p_contrasena REGEXP '[0-9]' AND 
       p_contrasena REGEXP '[^a-zA-Z0-9]' THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END$$
DELIMITER ;
