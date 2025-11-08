-- EJERCICIO 1

CREATE FUNCTION FN_DEPOSITO_ARTICULO (@deposito char(2), @producto char(8))
RETURNS nvarchar(40)
AS 
    BEGIN 

        DECLARE @cant_almacenada decimal(12,2)
        DECLARE @limite decimal(12,2)
        DECLARE @retorno nvarchar(40)

        SELECT @cant_almacenada = s.stoc_cantidad, @limite = s.stoc_stock_maximo
        FROM Stock s 
        WHERE s.stoc_producto = @producto
        AND s.stoc_deposito = @deposito

        IF @cant_almacenada < @limite
            SET @retorno = CONCAT('OCUPACION DEL DEPOSITO ',(@cant_almacenada * 100 / @limite),'%')
        ELSE
            SET @retorno = 'DEPOSITO COMPLETO'

        RETURN @retorno

    END;
GO

SELECT s.stoc_producto, s.stoc_deposito, dbo.FN_DEPOSITO_ARTICULO(s.stoc_producto, s.stoc_deposito)
FROM Stock s
GO


-- EJERCICIO 2

CREATE FUNCTION FN_ARTICULO_FECHA (@producto char(8), @fecha smalldatetime)
RETURNS decimal(12,2)
AS
    BEGIN

    DECLARE @retorno decimal(12,2)
    DECLARE @vendido decimal(12,2)
    DECLARE @stock_prod decimal(12,2)

    SELECT @vendido = ISNULL(SUM(i.item_cantidad), 0)
    FROM Item_factura i 
    INNER JOIN Factura f ON i.Item_factura = f.fact_numero
    WHERE i.item_producto = @producto
    AND f.fact_fecha < @fecha

    SELECT @stock_prod = ISNULL(s.stoc_cantidad, 0)
    FROM Stock s
    WHERE s.stoc_producto = @producto

    SET @retorno = @vendido + @stock_prod

    RETURN @retorno

    END
GO


-- EJERCICIO 3

CREATE PROCEDURE PR_CORREGIR_GERENTE_GRAL 
(@cant_empl_sin_jefe INT OUTPUT)
AS 
BEGIN

    SELECT @cant_empl_sin_jefe = COUNT(*)
    FROM Empleado e 
    WHERE e.empl_jefe IS NULL

    IF @cant_empl_sin_jefe <= 1 RETURN

    DECLARE @empl_mayor_saladio numeric(6)

    SELECT TOP 1 @empl_mayor_salario = e2.empl_codigo
    FROM Empleado e2
    WHERE e2.empl_jefe IS NULL
    ORDER BY e2.empl_salario, e2.empl_ingreso DESC


    BEGIN TRANSACTION
        UPDATE Empleado
        SET empl_jefe = @empl_mayor_salario 
        WHERE empl_jefe IS NULL
        AND empl_codigo <> @empl_mayor_salario
    COMMIT TRANSACTION

END;
GO



-- EJERCICIO 4

CREATE PROCEDURE PR_ACTUALIZAR_COMISION 
(@empl_mas_vendio numeric(6) OUTPUT)
AS
BEGIN 

    BEGIN TRANSACTION

    UPDATE Empleado 
    SET empl_comision = empl_comision + ISNULL((SELECT SUM(f.fact_total)
                                        FROM Factura f 
                                        WHERE f.fact_vendedor = empl_codigo
                                        AND YEAR(f.fact_fecha) = YEAR(GETDATE())
                                        GROUP BY f.fact_vendedor),0)

    COMMIT TRANSACTION

    SELECT TOP 1 @empl_mas_vendio = f.fact_vendedor
    FROM Factura f 
    WHERE YEAR(f.fact_fecha) = YEAR(GETDATE())
    GROUP BY f.fact_vendedor
    ORDER BY ISNULL(SUM(f.fact_total), 0) DESC

END;
GO



-- EJERCICIO 5

