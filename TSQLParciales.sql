USE [GD2015]
GO

--PARCIAL 1C2025

CREATE TABLE Item_factura_precio (
    item_precio_tipo CHAR(1),
    item_precio_sucursal CHAR(4),
    item_precio_numero CHAR(8),
    item_precio_producto CHAR(8),
    item_precio_cantidad DECIMAL(12,2),
    item_precio_precio DECIMAL(12,2),
    item_precio_total DECIMAL(12,2)

    FOREIGN KEY (item_precio_producto) REFERENCES Producto(prod_codigo),
    FOREIGN KEY (item_precio_tipo, item_precio_sucursal, item_precio_numero) 
    REFERENCES Factura(fact_tipo, fact_sucursal, fact_numero)
)
GO

CREATE PROCEDURE PR_MIGRAR_ITEM_FACTURA_PRECIO
AS
BEGIN

    INSERT INTO Item_factura_precio (item_precio_tipo,
                                    item_precio_sucursal,
                                    item_precio_numero,
                                    item_precio_producto,
                                    item_precio_cantidad,
                                    item_precio_precio,
                                    item_precio_total)
    SELECT i.item_tipo,
            i.item_sucursal,
            i.item_numero,
            i.item_producto,
            i.item_cantidad,
            i.item_precio,
            i.item_cantidad * i.item_precio
    FROM Item_factura i

END;
GO

EXEC PR_MIGRAR_ITEM_FACTURA_PRECIO;
GO

ALTER TABLE Item_factura DROP item_cantidad, item_precio
GO

CREATE VIEW v_item_factura AS
SELECT CONCAT(i.item_numero,'-',i.item_precio_sucursal,'-',i.item_tipo) AS factura_id,
        p.prod_detalle AS prod_nombre,
        ip.item_precio_precio AS prod_precio_unitario,
        ip.item_cantidad AS cantidad,
        ip.precio_total AS total
FROM Item_factura i 
INNER JOIN Producto p ON p.prod_codigo = i.item_producto
INNER JOIN Item_factura_precio ip ON ip.item_precio_numero = i.item_numero
                                AND ip.item_precio_sucursal = i.item_sucursal
                                AND ip.item_precio_tipo = i.item_tipo
                                AND ip.item_precio_producto = i.item_producto
GROUP BY i.item_producto, i.item_numero, i.item_sucursal, i.item_tipo
GO




-- 2024 2C

CREATE TABLE auditoria_cliente (
    clie_codigo CHAR(6),
    clie_razon_social CHAR(100),
    clie_telefono CHAR(100),
    clie_domicilio CHAR(100),
    clie_limite_credito DECIMAL(12,2),
    clie_vendedor NUMERIC(6),
    tipo_operacion CHAR(10),
    fecha_ejecucion DATETIME2,
    intento_masiva BIT
)
GO

CREATE TRIGGER TR_AUDITAR_CLIENTE
ON Cliente
AFTER INSERT, UPDATE, DELETE
AS
BEGIN

    DECLARE @clie_codigo CHAR(6),
            @clie_razon_social CHAR(100),
            @clie_telefono CHAR(100),
            @clie_domicilio CHAR(100),
            @clie_limite_credito DECIMAL(12,2),
            @clie_vendedor NUMERIC(6),
            @tipo_operacion CHAR(10),
            @fecha_ejecucion DATETIME2,
            @intento_masiva BIT

    SET @fecha_ejecucion = SYSDATETIME()

    IF EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted)
        SET @tipo_operacion = 'INSERT'
    ELSE IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        SET @tipo_operacion = 'DELETE'
    ELSE
        SET @tipo_operacion = 'UPDATE'
        
    IF (SELECT COUNT(*) FROM inserted) > 1 OR (SELECT COUNT(*) FROM deleted) > 1
    BEGIN

        SET @intento_masiva = 1

        INSERT INTO auditoria_cliente (tipo_operacion, fecha_ejecucion, intento_masiva)
        VALUES(@tipo_operacion, @fecha_ejecucion, @intento_masiva)

        ROLLBACK TRANSACTION;
        RETURN;

    END;

    SET @intento_masiva = 0

    IF @tipo_operacion = 'INSERT' OR @tipo_operacion = 'DELETE'
    BEGIN

        SELECT @clie_codigo = i.clie_codigo,
                @clie_razon_social = i.clie_razon_social,
                @clie_telefono = i.clie_telefono,
                @clie_domicilio = i.clie_domicilio,
                @clie_limite_credito = i.clie_limite_credito,
                @clie_vendedor = i.clie_vendedor
        FROM inserted i

        INSERT INTO auditoria_cliente (clie_codigo, clie_razon_social, clie_telefono, clie_domicilio,
                                        clie_limite_credito, clie_vendedor, tipo_operacion, fecha_ejecucion,
                                        intento_masiva)
        VALUES(@clie_codigo, @clie_razon_social, @clie_telefono, @clie_domicilio,
                @clie_limite_credito, @clie_vendedor, @tipo_operacion, @fecha_ejecucion,
                @intento_masiva)

    END;
    ELSE
    BEGIN

        SELECT @clie_codigo = i.clie_codigo,
                @clie_razon_social = i.clie_razon_social,
                @clie_telefono = i.clie_telefono,
                @clie_domicilio = i.clie_domicilio,
                @clie_limite_credito = i.clie_limite_credito,
                @clie_vendedor = i.clie_vendedor
        FROM deleted i

        INSERT INTO auditoria_cliente (clie_codigo, clie_razon_social, clie_telefono, clie_domicilio,
                                        clie_limite_credito, clie_vendedor, tipo_operacion, fecha_ejecucion,
                                        intento_masiva)
        VALUES(@clie_codigo, @clie_razon_social, @clie_telefono, @clie_domicilio,
                @clie_limite_credito, @clie_vendedor, @tipo_operacion, @fecha_ejecucion,
                @intento_masiva)

    END;

END;
GO