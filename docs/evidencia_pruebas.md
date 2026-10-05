# Evidencia de Ejecución de Pruebas en MySQL 8 Real

**Entorno de Ejecución:**
- **Motor:** MySQL 8.0.46 (Docker container ecommerce_mysql)
- **Collation:** utf8mb4 / utf8mb4_0900_ai_ci
- **Fecha y Hora de Ejecución:** 2026-10-05 18:31:00
- **Modo de Conexión:** --default-character-set=utf8mb4
- **Código de Salida (Exit Code):** 0

## Resumen Ejecutivo de Pruebas

| Métrica | Valor |
|---|:---:|
| Total Casos Ejecutados | 20 |
| Casos Exitosos (PASS) | 20 |
| Casos Fallidos (FAIL) | 0 |
| Tasa de Éxito | **100%** |

## Tabla Detallada de Aserciones y Resultados

| # | Caso de Prueba / Aserción | Estado |
|:---:|---|:---:|
| 1 | Caso 1: Cambia solo email genera 1 fila con valores correctos | ✅ PASS |
| 2 | Caso 2: Cambia solo direccion_envio genera 1 fila | ✅ PASS |
| 3 | Caso 3: Cambian email y direccion genera 2 filas independientes | ✅ PASS |
| 4 | Caso 4: Cambiar solo nombre NO genera filas de auditoria | ✅ PASS |
| 5 | Caso 5: Cambiar campos no auditados NO genera filas | ✅ PASS |
| 6 | Caso 6: UPDATE con el mismo valor NO genera filas | ✅ PASS |
| 7 | Caso 7: direccion_envio de NULL a valor registra correctamente | ✅ PASS |
| 8 | Caso 8: direccion_envio de valor a NULL registra correctamente | ✅ PASS |
| 9 | Caso 9: UPDATE masivo registra una fila por cada cliente afectado | ✅ PASS |
| 10 | Caso 10: Verificacion integral de metadatos de auditoria | ✅ PASS |
| 11 | Caso 11: ROLLBACK revierte los registros de auditoria | ✅ PASS |
| 12 | Caso 12: Trigger existe de forma unica y valida | ✅ PASS |
| 13 | Caso 13: Caracteres especiales y emojis soportados en UTF-8 | ✅ PASS |
| 14 | Caso 14: Texto largo (>10K caracteres) almacenado sin truncamiento | ✅ PASS |
| 15 | Caso 15: Cambio exclusivo de mayusculas/minusculas detectado | ✅ PASS |
| 16 | Caso 16: Cambio exclusivo de acento detectado | ✅ PASS |
| 17 | Caso 17: Cambio exclusivo de espacios finales detectado | ✅ PASS |
| 18 | Caso 18: Cambio de contrasena NO genera auditoria ni expone credenciales | ✅ PASS |
| 19 | Caso 19: Violacion de UNIQUE no genero filas huerfanas | ✅ PASS |
| 20 | Caso 20: Historial de auditoria sobrevive a eliminacion de cliente (sin FK restrictiva) | ✅ PASS |

## Registro Crudo de Ejecución (STDOUT)

`
Resultado
PASS - Caso 1: Cambia solo email genera 1 fila con valores correctos
Resultado
PASS - Caso 2: Cambia solo direccion_envio genera 1 fila
Resultado
PASS - Caso 3: Cambian email y direccion genera 2 filas independientes
Resultado
PASS - Caso 4: Cambiar solo nombre NO genera filas de auditoria
Resultado
PASS - Caso 5: Cambiar campos no auditados NO genera filas
Resultado
PASS - Caso 6: UPDATE con el mismo valor NO genera filas
Resultado
PASS - Caso 7: direccion_envio de NULL a valor registra correctamente
Resultado
PASS - Caso 8: direccion_envio de valor a NULL registra correctamente
Resultado
PASS - Caso 9: UPDATE masivo registra una fila por cada cliente afectado
Resultado
PASS - Caso 10: Verificacion integral de metadatos de auditoria
Resultado
PASS - Caso 11: ROLLBACK revierte los registros de auditoria
Resultado
PASS - Caso 12: Trigger existe de forma unica y valida
Resultado
PASS - Caso 13: Caracteres especiales y emojis soportados en UTF-8
Resultado
PASS - Caso 14: Texto largo (>10K caracteres) almacenado sin truncamiento
Resultado
PASS - Caso 15: Cambio exclusivo de mayusculas/minusculas detectado
Resultado
PASS - Caso 16: Cambio exclusivo de acento detectado
Resultado
PASS - Caso 17: Cambio exclusivo de espacios finales detectado
Resultado
PASS - Caso 18: Cambio de contrasena NO genera auditoria ni expone credenciales
Resultado
PASS - Caso 19: Violacion de UNIQUE no genero filas huerfanas
Resultado
PASS - Caso 20: Historial de auditoria sobrevive a eliminacion de cliente (sin FK restrictiva)
Resumen
=== BATERIA DE PRUEBAS COMPLETADA: 20/20 ASERCIONES VERIFICADAS ===
`
