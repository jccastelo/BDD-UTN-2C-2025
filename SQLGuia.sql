-- EJERCICIO 1
SELECT c.clie_codigo, c.clie_razon_social, c.clie_limite_credito
FROM Cliente c
WHERE c.clie_limite_credito >= 1000
ORDER BY 1 ASC


-- EJERCICIO 2
SELECT p.prod_codigo, p.prod_detalle, SUM(i.item_cantidad) as cantidad_vendida
FROM Producto p
INNER JOIN item_Factura i ON p.prod_codigo = i.item_producto
INNER JOIN  Factura f ON i.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY p.prod_codigo, p.prod_detalle
ORDER BY cantidad_vendida DESC


-- EJERCICIO 3
SELECT p.prod_codigo, p.prod_detalle, SUM(s.stoc_cantidad) as stock_total
FROM Producto p
INNER JOIN Stock s ON p.prod_codigo = s.stoc_producto
GROUP BY p.prod_codigo, p.prod_detalle
ORDER BY p.prod_codigo ASC


-- EJERCICIO 4
SELECT p.prod_codigo, p.prod_detalle, ISNULL(SUM(c.comp_cantidad), 0) as cantidad_articulos
FROM Producto p
LEFT OUTER JOIN Composicion c ON p.prod_codigo = c.comp_producto
GROUP BY p.prod_codigo, p.prod_detalle
HAVING (SELECT AVG(s.stoc_cantidad)
        FROM Stock s
        WHERE s.stoc_producto = p.prod_codigo
        GROUP BY s.stoc_producto) > 100


-- EJERCICIO 5
SELECT p.prod_codigo, p.prod_detalle, SUM(
    CASE WHEN YEAR(fact_fecha) = 2012 THEN item_cantidad
        ELSE 0
    END
) as cantidad_vendida
FROM Producto p 
INNER JOIN item_Factura i on i.item_producto = p.prod_codigo
INNER JOIN Factura f on i.item_numero = f.fact_numero and i.item_sucursal = f.fact_sucursal and i.item_tipo = f.fact_tipo
WHERE YEAR(f.fact_fecha) IN (2012, 2011)
GROUP BY p.prod_codigo, p.prod_detalle
HAVING SUM(
    CASE WHEN YEAR(f.fact_fecha) = 2012 THEN i.item_cantidad
        ELSE 0
    END
) > ISNULL(SUM(
    CASE WHEN YEAR(f.fact_fecha) = 2011 THEN I.item_cantidad
        ELSE 0
    END
),0)


--EJERCICIO 6
SELECT r.rubr_id, r.rubr_detalle, COUNT(DISTINCT ISNULL(p.prod_codigo,-1)) as cantidad_articulos, SUM(ISNULL(s.stoc_cantidad,0)) as stock_total
FROM Rubro r
INNER JOIN Producto p on p.prod_rubro = r.rubr_id
INNER JOIN Stock s on p.prod_codigo = s.stoc_producto
WHERE s.stoc_cantidad > (
    SELECT s2.stoc_cantidad 
    FROM Stock s2 
    WHERE s2.stoc_producto = '00000000'
    AND s2.stoc_deposito = '00')
GROUP BY r.rubr_id, r.rubr_detalle


-- EJERCICIO 7
SELECT p.prod_codigo, p.prod_detalle, MAX(i.item_precio) as precio_maximo, MIN(i.item_precio) as precio_minimo, (MAX(i.item_precio) - MIN(i.item_precio)) * 10 as diferencia_precio 
FROM Producto p
INNER JOIN Stock s ON p.prod_codigo = s.stoc_producto
INNER JOIN item_Factura i on i.item_producto = p.prod_codigo
GROUP BY p.prod_codigo, p.prod_detalle


-- EJERCICIO 8
select p.prod_codigo, p.prod_detalle, MAX(s.stoc_cantidad) as stock_maximo
from Stock s
INNER JOIN Producto p ON p.prod_codigo = s.stoc_producto AND s.stoc_cantidad > 0
GROUP BY p.prod_codigo, p.prod_detalle
HAVING COUNT(DISTINCT ISNULL(s.stoc_deposito,0)) = (SELECT COUNT(*) FROM Deposito)


-- EJERCICIO 9
SELECT e.empl_jefe, e.empl_codigo, CONCAT(RTRIM(e.empl_nombre), ' ', RTRIM(e.empl_apellido)), (
    SELECT COUNT(*) FROM Deposito d WHERE d.depo_encargado = e.empl_codigo
) as depositos_asignados
FROM Empleado e


-- EJERCICIO 10
SELECT p.prod_codigo, (
    SELECT TOP 1 f.fact_cliente
    FROM Factura f 
    INNER JOIN item_Factura i ON i.item_numero = f.fact_numero
    WHERE i.item_producto = p.prod_codigo
    GROUP BY f.fact_cliente
    ORDER BY SUM(i.item_cantidad) DESC
) as max_comprador
FROM Producto p
WHERE p.prod_codigo IN (
    SELECT TOP 10 i.item_producto 
    FROM item_Factura i
    GROUP BY i.item_producto
    ORDER BY SUM(i.item_cantidad) DESC
) OR p.prod_codigo IN (
    SELECT TOP 10 i.item_producto 
    FROM item_Factura i
    GROUP BY i.item_producto
    ORDER BY SUM(i.item_cantidad) ASC)


-- EJERCICIO 11
SELECT fa.fami_id,
    fa.fami_detalle,
    COUNT(DISTINCT i.item_producto) AS productos_diferentes_vendidos,
    SUM(i.item_cantidad * i.item_precio) AS monto_ventas
