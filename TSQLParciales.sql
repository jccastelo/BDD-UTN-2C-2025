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




-- 2024 2C 16/11

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



-- 2C2024 16/11

CREATE TABLE Productos_mas_vendidos (
    anio INT,
    posicion INT,
    prod_codigo CHAR(8),
    cantidad_vendida DECIMAL(12,2)
)
GO

CREATE TRIGGER TR_PRODS_MAS_VENDIDOS
ON Item_factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN

    DECLARE @anio INT

    DECLARE cAnios CURSOR FOR
    SELECT DISTINCT YEAR(f.fact_fecha)
    FROM Factura f
    WHERE YEAR(f.fact_fecha) IN (SELECT YEAR(f2.fact_fecha)
                                FROM inserted i 
                                INNER JOIN Factura f2 ON i.item_numero = f2.fact_numero
                                                        AND i.item_tipo = f2.fact_tipo
                                                        AND i.item_sucursal = f2.fact_sucursal)
    OR YEAR(f.fact_fecha) IN (SELECT YEAR(f3.fact_fecha)
                                FROM deleted d
                                INNER JOIN Factura f3 ON d.item_numero = f3.fact_numero
                                                        AND d.item_tipo = f3.fact_tipo
                                                        AND d.item_sucursal = f3.fact_sucursal)

    OPEN cAnios
    FETCH NEXT INTO @anio
    WHILE @@FETCH_STATUS = 0
    BEGIN

        DELETE FROM Productos_mas_vendidos WHERE anio = @anio

        INSERT INTO Productos_mas_vendidos (anio, posicion, prod_codigo, cantidad_vendida)
        SELECT TOP 10 YEAR(f.fact_fecha) AS anio,
                        ROW_NUMBER() OVER (ORDER BY SUM(i.item_cantidad) DESC) AS posicion,
                        i.item_producto, 
                        SUM(i.item_cantidad)
        FROM Item_factura i
        INNER JOIN Factura f ON f.fact_numero = i.item_numero
                            AND f.fact_tipo = i.item_tipo
                            AND f.fact_sucursal = i.item_sucursal
        WHERE YEAR(f.fact_fecha) = @anio
        GROUP BY i.item_producto, YEAR(f.fact_fecha)

        FETCH NEXT INTO @anio

    END;
    CLOSE cAnios
    DEALLOCATE cAnios

END;
GO



-- 2C2024 20/11

CREATE PROCEDURE PR_REORGANIZAR_VENTAS_COMPUESTOS
AS
BEGIN

    DECLARE @producto CHAR(8), @numero CHAR(8), @sucursal CHAR(4), @tipo CHAR(1), @cantidad DECIMAL(12,2)

    DECLARE cItems CURSOR FOR
    SELECT i.item_producto, 
            i.item_numero, 
            i.item_sucursal, 
            i.item_tipo,
            i.item_cantidad
    FROM Item_Factura i 
    INNER JOIN Composicion c ON i.item_producto = c.comp_producto
    GROUP BY i.item_producto, i.item_numero, i.item_sucursal, i.item_tipo, i.item_cantidad

    OPEN cItems
    FETCH NEXT INTO @producto, @numero, @sucursal, @tipo, @cantidad
    WHILE @@FETCH_STATUS = 0
    BEGIN

        BEGIN TRANSACTION

            INSERT INTO Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
            SELECT @tipo,
                    @sucursal,
                    @numero,
                    p.prod_codigo,
                    c.comp_cantidad * @cantidad,
                    p.prod_precio
            FROM Composicion c
            INNER JOIN Producto p ON p.prod_codigo = c.comp_componente
            WHERE c.comp_producto = @producto

            DELETE FROM Item_Factura WHERE item_numero = @numero 
            AND item_tipo = @tipo 
            AND item_sucursal = @sucursal
            AND item_producto = @producto

        COMMIT TRANSACTION

        FETCH NEXT INTO @producto, @numero, @sucursal, @tipo, @cantidad
    END;
    CLOSE cItems
    DEALLOCATE cItems

END;
GO



-- 2C2024 23/11

CREATE TABLE Registro_factura (
    fact_numero CHAR(8),
    fact_sucursal CHAR(4),
    fact_tipo CHAR(1),
    fact_estado CHAR(8),
    fecha_registro DATETIME

    FOREIGN KEY (fact_tipo, fact_sucursal, fact_numero) 
    REFERENCES Factura(fact_tipo, fact_sucursal, fact_numero)
)
GO

CREATE TRIGGER TR_REGISTRAR_FACTURA
ON Factura 
AFTER INSERT, UPDATE, DELETE
AS
BEGIN

    DECLARE @fecha DATETIME = GETDATE()

    CREATE TABLE #Facturas_invalidas (
        fact_numero CHAR(8),
        fact_sucursal CHAR(4),
        fact_tipo CHAR(1)
    )

    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
    BEGIN

        INSERT INTO #Facturas_invalidas (fact_numero, fact_sucursal, fact_tipo)
        SELECT d.fact_numero,
                d.fact_sucursal,
                d.fact_tipo
        FROM deleted d
        WHERE d.fact_numero+d.fact_sucursal+d.fact_tipo NOT IN (SELECT i.fact_numero+i.fact_sucursal+i.fact_tipo
                                                                FROM inserted i)

    END;

    IF EXISTS (SELECT 1 
                FROM inserted f 
                INNER JOIN Item_Factura i ON f.fact_numero = i.item_numero
                                            AND f.fact_sucursal = i.item_sucursal
                                            AND f.fact_tipo = i.item_tipo
                GROUP BY f.fact_numero, f.fact_tipo, f.fact_sucursal, f.fact_total
                HAVING f.fact_total <> SUM(i.item_cantidad * i.item_precio))
    BEGIN

        INSERT INTO #Facturas_invalidas (fact_numero, fact_sucursal, fact_tipo)
        SELECT f.fact_numero,
                f.fact_sucursal,
                f.fact_tipo
        FROM inserted f 
        INNER JOIN Item_Factura i ON f.fact_numero = i.item_numero
                                    AND f.fact_sucursal = i.item_sucursal
                                    AND f.fact_tipo = i.item_tipo
        GROUP BY f.fact_numero, f.fact_tipo, f.fact_sucursal, f.fact_total
        HAVING f.fact_total <> SUM(i.item_cantidad * i.item_precio)

    END;

    IF EXISTS (SELECT 1 FROM inserted WHERE fact_fecha < GETDATE())
    BEGIN

        INSERT INTO #Facturas_invalidas (fact_numero, fact_sucursal, fact_tipo)
        SELECT f.fact_numero,
                f.fact_sucursal,
                f.fact_tipo
        FROM inserted f 
        WHERE fact_fecha < GETDATE()

    END;

    INSERT INTO Registro_factura (fact_numero, fact_sucursal, fact_tipo, fact_estado, fecha_registro)
    SELECT f.fact_numero,
            f.fact_sucursal,
            f.fact_tipo,
            'INVALIDO',
            @fecha
    FROM #Facturas_invalidas f

    INSERT INTO Registro_factura (fact_numero, fact_sucursal, fact_tipo, fact_estado, fecha_registro)
    SELECT i.fact_numero,
            i.fact_sucursal,
            i.fact_tipo,
            'VALIDO',
            @fecha
    FROM inserted i
    WHERE i.fact_numero+i.fact_sucursal+i.fact_tipo NOT IN (SELECT f.fact_numero+f.fact_sucursal+f.fact_tipo
                                                            FROM #Facturas_invalidas f)

END;
GO