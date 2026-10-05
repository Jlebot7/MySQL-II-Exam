-- =====================================================================
-- sql/08_auditoria_clientes.sql
-- Script de Creación: Tabla de Auditoría y Trigger para Clientes
-- Base de Datos: ecommerce_db (MySQL 8.0+)
-- =====================================================================

USE ecommerce_db;

-- ---------------------------------------------------------------------
-- 1. CREACIÓN DE LA TABLA Auditoria_Clientes
-- ---------------------------------------------------------------------
-- DECISIÓN DE DISEÑO:
-- - id_auditoria: BIGINT AUTO_INCREMENT para prevenir el desbordamiento en tablas
--   de auditoría de alto volumen transaccional.
-- - id_cliente: INT con signo, coincidiendo exactamente con clientes.id_cliente.
-- - Sin Foreign Key (FK): La auditoría debe sobrevivir a la eliminación del cliente.
--   Una FK restrictiva impediría el borrado o un CASCADE borraría la evidencia histórica.
-- - campo_modificado: VARCHAR(50) para permitir futuras extensiones de auditoría sin ALTER TABLE.
-- - valor_antiguo / valor_nuevo: TEXT NULL para albergar sin truncamiento tanto emails como
--   direcciones extensas, además de permitir valores NULL legítimos.
-- - fecha_modificacion: DATETIME DEFAULT CURRENT_TIMESTAMP para registro temporal inmutable.
-- - usuario_modificacion: VARCHAR(255) DEFAULT (CURRENT_USER()) para trazabilidad del actor.
-- - Índices: Compuesto en (id_cliente, fecha_modificacion) para consultas por cliente,
--   e índice en (fecha_modificacion) para reportes y purgas periódicas.
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS Auditoria_Clientes (
    id_auditoria BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    campo_modificado VARCHAR(50) NOT NULL,
    valor_antiguo TEXT NULL,
    valor_nuevo TEXT NULL,
    fecha_modificacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    usuario_modificacion VARCHAR(255) DEFAULT (CURRENT_USER()),
    INDEX idx_auditoria_cliente_fecha (id_cliente, fecha_modificacion),
    INDEX idx_auditoria_fecha (fecha_modificacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- 2. CREACIÓN DEL TRIGGER trg_audit_cliente_after_update
-- ---------------------------------------------------------------------
-- DECISIONES DE IMPLEMENTACIÓN:
-- 1. MOMENTO: AFTER UPDATE ON clientes.
--    Se ejecuta exclusivamente tras confirmarse la validez de la modificación en clientes.
--    Si el UPDATE falla por restricciones (CHECK, UNIQUE, FK), el trigger nunca se dispara.
-- 2. TRANSACCIONALIDAD (ACID):
--    Al usar InnoDB, la inserción en Auditoria_Clientes forma parte de la misma transacción
--    del UPDATE; si se efectúa un ROLLBACK, los registros de auditoría también se revierten.
-- 3. COMPARACIÓN BINARIA Y NULL-SAFE:
--    MySQL utiliza por defecto colaciones *_ci (case-insensitive / accent-insensitive) y PAD SPACE.
--    Una comparación estándar no detectaría:
--      a) Cambios de mayúsculas/minúsculas ('Ana@x.com' -> 'ana@x.com')
--      b) Cambios de acentos ('José' -> 'Jose')
--      c) Cambios de espacios finales ('Calle 1' -> 'Calle 1   ')
--    Usar NOT (CAST(OLD.campo AS BINARY) <=> CAST(NEW.campo AS BINARY)) garantiza:
--      - Detección byte a byte de cualquier variación real de contenido.
--      - Seguridad ante NULLs gracias al operador <=> (NULL <=> NULL es 1; NULL <=> valor es 0).
--      - Ausencia de advertencias o errores al manejar valores nulos.
-- 4. INDEPENDENCIA DE CAMPOS (DOS INSERTS):
--    Se evalúan IF independientes para 'email' y 'direccion_envio'. Si ambos son alterados
--    en la misma sentencia, se generan DOS filas atómicas, facilitando el análisis granular.
-- 5. EXCLUSIÓN ESTRICTA DE 'contraseña':
--    Por estricto cumplimiento de seguridad y normativas (PCI-DSS, RGPD), las credenciales o
--    sus hashes jamás deben ser leídos, comparados ni almacenados en tablas de auditoría.
-- ---------------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_audit_cliente_after_update;

DELIMITER $$

CREATE TRIGGER trg_audit_cliente_after_update
AFTER UPDATE ON clientes
FOR EACH ROW
BEGIN
    -- Evaluación para el campo 'email'
    -- Emplea comparación binaria con casteo a BINARY y operador NULL-safe <=>
    IF NOT (CAST(OLD.email AS BINARY) <=> CAST(NEW.email AS BINARY)) THEN
        INSERT INTO Auditoria_Clientes (
            id_cliente,
            campo_modificado,
            valor_antiguo,
            valor_nuevo,
            fecha_modificacion,
            usuario_modificacion
        ) VALUES (
            NEW.id_cliente,
            'email',
            OLD.email,
            NEW.email,
            NOW(),
            CURRENT_USER()
        );
    END IF;

    -- Evaluación independiente para el campo 'direccion_envio'
    -- Permite transiciones NULL -> Valor, Valor -> NULL y ValorA -> ValorB
    IF NOT (CAST(OLD.direccion_envio AS BINARY) <=> CAST(NEW.direccion_envio AS BINARY)) THEN
        INSERT INTO Auditoria_Clientes (
            id_cliente,
            campo_modificado,
            valor_antiguo,
            valor_nuevo,
            fecha_modificacion,
            usuario_modificacion
        ) VALUES (
            NEW.id_cliente,
            'direccion_envio',
            OLD.direccion_envio,
            NEW.direccion_envio,
            NOW(),
            CURRENT_USER()
        );
    END IF;
END $$

DELIMITER ;

-- ---------------------------------------------------------------------
-- 3. POLÍTICA DE SEGURIDAD Y PERMISOS MÍNIMOS (REFERENCIA)
-- ---------------------------------------------------------------------
-- El usuario o rol de la aplicación NO debe poseer privilegios de UPDATE ni DELETE
-- sobre la tabla Auditoria_Clientes para garantizar la inmutabilidad de la bitácora:
--
-- GRANT SELECT, INSERT ON ecommerce_db.Auditoria_Clientes TO 'app_user'@'%';
-- REVOKE UPDATE, DELETE, DROP, ALTER ON ecommerce_db.Auditoria_Clientes FROM 'app_user'@'%';
-- ---------------------------------------------------------------------