FROM Factura f 
INNER JOIN Item_Factura i 
    ON f.fact_tipo = i.item_tipo
    AND f.fact_sucursal = i.item_sucursal
    AND f.fact_numero = i.item_numero 
INNER JOIN Producto p ON p.prod_codigo = i.item_producto
INNER JOIN Familia fa ON p.prod_familia = fa.fami_id
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY fa.fami_id, fa.fami_detalle
HAVING SUM(i.item_cantidad * i.item_precio) > 20000
ORDER BY COUNT(DISTINCT i.item_producto) DESC


-- EJERCICIO 12
-- PROD DETALLE
-- FACT CLIENTE DISTINTOS X PRODUCTO
-- FACT TOTAL PROMEDIO X PRODUCTO
-- CANT DEPOSITOS CON STOCK DEL PRODUCTO
-- CANT STOCK TOTAL
SELECT p.prod_detalle,
    COUNT(DISTINCT f.fact_cliente) AS clientes_que_compraron,
    AVG(f.fact_total) AS importe_promedio_pagado,
    COUNT(DISTINCT s.stoc_deposito) AS depositos_con_stock,
    SUM(ISNULL(s.stoc_cantidad,0)) AS stock_total
FROM Producto p
INNER JOIN item_Factura i ON i.item_producto = p.prod_codigo
INNER JOIN Factura f ON i.item_numero = f.fact_numero AND i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal
LEFT OUTER JOIN Stock s ON s.stoc_producto = p.prod_codigo
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY p.prod_detalle
ORDER BY 3 DESC


-- EJERCICIO 13
SELECT p.prod_detalle, 
    p.prod_precio, 
    SUM(c.comp_cantidad * comp.prod_precio) AS precio_componentes
FROM Producto p
INNER JOIN Composicion c ON p.prod_codigo = c.comp_producto
INNER JOIN Producto comp ON c.comp_componente = comp.prod_codigo
GROUP BY p.prod_detalle, p.prod_precio
HAVING COUNT(c.comp_producto) >= 2
ORDER BY COUNT(c.comp_producto)


-- EJERCICIO 14
SELECT F.fact_cliente as cod_cliente,
        COUNT(DISTINCT f.fact_numero + f.fact_tipo + f.fact_sucursal) AS cantidad_compras,
        AVG(f.fact_total) AS promedio_por_compra,
        COUNT(DISTINCT i.item_producto) AS productos_comprados,
        MAX(f.fact_total) AS mayor_compra
FROM Factura f
INNER JOIN Item_Factura i ON i.item_numero = f.fact_numero
                                AND i.item_sucursal = f.fact_sucursal
                                AND i.item_tipo = f.fact_tipo
WHERE YEAR(f.fact_fecha) = 2012
--WHERE YEAR(f.fact_fecha) >= DATEADD(YEAR, -1, GETDATE())
GROUP BY f.fact_cliente
ORDER BY 2 DESC


-- EJERCICIO 15
-- PARES EN LA MISMA FACTURA (PERO COUNT > 500)
SELECT i1.item_producto AS prod1,
        (SELECT p1.prod_detalle FROM Producto p1 WHERE i1.item_producto = p1.prod_codigo) AS detalle1,
        i2.item_producto AS prod2,
        (SELECT p2.prod_detalle FROM Producto p2 WHERE i2.item_producto = p2.prod_codigo) AS detalle2,
        COUNT(*) AS veces
FROM Item_Factura i1
INNER JOIN Item_Factura i2 ON i1.item_numero = i2.item_numero
                            AND i1.item_sucursal = i2.item_sucursal
                            AND i1.item_tipo = i2.item_tipo
WHERE i1.item_producto != i2.item_producto
GROUP BY i1.item_producto, i2.item_producto
HAVING COUNT(*) > 500
ORDER BY veces DESC


-- EJERCICIO 16
-- flojo de papeles)
SELECT c.clie_razon_social, 
    SUM(i.item_cantidad) AS cant_unidades_vendidas,
    (SELECT TOP 1 p.prod_codigo
    FROM Producto p 
    INNER JOIN Item_Factura i2 ON i2.item_producto = p.prod_codigo
    INNER JOIN Factura f2 ON i2.item_numero + i2.item_sucursal + i2.item_tipo = f2.fact_numero + f2.fact_sucursal + f2.fact_tipo
    WHERE YEAR(f2.fact_fecha) = 2012 AND f2.fact_cliente = c.clie_codigo
    GROUP BY p.prod_codigo
    ORDER BY COUNT(*) DESC) AS prod_mas_vendido
FROM Cliente c
INNER JOIN Factura f ON f.fact_cliente = c.clie_codigo
INNER JOIN Item_Factura i ON f.fact_numero + f.fact_sucursal + f.fact_tipo = i.item_numero + i.item_sucursal + i.item_tipo
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY c.clie_codigo, c.clie_razon_social, c.clie_domicilio
HAVING SUM(i.item_cantidad) < (SELECT TOP 1 COUNT(*) as ventas
            FROM Producto p 
            INNER JOIN Item_Factura i ON i.item_producto = p.prod_codigo
            INNER JOIN Factura f ON i.item_numero + i.item_sucursal + i.item_tipo = f.fact_numero + f.fact_sucursal + f.fact_tipo
            WHERE YEAR(f.fact_fecha) = 2012 
            GROUP BY p.prod_codigo
            ORDER BY COUNT(*) DESC)
ORDER BY c.clie_domicilio ASC


