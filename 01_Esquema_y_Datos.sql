-- ============================================================
-- 01_Esquema_y_Datos.sql
-- Creación de la base de datos ecommerce_db y carga de datos iniciales
-- ============================================================

-- 1. Base de datos
DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce_db;

-- 2. Creación de tablas

-- TABLAS INDEPENDIENTES
CREATE TABLE categorias (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT,
    num_productos INT DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE proveedores (
    id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    email_contacto VARCHAR(200) UNIQUE,
    telefono_contacto VARCHAR(20)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sucursales (
    id_sucursal INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    direccion TEXT,
    ciudad VARCHAR(100),
    activa BOOLEAN DEFAULT TRUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA PRODUCTOS
CREATE TABLE productos (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL UNIQUE,
    descripcion TEXT,
    precio DECIMAL(10,2) NOT NULL,
    costo DECIMAL(10,2) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    sku VARCHAR(50) NOT NULL UNIQUE,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE,
    peso DECIMAL(8,2) DEFAULT 0.00,
    umbral_minimo_stock INT DEFAULT 10,
    id_categoria INT,
    id_proveedor INT,
    CONSTRAINT chk_precio_positivo CHECK (precio > 0),
    CONSTRAINT chk_costo_no_negativo CHECK (costo >= 0),
    CONSTRAINT chk_stock_no_negativo CHECK (stock >= 0),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria),
    CONSTRAINT fk_producto_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA CLIENTES
CREATE TABLE clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(200) NOT NULL UNIQUE,
    `contraseña` VARCHAR(255) NOT NULL,
    direccion_envio TEXT,
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_nacimiento DATE,
    total_gastado DECIMAL(12,2) DEFAULT 0.00,
    fecha_ultimo_pedido DATETIME,
    id_referido INT,
    ciudad VARCHAR(100),
    region VARCHAR(100),
    id_sucursal INT DEFAULT 1,
    activo BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_cliente_referido FOREIGN KEY (id_referido) REFERENCES clientes(id_cliente),
    CONSTRAINT fk_cliente_sucursal FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA VENTAS
CREATE TABLE ventas (
    id_venta INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    fecha_venta DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('Pendiente de Pago','Procesando','Enviado','Entregado','Cancelado','Pagado','Devuelto') NOT NULL DEFAULT 'Pendiente de Pago',
    total DECIMAL(12,2) DEFAULT 0.00,
    id_sucursal INT DEFAULT 1,
    CONSTRAINT fk_venta_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    CONSTRAINT fk_venta_sucursal FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal),
    INDEX idx_ventas_estado (estado),
    INDEX idx_ventas_fecha (fecha_venta),
    INDEX idx_ventas_cliente_fecha (id_cliente, fecha_venta)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA DETALLE_VENTAS
CREATE TABLE detalle_ventas (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario_congelado DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_cantidad_positiva CHECK (cantidad > 0),
    CONSTRAINT fk_detalle_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta),
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLA PAGOS (Conciliación y Registro de Transacciones)
CREATE TABLE pagos (
    id_pago INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    metodo_pago VARCHAR(50) NOT NULL,
    monto DECIMAL(12,2) NOT NULL,
    fecha_pago DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pago_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- AUXILIARY / LOG TABLES
-- ============================================================

CREATE TABLE log_cambios_precio (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    precio_anterior DECIMAL(10,2),
    precio_nuevo DECIMAL(10,2),
    fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP,
    usuario VARCHAR(100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE log_nuevos_clientes (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    nombre_completo VARCHAR(200),
    email VARCHAR(200),
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE log_cambios_estado_pedido (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    estado_anterior VARCHAR(50),
    estado_nuevo VARCHAR(50),
    fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP,
    usuario VARCHAR(100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE alertas (
    id_alerta INT AUTO_INCREMENT PRIMARY KEY,
    tipo VARCHAR(50),
    mensaje TEXT,
    id_producto INT,
    stock_actual INT,
    fecha_alerta DATETIME DEFAULT CURRENT_TIMESTAMP,
    leida BOOLEAN DEFAULT FALSE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ventas_archivo (
    id_archivo INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT,
    id_cliente INT,
    fecha_venta DATETIME,
    estado VARCHAR(50),
    total DECIMAL(12,2),
    fecha_archivado DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE carritos (
    id_carrito INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL DEFAULT 1,
    fecha_agregado DATETIME DEFAULT CURRENT_TIMESTAMP,
    completado BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_carrito_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    CONSTRAINT fk_carrito_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE promociones (
    id_promocion INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    porcentaje_descuento DECIMAL(5,2) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    codigo VARCHAR(50) UNIQUE,
    activa BOOLEAN DEFAULT TRUE,
    id_categoria INT,
    id_producto INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE resenas (
    id_resena INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    id_cliente INT NOT NULL,
    calificacion INT NOT NULL,
    comentario TEXT,
    fecha_resena DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_calificacion CHECK (calificacion BETWEEN 1 AND 5),
    CONSTRAINT fk_resena_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto),
    CONSTRAINT fk_resena_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE vistas_productos (
    id_vista INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    id_cliente INT,
    fecha_vista DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_vista_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- REPORT / SUMMARY TABLES
-- ============================================================

CREATE TABLE reporte_ventas_semanales (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    fecha_inicio DATE,
    fecha_fin DATE,
    total_ventas DECIMAL(14,2),
    num_transacciones INT,
    fecha_generacion DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE resumen_ventas_diarias (
    id_resumen INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATE NOT NULL,
    total_ventas DECIMAL(14,2),
    num_transacciones INT,
    num_productos_vendidos INT,
    fecha_generacion DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ranking_productos (
    id_ranking INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    total_vendido INT,
    ingresos_generados DECIMAL(14,2),
    posicion INT,
    fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE kpis_mensuales (
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

CREATE TABLE log_tamano_bd (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    nombre_tabla VARCHAR(100),
    tamano_datos_mb DECIMAL(10,2),
    tamano_indice_mb DECIMAL(10,2),
    num_filas BIGINT,
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE actividad_sospechosa (
    id_actividad INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT,
    tipo_actividad VARCHAR(100),
    descripcion TEXT,
    fecha_deteccion DATETIME DEFAULT CURRENT_TIMESTAMP,
    revisada BOOLEAN DEFAULT FALSE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE reporte_rendimiento_proveedores (
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

CREATE TABLE log_permisos (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    usuario VARCHAR(100),
    accion VARCHAR(200),
    fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE tasas_cambio (
    id_tasa INT AUTO_INCREMENT PRIMARY KEY,
    moneda_origen VARCHAR(3) DEFAULT 'USD',
    moneda_destino VARCHAR(3) NOT NULL,
    tasa DECIMAL(10,4) NOT NULL,
    fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE log_intentos_login (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    usuario VARCHAR(100),
    ip_origen VARCHAR(45),
    exitoso BOOLEAN,
    fecha_intento DATETIME DEFAULT CURRENT_TIMESTAMP,
    mensaje VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================
-- 3. INSERCIÓN DE DATOS
-- ============================================================

-- Categorías
INSERT INTO categorias (id_categoria, nombre, descripcion) VALUES
(1, 'Electrónica', 'Dispositivos y gadgets electrónicos'),
(2, 'Ropa', 'Prendas de vestir para todas las edades'),
(3, 'Hogar y Cocina', 'Artículos para el hogar y utensilios de cocina'),
(4, 'Deportes', 'Equipamiento y ropa deportiva'),
(5, 'Libros', 'Libros físicos y electrónicos de varios géneros'),
(6, 'Juguetes', 'Juegos y juguetes para niños'),
(7, 'Salud y Belleza', 'Productos de cuidado personal'),
(8, 'Alimentos', 'Comida empaquetada y abarrotes'),
(9, 'General', 'Categoría general por defecto');

-- Proveedores
INSERT INTO proveedores (id_proveedor, nombre, email_contacto, telefono_contacto) VALUES
(1, 'TechDistribuciones S.A.', 'contacto@techdistribuciones.com', '555-0101'),
(2, 'ModaGlobal S.R.L.', 'ventas@modaglobal.com', '555-0202'),
(3, 'HogarPlus C.A.', 'info@hogarplus.com', '555-0303'),
(4, 'DeporteMax S.A.', 'soporte@deportemax.com', '555-0404'),
(5, 'Editorial Conocimiento', 'distribucion@edconocimiento.com', '555-0505'),
(6, 'SaludVital S.A.', 'contacto@saludvital.com', '555-0606');

-- Sucursales
INSERT INTO sucursales (id_sucursal, nombre, direccion, ciudad, activa) VALUES
(1, 'Sucursal Central', 'Av. Reforma 123', 'Ciudad de México', TRUE),
(2, 'Sucursal Norte', 'Constitución 456', 'Monterrey', TRUE),
(3, 'Sucursal Sur', 'López Mateos 789', 'Guadalajara', TRUE);

-- Productos (30 productos, distribuidos, precios variados)
INSERT INTO productos (id_producto, nombre, descripcion, precio, costo, stock, sku, peso, id_categoria, id_proveedor) VALUES
(1, 'Smartphone X1', 'Teléfono inteligente de última generación', 15000.00, 10000.00, 50, 'CAT1-PROD-001', 0.20, 1, 1),
(2, 'Laptop Pro 15', 'Laptop para profesionales creativos', 25000.00, 18000.00, 30, 'CAT1-PROD-002', 1.50, 1, 1),
(3, 'Auriculares Inalámbricos', 'Con cancelación de ruido', 3000.00, 1500.00, 100, 'CAT1-PROD-003', 0.15, 1, 1),
(4, 'Camiseta Básica Blanca', 'Algodón 100%', 250.00, 100.00, 200, 'CAT2-PROD-004', 0.10, 2, 2),
(5, 'Pantalón de Mezclilla', 'Corte recto clásico', 600.00, 300.00, 150, 'CAT2-PROD-005', 0.50, 2, 2),
(6, 'Chaqueta de Invierno', 'Impermeable y térmica', 1200.00, 600.00, 40, 'CAT2-PROD-006', 1.00, 2, 2),
(7, 'Juego de Ollas', 'Acero inoxidable, 5 piezas', 1500.00, 800.00, 25, 'CAT3-PROD-007', 5.00, 3, 3),
(8, 'Licuadora de Alta Potencia', 'Ideal para smoothies', 800.00, 400.00, 8, 'CAT3-PROD-008', 2.00, 3, 3),
(9, 'Juego de Sábanas Matrimonial', 'Algodón egipcio', 900.00, 450.00, 60, 'CAT3-PROD-009', 1.20, 3, 3),
(10, 'Balón de Fútbol', 'Tamaño oficial 5', 400.00, 150.00, 120, 'CAT4-PROD-010', 0.45, 4, 4),
(11, 'Mancuernas Ajustables', 'Set de 20kg', 1200.00, 700.00, 5, 'CAT4-PROD-011', 20.00, 4, 4),
(12, 'Esterilla de Yoga', 'Antideslizante, 6mm', 350.00, 120.00, 80, 'CAT4-PROD-012', 0.80, 4, 4),
(13, 'El Quijote', 'Edición conmemorativa', 300.00, 150.00, 45, 'CAT5-PROD-013', 0.60, 5, 5),
(14, 'Cien Años de Soledad', 'Tapa blanda', 250.00, 100.00, 70, 'CAT5-PROD-014', 0.40, 5, 5),
(15, 'Programación en MySQL', 'Guía completa para desarrolladores', 500.00, 200.00, 30, 'CAT5-PROD-015', 0.90, 5, 5),
(16, 'Bloques de Construcción', 'Set de 500 piezas', 600.00, 250.00, 90, 'CAT6-PROD-016', 1.50, 6, 6),
(17, 'Muñeca de Acción', 'Figura coleccionable', 450.00, 200.00, 110, 'CAT6-PROD-017', 0.30, 6, 6),
(18, 'Juego de Mesa Familiar', 'Para 2 a 6 jugadores', 700.00, 350.00, 7, 'CAT6-PROD-018', 1.00, 6, 6),
(19, 'Crema Hidratante Facial', 'Día y noche, 50ml', 350.00, 100.00, 150, 'CAT7-PROD-019', 0.10, 7, 6),
(20, 'Shampoo Orgánico', 'Sin parabenos', 200.00, 80.00, 200, 'CAT7-PROD-020', 0.50, 7, 6),
(21, 'Perfume Floral', '100ml', 1200.00, 500.00, 40, 'CAT7-PROD-021', 0.25, 7, 6),
(22, 'Caja de Chocolates Surtidos', 'Chocolate artesanal', 300.00, 150.00, 80, 'CAT8-PROD-022', 0.30, 8, 6),
(23, 'Café Tostado en Grano', '1kg, origen Veracruz', 400.00, 200.00, 100, 'CAT8-PROD-023', 1.00, 8, 6),
(24, 'Té Verde Matcha', 'Lata 100g', 250.00, 100.00, 60, 'CAT8-PROD-024', 0.15, 8, 6),
(25, 'Smartwatch Deportivo', 'Monitor de ritmo cardíaco', 2500.00, 1200.00, 35, 'CAT1-PROD-025', 0.05, 1, 1),
(26, 'Zapatillas de Correr', 'Talla 27', 1800.00, 900.00, 4, 'CAT2-PROD-026', 0.60, 2, 2),
(27, 'Microondas', '1000W, color plata', 2200.00, 1500.00, 15, 'CAT3-PROD-027', 12.00, 3, 3),
(28, 'Bicicleta de Montaña', 'Rodada 29', 8000.00, 5000.00, 9, 'CAT4-PROD-028', 15.00, 4, 4),
(29, 'Libro de Recetas', 'Cocina mexicana', 350.00, 150.00, 40, 'CAT5-PROD-029', 0.70, 5, 5),
(30, 'Set de Maquillaje', 'Básico completo', 800.00, 300.00, 50, 'CAT7-PROD-030', 0.40, 7, 6);

-- Clientes (25 clientes)
INSERT INTO clientes (id_cliente, nombre, apellido, email, `contraseña`, direccion_envio, fecha_nacimiento, ciudad, region, id_sucursal) VALUES
(1, 'Carlos', 'García', 'carlos.garcia@email.com', SHA2('password123',256), 'Calle 1, Col Centro', '1980-05-15', 'Ciudad de México', 'CDMX', 1),
(2, 'María', 'López', 'maria.lopez@email.com', SHA2('password123',256), 'Av Revolución 45', '1992-10-20', 'Monterrey', 'Nuevo León', 2),
(3, 'Juan', 'Martínez', 'juan.martinez@email.com', SHA2('password123',256), 'Blvd Insurgentes 89', '1975-03-08', 'Guadalajara', 'Jalisco', 3),
(4, 'Ana', 'Hernández', 'ana.hernandez@email.com', SHA2('password123',256), 'Calle Flores 12', '1988-12-05', 'Puebla', 'Puebla', 1),
(5, 'Pedro', 'Díaz', 'pedro.diaz@email.com', SHA2('password123',256), 'Calle Sol 44', '1995-07-22', 'Cancún', 'Quintana Roo', 1),
(6, 'Sofía', 'Pérez', 'sofia.perez@email.com', SHA2('password123',256), 'Av Luna 99', '1985-02-14', 'Monterrey', 'Nuevo León', 2),
(7, 'Luis', 'Sánchez', 'luis.sanchez@email.com', SHA2('password123',256), 'Calle Estrella 77', '1990-09-30', 'Guadalajara', 'Jalisco', 3),
(8, 'Laura', 'Ramírez', 'laura.ramirez@email.com', SHA2('password123',256), 'Av Mar 33', '1982-11-11', 'Ciudad de México', 'CDMX', 1),
(9, 'Jorge', 'Torres', 'jorge.torres@email.com', SHA2('password123',256), 'Calle Río 22', '1978-04-25', 'Tijuana', 'Baja California', 2),
(10, 'Marta', 'Flores', 'marta.flores@email.com', SHA2('password123',256), 'Av Bosque 55', '1993-08-19', 'Mérida', 'Yucatán', 3),
(11, 'Diego', 'Rivera', 'diego.rivera@email.com', SHA2('password123',256), 'Calle Montaña 88', '1987-01-07', 'Ciudad de México', 'CDMX', 1),
(12, 'Carmen', 'Gómez', 'carmen.gomez@email.com', SHA2('password123',256), 'Av Valle 66', '1998-06-12', 'Monterrey', 'Nuevo León', 2),
(13, 'Raúl', 'Rojas', 'raul.rojas@email.com', SHA2('password123',256), 'Calle Prado 11', '1981-12-28', 'Guadalajara', 'Jalisco', 3),
(14, 'Elena', 'Cruz', 'elena.cruz@email.com', SHA2('password123',256), 'Av Costa 77', '1996-03-16', 'Querétaro', 'Querétaro', 1),
(15, 'Andrés', 'Morales', 'andres.morales@email.com', SHA2('password123',256), 'Calle Brisa 44', '1979-05-29', 'León', 'Guanajuato', 2),
(16, 'Patricia', 'Ortiz', 'patricia.ortiz@email.com', SHA2('password123',256), 'Av Viento 22', '1991-10-04', 'Toluca', 'Estado de México', 3),
(17, 'Fernando', 'Gutiérrez', 'fernando.gutierrez@email.com', SHA2('password123',256), 'Calle Nieve 55', '1984-02-18', 'Ciudad de México', 'CDMX', 1),
(18, 'Isabel', 'Chávez', 'isabel.chavez@email.com', SHA2('password123',256), 'Av Fuego 88', '1999-08-27', 'Monterrey', 'Nuevo León', 2),
(19, 'Ricardo', 'Ruiz', 'ricardo.ruiz@email.com', SHA2('password123',256), 'Calle Tierra 33', '1976-11-09', 'Guadalajara', 'Jalisco', 3),
(20, 'Teresa', 'Álvarez', 'teresa.alvarez@email.com', SHA2('password123',256), 'Av Cielo 66', '1989-04-14', 'Aguascalientes', 'Aguascalientes', 1),
(21, 'Miguel', 'Fernández', 'miguel.fernandez@email.com', SHA2('password123',256), 'Calle Rayo 99', '1994-07-02', 'Saltillo', 'Coahuila', 2),
(22, 'Lucía', 'Jiménez', 'lucia.jimenez@email.com', SHA2('password123',256), 'Av Trueno 11', '1983-09-21', 'Morelia', 'Michoacán', 3),
(23, 'Alejandro', 'Moreno', 'alejandro.moreno@email.com', SHA2('password123',256), 'Calle Hielo 44', '1997-01-30', 'Ciudad de México', 'CDMX', 1),
(24, 'Valeria', 'Muñoz', 'valeria.munoz@email.com', SHA2('password123',256), 'Av Vapor 77', '1986-06-08', 'Monterrey', 'Nuevo León', 2),
(25, 'Hugo', 'Romero', 'hugo.romero@email.com', SHA2('password123',256), 'Calle Niebla 22', '1990-12-15', 'Guadalajara', 'Jalisco', 3);

-- Add some referrals
UPDATE clientes SET id_referido = 1 WHERE id_cliente IN (4, 8);
UPDATE clientes SET id_referido = 2 WHERE id_cliente IN (6, 12);
UPDATE clientes SET id_referido = 3 WHERE id_cliente IN (7);

-- Ventas (45 ventas)
INSERT INTO ventas (id_venta, id_cliente, fecha_venta, estado, id_sucursal) VALUES
(1, 1, '2025-01-15 10:00:00', 'Pagado', 1),
(2, 2, '2025-01-20 11:30:00', 'Entregado', 2),
(3, 3, '2025-02-05 14:15:00', 'Enviado', 3),
(4, 4, '2025-02-18 09:45:00', 'Cancelado', 1),
(5, 5, '2025-03-02 16:20:00', 'Entregado', 1),
(6, 6, '2025-03-15 12:10:00', 'Pagado', 2),
(7, 7, '2025-04-10 15:30:00', 'Entregado', 3),
(8, 8, '2025-04-22 10:50:00', 'Procesando', 1),
(9, 9, '2025-05-05 13:40:00', 'Entregado', 2),
(10, 10, '2025-05-18 11:25:00', 'Pendiente de Pago', 3),
(11, 11, '2025-06-01 09:15:00', 'Entregado', 1),
(12, 12, '2025-06-14 14:55:00', 'Pagado', 2),
(13, 13, '2025-07-03 16:45:00', 'Enviado', 3),
(14, 14, '2025-07-20 10:20:00', 'Entregado', 1),
(15, 15, '2025-08-08 12:35:00', 'Cancelado', 2),
(16, 16, '2025-08-25 15:10:00', 'Entregado', 3),
(17, 17, '2025-09-10 09:50:00', 'Pagado', 1),
(18, 18, '2025-09-28 14:30:00', 'Procesando', 2),
(19, 19, '2025-10-15 11:05:00', 'Entregado', 3),
(20, 20, '2025-10-30 16:15:00', 'Pendiente de Pago', 1),
(21, 21, '2025-11-12 10:40:00', 'Entregado', 2),
(22, 22, '2025-11-25 13:25:00', 'Enviado', 3),
(23, 23, '2025-12-10 09:00:00', 'Pagado', 1),
(24, 24, '2025-12-24 15:55:00', 'Entregado', 2),
(25, 25, '2026-01-05 11:15:00', 'Cancelado', 3),
(26, 1, '2026-01-18 14:45:00', 'Entregado', 1),
(27, 2, '2026-02-02 10:30:00', 'Pagado', 2),
(28, 3, '2026-02-15 16:05:00', 'Procesando', 3),
(29, 4, '2026-03-01 09:20:00', 'Entregado', 1),
(30, 5, '2026-03-20 13:50:00', 'Pendiente de Pago', 1),
(31, 6, '2026-04-05 11:40:00', 'Entregado', 2),
(32, 7, '2026-04-18 15:25:00', 'Enviado', 3),
(33, 8, '2026-05-10 10:10:00', 'Pagado', 1),
(34, 9, '2026-05-25 14:15:00', 'Entregado', 2),
(35, 10, '2026-06-08 09:35:00', 'Cancelado', 3),
(36, 11, '2026-06-22 16:50:00', 'Entregado', 1),
(37, 12, '2026-07-05 12:05:00', 'Pagado', 2),
(38, 13, '2026-07-19 10:45:00', 'Procesando', 3),
(39, 14, '2026-08-02 15:30:00', 'Entregado', 1),
(40, 15, '2026-08-16 11:15:00', 'Pendiente de Pago', 2),
(41, 16, '2026-09-01 09:00:00', 'Entregado', 3),
(42, 17, '2026-09-05 14:20:00', 'Enviado', 1),
(43, 18, '2026-09-10 10:55:00', 'Pagado', 2),
(44, 19, '2026-09-15 16:40:00', 'Entregado', 3),
(45, 20, '2026-09-20 12:25:00', 'Procesando', 1);

-- Detalle Ventas (45 ventas, ~120 detalles)
INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado) VALUES
(1, 1, 1, 15000.00), (1, 3, 2, 3000.00),
(2, 2, 1, 25000.00), (2, 4, 3, 250.00), (2, 5, 2, 600.00),
(3, 7, 1, 1500.00), (3, 8, 1, 800.00), (3, 9, 2, 900.00),
(4, 10, 1, 400.00), (4, 11, 1, 1200.00),
(5, 13, 2, 300.00), (5, 14, 1, 250.00), (5, 15, 1, 500.00),
(6, 16, 2, 600.00), (6, 17, 3, 450.00),
(7, 19, 4, 350.00), (7, 20, 2, 200.00), (7, 21, 1, 1200.00),
(8, 22, 5, 300.00), (8, 23, 2, 400.00),
(9, 25, 1, 2500.00), (9, 26, 1, 1800.00),
(10, 28, 1, 8000.00),
(11, 29, 2, 350.00), (11, 30, 1, 800.00),
(12, 1, 2, 15000.00),
(13, 3, 1, 3000.00), (13, 6, 1, 1200.00),
(14, 9, 3, 900.00), (14, 12, 2, 350.00),
(15, 15, 1, 500.00),
(16, 18, 1, 700.00), (16, 24, 4, 250.00),
(17, 27, 1, 2200.00),
(18, 4, 5, 250.00), (18, 5, 3, 600.00),
(19, 7, 1, 1500.00), (19, 8, 1, 800.00),
(20, 10, 2, 400.00),
(21, 13, 1, 300.00), (21, 14, 1, 250.00),
(22, 16, 1, 600.00), (22, 17, 1, 450.00),
(23, 19, 2, 350.00), (23, 20, 2, 200.00),
(24, 22, 3, 300.00), (24, 23, 1, 400.00),
(25, 25, 1, 2500.00),
(26, 2, 1, 25000.00), (26, 26, 1, 1800.00),
(27, 28, 1, 8000.00), (27, 11, 1, 1200.00),
(28, 29, 1, 350.00), (28, 30, 2, 800.00),
(29, 1, 1, 15000.00), (29, 3, 1, 3000.00),
(30, 4, 2, 250.00), (30, 6, 1, 1200.00),
(31, 7, 1, 1500.00), (31, 9, 1, 900.00),
(32, 10, 3, 400.00), (32, 12, 1, 350.00),
(33, 13, 2, 300.00), (33, 15, 1, 500.00),
(34, 16, 1, 600.00), (34, 18, 1, 700.00),
(35, 19, 3, 350.00),
(36, 22, 4, 300.00), (36, 24, 2, 250.00),
(37, 25, 1, 2500.00), (37, 27, 1, 2200.00),
(38, 28, 1, 8000.00),
(39, 2, 1, 25000.00),
(40, 5, 2, 600.00), (40, 6, 2, 1200.00),
(41, 8, 1, 800.00), (41, 9, 2, 900.00),
(42, 11, 1, 1200.00), (42, 12, 2, 350.00),
(43, 14, 3, 250.00), (43, 15, 1, 500.00),
(44, 17, 2, 450.00), (44, 18, 1, 700.00),
(45, 20, 4, 200.00), (45, 21, 1, 1200.00);

-- Update Ventas Totales based on detalle_ventas
UPDATE ventas v
JOIN (
    SELECT id_venta, SUM(cantidad * precio_unitario_congelado) AS monto_total
    FROM detalle_ventas
    GROUP BY id_venta
) d ON v.id_venta = d.id_venta
SET v.total = d.monto_total;

-- Inserción de Pagos para ventas pagadas y entregadas
INSERT INTO pagos (id_venta, metodo_pago, monto, fecha_pago)
SELECT id_venta, 
       ELT(1 + (id_venta % 4), 'Tarjeta de Crédito', 'Tarjeta de Débito', 'Transferencia SPEI', 'PayPal'),
       total,
       fecha_venta
FROM ventas
WHERE estado IN ('Pagado', 'Entregado', 'Enviado');

-- Update Clientes total_gastado and fecha_ultimo_pedido (only counting valid sales: not canceled)
UPDATE clientes c
JOIN (
    SELECT id_cliente, SUM(total) as gastado, MAX(fecha_venta) as ultima_compra
    FROM ventas
    WHERE estado NOT IN ('Cancelado', 'Devuelto')
    GROUP BY id_cliente
) v ON c.id_cliente = v.id_cliente
SET c.total_gastado = v.gastado, c.fecha_ultimo_pedido = v.ultima_compra;

-- Update Categorías num_productos
UPDATE categorias c
JOIN (
    SELECT id_categoria, COUNT(*) as num_prod
    FROM productos
    GROUP BY id_categoria
) p ON c.id_categoria = p.id_categoria
SET c.num_productos = p.num_prod;

-- Carritos (15 entries)
INSERT INTO carritos (id_cliente, id_producto, cantidad, completado) VALUES
(1, 1, 1, TRUE),
(2, 3, 2, TRUE),
(3, 5, 1, FALSE),
(4, 7, 1, TRUE),
(5, 9, 3, FALSE),
(6, 11, 1, TRUE),
(7, 13, 2, FALSE),
(8, 15, 1, TRUE),
(9, 17, 4, FALSE),
(10, 19, 2, TRUE),
(11, 21, 1, FALSE),
(12, 23, 3, TRUE),
(13, 25, 1, FALSE),
(14, 27, 1, TRUE),
(15, 29, 2, FALSE);

-- Promociones (5 entries)
INSERT INTO promociones (nombre, descripcion, porcentaje_descuento, fecha_inicio, fecha_fin, codigo, activa, id_categoria) VALUES
('Verano Tech', 'Descuentos en electrónica para el verano', 15.00, '2026-06-01', '2026-08-31', 'TECHVERANO', FALSE, 1),
('Vuelta al Cole', 'Ropa con descuento para estudiantes', 20.00, '2026-08-01', '2026-09-15', 'COLE20', FALSE, 2),
('Cyber Monday', 'Ofertas en toda la tienda', 30.00, '2026-11-25', '2026-11-30', 'CYBER30', TRUE, NULL),
('Navidad Deportiva', 'Regalos para deportistas', 10.00, '2026-12-01', '2026-12-25', 'NAVIDEP10', TRUE, 4),
('Primavera Belleza', 'Cuidado personal con descuento', 25.00, '2027-03-20', '2027-04-20', 'BELLEZA25', TRUE, 7);

-- Vistas Productos (50+ entries)
INSERT INTO vistas_productos (id_producto, id_cliente, fecha_vista) VALUES
(1, 1, '2026-09-01 10:00:00'), (1, 2, '2026-09-02 11:00:00'), (1, 3, '2026-09-03 12:00:00'), (2, 4, '2026-09-04 13:00:00'),
(2, 5, '2026-09-05 14:00:00'), (3, 6, '2026-09-06 15:00:00'), (3, 7, '2026-09-07 16:00:00'), (4, 8, '2026-09-08 17:00:00'),
(5, 9, '2026-09-09 18:00:00'), (6, 10, '2026-09-10 19:00:00'), (7, 11, '2026-09-11 20:00:00'), (8, 12, '2026-09-12 09:00:00'),
(9, 13, '2026-09-13 10:00:00'), (10, 14, '2026-09-14 11:00:00'), (11, 15, '2026-09-15 12:00:00'), (12, 16, '2026-09-16 13:00:00'),
(13, 17, '2026-09-17 14:00:00'), (14, 18, '2026-09-18 15:00:00'), (15, 19, '2026-09-19 16:00:00'), (16, 20, '2026-09-20 17:00:00'),
(17, 21, '2026-09-21 18:00:00'), (18, 22, '2026-09-22 19:00:00'), (19, 23, '2026-09-23 20:00:00'), (20, 24, '2026-09-24 09:00:00'),
(21, 25, '2026-09-01 10:30:00'), (22, 1, '2026-09-02 11:30:00'), (23, 2, '2026-09-03 12:30:00'), (24, 3, '2026-09-04 13:30:00'),
(25, 4, '2026-09-05 14:30:00'), (26, 5, '2026-09-06 15:30:00'), (27, 6, '2026-09-07 16:30:00'), (28, 7, '2026-09-08 17:30:00'),
(29, 8, '2026-09-09 18:30:00'), (30, 9, '2026-09-10 19:30:00'), (1, 10, '2026-09-11 20:30:00'), (2, 11, '2026-09-12 09:30:00'),
(3, 12, '2026-09-13 10:30:00'), (4, 13, '2026-09-14 11:30:00'), (5, 14, '2026-09-15 12:30:00'), (6, 15, '2026-09-16 13:30:00'),
(7, 16, '2026-09-17 14:30:00'), (8, 17, '2026-09-18 15:30:00'), (9, 18, '2026-09-19 16:30:00'), (10, 19, '2026-09-20 17:30:00'),
(11, 20, '2026-09-21 18:30:00'), (12, 21, '2026-09-22 19:30:00'), (13, 22, '2026-09-23 20:30:00'), (14, 23, '2026-09-24 09:30:00'),
(15, 24, '2026-09-21 10:00:00'), (16, 25, '2026-09-22 11:00:00'), (17, 1, '2026-09-23 12:00:00'), (18, 2, '2026-09-24 13:00:00');

-- Reseñas (15 entries)
INSERT INTO resenas (id_producto, id_cliente, calificacion, comentario) VALUES
(1, 1, 5, 'Excelente smartphone, muy rápido y buena cámara.'),
(2, 2, 4, 'Buena laptop, pero se calienta un poco al renderizar.'),
(3, 3, 5, 'El sonido es espectacular, cancelación de ruido top.'),
(4, 4, 3, 'Camiseta normal, nada extraordinario por el precio.'),
(7, 7, 5, 'Ollas de muy buena calidad, no se pega nada.'),
(10, 10, 4, 'Buen balón, resistente pero un poco pesado.'),
(13, 13, 5, 'Edición preciosa, vale cada centavo.'),
(16, 16, 5, 'Mis hijos no paran de jugar con estos bloques.'),
(19, 19, 4, 'Buena crema, hidrata bien aunque tiene fragancia fuerte.'),
(22, 22, 5, 'Chocolates deliciosos, excelente regalo.'),
(25, 25, 4, 'Buen reloj, la batería dura bastante.'),
(28, 3, 5, 'Bicicleta increíble para la montaña, muy ligera.'),
(30, 9, 4, 'Maquillaje muy completo, buena pigmentación.'),
(5, 12, 3, 'Los pantalones son un poco rígidos, espero que aflojen.'),
(8, 15, 5, 'Licuadora súper potente, pulveriza todo en segundos.');

-- Tasas Cambio (5 entries)
INSERT INTO tasas_cambio (moneda_destino, tasa) VALUES
('EUR', 0.9500),
('GBP', 0.8200),
('MXN', 17.5000),
('JPY', 145.2000),
('BRL', 5.0500);