CREATE PROCEDURE PR_CREAR_FACT_TABLE
AS
BEGIN 

    IF OBJECT_ID('Fact_table') IS NULL
    BEGIN
        CREATE TABLE Fact_table (
            anio char(4),
            mes char(2),
            familia char(3),
            rubro char(4),
            zona char(3),
            cliente char(6),
            producto char(8),
            cantidad decimal(12,2),
            monto decimal(12,2)
        )

        ALTER TABLE Fact_table 
        ADD CONSTRAINT PRIMARY KEY(anio,mes,familia,rubro,zona,cliente,producto)

    END;

    BEGIN TRANSACTION

        INSERT INTO Fact_table (anio,mes,familia,rubro,zona,cliente,producto, cantidad, monto)
        SELECT  YEAR(f.fact_fecha),
                MONTH(f.fact_fecha),
                p.prod_familia,
                p.prod_rubro,
                d.depo_zona,
                f.fact_cliente,
                p.prod_codigo,
                SUM(i.item_cantidad),
                SUM(i.item_cantidad * i.item_precio)
        FROM Factura f
        INNER JOIN Item_factura i ON f.fact_numero = i.item_numero
                                    AND f.fact_sucursal = i.item_sucursal
                                    AND f.fact_tipo = i.item_tipo
        INNER JOIN Producto p ON i.item_producto = p.prod_codigo
        INNER JOIN Stock s ON s.stoc_producto = p.prod_codigo
        INNER JOIN Deposito d ON s.stoc_deposito = d.depo_codigo
        GROUP BY f.fact_fecha, p.prod_familia, p.prod_rubro, d.depo_zona, f.fact_cliente, p.prod_codigo

    COMMIT TRANSACTION

END;
GO



-- EJERCICIO 6

CREATE PROCEDURE PR_COMPONER_PRODUCTOS
AS
BEGIN 

    DECLARE @combo CHAR(8);
    DECLARE @comboCantidad INTEGER;
    DECLARE @fact_tipo CHAR(1);
    DECLARE @fact_suc CHAR(4);
    DECLARE @fact_nro CHAR(8);

    DECLARE cFacturas CURSOR FOR
        SELECT f.fact_tipo, f.fact_sucursal, f.fact_numero
        FROM Factura f;

    OPEN cFacturas
    FETCH NEXT FROM cFacturas INTO @fact_tipo, @fact_suc, @fact_nro
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

                DECLARE cProducto CURSOR FOR
                SELECT c1.comp_producto
                FROM Item_factura i 
                INNER JOIN Composicion c1 ON i.item_producto = c1.comp_componente
                WHERE i.item_cantidad >= c1.comp_cantidad
                AND i.item_sucursal = @fact_suc
                AND i.item_numero = @fact_nro
                AND i.item_tipo = @fact_tipo
                GROUP BY c1.comp_producto
                HAVING COUNT(*) = (SELECT COUNT(*)
                                    FROM Composicion c2
                                    WHERE c2.comp_producto = c1.comp_producto)

                OPEN cProducto
                FETCH NEXT FROM cProducto INTO @combo
                WHILE @@FETCH_STATUS = 0
                BEGIN 

                    SELECT @comboCantidad = MIN(FLOOR((i.item_cantidad / c1.comp_cantidad)))
                    FROM Item_factura i
                    INNER JOIN Composicion c1 ON i.item_producto = c1.comp_componente
                    WHERE i.item_cantidad >= c1.comp_cantidad
                    AND i.item_sucursal = @fact_suc
                    AND i.item_numero = @fact_nro
                    AND i.item_tipo = @fact_tipo
                    AND c1.comp_producto = @combo

                    INSERT INTO Item_factura (item_tipo, item_sucursal, Item_factura, item_producto, item_cantidad, item_precio)
                    SELECT @fact_tipo, @fact_suc, @fact_nro, @combo, @comboCantidad, (@comboCantidad * (SELECT prod_precio FROM Producto WHERE prod_codigo = @combo))

                    UPDATE Item_factura
                    SET item_cantidad = i1.item_cantidad - (@comboCantidad * (SELECT comp_cantidad
                                                                                FROM Composicion
                                                                                WHERE comp_cantidad = @combo
                                                                                AND i1.item_producto = comp_componente)),
                    item_precio = (i1.item_cantidad - (@comboCantidad * (SELECT comp_cantidad
                                                                        FROM Composicion
                                                                        WHERE I1.item_producto = comp_componente
                                                                        AND comp_producto = @combo))) *
                                                                        (SELECT prod_precio 
                                                                        FROM Producto
                                                                        WHERE prod_codigo = i1.item_producto)
                    FROM Item_factura i1, Composicion c1
                    WHERE i1.item_sucursal = @fact_suc
                    AND i1.item_numero = @fact_nro 
                    AND i1.item_tipo = @fact_tipo
                    AND i1.item_producto = c1.comp_componente
                    AND c1.comp_producto = @combo


                    DELETE FROM Item_factura
                    WHERE item_sucursal = @fact_suc
                    AND item_numero = @fact_nro
                    AND item_tipo = @fact_tipo
                    AND item_cantidad = 0
            
                    FETCH NEXT FROM cProducto INTO @combo
                END;
                CLOSE cProducto;
                DEALLOCATE cProducto;

            COMMIT TRANSACTION;

        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;
        END CATCH;

        FETCH NEXT FROM cFacturas INTO @fact_tipo, @fact_suc, @fact_nro
    END;
    CLOSE cFacturas;
    DEALLOCATE cFacturas;
    
