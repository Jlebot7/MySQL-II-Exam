USE ecommerce_db;

-- 1. Top 10 Productos Más Vendidos: ¿Cuáles son los 10 productos que generan más ingresos?
SELECT 
    p.id_producto,
    p.nombre,
    SUM(dv.cantidad * dv.precio_unitario_congelado) AS ingresos
FROM detalle_ventas dv
JOIN productos p ON dv.id_producto = p.id_producto
JOIN ventas v ON dv.id_venta = v.id_venta
WHERE v.estado NOT IN ('Cancelado', 'Devuelto')
GROUP BY p.id_producto, p.nombre
ORDER BY ingresos DESC
LIMIT 10;

-- 2. Productos con Bajas Ventas: ¿Cuáles son los productos en el 10% inferior de ventas?
WITH VentasProductos AS (
    SELECT 
        p.id_producto,
        p.nombre,
        COALESCE(SUM(dv.cantidad * dv.precio_unitario_congelado), 0) AS ingresos,
        NTILE(10) OVER (ORDER BY COALESCE(SUM(dv.cantidad * dv.precio_unitario_congelado), 0) ASC) as decil
    FROM productos p
    LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
    LEFT JOIN ventas v ON dv.id_venta = v.id_venta AND v.estado NOT IN ('Cancelado', 'Devuelto')
    GROUP BY p.id_producto, p.nombre
)
SELECT id_producto, nombre, ingresos
FROM VentasProductos
WHERE decil = 1;

-- 3. Clientes VIP: ¿Cuáles son los 5 clientes principales según su valor de por vida (gasto histórico total)?
SELECT 
    c.id_cliente,
    c.nombre,
    c.apellido,
    SUM(v.total) as valor_de_por_vida
FROM clientes c
JOIN ventas v ON c.id_cliente = v.id_cliente
WHERE v.estado NOT IN ('Cancelado', 'Devuelto')
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY valor_de_por_vida DESC
LIMIT 5;

-- 4. Análisis de Ventas Mensuales: ¿Cuáles son las ventas totales agrupadas por mes y año?
SELECT 
    YEAR(fecha_venta) AS anio,
    MONTH(fecha_venta) AS mes,
    SUM(total) AS ventas_totales
FROM ventas
WHERE estado NOT IN ('Cancelado', 'Devuelto')
GROUP BY YEAR(fecha_venta), MONTH(fecha_venta)
ORDER BY anio DESC, mes DESC;

-- 5. Crecimiento de Clientes: ¿Cuántos clientes nuevos se registran por trimestre?
SELECT 
    YEAR(fecha_registro) AS anio,
    QUARTER(fecha_registro) AS trimestre,
    COUNT(*) AS nuevos_clientes
FROM clientes
GROUP BY YEAR(fecha_registro), QUARTER(fecha_registro)
ORDER BY anio DESC, trimestre DESC;

-- 6. Tasa de Compra Repetida: ¿Qué porcentaje de clientes ha realizado más de una compra?
WITH ComprasPorCliente AS (
    SELECT 
        id_cliente,
        COUNT(id_venta) AS total_compras
    FROM ventas
    WHERE estado NOT IN ('Cancelado', 'Devuelto')
    GROUP BY id_cliente
)
SELECT 
    (SUM(CASE WHEN total_compras > 1 THEN 1 ELSE 0 END) / COUNT(*)) * 100 AS porcentaje_compra_repetida
FROM ComprasPorCliente;

-- 7. Productos Comprados Juntos Frecuentemente: ¿Qué pares de productos se compran frecuentemente en la misma transacción?
SELECT 
    dv1.id_producto AS producto_1,
    p1.nombre AS nombre_producto_1,
    dv2.id_producto AS producto_2,
    p2.nombre AS nombre_producto_2,
    COUNT(*) AS frecuencia
FROM detalle_ventas dv1
JOIN detalle_ventas dv2 ON dv1.id_venta = dv2.id_venta AND dv1.id_producto < dv2.id_producto
JOIN productos p1 ON dv1.id_producto = p1.id_producto
JOIN productos p2 ON dv2.id_producto = p2.id_producto
GROUP BY dv1.id_producto, p1.nombre, dv2.id_producto, p2.nombre
ORDER BY frecuencia DESC
LIMIT 10;

-- 8. Rotación de Inventario: ¿Cuál es la tasa de rotación de stock por categoría (unidades vendidas / stock promedio)?
SELECT 
    c.id_categoria,
    c.nombre AS categoria,
    COALESCE(SUM(dv.cantidad), 0) AS unidades_vendidas,
    AVG(p.stock) AS stock_promedio,
    COALESCE(SUM(dv.cantidad), 0) / NULLIF(AVG(p.stock), 0) AS tasa_rotacion