SELECT TOP 1 p.prod_codigo, COUNT(*) as ventas
FROM Producto p 
INNER JOIN Item_Factura i ON i.item_producto = p.prod_codigo
INNER JOIN Factura f ON i.item_numero + i.item_sucursal + i.item_tipo = f.fact_numero + f.fact_sucursal + f.fact_tipo
WHERE YEAR(f.fact_fecha) = 2012 
GROUP BY p.prod_codigo
ORDER BY COUNT(*) DESC


-- EJERCICIO 17
-- estadisticas venta x año y mes
SELECT FORMAT(f.fact_fecha, 'yyyy/MM') AS periodo,
        i.item_producto as prod,
        (SELECT p.prod_detalle FROM Producto p WHERE p.prod_codigo = i.item_producto) AS detalle,
        SUM(ISNULL(i.item_cantidad,0)) as cantidad_vendida,
        ISNULL((SELECT SUM(ISNULL(i2.item_cantidad, 0))
        FROM Item_Factura i2
        INNER JOIN Factura f2 ON i2.item_numero + i2.item_sucursal + i2.item_tipo = f2.fact_numero + f2.fact_sucursal + f2.fact_tipo
        WHERE (MONTH(f.fact_fecha) = MONTH(f2.fact_fecha) AND YEAR(f.fact_fecha) = (YEAR(f2.fact_fecha) - 1) ) 
        AND i2.item_producto = i.item_producto
        GROUP BY i2.item_producto),0) AS ventas_año_ant,
        COUNT(DISTINCT f.fact_numero) AS cant_facturas
FROM Factura f
INNER JOIN Item_Factura i ON i.item_numero + i.item_sucursal + i.item_tipo = f.fact_numero + f.fact_sucursal + f.fact_tipo
GROUP BY f.fact_fecha, i.item_producto
ORDER BY f.fact_fecha, i.item_producto ASC


-- EJERCICIO 18
--DETALLE RUBRO
--SUM VENTAS X RUBRO
--PROD MAS VENDIDO
--SEGUNDO PROD MAS VENDIDO
--CLIENTE Q COMPRO MÁS EN LOS ULTIMOS 30DIAS
SELECT r.rubr_detalle,

    ISNULL(SUM(i.item_precio * i.item_precio), 0) AS ventas_rubro,

    ISNULL((SELECT TOP 1 p2.prod_codigo
    FROM Producto p2
    INNER JOIN Item_Factura i2 ON i2.item_producto = p2.prod_codigo
    WHERE p2.prod_rubro = r.rubr_id 
    GROUP BY p2.prod_codigo 
    ORDER BY COUNT(*) DESC), 'Sin ventas') AS producto_mas_vendido,

    ISNULL((SELECT TOP 1 prod_codigo FROM (SELECT TOP 2 p3.prod_codigo
    FROM Producto p3
    INNER JOIN Item_Factura i3 ON i3.item_producto = p3.prod_codigo
    WHERE p3.prod_rubro = r.rubr_id
    GROUP BY p3.prod_codigo 
    ORDER BY COUNT(*) ASC) AS top2), 'Sin ventas') AS sdo_producto_mas_vendido,

    ISNULL((SELECT TOP 1 f.fact_cliente 
    FROM Factura f
    INNER JOIN Item_Factura i2 ON f.fact_numero = i2.item_numero
        AND f.fact_sucursal = i2.item_sucursal
        AND f.fact_tipo = i2.item_tipo
    INNER JOIN Producto p2 ON i2.item_producto = p2.prod_codigo
    WHERE p2.prod_rubro = r.rubr_id
    GROUP BY f.fact_cliente
    ORDER BY SUM(ISNULL(i2.item_cantidad, 0)) DESC), 'No hay ventas')AS cliente_mas_comprador
FROM Rubro r
LEFT OUTER JOIN Producto p ON p.prod_rubro = r.rubr_id
RIGHT OUTER JOIN Item_Factura i ON i.item_producto = p.prod_codigo
GROUP BY r.rubr_id, r.rubr_detalle
ORDER BY COUNT(DISTINCT i.item_producto) DESC


-- EJERCICIO 19
SELECT p.prod_codigo,
    p.prod_detalle,
    p.prod_familia,
    f.fami_detalle,

    (SELECT TOP 1 f2.fami_id
    FROM Producto p2
    INNER JOIN Familia f2 ON p2.prod_familia = f2.fami_id
    WHERE SUBSTRING(p.prod_detalle, 0, 5) = SUBSTRING(p2.prod_detalle, 0, 5)
    GROUP BY f2.fami_id, f2.fami_detalle
    ORDER BY COUNT(fami_id) DESC, fami_id ASC) as cod_familia_sugerida,

    (SELECT TOP 1 f2.fami_detalle
    FROM Producto p2
    INNER JOIN Familia f2 ON p2.prod_familia = f2.fami_id
    WHERE SUBSTRING(p.prod_detalle, 0, 5) = SUBSTRING(p2.prod_detalle, 0, 5)
    GROUP BY f2.fami_id, f2.fami_detalle
    ORDER BY COUNT(fami_id) DESC, fami_id ASC) as detalle_familia_sugerida

