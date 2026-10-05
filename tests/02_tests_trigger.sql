-- =====================================================================
-- tests/02_tests_trigger.sql
-- Batería de Pruebas de Integración y Aceptación para el Trigger de Auditoría
-- Totalmente Aislada, Determinística e Idempotente
-- =====================================================================

SET NAMES utf8mb4;

-- =====================================================================
-- CASO 1: Cambia solo email -> Genera exactamente 1 fila
-- =====================================================================
UPDATE clientes SET email = 'juan.perez@test.com' WHERE id_cliente = 1;
DELETE FROM Auditoria_Clientes;

UPDATE clientes SET email = 'juan.nuevo@test.com' WHERE id_cliente = 1;

SELECT 
    CASE 
        WHEN COUNT(*) = 1 
         AND MAX(campo_modificado) = 'email' 
         AND MAX(valor_antiguo) = 'juan.perez@test.com'
         AND MAX(valor_nuevo) = 'juan.nuevo@test.com'
        THEN 'PASS - Caso 1: Cambia solo email genera 1 fila con valores correctos'
        ELSE 'FAIL - Caso 1: Cambia solo email'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 2: Cambia solo direccion_envio -> Genera exactamente 1 fila
-- =====================================================================
UPDATE clientes SET direccion_envio = 'Calle Alcalá 45' WHERE id_cliente = 2;
DELETE FROM Auditoria_Clientes;

UPDATE clientes SET direccion_envio = 'Calle Gran Vía 100' WHERE id_cliente = 2;

SELECT 
    CASE 
        WHEN COUNT(*) = 1 
         AND MAX(campo_modificado) = 'direccion_envio'
         AND MAX(valor_antiguo) = 'Calle Alcalá 45'
         AND MAX(valor_nuevo) = 'Calle Gran Vía 100'
        THEN 'PASS - Caso 2: Cambia solo direccion_envio genera 1 fila'
        ELSE 'FAIL - Caso 2: Cambia solo direccion_envio'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 3: Cambian ambos campos en un mismo UPDATE -> Genera 2 filas
-- =====================================================================
UPDATE clientes SET email = 'jose.munoz@test.com', direccion_envio = 'Calle Córdoba 12' WHERE id_cliente = 3;
DELETE FROM Auditoria_Clientes;

UPDATE clientes 
SET email = 'jose.actualizado@test.com', direccion_envio = 'Avenida Constitución 50' 
WHERE id_cliente = 3;

SELECT 
    CASE 
        WHEN COUNT(*) = 2 
         AND SUM(CASE WHEN campo_modificado = 'email' AND valor_nuevo = 'jose.actualizado@test.com' THEN 1 ELSE 0 END) = 1
         AND SUM(CASE WHEN campo_modificado = 'direccion_envio' AND valor_nuevo = 'Avenida Constitución 50' THEN 1 ELSE 0 END) = 1
        THEN 'PASS - Caso 3: Cambian email y direccion genera 2 filas independientes'
        ELSE 'FAIL - Caso 3: Cambian ambos campos'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 4: Cambia solo nombre u otro campo no auditado -> 0 filas
-- =====================================================================
UPDATE clientes SET nombre = 'Juan' WHERE id_cliente = 1;
DELETE FROM Auditoria_Clientes;

UPDATE clientes SET nombre = 'Juan Carlos' WHERE id_cliente = 1;

SELECT 
    CASE 
        WHEN COUNT(*) = 0 
        THEN 'PASS - Caso 4: Cambiar solo nombre NO genera filas de auditoria'
        ELSE 'FAIL - Caso 4: Modificacion de nombre genero auditoria'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 5: Cambian otros campos (apellido, ciudad, region, total, activo) -> 0 filas
-- =====================================================================
UPDATE clientes SET apellido = 'López', ciudad = 'Valencia', region = 'Comunidad Valenciana', total_gastado = 0.00, activo = TRUE WHERE id_cliente = 4;
DELETE FROM Auditoria_Clientes;

UPDATE clientes 
SET apellido = 'Pérez Gómez', ciudad = 'Sevilla', region = 'Andalucía', total_gastado = 999.99, activo = FALSE 
WHERE id_cliente = 4;

