# 🛒 Proyecto de Base de Datos para un E-commerce

## Descripción

Este proyecto implementa el diseño completo de una base de datos relacional para una tienda en línea (e-commerce), desarrollada en **MySQL 8.0**. El sistema gestiona de forma eficiente y segura toda la información relacionada con productos, inventario, clientes, proveedores y el ciclo de vida completo de las ventas. Incluye lógica de negocio avanzada mediante funciones, triggers, eventos programados y procedimientos almacenados, así como un esquema de seguridad robusto basado en roles.

## Integrantes

| # | Nombre Completo |
|---|----------------|
| 1 | _[Nombre del integrante 1]_ |
| 2 | _[Nombre del integrante 2]_ |
| 3 | _[Nombre del integrante 3]_ |

> **Nota:** Reemplazar los nombres de ejemplo con los nombres reales de los integrantes del equipo.

## Diagrama Entidad-Relación

```
┌──────────────┐       ┌──────────────┐       ┌──────────────────┐
│  Categorías  │1────N│  Productos   │N────1│   Proveedores    │
│              │       │              │       │                  │
│ id_categoria │       │ id_producto  │       │ id_proveedor     │
│ nombre       │       │ nombre       │       │ nombre           │
│ descripcion  │       │ precio/costo │       │ email_contacto   │
│ num_productos│       │ stock/sku    │       │ telefono_contacto│
└──────────────┘       │ id_categoria │       └──────────────────┘
                       │ id_proveedor │
                       └──────┬───────┘
                              │N
                              │
                       ┌──────┴───────┐
                       │Detalle Ventas│
                       │              │
                       │ id_detalle   │
                       │ cantidad     │
                       │ precio_cong. │
                       └──────┬───────┘
                              │N
                              │
                       ┌──────┴───────┐       ┌──────────────┐
                       │   Ventas     │N────1│   Clientes    │
                       │              │       │              │
                       │ id_venta     │       │ id_cliente   │
                       │ fecha_venta  │       │ nombre       │
                       │ estado       │       │ apellido     │
                       │ total        │       │ email        │
                       └──────────────┘       │ contraseña   │
                                              └──────────────┘
```

## Tecnologías Utilizadas

- **MySQL 8.0** — Motor de base de datos relacional
- **Docker & Docker Compose** — Contenedorización del entorno
- **phpMyAdmin** — Interfaz web de administración (opcional)

## Requisitos Previos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y en ejecución
- Git (para clonar el repositorio)
- (Opcional) Cliente MySQL como MySQL Workbench, DBeaver o la CLI de MySQL

## Estructura del Repositorio

```
📁 Proyecto_BD_Avanzada/
├── 📄 README.md                           ← Este archivo
├── 📄 docker-compose.yml                  ← Configuración de Docker
├── 📄 01_Esquema_y_Datos.sql              ← Estructura de tablas + datos de ejemplo
├── 📄 02_Consultas_Avanzadas.sql          ← 20 consultas de análisis y reporteo
├── 📄 03_Funciones.sql                    ← 20 funciones definidas por el usuario
├── 📄 04_Seguridad.sql                    ← Roles, usuarios y permisos
├── 📄 05_Triggers.sql                     ← 20 triggers + tablas de auditoría
├── 📄 06_Eventos.sql                      ← 20 eventos programados
└── 📄 07_Procedimientos_Almacenados.sql   ← 20 procedimientos almacenados
```

## Instrucciones de Ejecución