FROM Producto p 
LEFT OUTER JOIN Familia f ON p.prod_familia = f.fami_id
WHERE p.prod_familia != (
    SELECT TOP 1 f2.fami_id
    FROM Producto p2
    INNER JOIN Familia f2 ON p2.prod_familia = f2.fami_id
    WHERE SUBSTRING(p.prod_detalle, 0, 5) = SUBSTRING(p2.prod_detalle, 0, 5)
    GROUP BY f2.fami_id, f2.fami_detalle
    ORDER BY COUNT(fami_id) DESC, fami_id ASC
)
GROUP BY p.prod_codigo, p.prod_detalle, p.prod_familia, f.fami_detalle
ORDER BY P.prod_detalle ASC


-- EJERCICIO 20
-- 50 facturas -> CANT FACTURAS WHERE precio > 100 en el año
-- >50 -> 50% cant facturas de los subordinados en el año

SELECT TOP 3 e.empl_codigo,

        CONCAT(RTRIM(e.empl_apellido), ', ', RTRIM(e.empl_nombre)) AS nombre_y_apellido,
        YEAR(e.empl_ingreso) AS anio_ingreso,

        CASE WHEN (SELECT COUNT(DISTINCT f.fact_numero)
        FROM Factura f 
        WHERE f.fact_vendedor = e.empl_codigo AND YEAR(f.fact_fecha) = 2011) >= 50 
        THEN (SELECT COUNT(DISTINCT f.fact_numero) 
            FROM Factura f 
            WHERE f.fact_vendedor = e.empl_codigo 
            AND YEAR(f.fact_fecha) = 2011
            AND f.fact_total > 100)
        ELSE (SELECT COUNT(DISTINCT f.fact_numero)
            FROM Factura f 
            LEFT OUTER JOIN Empleado s ON e.empl_codigo = s.empl_jefe
            WHERE f.fact_vendedor = s.empl_codigo
            AND YEAR(f.fact_fecha) = 2011) / 2
        END
        AS puntaje_2011,

        CASE WHEN (SELECT COUNT(DISTINCT f.fact_numero)
        FROM Factura f 
        WHERE f.fact_vendedor = e.empl_codigo AND YEAR(f.fact_fecha) = 2012) >= 50 
        THEN (SELECT COUNT(DISTINCT f.fact_numero) 
            FROM Factura f 
            WHERE f.fact_vendedor = e.empl_codigo 
            AND YEAR(f.fact_fecha) = 2012
            AND f.fact_total > 100)
        ELSE (SELECT COUNT(DISTINCT f.fact_numero)
            FROM Factura f 
            LEFT OUTER JOIN Empleado s ON e.empl_codigo = s.empl_jefe
            WHERE f.fact_vendedor = s.empl_codigo
            AND YEAR(f.fact_fecha) = 2012) / 2
        END
        AS puntaje_2012
FROM Empleado e 
ORDER BY puntaje_2012 DESC


-- EJERCICIO 21
SELECT YEAR(f.fact_fecha) AS anio,
        COUNT(DISTINCT f.fact_cliente) AS clientes_mal_facturados,
        COUNT(DISTINCT f.fact_numero + f.fact_sucursal + f.fact_tipo) AS cant_facturas
FROM Factura f
WHERE f.fact_total - f.fact_total_impuestos - 
    (SELECT SUM(i.item_cantidad * i.item_precio)
    FROM Item_Factura i 
    WHERE f.fact_numero + f.fact_sucursal + f.fact_tipo = i.item_numero + i.item_sucursal + item_tipo) > 1
GROUP BY YEAR(f.fact_fecha)


-- EJERCICIO 22
-- ESTADISTICA X RUBRO X TRIMESTRE
-- MAX 4 FILAS POR RUBRO (TRIMESTRE 1 AL 4)
-- CANT FACTURAS DEL TRIMESTRE CON 1 PROD VENDIDO DEL RUBRO
-- CANT PROD VENDIDOS DIFERENTES DEL RUBRO
SELECT r.rubr_detalle,
        ((MONTH(f.fact_fecha) -1 ) / 3) + 1 AS trimestre,
        COUNT(DISTINCT f.fact_numero + f.fact_tipo + f.fact_sucursal) AS cantidad_facturas_emitidas,
        COUNT(DISTINCT i.item_producto) as prod_diferentes_vendidos
FROM Rubro r
LEFT OUTER JOIN Producto p ON p.prod_rubro = r.rubr_id
INNER JOIN Item_Factura i ON p.prod_codigo = i.item_producto
INNER JOIN Factura f ON f.fact_numero = i.item_numero
                    AND f.fact_tipo = i.item_tipo
                    AND f.fact_sucursal = i.item_sucursal
GROUP BY r.rubr_id, r.rubr_detalle,  ((MONTH(f.fact_fecha) -1 ) / 3) + 1
HAVING COUNT(DISTINCT f.fact_numero + f.fact_tipo + f.fact_sucursal) > 100
ORDER BY r.rubr_detalle ASC, cantidad_facturas_emitidas DESC


-- EJERCICIO 23
-- PROD CON COMPOSICION  + VENDIDO
-- CANT Q LO COMPONEN
-- CANT FACTURAS Q APARECE
-- CLIENTE Q MAS COMPRÓ
-- %
SELECT YEAR(f.fact_fecha) as AÑO,
    i.item_producto,

    (SELECT COUNT(*) FROM Composicion c WHERE i.item_producto = c.comp_producto) AS cant_componentes,

    COUNT(DISTINCT f.fact_numero + f.fact_tipo + f.fact_sucursal) AS cant_facturas,

    (SELECT TOP 1 f2.fact_cliente 
    FROM Factura f2
    INNER JOIN Item_Factura i2 ON f2.fact_numero + f2.fact_tipo + f2.fact_sucursal = i2.item_numero + i2.item_tipo + i2.item_sucursal
    WHERE i2.item_producto = i.item_producto AND YEAR(f.fact_fecha) = YEAR(f2.fact_fecha)
    GROUP BY f2.fact_cliente
    ORDER BY SUM(i2.item_cantidad) DESC) AS cliente_mas_comprador,

    SUM(i.item_cantidad * i.item_precio) / 
    (SELECT SUM(i3.item_cantidad * i3.item_precio)
    FROM Factura f3
    INNER JOIN Item_Factura i3 ON f3.fact_numero + f3.fact_tipo + f3.fact_sucursal = i3.item_numero + i3.item_tipo + i3.item_sucursal
    WHERE i3.item_producto = i.item_producto
    GROUP BY i3.item_producto) * 100 AS porcentaje