FROM categorias c
JOIN productos p ON c.id_categoria = p.id_categoria
LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
LEFT JOIN ventas v ON dv.id_venta = v.id_venta AND v.estado NOT IN ('Cancelado', 'Devuelto')
GROUP BY c.id_categoria, c.nombre;

-- 9. Productos que Necesitan Reabastecimiento: ¿Qué productos tienen un stock menor a su umbral mínimo?
SELECT 
    p.id_producto,
    p.nombre,
    p.stock AS stock_actual,
    p.umbral_minimo_stock,
    pr.nombre AS proveedor
FROM productos p
JOIN proveedores pr ON p.id_proveedor = pr.id_proveedor
WHERE p.stock < p.umbral_minimo_stock;

-- 10. Análisis de Carrito Abandonado (Simulado): ¿Qué clientes tienen artículos en carritos no completados con más de 7 días de antigüedad?
SELECT 
    ca.id_cliente,
    c.nombre,
    c.apellido,
    c.email,
    ca.id_producto,
    p.nombre AS nombre_producto,
    ca.fecha_agregado
FROM carritos ca
JOIN clientes c ON ca.id_cliente = c.id_cliente
JOIN productos p ON ca.id_producto = p.id_producto
WHERE ca.completado = FALSE
AND ca.fecha_agregado < DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY);

-- 11. Rendimiento de Proveedores: ¿Cuál es el ranking de proveedores según el volumen de ventas de sus productos?
SELECT 
    pr.id_proveedor,
    pr.nombre,
    SUM(dv.cantidad) AS volumen_ventas,
    SUM(dv.cantidad * dv.precio_unitario_congelado) AS ingresos_generados
FROM proveedores pr
JOIN productos p ON pr.id_proveedor = p.id_proveedor
JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
JOIN ventas v ON dv.id_venta = v.id_venta
WHERE v.estado NOT IN ('Cancelado', 'Devuelto')
GROUP BY pr.id_proveedor, pr.nombre
ORDER BY volumen_ventas DESC;

-- 12. Análisis Geográfico de Ventas: ¿Cuáles son las ventas agrupadas por ciudad y región del cliente?
SELECT 
    c.region,
    c.ciudad,
    COUNT(v.id_venta) AS numero_ventas,
    SUM(v.total) AS ventas_totales
FROM ventas v
JOIN clientes c ON v.id_cliente = c.id_cliente
WHERE v.estado NOT IN ('Cancelado', 'Devuelto')
GROUP BY c.region, c.ciudad
ORDER BY ventas_totales DESC;

-- 13. Ventas por Hora del Día: ¿Cuáles son las horas pico de compra?
SELECT 
    HOUR(fecha_venta) AS hora_del_dia,
    COUNT(id_venta) AS numero_de_compras,
    SUM(total) AS ingresos_totales
FROM ventas
WHERE estado NOT IN ('Cancelado', 'Devuelto')
GROUP BY HOUR(fecha_venta)
ORDER BY numero_de_compras DESC;

-- 14. Impacto de Promociones: ¿Cómo se comparan las ventas de un producto antes, durante y después de una promoción?
SELECT 
    pr.id_promocion,
    p.nombre AS producto,
    SUM(CASE WHEN v.fecha_venta < pr.fecha_inicio THEN dv.cantidad ELSE 0 END) AS ventas_antes,
    SUM(CASE WHEN v.fecha_venta BETWEEN pr.fecha_inicio AND pr.fecha_fin THEN dv.cantidad ELSE 0 END) AS ventas_durante,
    SUM(CASE WHEN v.fecha_venta > pr.fecha_fin THEN dv.cantidad ELSE 0 END) AS ventas_despues
FROM promociones pr
JOIN productos p ON pr.id_producto = p.id_producto
JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
JOIN ventas v ON dv.id_venta = v.id_venta AND v.estado NOT IN ('Cancelado', 'Devuelto')
WHERE pr.id_producto IS NOT NULL
GROUP BY pr.id_promocion, p.nombre;

-- 15. Análisis de Cohort: ¿Cuál es la retención mensual de clientes desde su primera compra?
WITH PrimeraCompra AS (
    SELECT 
        id_cliente,
        DATE_FORMAT(MIN(fecha_venta), '%Y-%m-01') AS mes_cohorte
    FROM ventas
    WHERE estado NOT IN ('Cancelado', 'Devuelto')
    GROUP BY id_cliente
),
VentasMensuales AS (
    SELECT 
        v.id_cliente,
        DATE_FORMAT(v.fecha_venta, '%Y-%m-01') AS mes_venta
    FROM ventas v
    WHERE v.estado NOT IN ('Cancelado', 'Devuelto')
)
SELECT 
    p.mes_cohorte,
    v.mes_venta,
    COUNT(DISTINCT v.id_cliente) AS clientes_activos
