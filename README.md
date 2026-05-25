# 📦 Sistema de Gestión de Almacén y Logística

<div align="center">

![MySQL](https://img.shields.io/badge/MySQL-8.0+-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![Status](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)

**Base de datos relacional para gestión integral de almacén, inventario y logística.**

Diseñada con integridad referencial, trazabilidad completa de movimientos y optimización para entornos de producción.

[Características](#-características) •
[Modelo E-R](#-modelo-entidad-relación) •
[Estructura](#-estructura-de-tablas) •
[Instalación](#-instalación) •
[Consultas Útiles](#-consultas-útiles)

</div>

---

## ✨ Características

| Característica | Detalle |
|---|---|
| 🔗 **Integridad Referencial** | Claves foráneas con políticas `RESTRICT` / `CASCADE` para borrado y actualización |
| 📋 **Trazabilidad de Inventario** | Registro completo de movimientos (Entradas, Salidas, Ajustes) con timestamps |
| 🛒 **Control de Pedidos** | Flujo de ventas con estados dinámicos y precios históricos inmutables |
| 🌍 **Soporte Unicode** | `utf8mb4_unicode_ci` para caracteres internacionales y emojis |
| ⚡ **Rendimiento** | Índices optimizados para consultas frecuentes |
| 🔒 **Consistencia** | Triggers para actualización automática de stock y totales |

---

## 🗺️ Modelo Entidad-Relación

El diseño se divide en **dos bloques** para garantizar la consistencia de los datos:

```
┌─────────────────────────────────────────────────────────────┐
│                    TABLAS MAESTRAS                          │
│              (Independientes - Sin FKs)                     │
│                                                             │
│   ┌──────────┐  ┌────────────┐  ┌──────────┐              │
│   │categorias│  │proveedores │  │ clientes │              │
│   └────┬─────┘  └─────┬──────┘  └────┬─────┘              │
│        │              │               │                     │
└────────┼──────────────┼───────────────┼─────────────────────┘
         │              │               │
┌────────┼──────────────┼───────────────┼─────────────────────┐
│        ▼              ▼               ▼                     │
│   ┌──────────┐  ┌────────────────┐  ┌──────────┐          │
│   │ productos│  │historial_inv.  │  │ pedidos  │          │
│   └────┬─────┘  └────────────────┘  └────┬─────┘          │
│        │                                  │                 │
│        └──────────┐    ┌──────────────────┘                │
│                   ▼    ▼                                    │
│            ┌───────────────┐                                │
│            │detalle_pedidos│                                │
│            └───────────────┘                                │
│                                                             │
│                  TABLAS RELACIONALES                        │
│                   (Dependientes)                            │
└─────────────────────────────────────────────────────────────┘
```

> 📎 **Diagrama completo:** [`docs/diagrama-ER.png`](./docs/diagrama-ER.png)

---

## 📁 Estructura de Tablas

### Tablas Maestras (Independientes)

| Tabla | Descripción | Registros |
|---|---|---|
| `categorias` | Clasificación de productos | ~10-50 |
| `proveedores` | Información de proveedores | ~50-500 |
| `clientes` | Datos de clientes | ~100-10K |

### Tablas Relacionales (Dependientes)

| Tabla | Depende de | Descripción |
|---|---|---|
| `productos` | `categorias` | Catálogo de productos con stock |
| `pedidos` | `clientes` | Órdenes de compra |
| `detalle_pedidos` | `pedidos`, `productos` | Líneas de cada pedido |
| `historial_inventario` | `productos`, `proveedores` | Trazabilidad de movimientos |

---

## 🚀 Instalación

### Requisitos

- MySQL 8.0+ o MariaDB 10.5+
- Cliente MySQL o herramienta GUI (MySQL Workbench, DBeaver, etc.)

### Opción 1: Línea de comandos

```bash
# Clonar el repositorio
git clone https://github.com/Arbolencio/almacen-logistica-db.git
cd almacen-logistica-db

# Crear la base de datos
mysql -u root -p < schema.sql

# (Opcional) Cargar datos de ejemplo
mysql -u root -p almacen_logistica < seed.sql
```

### Opción 2: MySQL Workbench

1. Abrir `schema.sql` en MySQL Workbench
2. Ejecutar el script completo (⚡ icono o `Ctrl+Shift+Enter`)
3. Verificar que las tablas se crearon correctamente

---

## 📊 Consultas Útiles

### Stock actual por categoría

```sql
SELECT
    c.nombre AS categoria,
    COUNT(p.producto_id) AS total_productos,
    SUM(p.stock_actual) AS stock_total,
    SUM(p.stock_actual * p.precio_unitario) AS valor_inventario
FROM categorias c
JOIN productos p ON c.categoria_id = p.categoria_id
GROUP BY c.categoria_id, c.nombre
ORDER BY valor_inventario DESC;
```

### Productos bajo stock mínimo

```sql
SELECT
    p.nombre,
    p.stock_actual,
    p.stock_minimo,
    (p.stock_minimo - p.stock_actual) AS unidades_faltantes,
    pr.razon_social AS proveedor
FROM productos p
LEFT JOIN proveedores pr ON p.producto_id IN (
    SELECT producto_id FROM historial_inventario
    WHERE tipo_movimiento = 'Entrada'
    ORDER BY fecha_movimiento DESC LIMIT 1
)
WHERE p.stock_actual < p.stock_minimo
ORDER BY unidades_faltantes DESC;
```

### Historial de movimientos de un producto

```sql
SELECT
    hi.fecha_movimiento,
    hi.tipo_movimiento,
    hi.cantidad,
    hi.motivo,
    pr.razon_social AS proveedor
FROM historial_inventario hi
LEFT JOIN proveedores pr ON hi.proveedor_id = pr.proveedor_id
WHERE hi.producto_id = 1
ORDER BY hi.fecha_movimiento DESC;
```

### Pedidos por cliente con detalle

```sql
SELECT
    cl.nombre AS cliente,
    p.fecha_pedido,
    p.estado,
    pr.nombre AS producto,
    dp.cantidad,
    dp.precio_unitario_historico,
    (dp.cantidad * dp.precio_unitario_historico) AS subtotal
FROM pedidos p
JOIN clientes cl ON p.cliente_id = cl.cliente_id
JOIN detalle_pedidos dp ON p.pedido_id = dp.pedido_id
JOIN productos pr ON dp.producto_id = pr.producto_id
ORDER BY p.fecha_pedido DESC;
```

---

## 📝 Notas de Diseño

- **Precios históricos:** `detalle_pedidos.precio_unitario_historico` captura el precio al momento de la venta, protegiendo contra cambios futuros de tarifa.
- **Stock automático:** Los triggers en `historial_inventario` actualizan `productos.stock_actual` automáticamente.
- **Borrado seguro:** Las tablas maestras usan `ON DELETE RESTRICT` para prevenir eliminación accidental de datos con dependencias.

---

## 📄 Licencia

Este proyecto está bajo la licencia [MIT](./LICENSE).

---

<div align="center">

**Desarrollado con ❤️ por [jmrodg8]([https://github.com/jmrodg8)**

</div>