FROM Factura f
INNER JOIN Item_Factura i ON f.fact_numero = i.item_numero
                    AND f.fact_tipo = i.item_tipo
                    AND f.fact_sucursal = i.item_sucursal
WHERE i.item_producto = (
    SELECT TOP 1 i2.item_producto
    FROM Item_Factura i2
    INNER JOIN Composicion c2 ON c2.comp_producto = i2.item_producto
    INNER JOIN Factura f2 ON f2.fact_numero = i2.item_numero
                    AND f2.fact_tipo = i2.item_tipo
                    AND f2.fact_sucursal = i2.item_sucursal
    WHERE YEAR(f2.fact_fecha) = YEAR(f.fact_fecha)
    GROUP BY i2.item_producto
    ORDER BY SUM(i2.item_cantidad) DESC
)
GROUP BY YEAR(f.fact_fecha), i.item_producto
ORDER BY SUM(i.item_cantidad) DESC


-- EJERCICIO 24
-- FACTURAS DE LOS TOP 2 VENDEDORES CON MAS COMISIONES
-- RETORNE PROD CON COMPOSICION FACTURADOS EN AL MENOS 5 FACTURAS
-- COD PROD, NOMBRE PROD, UNIDADES FACTURADAS
SELECT p.prod_codigo,
       p.prod_detalle,
       SUM(i.item_cantidad) AS unidades_facturadas
FROM Producto p
INNER JOIN Composicion c 
        ON p.prod_codigo = c.comp_componente
INNER JOIN Item_Factura i 
        ON i.item_producto = p.prod_codigo
INNER JOIN Factura f 
        ON f.fact_numero   = i.item_numero
       AND f.fact_tipo     = i.item_tipo
       AND f.fact_sucursal = i.item_sucursal
WHERE f.fact_vendedor IN (
    SELECT TOP 2 e.empl_codigo
    FROM Empleado e
    ORDER BY e.empl_comision DESC
)
GROUP BY p.prod_codigo, p.prod_detalle
HAVING COUNT(DISTINCT f.fact_numero) >= 5
ORDER BY unidades_facturadas DESC


-- EJERCICIO 25
SELECT YEAR(f.fact_fecha) AS año,

        p.prod_familia AS familia_mas_vendida,

        COUNT(DISTINCT p.prod_rubro) AS cant_rubros_familia,

        (SELECT COUNT(DISTINCT c.comp_componente)
        FROM Item_Factura i3 
        LEFT OUTER JOIN Composicion c ON i3.item_producto = c.comp_producto
        WHERE i3.item_producto = (SELECT TOP 1 p3.prod_codigo 
                                    FROM Producto p3
                                    INNER JOIN Item_Factura i3 ON i3.item_producto = p3.prod_codigo
                                    WHERE p3.prod_familia = p.prod_familia
                                    GROUP BY p3.prod_codigo
                                    ORDER BY SUM(i3.item_cantidad) DESC)
        ) AS cant_productos_componen,
        COUNT(DISTINCT f.fact_numero + f.fact_tipo + f.fact_sucursal) AS cant_facturas,

        (SELECT TOP 1 f4.fact_cliente
        FROM Factura f4 
        INNER JOIN Item_Factura i4 ON f4.fact_numero = i4.item_numero
        INNER JOIN Producto p4 ON p4.prod_codigo = i4.item_producto
        WHERE  p4.prod_familia = p.prod_familia
        GROUP BY f4.fact_cliente
        ORDER BY SUM(i4.item_cantidad) DESC) AS cliente_mas_comprador,

        (SUM(i.item_cantidad) / (SELECT SUM(i5.item_cantidad) 
                                FROM Item_Factura i5
                                INNER JOIN Factura f5 ON f5.fact_numero = i5.item_numero
                                WHERE YEAR(f5.fact_fecha) = YEAR(f.fact_fecha))
        * 100) AS porcentaje_familia
FROM Producto p 
INNER JOIN Item_Factura i ON p.prod_codigo = i.item_producto
INNER JOIN Factura f ON f.fact_numero = i.item_numero
                    AND f.fact_tipo = i.item_tipo
                    AND f.fact_sucursal = i.item_sucursal
WHERE p.prod_familia = (SELECT TOP 1 p2.prod_familia
                            FROM Producto p2
                            INNER JOIN Item_Factura i2 ON i2.item_producto = p2.prod_codigo
                            INNER JOIN Factura f2 ON f2.fact_numero = i2.item_numero
                                                AND f2.fact_tipo = i2.item_tipo
                                                AND f2.fact_sucursal = i2.item_sucursal 
                            WHERE YEAR(f2.fact_fecha) = YEAR(f.fact_fecha)
                            GROUP BY p2.prod_familia
                            ORDER BY SUM(i2.item_cantidad) DESC)
