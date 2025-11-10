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
    INNER JOIN Factura f ON i.item_numero = f.fact_numero
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

    DECLARE @empl_mayor_salario numeric(6)

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

                    INSERT INTO Item_factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
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
            COUNT(i.item_numero),
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
        FROM Composicion c
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

    DECLARE @componente CHAR(8), @cantidad DECIMAL(12,2), @producto CHAR(8)

    DECLARE cComponentes CURSOR FOR 
    SELECT c.comp_componente, (i.item_cantidad - d.item_cantidad) * c.comp_cantidad
    FROM Composicion c 
    INNER JOIN inserted i ON c.comp_producto = i.item_producto
    INNER JOIN deleted d ON d.item_producto = i.item_producto
                        AND d.item_numero = i.item_numero
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

    IF NOT EXISTS (SELECT 1 FROM Empleado e WHERE e.empl_jefe = @empleado)
        BEGIN
            SET @retorno = 0
            RETURN @retorno
        END;

    DECLARE cEmpleados CURSOR FOR
    SELECT e.empl_codigo
    FROM Empleado e 
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



-- EJERCICIO 12

CREATE TRIGGER TR_NO_AUTO_COMPOSICION
ON Composicion
AFTER INSERT, UPDATE
AS 
BEGIN
    IF UPDATE(comp_producto) OR UPDATE(comp_componente)
    BEGIN

        DECLARE @cantidad INT = 1;
        DECLARE @nivel INT = 0;

        CREATE TABLE #tr_composicion (
            componente CHAR(8),
            nivel INT
        )

        IF EXISTS (SELECT 1 FROM inserted WHERE comp_producto = comp_componente)
        BEGIN
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        INSERT INTO #tr_composicion (componente, nivel)
        SELECT comp_componente, @nivel
        FROM inserted

        WHILE @cantidad > 0
        BEGIN

            INSERT INTO #tr_composicion (componente, nivel)
            SELECT c.comp_componente, @nivel + 1
            FROM Composicion c
            INNER JOIN #tr_composicion t ON t.componente = c.comp_producto
            AND t.nivel = @nivel

            SET @nivel = @nivel + 1
            SET @cantidad = @@ROWCOUNT

        END;

        IF EXISTS (SELECT 1 FROM inserted i INNER JOIN #tr_composicion t ON i.comp_producto = t.componente)
        BEGIN
            ROLLBACK TRANSACTION;
            RETURN;
        END;
    END;
END;
GO



-- EJERCICIO 13

CREATE FUNCTION FN_SUMA_SALARIO_EMPLEADOS (@jefe NUMERIC(6))
RETURNS DECIMAL(12,2)
AS
BEGIN

    DECLARE @retorno DECIMAL(12,2)
    DECLARE @empl_a_cargo NUMERIC(6)
    DECLARE @salario_actual DECIMAL(12,2)

    IF NOT EXISTS (SELECT 1 FROM Empleado e WHERE e.empl_jefe = @jefe)
        BEGIN
            SET @retorno = 0
            RETURN @retorno
        END;

    DECLARE cEmpleados CURSOR FOR
    SELECT e.empl_codigo, e.empl_salario
    FROM Empleado e 
    WHERE e.empl_jefe = @jefe

    SET @retorno = 0

    OPEN cEmpleados
    FETCH NEXT INTO @empl_a_cargo, @salario_actual
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @retorno = @retorno 
                    + @salario_actual
                    + dbo.FN_SUMA_SALARIO_EMPLEADOS(@empl_a_cargo)
        FETCH NEXT INTO @empl_a_cargo, @salario_actual
    END;
    CLOSE cEmpleados
    DEALLOCATE cEmpleados

    RETURN @retorno

END;
GO

CREATE TRIGGER TR_TOPE_SALARIAL_JEFE
ON Empleado
AFTER INSERT, UPDATE
AS 
BEGIN
    IF UPDATE(empl_salario) OR UPDATE(empl_jefe)
    BEGIN

        IF EXISTS (SELECT 1 FROM inserted i WHERE i.empl_salario > 0.2 * dbo.FN_SUMA_SALARIO_EMPLEADOS(i.empl_codigo))
        BEGIN
            ROLLBACK TRANSACTION;
            RETURN;
        END;
    END;
END;
GO


-- EJERCICIO 14

CREATE FUNCTION FN_SUMA_PROD_COMPUESTOS (@producto CHAR(8))
RETURNS DECIMAL(12,2)
AS
BEGIN

    DECLARE @retorno DECIMAL(12,2)

    IF @producto NOT IN (SELECT c.comp_producto FROM Composicion c)
    BEGIN
        RETURN 0
    END;

    SELECT @retorno = SUM(p.prod_precio)
    FROM Composicion c 
    INNER JOIN Producto p ON p.prod_codigo = c.comp_componente
    WHERE c.comp_producto = @producto
    GROUP BY c.comp_producto

    RETURN @retorno


END;
GO

CREATE TRIGGER TR_PRECIO_PROD_COMPUESTO
ON Item_factura
AFTER INSERT
AS
BEGIN

    DECLARE @prod_comprado CHAR(8)
    DECLARE @fecha SMALLDATETIME, @cliente CHAR(6), @precio DECIMAL(12,2)

    DECLARE cProducto CURSOR FOR
    SELECT  i.item_producto,
            f.fact_fecha,
            f.fact_cliente,
            i.item_precio * i.item_cantidad
    FROM inserted i
    INNER JOIN Composicion c ON c.comp_producto = item_producto
    INNER JOIN Factura f ON f.fact_numero + f.fact_tipo + f.fact_sucursal = i.item_numero + i.item_tipo + i.item_sucursal
    WHERE i.item_precio < dbo.FN_CALCULAR_SUMA_COMPONENTES(i.item_producto)

    OPEN cProducto
    FETCH NEXT INTO @prod_comprado, @fecha, @cliente, @precio
    WHILE @@FETCH_STATUS = 0
    BEGIN

        IF @precio < 0.5 * dbo.FN_CALCULAR_SUMA_COMPONENTES(@prod_comprado)
        BEGIN
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        PRINT 'FECHA: ' + CONVERT(VARCHAR, @fecha, 103)
                + 'CLIENTE: ' + @cliente
                + 'PRODUCTO: ' + @producto
                + 'PRECIO: ' + CAST(@precio AS VARCHAR)
        FETCH NEXT INTO @prod_comprado, @fecha, @cliente, @precio
    END;
    CLOSE cEmpleados
    DEALLOCATE cEmpleados

END;
GO



-- EJERCICIO 15

--TRAIGO LA FUNCION DE OTRO EJERCICIO FN_CALCULAR_SUMA_COMPONENTES

CREATE FUNCTION FN_PRECIO_PRODUCTO (@producto CHAR(8))
RETURNS DECIMAL(12,2)
AS
BEGIN

    DECLARE @precio DECIMAL(12,2)

    SELECT @precio = prod_precio
    FROM Producto
    WHERE prod_codigo = @producto

    IF @producto IN (SELECT comp_producto FROM Composicion)
    BEGIN
        SET @precio = dbo.FN_CALCULAR_SUMA_COMPONENTES(@producto)
    END;

    RETURN @precio

END;
GO



-- EJERCICIO 16

CREATE TRIGGER TR_DESCONTAR_STOCK_VENTA
ON Item_factura
AFTER INSERT
AS
BEGIN

    DECLARE @prod_vendido CHAR(8), @cantidad DECIMAL(12,2)
    DECLARE @deposito CHAR(2), @cantidad_deposito DECIMAL(12,2), @ultimo_deposito CHAR(2)

    DECLARE cProducto CURSOR FOR
    SELECT i.item_producto, 
            SUM(i.item_cantidad)
    FROM inserted i
    GROUP BY i.item_producto

    OPEN cProducto
    FETCH NEXT INTO @prod_vendido, @cantidad
    WHILE @@FETCH_STATUS = 0
    BEGIN

        DECLARE cStock CURSOR FOR
        SELECT s.stoc_deposito,
                s.stoc_cantidad
        FROM Stock s
        WHERE s.stoc_producto = @prod_vendido
        ORDER BY s.stoc_cantidad DESC

        OPEN cStock
        FETCH NEXT INTO @deposito, @cantidad_deposito
        WHILE @@FETCH_STATUS = 0 AND @cantidad > 0
        BEGIN

            SET @ultimo_deposito = @deposito

            IF @cantidad_deposito >= @cantidad
            BEGIN
                SET @cantidad_deposito = @cantidad_deposito - @cantidad
                SET @cantidad = 0
            END;
            ELSE
            BEGIN
                SET @cantidad = @cantidad - @cantidad_deposito
                SET @cantidad_deposito = 0
            END;

            UPDATE Stock
            SET stoc_cantidad = @cantidad_deposito
            WHERE stoc_deposito = @deposito AND stoc_producto = @prod_vendido

            FETCH NEXT INTO @deposito, @cantidad_deposito

        END;

        IF @cantidad > 0
        BEGIN
            UPDATE Stock 
            SET stoc_cantidad = stoc_cantidad - @cantidad
            WHERE stoc_deposito = @ultimo_deposito AND stoc_producto = @prod_vendido
        END;

        CLOSE cStock
        DEALLOCATE cStock

        FETCH NEXT INTO @prod_vendido, @cantidad
    END;
    CLOSE cProducto
    DEALLOCATE cProducto

END;
GO



-- EJERCICIO 17

CREATE TRIGGER TR_STOCK_MAX_MIN
ON Stock
AFTER INSERT, UPDATE
AS
BEGIN

    IF UPDATE(stoc_cantidad)
        BEGIN

        IF EXISTS (SELECT 1 FROM inserted i WHERE i.stoc_cantidad < i.stoc_punto_reposicion
                                                OR i.stoc_cantidad > i.stoc_stock_maximo)
        BEGIN
            ROLLBACK TRANSACTION;
            RETURN;
        END;

    END;

END;
GO



-- EJERCICIO 18

CREATE TRIGGER TR_MONTO_MAXIMO_CLIENTE
ON Factura 
AFTER INSERT
AS
BEGIN

    IF EXISTS (SELECT 1
                FROM inserted f 
                INNER JOIN Cliente c ON c.clie_codigo = f.fact_cliente
                GROUP BY f.fact_cliente, MONTH(f.fact_fecha), YEAR(f.fact_fecha), c.clie_limite_credito
                HAVING c.clie_limite_credito < (SELECT SUM(f2.fact_total)
                                                FROM Factura f2
                                                WHERE f2.fact_cliente = f.fact_cliente
                                                AND YEAR(f2.fact_fecha) = YEAR(f.fact_fecha)
                                                AND MONTH(f2.fact_fecha) = MONTH(f.fact_fecha)))
    BEGIN
        ROLLBACK TRANSACTION;
        RETURN;
    END;
    
END;
GO



-- EJERCICIO 19

CREATE TRIGGER TR_JEFE_ANTIGUEDAD_PERSONAL
ON Empleado
AFTER INSERT, UPDATE
AS
BEGIN

    CREATE TABLE #Jefe (
        codigo NUMERIC(6)
    )

    INSERT INTO #Jefe (codigo)
    SELECT DISTINCT j.empl_codigo
    FROM Empleado j
    INNER JOIN Empleado e ON e.empl_jefe = j.empl_codigo

    IF EXISTS (SELECT 1 FROM inserted WHERE empl_codigo IN (SELECT codigo FROM #Jefe)
                                            AND DATEDIFF(YEAR, empl_ingreso, GETDATE()) < 5)
    BEGIN
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM inserted WHERE empl_codigo IN (SELECT codigo FROM #Jefe)
                                            AND dbo.FN_EMPLEADOS_A_CARGO(empl_codigo) > 0.5 * (SELECT COUNT(*) FROM Empleado)
                                            AND empl_jefe IS NOT NULL)
    BEGIN
        ROLLBACK TRANSACTION;
        RETURN;
    END;
    
END;
GO


-- EJERCICIO 20
CREATE PROCEDURE PR_COMISION_VENDEDOR
AS
BEGIN

    DECLARE @mes_actual INT = MONTH(GETDATE()), @anio_actual INT = YEAR(GETDATE())
    DECLARE @empleado NUMERIC(6), @ventas_mes DECIMAL(12,2), @cant_prod_distintos INT

    DECLARE cFactura CURSOR FOR
    SELECT f.fact_vendedor,
            SUM(i.item_cantidad * i.item_precio),
            COUNT(DISTINCT i.item_producto)
    FROM Factura f
    INNER JOIN Item_Factura i ON f.fact_numero + f.fact_sucursal + f.fact_tipo = i.item_numero + i.item_sucursal + i.item_tipo
    WHERE MONTH(f.fact_fecha) = @mes_actual AND YEAR(f.fact_fecha) = @anio_actual
    GROUP BY f.fact_vendedor, MONTH(f.fact_fecha), YEAR(f.fact_fecha)

    BEGIN TRANSACTION
    
        OPEN cFactura
        FETCH NEXT INTO @empleado, @ventas_mes, @cant_prod_distintos
        WHILE @@FETCH_STATUS = 0
        BEGIN

            DECLARE @comision DECIMAL(12,2)

            SET @comision = @ventas_mes * 0.05

            IF @cant_prod_distintos >= 50
            BEGIN
                SET @comision = @comision * 1.03
            END;

            UPDATE Empleado
            SET empl_comision = @comision
            WHERE empl_codigo = @empleado

            FETCH NEXT INTO @empleado, @ventas_mes, @cant_prod_distintos
        END;
        CLOSE cFactura
        DEALLOCATE cFactura
    COMMIT TRANSACTION
END;
GO



-- EJERCICIO 21

CREATE FUNCTION FN_FAMILIA_PRODUCTO (@producto CHAR(8))
RETURNS CHAR(3)
AS
BEGIN

    DECLARE @familia CHAR(3)

    SELECT @familia = p.prod_familia
    FROM Producto p 
    WHERE p.prod_codigo = @producto

    RETURN @familia

END;
GO

CREATE TRIGGER TR_PROD_DISTINTA_FAMILIA
ON Item_Factura
AFTER INSERT
AS
BEGIN

    IF EXISTS (SELECT 1
                FROM inserted i
                INNER JOIN Item_Factura i2 ON i.item_numero = i2.item_numero
                                            AND i.item_sucursal = i2.item_sucursal
                                            AND i.item_tipo = i2.item_tipo
                                            AND i.item_producto <> i2.item_producto
                WHERE dbo.FN_FAMILIA_PRODUCTO(i.item_producto) <> dbo.FN_FAMILIA_PRODUCTO(i2.item_producto))
    BEGIN
        ROLLBACK TRANSACTION;
        RETURN;
    END;

END;
GO



-- EJERCICIO 22
-- RUBRO MAX 20 PROD
-- > 20 => A OTRO CON MENOS
-- TODOS 20 => CREO RUBRO REASIGNADO

CREATE PROCEDURE PR_RECATEGORIZAR_RUBROS
AS
BEGIN

    DECLARE @rubro CHAR(4), @cantidad_productos INT
    DECLARE @nuevo_rubro CHAR(4), @nueva_cantidad INT
    DECLARE @producto CHAR(8)

    DECLARE cRubro CURSOR FOR
    SELECT p.prod_rubro,
            COUNT(DISTINCT p.prod_codigo)
    FROM Producto p 
    GROUP BY p.prod_rubro
    HAVING COUNT(DISTINCT p.prod_codigo) > 20

    SELECT TOP 1 @nuevo_rubro = p.prod_rubro,
                            @nueva_cantidad = COUNT(DISTINCT p.prod_codigo)
                FROM Producto p 
                GROUP BY p.prod_rubro 
                ORDER BY COUNT(DISTINCT p.prod_codigo) ASC

    OPEN cRubro
    FETCH NEXT INTO @rubro, @cantidad_productos
    WHILE @@FETCH_STATUS = 0
    BEGIN

        DECLARE cProducto CURSOR FOR
        SELECT p.prod_codigo
        FROM Producto p 
        WHERE p.prod_rubro = @rubro

        OPEN cProducto
        FETCH NEXT INTO @producto
        WHILE @@FETCH_STATUS = 0 AND @cantidad_productos > 20
        BEGIN

            UPDATE Producto
            SET prod_rubro = @nuevo_rubro
            WHERE prod_codigo = @producto

            SET @cantidad_productos = @cantidad_productos -1
            SET @nueva_cantidad = @nueva_cantidad + 1

            IF @nueva_cantidad > 20
            BEGIN
                SELECT TOP 1 @nuevo_rubro = p.prod_rubro,
                            @nueva_cantidad = COUNT(DISTINCT p.prod_codigo)
                FROM Producto p 
                GROUP BY p.prod_rubro 
                ORDER BY COUNT(DISTINCT p.prod_codigo) ASC

                IF @nueva_cantidad > 20
                BEGIN
                    INSERT Rubro (rubr_id, rubr_detalle)
                    VALUES('RRAA','RUBRO REASIGNADO')

                    SET @nuevo_rubro = 'RRAA'
                    SET @nueva_cantidad = 0
                END;
            END;
            FETCH NEXT INTO @producto
        END;
        CLOSE cProducto
        DEALLOCATE cProducto

        FETCH NEXT INTO @rubro, @cantidad_productos
    END;
    CLOSE cRubro
    DEALLOCATE cRubro

END;
GO




-- EJERCICIO 23
CREATE TRIGGER TR_NO_COMPOSICION 
ON Item_Factura
AFTER INSERT
AS
BEGIN

    IF (SELECT COUNT(DISTINCT i.item_producto) 
        FROM inserted i 
        INNER JOIN Composicion c ON c.comp_producto = i.item_producto
        GROUP BY i.item_numero, i.item_sucursal, i.item_tipo) > 2
    BEGIN
    ROLLBACK TRANSACTION
    RETURN
    END;

END;
GO



-- EJERCICIO 24

CREATE FUNCTION FN_EMPLEADO_MENOS_DEPOSITOS (@zona CHAR(3))
RETURNS NUMERIC(6)
AS
BEGIN

    DECLARE @empleado NUMERIC(6)
    DECLARE @departamento NUMERIC(6)

    SELECT @departamento = de.depa_codigo
    FROM Departamento de
    WHERE de.depa_zona = @zona

    SELECT TOP 1 @empleado = e.empl_codigo
    FROM Empleado e
    INNER JOIN Deposito d ON d.depo_encargado = e.empl_codigo
    WHERE e.empl_departamento = @departamento AND d.depo_zona = @zona
    GROUP BY e.empl_codigo
    ORDER BY COUNT(DISTINCT d.depo_codigo) ASC

    RETURN @empleado


END;
GO

CREATE PROCEDURE PR_REASIGNAR_DEPOSITOS
AS
BEGIN

    DECLARE @deposito CHAR(2), @zona CHAR(3)

    DECLARE cDeposito CURSOR FOR
    SELECT d.depo_codigo,
            d.depo_zona
    FROM Deposito d 
    INNER JOIN Empleado e ON e.empl_codigo = d.depo_encargado
    WHERE d.depo_zona NOT IN (SELECT de.depa_zona 
                                FROM Departamento de 
                                WHERE de.depa_codigo = e.empl_departamento)

    OPEN cDeposito
    FETCH NEXT INTO @deposito, @zona
    WHILE @@FETCH_STATUS = 0
    BEGIN

        UPDATE Deposito 
        SET depo_encargado = dbo.FN_EMPLEADO_MENOS_DEPOSITOS(@zona)
        WHERE depo_codigo = @deposito

        FETCH NEXT INTO @deposito, @zona
    END;
    CLOSE cDeposito
    DEALLOCATE cDeposito

END;
GO



-- EJERCICIO 25

CREATE TRIGGER TR_NO_COMPOSICION_RECURSIVA
ON Composicion
AFTER INSERT, UPDATE
AS
BEGIN

    IF UPDATE(comp_producto) OR UPDATE(comp_componente)
    BEGIN

        IF EXISTS (SELECT 1
                    FROM inserted i
                    INNER JOIN Composicion c ON c.comp_producto = i.comp_componente
                                            AND c.comp_componente = i.comp_producto)
        BEGIN
            ROLLBACK TRANSACTION;
            RETURN;
        END;

    END;

END;
GO



-- EJERCICIO 26

CREATE TRIGGER TR_NO_COMPOSICION_FACTURA
ON Item_factura
AFTER INSERT
AS
BEGIN

    IF EXISTS (SELECT 1
                FROM inserted i
                INNER JOIN Composicion c ON i.item_producto = c.comp_componente
                WHERE c.comp_producto IN (SELECT i2.item_producto
                                            FROM Item_Factura i2
                                            WHERE i2.item_numero = i.item_numero
                                            AND i2.item_sucursal = i.item_sucursal
                                            AND i2.item_tipo = i.item_tipo))
    BEGIN
        ROLLBACK TRANSACTION
        PRINT 'NO SE PUEDEN FACTURAR PRODUCTOS QUE COMPONEN OTROS EN LA MISMA FACTURA'
        RETURN;
    END;
END;
GO



-- EJERCICIO 27

CREATE FUNCTION FN_OBTENER_NUEVO_ENCARGADO ()
RETURNS NUMERIC(6)
AS
BEGIN

    DECLARE @nuevo_encargado NUMERIC(6)

    SELECT TOP 1 @nuevo_encargado = e.empl_codigo
    FROM Empleado e 
    LEFT OUTER JOIN Deposito d ON d.depo_encargado = e.empl_codigo
    WHERE e.empl_codigo NOT IN (SELECT DISTINCT e2.empl_jefe
                                FROM Empleado e2
                                WHERE e2.empl_jefe IS NOT NULL)
        AND e.empl_codigo NOT IN (SELECT DISTINCT c.clie_vendedor
                                    FROM Cliente c
                                    WHERE c.clie_vendedor IS NOT NULL)
    GROUP BY e.empl_codigo
    ORDER BY COUNT(DISTINCT d.depo_codigo) ASC

    RETURN @nuevo_encargado

END;
GO

CREATE PROCEDURE PR_REASIGNAR_DEPOSITOS_2
AS
BEGIN

    DECLARE @deposito CHAR(2)

    DECLARE cDepositos CURSOR FOR
    SELECT d.depo_codigo
    FROM Deposito d

    OPEN cDepositos
    FETCH NEXT INTO @deposito
    WHILE @@FETCH_STATUS = 0
    BEGIN

        UPDATE Deposito 
        SET depo_encargado = dbo.FN_OBTENER_NUEVO_ENCARGADO()
        WHERE depo_codigo = @deposito

        FETCH NEXT INTO @deposito

    END;
    CLOSE cDepositos
    DEALLOCATE cDepositos

END;
GO



-- EJERCICIO 28
CREATE PROCEDURE PR_REASIGNAR_VENDEDOR
AS
BEGIN

    DECLARE @nuevo_vendedor NUMERIC(6), @cliente CHAR(6)
    DECLARE @mejor_vendedor NUMERIC(6)

    DECLARE cCliente CURSOR FOR
    SELECT c.clie_codigo
    FROM Cliente c

    SELECT TOP 1 @mejor_vendedor = f.fact_vendedor
    FROM Factura f
    GROUP BY f.fact_vendedor
    ORDER BY SUM(f.fact_total) DESC

    OPEN cCliente
    FETCH NEXT INTO @cliente
    WHILE @@FETCH_STATUS = 0
    BEGIN

        IF @cliente NOT IN (SELECT f.fact_cliente FROM Factura f)
        BEGIN
            SET @nuevo_vendedor = @mejor_vendedor
        END;
        ELSE
        BEGIN
            SELECT TOP 1 @nuevo_vendedor = f.fact_vendedor
            FROM Factura f 
            WHERE f.fact_cliente = @cliente
            GROUP BY f.fact_vendedor, f.fact_cliente
            ORDER BY COUNT(DISTINCT f.fact_numero + f.fact_tipo + f.fact_sucursal) DESC
        END;

        UPDATE Cliente
        SET clie_vendedor = @nuevo_vendedor
        WHERE clie_codigo = @cliente

        FETCH NEXT INTO @cliente
    END;

END;
GO



-- EJERCICIO 29

CREATE TRIGGER TR_COMPOSICION_PROD_DIFERENTES
ON Item_Factura
AFTER INSERT
AS
BEGIN

    IF EXISTS (SELECT i.item_producto
                FROM inserted i
                INNER JOIN Composicion c ON i.item_producto = c.comp_componente
                GROUP BY i.item_producto
                HAVING COUNT(DISTINCT c.comp_componente) > 1)
    BEGIN

        PRINT 'ERROR: UNA FACTURA NO PUEDE CONTENER UN PRODUCTO QUE COMPONGA A MÁS DE UN PRODUCTO DIFERENTE'
        ROLLBACK TRANSACTION;
        RETURN;

    END;

END;
GO



-- EJERCICIO 30

CREATE TRIGGER TR_LIMITE_PRODUCTOS
ON Item_Factura
AFTER INSERT, UPDATE
AS
BEGIN

    IF UPDATE(item_cantidad)
    BEGIN

        IF EXISTS (SELECT 1
            FROM inserted i
            INNER JOIN Item_Factura i2 ON i.item_producto = i2.item_producto
            AND i.item_numero + i.item_sucursal + i.item_tipo <> i2.item_numero + i2.item_sucursal + i2.item_tipo
            INNER JOIN Factura f ON i.item_numero + i.item_sucursal + i.item_tipo <> f.fact_numero + f.fact_sucursal + f.fact_tipo
            WHERE YEAR(f.fact_fecha) = YEAR(GETDATE()) AND MONTH(f.fact_fecha) = MONTH(GETDATE())
            GROUP BY i.item_producto, f.fact_cliente
            HAVING SUM(i.item_cantidad) > 100)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'Se ha superado el limite maximo de compra de un producto'
            RETURN;
        END;
    END;
END;
GO



-- EJERCICIO 31

CREATE TRIGGER TR_LIMITE_EMPLEADOS
ON Empleado
AFTER INSERT, UPDATE
AS
BEGIN

    IF UPDATE(empl_jefe)
    BEGIN

        DECLARE @empleado NUMERIC(6)
        DECLARE @nuevo_jefe NUMERIC(6)
        DECLARE @gerente NUMERIC(6)

        SELECT @gerente = e.empl_codigo
                FROM Empleado e
                WHERE e.empl_jefe IS NULL

        DECLARE cEmpleados CURSOR FOR
        SELECT e.empl_codigo
        FROM inserted e 
        WHERE dbo.FN_EMPLEADOS_A_CARGO(e.empl_jefe) >= 20

        OPEN cEmpleados
        FETCH NEXT INTO @empleado
        WHILE @@FETCH_STATUS = 0
        BEGIN

            SELECT TOP 1 @nuevo_jefe = e.empl_codigo
            FROM Empleado e
            WHERE dbo.FN_EMPLEADOS_A_CARGO(e.empl_codigo) < 20
            AND e.empl_codigo <> @empleado

            IF @nuevo_jefe IS NULL
            BEGIN
                SET @nuevo_jefe = @gerente
            END;

            UPDATE Empleado
            SET empl_jefe = @nuevo_jefe
            WHERE empl_codigo = @empleado

            FETCH NEXT INTO @empleado
        END;
        CLOSE cEmpleados
        DEALLOCATE cEmpleados
    END;
END;
GO