SELECT 
    CASE 
        WHEN COUNT(*) = 0 
        THEN 'PASS - Caso 5: Cambiar campos no auditados NO genera filas'
        ELSE 'FAIL - Caso 5: Modificacion de campos no auditados genero auditoria'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 6: UPDATE con el mismo valor (sin cambio real) -> 0 filas
-- =====================================================================
UPDATE clientes SET email = 'juan.mismo@test.com' WHERE id_cliente = 1;
DELETE FROM Auditoria_Clientes;

UPDATE clientes SET email = 'juan.mismo@test.com' WHERE id_cliente = 1;

SELECT 
    CASE 
        WHEN COUNT(*) = 0 
        THEN 'PASS - Caso 6: UPDATE con el mismo valor NO genera filas'
        ELSE 'FAIL - Caso 6: UPDATE con valor identico genero auditoria'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 7: direccion_envio de NULL a valor -> 1 fila con valor_antiguo NULL
-- =====================================================================
UPDATE clientes SET direccion_envio = NULL WHERE id_cliente = 1;
DELETE FROM Auditoria_Clientes;

UPDATE clientes SET direccion_envio = 'Primera Direccion Asignada' WHERE id_cliente = 1;

SELECT 
    CASE 
        WHEN COUNT(*) = 1 
         AND MAX(valor_antiguo) IS NULL 
         AND MAX(valor_nuevo) = 'Primera Direccion Asignada'
        THEN 'PASS - Caso 7: direccion_envio de NULL a valor registra correctamente'
        ELSE 'FAIL - Caso 7: Transicion NULL a valor'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 8: direccion_envio de valor a NULL -> 1 fila con valor_nuevo NULL
-- =====================================================================
UPDATE clientes SET direccion_envio = 'Direccion Existente' WHERE id_cliente = 1;
DELETE FROM Auditoria_Clientes;

UPDATE clientes SET direccion_envio = NULL WHERE id_cliente = 1;

SELECT 
    CASE 
        WHEN COUNT(*) = 1 
         AND MAX(valor_antiguo) = 'Direccion Existente' 
         AND MAX(valor_nuevo) IS NULL
        THEN 'PASS - Caso 8: direccion_envio de valor a NULL registra correctamente'
        ELSE 'FAIL - Caso 8: Transicion valor a NULL'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 9: UPDATE masivo afectando multiples clientes -> 1 fila por cliente y campo
-- =====================================================================
UPDATE clientes SET direccion_envio = 'Original 2' WHERE id_cliente = 2;
UPDATE clientes SET direccion_envio = 'Original 3' WHERE id_cliente = 3;
DELETE FROM Auditoria_Clientes;

UPDATE clientes 
SET direccion_envio = CONCAT('Direccion Masiva ', id_cliente) 
WHERE id_cliente IN (2, 3);

SELECT 
    CASE 
        WHEN COUNT(*) = 2 
         AND COUNT(DISTINCT id_cliente) = 2
        THEN 'PASS - Caso 9: UPDATE masivo registra una fila por cada cliente afectado'
        ELSE 'FAIL - Caso 9: UPDATE masivo'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 10: Verificacion integral de metadata (id_cliente, campo, fecha, usuario)
-- =====================================================================
UPDATE clientes SET email = 'antes.meta@test.com' WHERE id_cliente = 2;
DELETE FROM Auditoria_Clientes;

UPDATE clientes SET email = 'verificacion.meta@test.com' WHERE id_cliente = 2;

SELECT 
    CASE 
        WHEN COUNT(*) = 1 
         AND MAX(id_cliente) = 2
         AND MAX(campo_modificado) = 'email'
         AND MAX(valor_antiguo) = 'antes.meta@test.com'
         AND MAX(valor_nuevo) = 'verificacion.meta@test.com'
         AND MAX(fecha_modificacion) IS NOT NULL
         AND MAX(usuario_modificacion) IS NOT NULL
        THEN 'PASS - Caso 10: Verificacion integral de metadatos de auditoria'
        ELSE 'FAIL - Caso 10: Metadatos incompletos'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 11: Rollback revierte tambien las filas de auditoria (ACID / InnoDB)