GROUP BY YEAR(f.fact_fecha), p.prod_familia
ORDER BY SUM(i.item_cantidad) DESC, p.prod_familia DESC



-- EJERCICIO 26
SELECT e.empl_codigo,
        
        COUNT(DISTINCT d.depo_codigo) AS depositos_a_cargo,

        ISNULL((
            SELECT SUM(f2.fact_total) 
            FROM Factura f2
            WHERE f2.fact_vendedor = e.empl_codigo AND YEAR(f2.fact_fecha) = 2012
        ), 0) AS monto_total_facturado,

        (SELECT TOP 1 f3.fact_cliente
        FROM Factura f3
        WHERE f3.fact_vendedor = e.empl_codigo AND YEAR(f3.fact_fecha) = 2012
        GROUP BY f3.fact_cliente
        ORDER BY COUNT(f3.fact_cliente) DESC) AS cliente_que_mas_vendio,

        (SELECT TOP 1 i.item_producto
        FROM Item_Factura i 
        INNER JOIN Factura f4 ON f4.fact_numero = i.item_numero
                                AND f4.fact_sucursal = i.item_sucursal
                                AND f4.fact_tipo = i.item_tipo
        WHERE f4.fact_vendedor = e.empl_codigo AND YEAR(f4.fact_fecha) = 2012
        GROUP BY i.item_producto
        ORDER BY SUM(i.item_cantidad) DESC) AS prod_mas_vendido,

        ISNULL(((SELECT SUM(f5.fact_total)
        FROM Factura f5
        WHERE f5.fact_vendedor = e.empl_codigo AND YEAR(f5.fact_fecha) = 2012) * 100
        /
        (SELECT SUM(f6.fact_total)
        FROM Factura f6
        WHERE YEAR(f6.fact_fecha) = 2012)), 0) AS porcentaje_venta

FROM Empleado e
LEFT OUTER JOIN Deposito d ON d.depo_encargado = e.empl_codigo
GROUP BY e.empl_codigo
ORDER BY 3 DESC


-- EJERCICIO 27
SELECT YEAR(f.fact_fecha) AS año,
        e.enva_codigo,
        e.enva_detalle,
        COUNT(DISTINCT p.prod_codigo) AS cant_prod,
        SUM(i.item_cantidad) AS cant_prod_facturados,

        (SELECT TOP 1 p2.prod_codigo
        FROM Producto p2
        INNER JOIN Item_Factura i2 ON i2.item_producto = p2.prod_codigo
        INNER JOIN Factura f2 ON i2.item_numero = f2.fact_numero
                            AND i2.item_sucursal = f2.fact_sucursal
                            AND i2.item_tipo = f2.fact_tipo
        WHERE p2.prod_envase = e.enva_codigo AND YEAR(f2.fact_fecha) = YEAR(f.fact_fecha)
        GROUP BY p2.prod_codigo
        ORDER BY SUM(i2.item_cantidad) DESC
        ) AS prod_mas_vendido,

        SUM(i.item_cantidad * i.item_precio) AS monto_total_venta,

        SUM(i.item_cantidad * i.item_precio) * 100
        / (SELECT SUM(f3.fact_total)
        FROM Factura f3
        WHERE YEAR(f3.fact_fecha) = YEAR(f.fact_fecha)
        ) AS porcentaje_venta_envase

FROM Factura f
INNER JOIN Item_Factura i ON i.item_numero = f.fact_numero
                            AND i.item_sucursal = f.fact_sucursal
                            AND i.item_tipo = f.fact_tipo
INNER JOIN Producto p ON p.prod_codigo = i.item_producto
INNER JOIN Envases e ON e.enva_codigo = p.prod_envase
GROUP BY YEAR(f.fact_fecha), e.enva_codigo, e.enva_detalle
ORDER BY 1 ASC, 5 DESC


-- EJERCICIO 28
SELECT YEAR(f.fact_fecha) AS año,
        e.empl_codigo AS cod_vendedor,
        CONCAT(RTRIM(e.empl_nombre), ',', SPACE(1), RTRIM(e.empl_apellido)) AS vendedor_detalle,
        COUNT(DISTINCT f.fact_numero) AS cant_facturas,
        COUNT(DISTINCT f.fact_cliente) AS cant_clientes,

        ISNULL((SELECT SUM(i.item_cantidad)
        FROM Item_Factura i
        INNER JOIN Composicion c ON i.item_producto = c.comp_producto
        INNER JOIN Factura f2 ON i.item_numero = f2.fact_numero
                            AND i.item_sucursal = f2.fact_sucursal
                            AND i.item_tipo = f2.fact_tipo 
        WHERE f2.fact_vendedor = e.empl_codigo AND YEAR(f2.fact_fecha) = YEAR(f.fact_fecha)
        ), 0) AS cant_prod_composicion,

        ISNULL((SELECT SUM(i2.item_cantidad)
        FROM Item_Factura i2
        INNER JOIN Factura f3 ON i2.item_numero = f3.fact_numero
                            AND i2.item_sucursal = f3.fact_sucursal
                            AND i2.item_tipo = f3.fact_tipo 
        WHERE f3.fact_vendedor = e.empl_codigo AND YEAR(f3.fact_fecha) = YEAR(f.fact_fecha)
        AND i2.item_producto NOT IN (SELECT comp_producto FROM Composicion)
        ), 0) AS cant_prod_no_composicion,

        SUM(f.fact_total) AS monto_total_vendido

