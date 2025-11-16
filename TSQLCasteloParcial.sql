CREATE TABLE Registro_stock_negativo (
    depo_codigo CHAR(2),
    sucursal CHAR(4),
    prod_codigo CHAR(8),
    rango_inicio SMALLDATETIME,
    rango_final SMALLDATETIME,

    PRIMARY KEY (depo_codigo, sucursal)
)
GO

CREATE TRIGGER TR_REGISTRAR_STOCK_NEGATIVO_23
ON Stock
AFTER UPDATE
AS
BEGIN

    DECLARE @deposito CHAR(2) = '23'
    DECLARE @sucursal CHAR(4) = '0023'
    DECLARE @producto CHAR(8), @cantidad_vieja DECIMAL(12,2), @cantidad_nueva DECIMAL(12,2)
    DECLARE @fecha_ultimo_inicio SMALLDATETIME

    DECLARE cProducto CURSOR FOR 
    SELECT i.stoc_producto, i.stoc_cantidad, d.stoc_cantidad
    FROM inserted i
    INNER JOIN deleted d ON d.stoc_deposito = i.stoc_deposito AND d.stoc_producto = i.stoc_producto
    INNER JOIN Item_factura it ON it.item_producto = i.stoc_producto
                                AND it.item_sucursal = @sucursal
    WHERE i.stoc_deposito = @deposito

    OPEN cProducto
    FETCH NEXT INTO @producto, @cantidad_nueva, @cantidad_vieja
    WHILE @@FETCH_STATUS = 0
    BEGIN

        IF (@cantidad_nueva <= 0 AND @cantidad_vieja > 0) --pasé a cero o negativo
        BEGIN

            INSERT INTO Registro_stock_negativo (depo_codigo, sucursal, prod_codigo, rango_inicio, rango_final)
            VALUES(@deposito, @sucursal, @producto, GETDATE(), NULL)

        END;

        IF (@cantidad_nueva > 0 AND @cantidad_vieja <= 0) --pasé a positivo
        BEGIN

            -- con esto hago que me agarre el ultimo rango, por si hay más anteriormente con stock negativo
            SELECT TOP 1 @fecha_ultimo_inicio = r.rango_inicio
            FROM Registro_stock_negativo r
            WHERE r.prod_codigo = @producto
            AND r.depo_codigo = @deposito
            AND r.sucursal = @sucursal
            ORDER BY r.rango_inicio DESC

            UPDATE Registro_stock_negativo
            SET rango_final = GETDATE()
            WHERE prod_codigo = @producto
            AND depo_codigo = @deposito
            AND sucursal = @sucursal
            AND rango_inicio = @fecha_ultimo_inicio

        END;

        FETCH NEXT INTO @producto, @cantidad_nueva, @cantidad_vieja
    END;
    CLOSE cProducto
    DEALLOCATE cProducto

END;
GO