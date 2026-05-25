-- ============================================================
--  Sistema de Gestión de Almacén y Logística
--  Base de datos: almacen_logistica
--  Motor: MySQL 8.0+ / MariaDB 10.5+
--  Autor: Arbolencio
-- ============================================================

DROP DATABASE IF EXISTS almacen_logistica;

CREATE DATABASE almacen_logistica
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE almacen_logistica;

-- ============================================================
--  TABLAS MAESTRAS (Independientes)
-- ============================================================

CREATE TABLE categorias (
    categoria_id    INT UNSIGNED AUTO_INCREMENT,
    nombre          VARCHAR(255)    NOT NULL,
    descripcion     VARCHAR(500),

    CONSTRAINT pk_categorias PRIMARY KEY (categoria_id),
    CONSTRAINT uq_categorias_nombre UNIQUE (nombre)
);

CREATE TABLE proveedores (
    proveedor_id    INT UNSIGNED AUTO_INCREMENT,
    razon_social    VARCHAR(255)    NOT NULL,
    contacto_nombre VARCHAR(255),
    email           VARCHAR(255),
    telefono        VARCHAR(15),
    direccion       TEXT,
    fecha_registro  DATETIME        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_proveedores PRIMARY KEY (proveedor_id),
    CONSTRAINT uq_proveedores_email UNIQUE (email)
);

CREATE TABLE clientes (
    cliente_id      INT UNSIGNED AUTO_INCREMENT,
    nombre          VARCHAR(255)    NOT NULL,
    email           VARCHAR(255)    NOT NULL,
    telefono        VARCHAR(15),
    fecha_registro  DATETIME        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_clientes PRIMARY KEY (cliente_id),
    CONSTRAINT uq_clientes_email UNIQUE (email)
);

-- ============================================================
--  TABLAS RELACIONALES (Dependientes)
-- ============================================================

