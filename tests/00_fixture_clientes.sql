-- =====================================================================
-- tests/00_fixture_clientes.sql
-- Fixture de pruebas: Configuración de entorno mínimo para clientes y sucursales
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- Eliminar tablas en orden para idempotencia
DROP TABLE IF EXISTS detalle_ventas;
DROP TABLE IF EXISTS ventas;
DROP TABLE IF EXISTS carritos;
DROP TABLE IF EXISTS resenas;
DROP TABLE IF EXISTS vistas_productos;
DROP TABLE IF EXISTS clientes;
DROP TABLE IF EXISTS sucursales;

SET FOREIGN_KEY_CHECKS = 1;

-- 1. Tabla sucursales (mínima requerida para FK fk_cliente_sucursal)
CREATE TABLE sucursales (
    id_sucursal INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    direccion TEXT,
    ciudad VARCHAR(100),
    activa BOOLEAN DEFAULT TRUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO sucursales (id_sucursal, nombre, direccion, ciudad, activa) 
VALUES (1, 'Sucursal Central', 'Avenida Principal 123', 'Ciudad Central', TRUE);

-- 2. Tabla real clientes (fuente de verdad, esquema exacto)
CREATE TABLE clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(200) NOT NULL UNIQUE,
    contraseña VARCHAR(255) NOT NULL,
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

-- 3. Inserción de 5 clientes de prueba con diversidad de casos
INSERT INTO clientes (id_cliente, nombre, apellido, email, contraseña, direccion_envio, ciudad, region, id_sucursal) VALUES
(1, 'Juan', 'Pérez', 'juan.perez@test.com', SHA2('Password123!', 256), NULL, 'Madrid', 'Comunidad de Madrid', 1),
(2, 'Ana', 'García', 'Ana@test.com', SHA2('Password123!', 256), 'Calle Alcalá 45', 'Barcelona', 'Cataluña', 1),
(3, 'José', 'Muñoz', 'jose.munoz@test.com', SHA2('Password123!', 256), 'Calle Córdoba 12', 'Sevilla', 'Andalucía', 1),
(4, 'María', 'López', 'maria.lopez@test.com', SHA2('Password123!', 256), 'Avenida Siempreviva 742', 'Valencia', 'Comunidad Valenciana', 1),
(5, 'Iñaki', 'Ñandú', 'inaki.nandu@test.com', SHA2('Password123!', 256), 'Plaza de España 1', 'Zaragoza', 'Aragón', 1);
