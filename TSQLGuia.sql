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