FROM PrimeraCompra p
JOIN VentasMensuales v ON p.id_cliente = v.id_cliente AND v.mes_venta >= p.mes_cohorte
GROUP BY p.mes_cohorte, v.mes_venta
ORDER BY p.mes_cohorte, v.mes_venta;

-- 16. Margen de Beneficio por Producto: ¿Cuál es el margen de beneficio por producto y el beneficio total?
SELECT 
    p.id_producto,
    p.nombre,
    p.precio,
    p.costo,
    ((p.precio - p.costo) / p.precio * 100) AS margen_beneficio_porcentaje,
    COALESCE(SUM(dv.cantidad), 0) AS unidades_vendidas,
    COALESCE(SUM((dv.precio_unitario_congelado - p.costo) * dv.cantidad), 0) AS beneficio_total
FROM productos p
LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
LEFT JOIN ventas v ON dv.id_venta = v.id_venta AND v.estado NOT IN ('Cancelado', 'Devuelto')
GROUP BY p.id_producto, p.nombre, p.precio, p.costo;

-- 17. Tiempo Promedio Entre Compras: ¿Cuál es el tiempo promedio entre compras por cliente?
WITH ComprasConLag AS (
    SELECT 
        id_cliente,
        fecha_venta,
        LAG(fecha_venta) OVER (PARTITION BY id_cliente ORDER BY fecha_venta) AS compra_anterior
    FROM ventas
    WHERE estado NOT IN ('Cancelado', 'Devuelto')
)
SELECT 
    id_cliente,
    AVG(DATEDIFF(fecha_venta, compra_anterior)) AS dias_promedio_entre_compras
FROM ComprasConLag
WHERE compra_anterior IS NOT NULL
GROUP BY id_cliente;

-- 18. Productos Más Vistos vs. Comprados: ¿Cómo se comparan los productos más vistos con los más comprados?
SELECT 
    p.id_producto,
    p.nombre,
    COUNT(DISTINCT vp.id_vista) AS total_vistas,
    COALESCE(SUM(dv.cantidad), 0) AS total_comprados
FROM productos p
LEFT JOIN vistas_productos vp ON p.id_producto = vp.id_producto
LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
LEFT JOIN ventas v ON dv.id_venta = v.id_venta AND v.estado NOT IN ('Cancelado', 'Devuelto')
GROUP BY p.id_producto, p.nombre
ORDER BY total_vistas DESC, total_comprados DESC;

-- 19. Segmentación de Clientes (RFM): ¿Cómo se clasifican los clientes por Recency, Frequency y Monetary?
WITH RFM_Base AS (
    SELECT 
        c.id_cliente,
        DATEDIFF(CURRENT_DATE, MAX(v.fecha_venta)) AS recency,
        COUNT(v.id_venta) AS frequency,
        SUM(v.total) AS monetary
    FROM clientes c
    JOIN ventas v ON c.id_cliente = v.id_cliente
    WHERE v.estado NOT IN ('Cancelado', 'Devuelto')
    GROUP BY c.id_cliente
)
SELECT 
    id_cliente,
    recency,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY recency ASC) AS r_score,
    NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
    NTILE(5) OVER (ORDER BY monetary DESC) AS m_score
FROM RFM_Base;

-- 20. Predicción de Demanda Simple: Proyección de ventas por categoría usando promedio móvil de 3 meses.
WITH VentasMensualesCategoria AS (
    SELECT 
        p.id_categoria,
        c.nombre AS categoria,
        YEAR(v.fecha_venta) AS anio,
        MONTH(v.fecha_venta) AS mes,
        SUM(dv.cantidad) AS cantidad_vendida
    FROM detalle_ventas dv
    JOIN productos p ON dv.id_producto = p.id_producto
    JOIN categorias c ON p.id_categoria = c.id_categoria
    JOIN ventas v ON dv.id_venta = v.id_venta
    WHERE v.estado NOT IN ('Cancelado', 'Devuelto')
    GROUP BY p.id_categoria, c.nombre, YEAR(v.fecha_venta), MONTH(v.fecha_venta)
)
SELECT 
    id_categoria,
    categoria,
    anio,
    mes,
    cantidad_vendida,
    AVG(cantidad_vendida) OVER (
        PARTITION BY id_categoria 
        ORDER BY anio, mes 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS demanda_proyectada_proximo_mes
FROM VentasMensualesCategoria;
