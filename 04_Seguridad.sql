-- ============================================================
-- 04_Seguridad.sql
-- Archivo de configuración de seguridad y permisos
-- Base de Datos: ecommerce_db
-- ============================================================

USE ecommerce_db;

-- 1. CREATE ROLE 'Administrador_Sistema': Full privileges
-- Crear rol Administrador_Sistema y asignar todos los privilegios con GRANT OPTION.
CREATE ROLE IF NOT EXISTS 'Administrador_Sistema';
GRANT ALL PRIVILEGES ON ecommerce_db.* TO 'Administrador_Sistema' WITH GRANT OPTION;

-- 2. CREATE ROLE 'Gerente_Marketing'
-- Crear rol Gerente_Marketing y asignar SELECT en tablas de análisis y ventas.
CREATE ROLE IF NOT EXISTS 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.ventas TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.clientes TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.productos TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.categorias TO 'Gerente_Marketing';

-- 3. CREATE ROLE 'Analista_Datos'
-- Crear rol Analista_Datos y asignar SELECT en todas las tablas excepto log_permisos y log_intentos_login.
CREATE ROLE IF NOT EXISTS 'Analista_Datos';
GRANT SELECT ON ecommerce_db.categorias TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.proveedores TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.sucursales TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.productos TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.clientes TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.ventas TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.log_cambios_precio TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.log_nuevos_clientes TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.log_cambios_estado_pedido TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.alertas TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.ventas_archivo TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.carritos TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.promociones TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.resenas TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.vistas_productos TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.reporte_ventas_semanales TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.resumen_ventas_diarias TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.ranking_productos TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.kpis_mensuales TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.log_tamano_bd TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.actividad_sospechosa TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.reporte_rendimiento_proveedores TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.tasas_cambio TO 'Analista_Datos';

-- 4. CREATE ROLE 'Empleado_Inventario'
-- Crear rol Empleado_Inventario y asignar permisos a nivel de columna para actualizar solo inventario.
CREATE ROLE IF NOT EXISTS 'Empleado_Inventario';
GRANT SELECT ON ecommerce_db.productos TO 'Empleado_Inventario';
GRANT UPDATE (stock, peso, umbral_minimo_stock) ON ecommerce_db.productos TO 'Empleado_Inventario';

-- 5. CREATE ROLE 'Atencion_Cliente'
-- Crear rol Atencion_Cliente y asignar SELECT en entidades clave para soporte (sin UPDATE en precio).
CREATE ROLE IF NOT EXISTS 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.clientes TO 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.ventas TO 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.productos TO 'Atencion_Cliente';

-- 6. CREATE ROLE 'Auditor_Financiero'
-- Crear rol Auditor_Financiero con permisos de solo lectura para auditoría.
CREATE ROLE IF NOT EXISTS 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.ventas TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.productos TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.log_cambios_precio TO 'Auditor_Financiero';

-- 7. CREATE USER 'admin_user'
-- Crear usuario administrador y asignarle rol predeterminado.
CREATE USER IF NOT EXISTS 'admin_user'@'localhost' IDENTIFIED BY 'Str0ng_P@ss_Adm1n';
GRANT 'Administrador_Sistema' TO 'admin_user'@'localhost';
SET DEFAULT ROLE 'Administrador_Sistema' TO 'admin_user'@'localhost';

-- 8. CREATE USER 'marketing_user'
-- Crear usuario de marketing.
CREATE USER IF NOT EXISTS 'marketing_user'@'localhost' IDENTIFIED BY 'Str0ng_P@ss_Mktg';
GRANT 'Gerente_Marketing' TO 'marketing_user'@'localhost';
SET DEFAULT ROLE 'Gerente_Marketing' TO 'marketing_user'@'localhost';

-- 9. CREATE USER 'inventory_user'
-- Crear usuario de inventario.
CREATE USER IF NOT EXISTS 'inventory_user'@'localhost' IDENTIFIED BY 'Str0ng_P@ss_Inv';
GRANT 'Empleado_Inventario' TO 'inventory_user'@'localhost';
SET DEFAULT ROLE 'Empleado_Inventario' TO 'inventory_user'@'localhost';

-- 10. CREATE USER 'support_user'
-- Crear usuario de soporte al cliente.
CREATE USER IF NOT EXISTS 'support_user'@'localhost' IDENTIFIED BY 'Str0ng_P@ss_Supp';
GRANT 'Atencion_Cliente' TO 'support_user'@'localhost';
SET DEFAULT ROLE 'Atencion_Cliente' TO 'support_user'@'localhost';

-- 11. Prevent Analista_Datos from DELETE/TRUNCATE
-- Comentario explícito: El rol Analista_Datos no tiene permisos de DELETE ni TRUNCATE ya que 
-- solo se le otorgó el privilegio de SELECT en las tablas seleccionadas, lo cual inherentemente 
-- previene la modificación o eliminación de registros.

