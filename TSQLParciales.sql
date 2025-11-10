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