END;
GO



-- EJERCICIO 7

CREATE TABLE Ventas (
    codigo CHAR(8),
    detalle CHAR(50),
    cant_mov INTEGER,
    precio_de_venta DECIMAL(12,2),
    renglon INTEGER,
    ganancia DECIMAL(12,2)
)
GO

CREATE PROCEDURE PR_COMPLETAR_VENTAS
(@fechaInicio smalldatetime, @fechaFin smalldatetime)
AS
BEGIN

    INSERT INTO Ventas (codigo, detalle, cant_mov, precio_de_venta, renglon, ganancia)
    SELECT i.item_producto, 
            p.prod_detalle,
            COUNT(i.Item_factura),
            AVG(i.item_precio),
            ROW_NUMBER() OVER (ORDER BY i.item_producto),
            AVG(i.item_precio) - (SUM(i.item_cantidad) * p.prod_precio)
    FROM Item_factura i
    INNER JOIN Factura f ON f.fact_numero = i.item_numero
                        AND f.fact_tipo = i.item_tipo
                        AND f.fact_sucursal = i.item_sucursal
    INNER JOIN Producto p ON p.prod_codigo = i.item_producto
    WHERE f.fact_fecha >= @fechaInicio AND f.fact_fecha <= @fechaFin
    GROUP BY i.item_producto, p.prod_detalle

END;
GO



-- EJERCICIO 8

CREATE TABLE Diferencias (
        codigo CHAR(8),
        detalle CHAR(50),
        cantidad INTEGER,
        precio_generado DECIMAL(12,2),
        precio_facturado DECIMAL(12,2)
    )
GO

CREATE FUNCTION FN_CALCULAR_SUMA_COMPONENTES (@producto char(8))
RETURNS DECIMAL(12,2)
AS
    BEGIN

        DECLARE @suma DECIMAL(12,2)
        DECLARE @cantidad DECIMAL(12,2)
        DECLARE @componente CHAR(8)

        IF NOT EXISTS (SELECT 1 FROM Composicion WHERE comp_producto = @producto)
        BEGIN
            SET @suma = (SELECT ISNULL(prod_precio, 0) FROM Producto WHERE prod_codigo = @producto)
            RETURN @suma
        END;

        DECLARE cComponentes CURSOR FOR
        SELECT c.comp_componente, c.comp_cantidad
        FROM Componente c
        WHERE c.comp_producto = @producto

        SET @suma = 0

        FETCH NEXT FROM cComponentes INTO @componente, @cantidad

        WHILE @@FETCH_STATUS = 0
        BEGIN

            SET @suma = @suma + dbo.FN_CALCULAR_SUMA_COMPONENTES(@componente) * @cantidad

            FETCH NEXT FROM cComponentes INTO @componente, @cantidad

        END;
        CLOSE cComponentes;
        DEALLOCATE cComponentes;

        RETURN @suma
    END;
GO