FROM Factura f 
INNER JOIN Empleado e ON f.fact_vendedor = e.empl_codigo
INNER JOIN Item_Factura i4 ON i4.item_numero = f.fact_numero
                                AND i4.item_sucursal = f.fact_sucursal
                                AND i4.item_tipo = f.fact_tipo
GROUP BY YEAR(f.fact_fecha), e.empl_codigo, e.empl_nombre, e.empl_apellido
ORDER BY año ASC, COUNT(DISTINCT I4.item_producto) DESC


-- EJERCICIO 29
SELECT p.prod_codigo, p.prod_detalle, p.prod_familia,
        SUM(i.item_cantidad) AS cantidad_vendida,
        COUNT(DISTINCT f.fact_numero + f.fact_sucursal + f.fact_tipo) AS cant_facturas,
        SUM(i.item_cantidad * i.item_producto) AS monto_total_facturado
FROM Producto p 
INNER JOIN Item_Factura i ON i.item_producto = p.prod_codigo
INNER JOIN Factura f ON i.item_numero = f.fact_numero
                            AND i.item_sucursal = f.fact_sucursal
                            AND i.item_tipo = f.fact_tipo
WHERE prod_familia IN (SELECT p2.prod_familia 
                        FROM Producto p2
                        INNER JOIN Familia fa ON fa.fami_id = p2.prod_familia
                        GROUP BY p2.prod_familia
                        HAVING COUNT(DISTINCT p2.prod_codigo) > 20)
AND YEAR(f.fact_fecha) = 2011
GROUP BY p.prod_codigo, p.prod_detalle, p.prod_familia
ORDER BY cantidad_vendida DESC


-- EJERCICIO 30
SELECT j.empl_codigo AS jefe_codigo, 
        CONCAT(RTRIM(j.empl_apellido), ',', SPACE(1), RTRIM(j.empl_nombre)) AS nombre_jefe,
        COUNT(DISTINCT e.empl_codigo) AS cant_empleados,
        ISNULL(SUM(f.fact_total), 0) AS monto_vendido_empleados,
        COUNT(DISTINCT f.fact_numero + f.fact_sucursal + f.fact_tipo) AS cant_facturas_empleados,
        (SELECT TOP 1 CONCAT(RTRIM(e2.empl_apellido), ',', SPACE(1), RTRIM(e2.empl_nombre))
        FROM Factura f2
        INNER JOIN Empleado e2 ON f2.fact_vendedor = e2.empl_codigo
        WHERE e2.empl_jefe = j.empl_codigo AND YEAR(f2.fact_fecha) = 2012
        GROUP BY e2.empl_codigo, e2.empl_apellido, e2.empl_nombre
        ORDER BY SUM(f2.fact_total) DESC) AS mejor_empleado
FROM Empleado j
INNER JOIN Empleado e ON j.empl_codigo = e.empl_jefe
LEFT OUTER JOIN Factura f ON f.fact_vendedor = e.empl_codigo
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY j.empl_codigo, j.empl_nombre, j.empl_apellido
HAVING COUNT(DISTINCT f.fact_numero + f.fact_sucursal + f.fact_tipo) > 10
ORDER BY monto_vendido_empleados DESC


-- EJERCICIO 32
SELECT f1.fami_id,
        f1.fami_detalle,
        f2.fami_id,
        f2.fami_detalle,
        COUNT(DISTINCT i1.item_numero + i1.item_sucursal + i2.item_tipo) AS cant_facturas,
        (SUM(i1.item_cantidad * i1.item_precio) + SUM(i2.item_cantidad * i2.item_precio)) AS total_vendido
FROM Item_Factura i1
INNER JOIN Item_Factura i2 ON i1.item_numero + i1.item_sucursal + i1.item_tipo = i2.item_numero + i2.item_sucursal + i2.item_tipo
INNER JOIN Producto p1 ON p1.prod_codigo = i1.item_producto
INNER JOIN Producto p2 ON p2.prod_codigo = i2.item_producto
INNER JOIN Familia f1 ON p1.prod_familia = f1.fami_id
INNER JOIN Familia f2 ON p2.prod_familia = f2.fami_id
WHERE f1.fami_id < f2.fami_id
GROUP BY f1.fami_id, f1.fami_detalle, f2.fami_id, f2.fami_detalle
HAVING COUNT(DISTINCT i1.item_numero + i1.item_sucursal + i2.item_tipo) > 10
ORDER BY total_vendido DESC


-- EJERCICIO 33
SELECT p.prod_codigo,
        p.prod_detalle,
        SUM(i.item_cantidad) AS cant_vendidas,
        COUNT(DISTINCT i.item_numero + i.item_sucursal + i.item_tipo) AS cant_facturas,
        AVG(i.item_precio) AS precio_promedio,
        SUM(i.item_cantidad * i.item_precio) AS total_facturado
FROM Producto p 
INNER JOIN Composicion c ON p.prod_codigo = c.comp_componente
INNER JOIN Item_Factura i ON i.item_producto = p.prod_codigo
INNER JOIN Factura f ON i.item_numero = f.fact_numero
                            AND i.item_sucursal = f.fact_sucursal
                            AND i.item_tipo = f.fact_tipo
WHERE YEAR(f.fact_fecha) = 2012 
AND c.comp_producto = (SELECT TOP 1 c2.comp_producto
                    FROM Composicion c2
                    INNER JOIN Item_Factura i2 ON i2.item_producto = c2.comp_producto
                    INNER JOIN Factura f2 ON i2.item_numero = f2.fact_numero
                            AND i2.item_sucursal = f2.fact_sucursal
                            AND i2.item_tipo = f2.fact_tipo
                    WHERE YEAR(f2.fact_fecha) = 2012
                    GROUP BY c2.comp_producto
                    ORDER BY SUM(i2.item_cantidad) DESC)