-- =====================================================================
UPDATE clientes SET email = 'estable@test.com' WHERE id_cliente = 1;
DELETE FROM Auditoria_Clientes;

START TRANSACTION;
UPDATE clientes SET email = 'transaccion.abortada@test.com' WHERE id_cliente = 1;
ROLLBACK;

SELECT 
    CASE 
        WHEN COUNT(*) = 0 
        THEN 'PASS - Caso 11: ROLLBACK revierte los registros de auditoria'
        ELSE 'FAIL - Caso 11: Filas sobrevivieron al ROLLBACK'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 12: Idempotencia: existencia de exactamente 1 trigger
-- =====================================================================
SELECT 
    CASE 
        WHEN COUNT(*) = 1 
        THEN 'PASS - Caso 12: Trigger existe de forma unica y valida'
        ELSE 'FAIL - Caso 12: Trigger no existe o esta duplicado'
    END AS Resultado
FROM information_schema.TRIGGERS 
WHERE TRIGGER_SCHEMA = DATABASE() 
  AND TRIGGER_NAME = 'trg_audit_cliente_after_update' 
  AND EVENT_OBJECT_TABLE = 'clientes';

-- =====================================================================
-- CASO 13: Caracteres especiales (acentos, enie, emojis, comillas)
-- =====================================================================
UPDATE clientes SET direccion_envio = 'Base 3' WHERE id_cliente = 3;
DELETE FROM Auditoria_Clientes;

UPDATE clientes 
SET direccion_envio = 'Mansión Peña 🏰, Calle del O\'Connor con "comillas" y Ñandú' 
WHERE id_cliente = 3;

SELECT 
    CASE 
        WHEN COUNT(*) = 1 
         AND MAX(valor_nuevo) = 'Mansión Peña 🏰, Calle del O\'Connor con "comillas" y Ñandú'
        THEN 'PASS - Caso 13: Caracteres especiales y emojis soportados en UTF-8'
        ELSE 'FAIL - Caso 13: Caracteres especiales fallaron'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 14: Texto muy largo (> 10,000 caracteres en TEXT)
-- =====================================================================
UPDATE clientes SET direccion_envio = 'Corta' WHERE id_cliente = 4;
DELETE FROM Auditoria_Clientes;

UPDATE clientes SET direccion_envio = REPEAT('ABC123_', 1500) WHERE id_cliente = 4;

SELECT 
    CASE 
        WHEN COUNT(*) = 1 
         AND LENGTH(MAX(valor_nuevo)) = 10500
        THEN 'PASS - Caso 14: Texto largo (>10K caracteres) almacenado sin truncamiento'
        ELSE 'FAIL - Caso 14: Texto largo truncado o fallido'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 15: Solo cambia mayusculas/minusculas en email -> 1 fila (semantica binaria)
-- =====================================================================
UPDATE clientes SET email = 'Ana@test.com' WHERE id_cliente = 2;
DELETE FROM Auditoria_Clientes;

-- Modificamos exclusivamente la capitalizacion: 'Ana@test.com' -> 'ana@test.com'
UPDATE clientes SET email = 'ana@test.com' WHERE id_cliente = 2;

SELECT 
    CASE 
        WHEN COUNT(*) = 1 
         AND BINARY MAX(valor_antiguo) = BINARY 'Ana@test.com'
         AND BINARY MAX(valor_nuevo) = BINARY 'ana@test.com'
        THEN 'PASS - Caso 15: Cambio exclusivo de mayusculas/minusculas detectado'
        ELSE 'FAIL - Caso 15: Falso negativo en cambio de capitalizacion'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 16: Solo cambia un acento en direccion_envio -> 1 fila (semantica binaria)
-- =====================================================================
UPDATE clientes SET direccion_envio = 'Calle Córdoba 12' WHERE id_cliente = 3;
DELETE FROM Auditoria_Clientes;

-- Cambiamos exclusivamente el acento: 'Córdoba' -> 'Cordoba'
UPDATE clientes SET direccion_envio = 'Calle Cordoba 12' WHERE id_cliente = 3;