CREATE PROCEDURE PR_TABLA_DIFERENCIA_PRECIO
AS
BEGIN 

    INSERT INTO Diferencias (codigo, detalle, cantidad, precio_generado, precio_facturado)
    SELECT p.prod_codigo,
            p.prod_detalle,
            COUNT(DISTINCT c.comp_componente),
            dbo.FN_CALCULAR_SUMA_COMPONENTES(p.prod_codigo),
            p.prod_precio
    FROM Producto p
    INNER JOIN Composicion c ON p.prod_codigo = c.comp_producto
    INNER JOIN Item_factura i ON p.prod_codigo = i.item_producto
    WHERE p.prod_precio <> dbo.FN_CALCULAR_SUMA_COMPONENTES(p.prod_codigo)
    GROUP BY p.prod_codigo, p.prod_detalle

END;
GO



-- EJERCICIO 9

CREATE TRIGGER TR_MODIFICACION_ITEM_COMPOSICION
ON Item_factura
AFTER UPDATE
AS
    BEGIN

    DECLARE @componente CHAR(8), @cantidad DECIMAL(12,2)

    DECLARE cComponentes CURSOR FOR 
    SELECT c.comp_componente, (i.item_cantidad - d.item_cantidad) * c.comp_cantidad
    FROM Composicion c 
    INNER JOIN inserted i ON c.comp_producto = i.item_producto
    INNER JOIN deleted d ON d.item_producto = i.item_producto
                        AND d.Item_factura = i.Item_factura
                        AND d.item_tipo = i.item_tipo
                        AND d.item_sucursal = i.item_sucursal
    WHERE i.item_cantidad > d.item_cantidad

    OPEN cComponentes
    FETCH NEXT FROM cComponentes INTO @componente, @cantidad
    WHILE @@FETCH_STATUS = 0
    BEGIN

        UPDATE Stock SET stoc_cantidad = stoc_cantidad - @cantidad
        WHERE stoc_producto = @producto
        AND stoc_deposito = (SELECT TOP 1 stoc_deposito 
                                FROM Stock 
                                WHERE stoc_producto = @componente
                                ORDER BY stoc_cantidad DESC)

        FETCH NEXT FROM cComponentes INTO @componente, @cantidad

    END;
    CLOSE cComponentes;
    DEALLOCATE cComponentes;

    END;
GO



-- EJERCICIO 10
CREATE TRIGGER TR_PRODUCTO_BORRADO
ON Producto
INSTEAD OF DELETE
AS
BEGIN

    DECLARE @prod_borrado CHAR(8)

    SELECT @prod_borrado = d.prod_codigo
    FROM deleted d

    IF EXISTS (SELECT 1 
                    FROM Stock 
                    WHERE stoc_producto = @prod_borrado
                    AND ISNULL(stoc_cantidad, 0) != 0)
        BEGIN
            ROLLBACK TRANSACTION
            PRINT 'ERROR AL BORRAR PRODUCTO PORQUE AUN TIENE STOCK'
            RETURN
        END;

    DELETE Stock WHERE stoc_producto = @prod_borrado
    DELETE Producto WHERE prod_codigo = @prod_borrado

END;
GO



-- EJERCICIO 11
CREATE FUNCTION FN_EMPLEADOS_A_CARGO
(@empleado numeric(6))
RETURNS INTEGER
AS
BEGIN

    DECLARE @retorno INTEGER
    DECLARE @empl_a_cargo NUMERIC(6)

    IF NOT EXISTS (SELECT 1 FROM Empleados e WHERE e.empl_jefe = @empleado)
        BEGIN
            SET @retorno = 0
            RETURN @retorno
        END;

    DECLARE cEmpleados CURSOR FOR
    SELECT e.empl_codigo
    FROM Empleados e 
    WHERE e.empl_jefe = @empleado
    AND e.empl_codigo > e.empl_jefe

    SET @retorno = 0

    OPEN cEmpleados
    FETCH NEXT INTO @empl_a_cargo
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @retorno = @retorno + 1 + dbo.FN_EMPLEADOS_A_CARGO(@empl_a_cargo)
        FETCH NEXT INTO @empl_a_cargo
    END;
    CLOSE cEmpleados
    DEALLOCATE cEmpleados

    RETURN @retorno

END;
GO