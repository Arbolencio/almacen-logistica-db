# 📋 Changelog

Todos los cambios notables de este proyecto se documentan aquí.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).

## [2.0.0] - 2026-05-25

### Añadido
- **Índices optimizados** en todas las tablas para consultas frecuentes
- **Triggers automáticos** para actualización de stock al registrar movimientos
- **Triggers de totales** que recalculan `pedidos.total_pedido` al modificar detalles
- **4 vistas SQL** para reporting: inventario por categoría, productos bajo stock, pedidos con detalle, historial completo
- **5 procedimientos almacenados**: registrar entrada/salida, crear pedido, cambiar estado, reporte de ventas
- **Datos de ejemplo** (seed) con 3 proveedores, 3 clientes, 7 productos, 2 pedidos y movimientos
- **Archivo .gitignore** para mantener el repo limpio
- **Documentación mejorada** con badges, diagrama ASCII, consultas útiles y notas de diseño

### Mejorado
- `README.md` completamente rediseñado con estructura profesional
- `schema.sql` con mejor formato, comentarios y organización por secciones
- `historial_invemtario.proveedor_id` ahora permite `NULL` con `ON DELETE SET NULL`

### Eliminado
- Comentario `--jmrodg8` del inicio del schema (ya no aplica)

## [1.0.0] - (Versión original)

### Añadido
- Estructura base con 7 tablas (3 maestras + 4 relacionales)
- Integridad referencial con claves foráneas
- Diagrama Entidad-Relación en PNG