CREATE TABLE productos (
    producto_id     INT UNSIGNED AUTO_INCREMENT,
    categoria_id    INT UNSIGNED    NOT NULL,
    nombre          VARCHAR(255)    NOT NULL,
    descripcion     TEXT,
    precio_unitario DECIMAL(10, 2)  NOT NULL,
    stock_actual    INT UNSIGNED    DEFAULT 0,
    stock_minimo    INT UNSIGNED    DEFAULT 0,
    fecha_ingreso   DATETIME        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_productos PRIMARY KEY (producto_id),
    CONSTRAINT uq_productos_nombre UNIQUE (nombre),
    CONSTRAINT fk_productos_categorias FOREIGN KEY (categoria_id)
        REFERENCES categorias (categoria_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE pedidos (
    pedido_id       INT UNSIGNED AUTO_INCREMENT,
    cliente_id      INT UNSIGNED    NOT NULL,
    fecha_pedido    DATETIME        DEFAULT CURRENT_TIMESTAMP,
    estado          ENUM('Pendiente', 'Procesado', 'Enviado', 'Entregado', 'Cancelado')
                                    DEFAULT 'Pendiente',
    total_pedido    DECIMAL(12, 2)  DEFAULT 0.00,

    CONSTRAINT pk_pedidos PRIMARY KEY (pedido_id),
    CONSTRAINT fk_pedidos_clientes FOREIGN KEY (cliente_id)
        REFERENCES clientes (cliente_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE detalle_pedidos (
    pedido_id                   INT UNSIGNED    NOT NULL,
    producto_id                 INT UNSIGNED    NOT NULL,
    cantidad                    INT UNSIGNED    NOT NULL,
    precio_unitario_historico   DECIMAL(10, 2)  NOT NULL,

    CONSTRAINT pk_detalle_pedidos PRIMARY KEY (pedido_id, producto_id),
    CONSTRAINT fk_detalle_pedidos_pedidos FOREIGN KEY (pedido_id)
        REFERENCES pedidos (pedido_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_detalle_pedidos_productos FOREIGN KEY (producto_id)
        REFERENCES productos (producto_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE historial_inventario (
    movimiento_id   INT UNSIGNED AUTO_INCREMENT,
    producto_id     INT UNSIGNED    NOT NULL,
    proveedor_id    INT UNSIGNED    NULL,
    tipo_movimiento ENUM('Entrada', 'Salida', 'Ajuste_Positivo', 'Ajuste_Negativo')
                                    NOT NULL,
    cantidad        INT UNSIGNED    NOT NULL,
    fecha_movimiento DATETIME       DEFAULT CURRENT_TIMESTAMP,
    motivo          TEXT,

    CONSTRAINT pk_historial_inventario PRIMARY KEY (movimiento_id),
    CONSTRAINT fk_historial_productos FOREIGN KEY (producto_id)
        REFERENCES productos (producto_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_historial_proveedores FOREIGN KEY (proveedor_id)
        REFERENCES proveedores (proveedor_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- ============================================================
--  ÍNDICES para optimización de consultas frecuentes
-- ============================================================

CREATE INDEX idx_productos_categoria ON productos (categoria_id);
CREATE INDEX idx_productos_nombre ON productos (nombre);
CREATE INDEX idx_productos_stock ON productos (stock_actual, stock_minimo);

CREATE INDEX idx_pedidos_cliente ON pedidos (cliente_id);
CREATE INDEX idx_pedidos_estado ON pedidos (estado);
CREATE INDEX idx_pedidos_fecha ON pedidos (fecha_pedido);

CREATE INDEX idx_detalle_producto ON detalle_pedidos (producto_id);

CREATE INDEX idx_historial_producto ON historial_inventario (producto_id);
CREATE INDEX idx_historial_fecha ON historial_inventario (fecha_movimiento);
CREATE INDEX idx_historial_tipo ON historial_inventario (tipo_movimiento);

-- ============================================================
--  TRIGGERS para actualización automática de stock
-- ============================================================

DELIMITER $$

-- Trigger: Actualizar stock al registrar movimiento de inventario
CREATE TRIGGER trg_actualizar_stock_after_insert
AFTER INSERT ON historial_inventario
FOR EACH ROW
BEGIN
    IF NEW.tipo_movimiento = 'Entrada' OR NEW.tipo_movimiento = 'Ajuste_Positivo' THEN
        UPDATE productos
        SET stock_actual = stock_actual + NEW.cantidad
        WHERE producto_id = NEW.producto_id;
    ELSEIF NEW.tipo_movimiento = 'Salida' OR NEW.tipo_movimiento = 'Ajuste_Negativo' THEN
        UPDATE productos
        SET stock_actual = GREATEST(stock_actual - NEW.cantidad, 0)
        WHERE producto_id = NEW.producto_id;
    END IF;
END$$

-- Trigger: Calcular total del pedido al insertar detalle
CREATE TRIGGER trg_calcular_total_after_detalle
AFTER INSERT ON detalle_pedidos
FOR EACH ROW
BEGIN
    UPDATE pedidos
    SET total_pedido = (
        SELECT COALESCE(SUM(cantidad * precio_unitario_historico), 0)
        FROM detalle_pedidos
        WHERE pedido_id = NEW.pedido_id
    )
    WHERE pedido_id = NEW.pedido_id;
END$$

-- Trigger: Recalcular total al eliminar detalle
CREATE TRIGGER trg_calcular_total_after_delete
AFTER DELETE ON detalle_pedidos
FOR EACH ROW
BEGIN
    UPDATE pedidos
    SET total_pedido = (
        SELECT COALESCE(SUM(cantidad * precio_unitario_historico), 0)
        FROM detalle_pedidos
        WHERE pedido_id = OLD.pedido_id
    )
    WHERE pedido_id = OLD.pedido_id;
END$$

DELIMITER ;

-- ============================================================
--  VISTAS útiles para reporting
-- ============================================================

-- Vista: Resumen de inventario por categoría
CREATE VIEW vw_inventario_categoria AS
SELECT
    c.categoria_id,
    c.nombre AS categoria,
    COUNT(p.producto_id) AS total_productos,
    SUM(p.stock_actual) AS stock_total,
    SUM(p.stock_actual * p.precio_unitario) AS valor_inventario,
    SUM(CASE WHEN p.stock_actual < p.stock_minimo THEN 1 ELSE 0 END) AS productos_bajo_stock
FROM categorias c
LEFT JOIN productos p ON c.categoria_id = p.categoria_id
GROUP BY c.categoria_id, c.nombre;

-- Vista: Productos bajo stock mínimo
CREATE VIEW vw_productos_bajo_stock AS
SELECT
    p.producto_id,
    p.nombre,
    p.stock_actual,
    p.stock_minimo,
    (p.stock_minimo - p.stock_actual) AS unidades_faltantes,
    c.nombre AS categoria,
    p.precio_unitario
FROM productos p
JOIN categorias c ON p.categoria_id = c.categoria_id
WHERE p.stock_actual < p.stock_minimo
ORDER BY unidades_faltantes DESC;

-- Vista: Pedidos con detalle completo
CREATE VIEW vw_pedidos_detalle AS
SELECT
    p.pedido_id,
    cl.nombre AS cliente,
    cl.email AS cliente_email,
    p.fecha_pedido,
    p.estado,
    p.total_pedido,
    COUNT(dp.producto_id) AS lineas_total
FROM pedidos p
JOIN clientes cl ON p.cliente_id = cl.cliente_id
LEFT JOIN detalle_pedidos dp ON p.pedido_id = dp.pedido_id
GROUP BY p.pedido_id, cl.nombre, cl.email, p.fecha_pedido, p.estado, p.total_pedido;

-- Vista: Movimientos de inventario enriquecidos
CREATE VIEW vw_historial_completo AS
SELECT
    hi.movimiento_id,
    pr.nombre AS producto,
    hi.tipo_movimiento,
    hi.cantidad,
    hi.fecha_movimiento,
    hi.motivo,
    prov.razon_social AS proveedor
FROM historial_inventario hi
JOIN productos pr ON hi.producto_id = pr.producto_id
LEFT JOIN proveedores prov ON hi.proveedor_id = prov.proveedor_id
ORDER BY hi.fecha_movimiento DESC;

-- ============================================================
--  PROCEDIMIENTOS ALMACENADOS
-- ============================================================

DELIMITER $$

-- Procedimiento: Registrar entrada de inventario
CREATE PROCEDURE sp_registrar_entrada(
    IN p_producto_id INT UNSIGNED,
    IN p_proveedor_id INT UNSIGNED,
    IN p_cantidad INT UNSIGNED,
    IN p_motivo TEXT
)
BEGIN
    INSERT INTO historial_inventario (producto_id, proveedor_id, tipo_movimiento, cantidad, motivo)
    VALUES (p_producto_id, p_proveedor_id, 'Entrada', p_cantidad, p_motivo);
END$$

-- Procedimiento: Registrar salida de inventario
CREATE PROCEDURE sp_registrar_salida(
    IN p_producto_id INT UNSIGNED,
    IN p_cantidad INT UNSIGNED,
    IN p_motivo TEXT
)
BEGIN
    DECLARE v_stock INT UNSIGNED;

    SELECT stock_actual INTO v_stock FROM productos WHERE producto_id = p_producto_id;

    IF v_stock >= p_cantidad THEN
        INSERT INTO historial_inventario (producto_id, proveedor_id, tipo_movimiento, cantidad, motivo)
        VALUES (p_producto_id, NULL, 'Salida', p_cantidad, p_motivo);
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock insuficiente para realizar la salida';
    END IF;
END$$

-- Procedimiento: Crear nuevo pedido con detalle
CREATE PROCEDURE sp_crear_pedido(
    IN p_cliente_id INT UNSIGNED,
    IN p_producto_id INT UNSIGNED,
    IN p_cantidad INT UNSIGNED
)
BEGIN
    DECLARE v_precio DECIMAL(10, 2);
    DECLARE v_pedido_id INT UNSIGNED;

    SELECT precio_unitario INTO v_precio FROM productos WHERE producto_id = p_producto_id;

    INSERT INTO pedidos (cliente_id, estado)
    VALUES (p_cliente_id, 'Pendiente');

    SET v_pedido_id = LAST_INSERT_ID();

    INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario_historico)
    VALUES (v_pedido_id, p_producto_id, p_cantidad, v_precio);

    SELECT v_pedido_id AS pedido_id;
END$$

-- Procedimiento: Cambiar estado de pedido
CREATE PROCEDURE sp_cambiar_estado_pedido(
    IN p_pedido_id INT UNSIGNED,
    IN p_nuevo_estado ENUM('Pendiente', 'Procesado', 'Enviado', 'Entregado', 'Cancelado')
)
BEGIN
    UPDATE pedidos
    SET estado = p_nuevo_estado
    WHERE pedido_id = p_pedido_id;
END$$

-- Procedimiento: Reporte de ventas por período
CREATE PROCEDURE sp_reporte_ventas(
    IN p_fecha_inicio DATETIME,
    IN p_fecha_fin DATETIME
)
BEGIN
    SELECT
        DATE(p.fecha_pedido) AS fecha,
        COUNT(DISTINCT p.pedido_id) AS total_pedidos,
        SUM(dp.cantidad) AS unidades_vendidas,
        SUM(dp.cantidad * dp.precio_unitario_historico) AS ingresos_totales
    FROM pedidos p
    JOIN detalle_pedidos dp ON p.pedido_id = dp.pedido_id
    WHERE p.fecha_pedido BETWEEN p_fecha_inicio AND p_fecha_fin
      AND p.estado != 'Cancelado'
    GROUP BY DATE(p.fecha_pedido)
    ORDER BY fecha DESC;
END$$

DELIMITER ;

-- ============================================================
--  DATOS DE EJEMPLO (Seed)
-- ============================================================

INSERT INTO categorias (nombre, descripcion) VALUES
    ('Electrónica', 'Dispositivos electrónicos y accesorios'),
    ('Alimentos', 'Productos alimenticios y bebidas'),
    ('Hogar', 'Artículos para el hogar y decoración'),
    ('Ropa', 'Prendas de vestir y accesorios'),
    ('Herramientas', 'Herramientas manuales y eléctricas');

INSERT INTO proveedores (razon_social, contacto_nombre, email, telefono, direccion) VALUES
    ('TechSupply S.A.', 'Carlos Martínez', 'contacto@techsupply.com', '+34912345678', 'Calle Industria 42, Madrid'),
    ('Alimentación Gómez', 'María Gómez', 'info@aligomez.es', '+34923456789', 'Pol. Ind. Sur, Nave 12, Valencia'),
    ('HogarDiseño SL', 'Ana Ruiz', 'ventas@hogardiseno.com', '+34934567890', 'Av. Diseño 8, Barcelona');

INSERT INTO clientes (nombre, email, telefono) VALUES
    ('Juan Pérez', 'juan.perez@email.com', '+34612345678'),
    ('Laura Sánchez', 'laura.sanchez@email.com', '+34623456789'),
    ('Pedro García', 'pedro.garcia@email.com', '+34634567890');

INSERT INTO productos (categoria_id, nombre, descripcion, precio_unitario, stock_actual, stock_minimo) VALUES
    (1, 'Auriculares Bluetooth', 'Auriculares inalámbricos con cancelación de ruido', 59.99, 150, 20),
    (1, 'Cargador USB-C 65W', 'Cargador rápido universal USB-C', 24.99, 200, 30),
    (2, 'Café Premium 1kg', 'Café de origen colombiano tostado', 12.50, 80, 25),
    (2, 'Aceite de Oliva 500ml', 'Aceite de oliva virgen extra', 8.99, 120, 40),
    (3, 'Lámpara LED Escritorio', 'Lámpara regulable con puerto USB', 34.99, 45, 10),
    (4, 'Camiseta Algodón M', 'Camiseta básica de algodón orgánico', 15.99, 300, 50),
    (5, 'Taladro Inalámbrico', 'Taladro con batería litio 18V', 89.99, 25, 5);

-- Pedido de ejemplo
INSERT INTO pedidos (cliente_id, estado) VALUES (1, 'Procesado');
SET @pedido1 = LAST_INSERT_ID();
INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario_historico) VALUES
    (@pedido1, 1, 2, 59.99),
    (@pedido1, 2, 1, 24.99);

INSERT INTO pedidos (cliente_id, estado) VALUES (2, 'Pendiente');
SET @pedido2 = LAST_INSERT_ID();
INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario_historico) VALUES
    (@pedido2, 3, 5, 12.50),
    (@pedido2, 5, 1, 34.99);

-- Movimientos de inventario de ejemplo
INSERT INTO historial_inventario (producto_id, proveedor_id, tipo_movimiento, cantidad, motivo) VALUES
    (1, 1, 'Entrada', 150, 'Compra inicial de stock'),
    (2, 1, 'Entrada', 200, 'Compra inicial de stock'),
    (3, 2, 'Entrada', 80, 'Compra inicial de stock'),
    (4, 2, 'Entrada', 120, 'Compra inicial de stock'),
    (5, 3, 'Entrada', 45, 'Compra inicial de stock'),
    (6, NULL, 'Entrada', 300, 'Compra inicial de stock'),
    (7, NULL, 'Entrada', 25, 'Compra inicial de stock');