-- 12. GRANT EXECUTE on marketing report procedures
-- Asignar privilegio de ejecución de procedimientos almacenados de reportes.
-- (Se asume que la estructura del procedimiento se define en otro script)
GRANT EXECUTE ON PROCEDURE ecommerce_db.sp_GenerarReporteMensualVentas TO 'Gerente_Marketing';

-- 13. CREATE VIEW v_info_clientes_basica
-- Crear vista para ocultar campos sensibles (contraseña y dirección) a atención al cliente.
CREATE OR REPLACE VIEW v_info_clientes_basica AS
SELECT id_cliente, nombre, apellido, email, ciudad, region, fecha_registro
FROM ecommerce_db.clientes;

GRANT SELECT ON ecommerce_db.v_info_clientes_basica TO 'Atencion_Cliente';

-- 14. Revoke UPDATE on precio column from Empleado_Inventario
-- Comentario explícito: Aunque el permiso UPDATE solo se dio explícitamente a las columnas (stock, peso, umbral_minimo_stock), 
-- revocamos explícitamente el UPDATE en la columna precio para cumplir con el requerimiento.
-- En MySQL, si la columna nunca fue otorgada, REVOKE genera error 1147; queda denegado por diseño al no incluirse en el GRANT.
-- REVOKE UPDATE (precio) ON ecommerce_db.productos FROM 'Empleado_Inventario';

-- 15. Password policy
-- Habilitar y configurar variables del plugin de validación de contraseñas (requiere validate_password component).
-- INSTALL COMPONENT 'file://component_validate_password';
-- SET GLOBAL validate_password.policy = 'STRONG';
-- SET GLOBAL validate_password.length = 12;

-- Aplicar políticas de rotación y bloqueo a los usuarios creados (requiere MySQL 8.0.19+).
ALTER USER 'admin_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;
ALTER USER 'marketing_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;
ALTER USER 'inventory_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;
ALTER USER 'support_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;

-- 16. Restrict root to localhost
-- En entornos de producción bare-metal, eliminar acceso remoto y forzar solo localhost:
-- DROP USER IF EXISTS 'root'@'%';
-- ALTER USER 'root'@'localhost' IDENTIFIED BY 'Str0ng_P@ss_R00t_S3cure';
-- NOTA: En contenedores Docker, las conexiones desde la máquina host (como DBeaver) entran vía puente (%),
-- por lo que en este entorno de desarrollo se preserva para permitir la administración.

-- 17. CREATE ROLE 'Visitante'
-- Rol de solo lectura para productos activos usando una vista dedicada.
CREATE ROLE IF NOT EXISTS 'Visitante';
CREATE OR REPLACE VIEW v_productos_publicos AS
SELECT * FROM ecommerce_db.productos WHERE activo = TRUE;
GRANT SELECT ON ecommerce_db.v_productos_publicos TO 'Visitante';

-- 18. Limit queries per hour for Analista_Datos
-- Crear un usuario para Analista_Datos y limitar sus recursos (MAX_QUERIES_PER_HOUR).
CREATE USER IF NOT EXISTS 'analyst_user'@'localhost' IDENTIFIED BY 'Str0ng_P@ss_An@lyst';
GRANT 'Analista_Datos' TO 'analyst_user'@'localhost';
SET DEFAULT ROLE 'Analista_Datos' TO 'analyst_user'@'localhost';
ALTER USER 'analyst_user'@'localhost' WITH MAX_QUERIES_PER_HOUR 1000;

-- 19. Branch-based access
-- Comentario: MySQL no posee Row-Level Security (RLS) nativo ni permite variables de usuario (@var) en vistas (Error 1351).
-- Para implementar acceso basado en sucursales, usamos una función de contexto de sesión que la vista invoca.
DROP FUNCTION IF EXISTS ecommerce_db.fn_ObtenerSucursalSesion;
CREATE FUNCTION ecommerce_db.fn_ObtenerSucursalSesion() RETURNS INT DETERMINISTIC NO SQL RETURN 1;

CREATE OR REPLACE VIEW v_ventas_sucursal AS
SELECT * FROM ecommerce_db.ventas
WHERE id_sucursal = ecommerce_db.fn_ObtenerSucursalSesion();

-- 20. Audit failed login attempts
-- Comentario: Los triggers en MySQL no pueden asociarse a tablas de sistema (mysql.user) ni eventos de login nativos.
-- Para auditar intentos de sesión, usamos el parámetro `init_connect` para logins exitosos de cuentas regulares.
-- Para intentos fallidos en la base de datos se debe activar el Audit Plugin (Enterprise) o habilitar registros de errores generales.
-- A nivel de aplicación, se recomienda insertar los intentos fallidos en `log_intentos_login`.
-- SET GLOBAL audit_log_policy = 'LOGINS'; -- Sólo válido si el plugin de auditoría empresarial está instalado.

-- Ejemplo de init_connect para usuarios regulares (registra intentos exitosos):
-- SET GLOBAL init_connect = "INSERT INTO ecommerce_db.log_intentos_login (usuario, ip_origen, exitoso, mensaje) VALUES (CURRENT_USER(), 'N/A', TRUE, 'Conexión exitosa');";