GROUP BY p.prod_codigo, p.prod_detalle
ORDER BY total_facturado DESC


-- EJERCICIO 34
SELECT r.rubr_id,
        MONTH(f.fact_fecha) AS mes,
        COUNT(DISTINCT f.fact_numero + f.fact_sucursal + f.fact_tipo) AS cant_facturas_mal_hechas
FROM Rubro r 
LEFT OUTER JOIN Producto p ON p.prod_rubro = r.rubr_id
LEFT OUTER JOIN Item_Factura i ON i.item_producto = p.prod_codigo
LEFT OUTER JOIN Factura f ON i.item_numero = f.fact_numero
                            AND i.item_sucursal = f.fact_sucursal
                            AND i.item_tipo = f.fact_tipo
WHERE YEAR(f.fact_fecha) = 2011
AND (f.fact_numero + f.fact_sucursal + f.fact_tipo) IN (SELECT i2.item_numero + i2.item_sucursal + i2.item_tipo
                                                        FROM Item_Factura i2
                                                        INNER JOIN Item_Factura i3 ON i3.item_numero + i3.item_sucursal + i3.item_tipo = i2.item_numero + i2.item_sucursal + i2.item_tipo
                                                        INNER JOIN Producto p2 ON p2.prod_codigo = i2.item_producto
                                                        INNER JOIN Producto p3 ON p3.prod_codigo = i3.item_producto
                                                        WHERE p2.prod_rubro <> p3.prod_rubro AND i2.item_producto <> i3.item_producto
                                                        GROUP BY i2.item_numero + i2.item_sucursal + i2.item_tipo
                                                        )
GROUP BY r.rubr_id, MONTH(f.fact_fecha)
ORDER BY 2 ASC, 1 ASC

-- otra solucion, mejor?
SELECT r.rubr_id,
    Meses.mes as Mes,
    COUNT(DISTINCT f.fact_numero + f.fact_sucursal + f.fact_tipo) AS cant_facturas_mal_hechas
FROM Rubro r 
CROSS JOIN (SELECT 1 as Mes
UNION SELECT 2 AS Mes
UNION SELECT 3 AS Mes
UNION SELECT 4 AS Mes
UNION SELECT 5 AS Mes
UNION SELECT 6 AS Mes
UNION SELECT 7 AS Mes
UNION SELECT 8 AS Mes
UNION SELECT 9 AS Mes
UNION SELECT 10 AS Mes
UNION SELECT 11 AS Mes
UNION SELECT 12 AS Mes) as Meses
LEFT OUTER JOIN Producto p ON p.prod_rubro = r.rubr_id
LEFT OUTER JOIN Item_Factura i ON i.item_producto = p.prod_codigo
LEFT OUTER JOIN Factura f 
ON i.item_numero = f.fact_numero
AND i.item_sucursal = f.fact_sucursal
AND i.item_tipo = f.fact_tipo
AND YEAR(f.fact_fecha) = 2011
AND MONTH(f.fact_fecha) = Meses.Mes
AND (f.fact_numero + f.fact_sucursal + f.fact_tipo) IN (SELECT i2.item_numero + i2.item_sucursal + i2.item_tipo
                                                        FROM Item_Factura i2
                                                        INNER JOIN Item_Factura i3 ON i3.item_numero + i3.item_sucursal + i3.item_tipo = i2.item_numero + i2.item_sucursal + i2.item_tipo
                                                        INNER JOIN Producto p2 ON p2.prod_codigo = i2.item_producto
                                                        INNER JOIN Producto p3 ON p3.prod_codigo = i3.item_producto
                                                        WHERE p2.prod_rubro <> p3.prod_rubro AND i2.item_producto <> i3.item_producto
                                                        GROUP BY i2.item_numero + i2.item_sucursal + i2.item_tipo
                                                        )
GROUP BY r.rubr_id, Meses.Mes
ORDER BY Meses.Mes ASC, r.rubr_id ASC


-- EJERCICIO 35
SELECT YEAR(f.fact_fecha) AS año,
        p.prod_codigo,
        p.prod_detalle,
        COUNT(DISTINCT f.fact_numero + f.fact_sucursal + f.fact_tipo) AS cant_facturas,
        COUNT(DISTINCT f.fact_cliente) AS cant_clientes,
        COUNT(DISTINCT c.comp_componente) AS cant_componentes,
        ((SUM(i.item_cantidad * i.item_precio) * 100 )
        / (SELECT SUM(i2.item_cantidad * i2.item_precio)
            FROM Factura f2 
            INNER JOIN Item_Factura i2 ON i2.item_numero = f2.fact_numero
                            AND i2.item_sucursal = f2.fact_sucursal
                            AND i2.item_tipo = f2.fact_tipo
            WHERE YEAR(f2.fact_fecha) = YEAR(f.fact_fecha))) AS porcentaje_sobre_total
FROM Producto p 
INNER JOIN Item_Factura i ON i.item_producto = p.prod_codigo
INNER JOIN Factura f ON i.item_numero = f.fact_numero
                            AND i.item_sucursal = f.fact_sucursal
                            AND i.item_tipo = f.fact_tipo
LEFT OUTER JOIN Composicion c ON p.prod_codigo = c.comp_producto
GROUP BY YEAR(f.fact_fecha), p.prod_codigo, p.prod_detalle
ORDER BY año ASC, SUM(i.item_cantidad) DESC