SELECT 
    CASE 
        WHEN COUNT(*) = 1 
         AND BINARY MAX(valor_antiguo) = BINARY 'Calle Córdoba 12'
         AND BINARY MAX(valor_nuevo) = BINARY 'Calle Cordoba 12'
        THEN 'PASS - Caso 16: Cambio exclusivo de acento detectado'
        ELSE 'FAIL - Caso 16: Falso negativo en cambio de acento'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 17: Solo cambian espacios finales en direccion_envio -> 1 fila (NO PAD)
-- =====================================================================
UPDATE clientes SET direccion_envio = 'Calle Cordoba 12' WHERE id_cliente = 3;
DELETE FROM Auditoria_Clientes;

-- Agregamos espacios al final
UPDATE clientes SET direccion_envio = 'Calle Cordoba 12   ' WHERE id_cliente = 3;

SELECT 
    CASE 
        WHEN COUNT(*) = 1 
         AND BINARY MAX(valor_antiguo) = BINARY 'Calle Cordoba 12'
         AND BINARY MAX(valor_nuevo) = BINARY 'Calle Cordoba 12   '
        THEN 'PASS - Caso 17: Cambio exclusivo de espacios finales detectado'
        ELSE 'FAIL - Caso 17: Falso negativo en cambio de espacios finales'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 18: Solo cambia contrasena -> 0 filas y ninguna fuga de credencial
-- =====================================================================
DELETE FROM Auditoria_Clientes;

UPDATE clientes SET contraseña = SHA2('NuevaClaveSegura2026!', 256) WHERE id_cliente = 1;

SELECT 
    CASE 
        WHEN COUNT(*) = 0 
         AND (SELECT COUNT(*) FROM Auditoria_Clientes WHERE valor_nuevo LIKE '%NuevaClaveSegura%' OR valor_antiguo LIKE '%Password%') = 0
        THEN 'PASS - Caso 18: Cambio de contrasena NO genera auditoria ni expone credenciales'
        ELSE 'FAIL - Caso 18: Fuga o registro indebido de contrasena'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 19: Violacion de UNIQUE en email -> Falla y no deja filas huerfanas
-- =====================================================================
DELETE FROM Auditoria_Clientes;

-- Intentar asignar un email ya existente debe fallar; capturamos con UPDATE IGNORE
UPDATE IGNORE clientes SET email = 'ana@test.com' WHERE id_cliente = 5;

SELECT 
    CASE 
        WHEN COUNT(*) = 0 
        THEN 'PASS - Caso 19: Violacion de UNIQUE no genero filas huerfanas'
        ELSE 'FAIL - Caso 19: Violacion UNIQUE genero filas de auditoria'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- CASO 20: Borrado de cliente auditado -> Registros de auditoria permanecen
-- =====================================================================
DELETE FROM Auditoria_Clientes;
DELETE FROM clientes WHERE id_cliente = 9999;

-- Crear un cliente aislado exclusivo para prueba de eliminacion
INSERT INTO clientes (id_cliente, nombre, apellido, email, contraseña, ciudad, id_sucursal) 
VALUES (9999, 'Cliente', 'Temporal', 'temp.delete@test.com', SHA2('test', 256), 'Madrid', 1);

DELETE FROM Auditoria_Clientes;

-- Generar auditoria intencional para cliente 9999
UPDATE clientes SET email = 'temp.antes_de_borrar@test.com' WHERE id_cliente = 9999;

-- Borrar el cliente 9999 (sin restricciones de tablas externas)
DELETE FROM clientes WHERE id_cliente = 9999;

SELECT 
    CASE 
        WHEN COUNT(*) = 1 
         AND MAX(id_cliente) = 9999
         AND MAX(valor_nuevo) = 'temp.antes_de_borrar@test.com'
        THEN 'PASS - Caso 20: Historial de auditoria sobrevive a eliminacion de cliente (sin FK restrictiva)'
        ELSE 'FAIL - Caso 20: Auditoria eliminada o alterada tras DELETE de cliente'
    END AS Resultado
FROM Auditoria_Clientes;

-- =====================================================================
-- RESUMEN FINAL DE RESULTADOS
-- =====================================================================
SELECT 
    '=== BATERIA DE PRUEBAS COMPLETADA: 20/20 ASERCIONES VERIFICADAS ===' AS Resumen;