### Opción A: Usando Docker Compose (Recomendado)

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/<usuario>/Proyecto_BD_Avanzada_<NombreEquipo>.git
   cd Proyecto_BD_Avanzada_<NombreEquipo>
   ```

2. **Iniciar los contenedores:**
   ```bash
   docker compose up -d
   ```
   > Esto creará automáticamente la base de datos y ejecutará los scripts `01`, `03`, `04`, `05`, `06` y `07` en orden.

3. **Esperar a que MySQL esté listo** (aprox. 30-60 segundos):
   ```bash
   docker compose logs -f mysql
   ```
   > Buscar el mensaje: `ready for connections`

4. **Ejecutar las consultas avanzadas manualmente:**
   ```bash
   docker exec -i ecommerce_mysql mysql -u root -pR00t_S3cur3_P@ss! ecommerce_db < 02_Consultas_Avanzadas.sql
   ```

5. **Acceder a phpMyAdmin** (opcional):
   - Abrir el navegador en: [http://localhost:8080](http://localhost:8080)
   - Servidor: `mysql` | Usuario: `root` | Contraseña: `R00t_S3cur3_P@ss!`

6. **Detener los contenedores:**
   ```bash
   docker compose down
   ```
   > Para eliminar también los datos persistidos: `docker compose down -v`

### Opción B: Ejecución Manual en MySQL

Si se prefiere ejecutar directamente en un servidor MySQL ya existente, seguir este orden estricto:

| Orden | Archivo | Descripción |
|:-----:|---------|-------------|
| 1️⃣ | `01_Esquema_y_Datos.sql` | Crea la base de datos, todas las tablas y carga los datos de ejemplo |
| 2️⃣ | `03_Funciones.sql` | Crea las 20 funciones definidas por el usuario |
| 3️⃣ | `05_Triggers.sql` | Crea las tablas de auditoría y los 20 triggers |
| 4️⃣ | `06_Eventos.sql` | Activa el event_scheduler y crea los 20 eventos programados |
| 5️⃣ | `07_Procedimientos_Almacenados.sql` | Crea los 20 procedimientos almacenados |
| 6️⃣ | `04_Seguridad.sql` | Crea los roles, usuarios, vistas y asigna permisos |
| 7️⃣ | `02_Consultas_Avanzadas.sql` | Ejecutar las consultas de análisis para verificar los datos |

```bash
mysql -u root -p < 01_Esquema_y_Datos.sql
mysql -u root -p ecommerce_db < 03_Funciones.sql
mysql -u root -p ecommerce_db < 05_Triggers.sql
mysql -u root -p ecommerce_db < 06_Eventos.sql
mysql -u root -p ecommerce_db < 07_Procedimientos_Almacenados.sql
mysql -u root -p < 04_Seguridad.sql
mysql -u root -p ecommerce_db < 02_Consultas_Avanzadas.sql
```

> ⚠️ **Nota:** El archivo `04_Seguridad.sql` se ejecuta después de los demás porque necesita que las tablas, vistas y procedimientos ya existan para asignar permisos correctamente.

## Credenciales por Defecto (Docker)

| Servicio | Usuario | Contraseña |
|----------|---------|------------|
| MySQL (root) | `root` | `R00t_S3cur3_P@ss!` |
| MySQL (app) | `app_user` | `App_Us3r_P@ss!` |
| phpMyAdmin | `root` | `R00t_S3cur3_P@ss!` |

## Contenido Detallado

### 📊 Consultas Avanzadas (20)
Incluye análisis como: Top 10 productos más vendidos, clientes VIP, análisis de cohorte, segmentación RFM, predicción de demanda, productos comprados juntos, y más.

### ⚙️ Funciones (20)
Lógica de negocio reutilizable: cálculo de totales, verificación de stock, validación de email, estados de lealtad, conversión de moneda, generación de SKU, etc.

### 🔐 Seguridad (20)
Esquema completo con 7 roles (Administrador, Gerente Marketing, Analista, Inventario, Atención al Cliente, Auditor, Visitante), 4 usuarios, vistas de seguridad, y políticas de contraseñas.

### 🔔 Triggers (20)
Automatización de: auditoría de precios, control de stock, validación de datos, archivado de ventas, capitalización de nombres, alertas de stock bajo, y más.

### ⏰ Eventos Programados (20)
Tareas automáticas: reportes semanales, limpieza de datos, detección de fraude, cálculo de KPIs, reabastecimiento, mantenimiento de índices, y más.

### 📋 Procedimientos Almacenados (20)
Operaciones transaccionales: procesamiento de ventas, devoluciones, registro de clientes, búsqueda avanzada, dashboard administrativo, fusión de cuentas, y más.

## Entidades Principales

| Entidad | Descripción |
|---------|-------------|
| **Categorías** | Clasificación jerárquica de productos |
| **Proveedores** | Entidades que suministran productos |
| **Productos** | Catálogo de artículos con inventario |
| **Clientes** | Usuarios registrados del e-commerce |
| **Ventas** | Transacciones comerciales (encabezado) |
| **Detalle de Ventas** | Productos específicos en cada venta |
| **Sucursales** | Puntos de venta físicos |

## Licencia

Este proyecto fue desarrollado con fines académicos para el curso de Bases de Datos Avanzadas.

---

> 📝 **Proyecto de Base de Datos Avanzada** — MySQL II
