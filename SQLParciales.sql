-- 1C2025 28/06

SELECT TOP 10 i.item_producto
FROM Item_Factura i 
INNER JOIN Factura f ON f.fact_numero + f.fact_sucursal + f.fact_tipo = i.item_numero + i.item_sucursal + i.item_tipo
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY i.item_producto
ORDER BY SUM(i.item_cantidad) DESC

SELECT TOP 10 i.item_producto
FROM Item_Factura i 
INNER JOIN Factura f ON f.fact_numero + f.fact_sucursal + f.fact_tipo = i.item_numero + i.item_sucursal + i.item_tipo
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY i.item_producto
ORDER BY SUM(i.item_cantidad) ASC

SELECT ROW_NUMBER() OVER (ORDER BY SUM(i.item_cantidad * i.item_precio)) AS numero_fila,
    c.clie_razon_social,
    (CASE
        WHEN EXISTS (SELECT 1
                    FROM Item_Factura i2 
                    INNER JOIN Factura f2 ON f2.fact_numero + f2.fact_sucursal + f2.fact_tipo = i2.item_numero + i2.item_sucursal + i2.item_tipo
                    WHERE YEAR(f2.fact_fecha) = 2012
                    AND f2.fact_cliente = c.clie_codigo
                    AND i2.item_producto IN (SELECT TOP 10 imas.item_producto
                                            FROM Item_Factura imas
                                            INNER JOIN Factura fmas ON fmas.fact_numero + fmas.fact_sucursal + fmas.fact_tipo = imas.item_numero + imas.item_sucursal + imas.item_tipo
                                            WHERE YEAR(fmas.fact_fecha) = 2012
                                            GROUP BY imas.item_producto
                                            ORDER BY SUM(imas.item_cantidad) DESC)
                    ) THEN 'Si'
        ELSE 'No'
        END) AS esta_ranking_mas_vendidos,
        COUNT(DISTINCT f.fact_numero + f.fact_sucursal + f.fact_tipo) AS cant_facturas
FROM Cliente c 
INNER JOIN Factura f ON c.clie_codigo = f.fact_cliente
INNER JOIN Item_Factura i ON f.fact_numero + f.fact_sucursal + f.fact_tipo = i.item_numero + i.item_sucursal + i.item_tipo
WHERE YEAR(f.fact_fecha) = 2012 
AND i.item_producto IN ((SELECT TOP 10 imas.item_producto
                        FROM Item_Factura imas
                        INNER JOIN Factura fmas ON fmas.fact_numero + fmas.fact_sucursal + fmas.fact_tipo = imas.item_numero + imas.item_sucursal + imas.item_tipo
                        WHERE YEAR(fmas.fact_fecha) = 2012
                        GROUP BY imas.item_producto
                        ORDER BY SUM(imas.item_cantidad) DESC)
                        UNION
                        (SELECT TOP 10 imenos.item_producto
                        FROM Item_Factura imenos
                        INNER JOIN Factura fmenos ON fmenos.fact_numero + fmenos.fact_sucursal + fmenos.fact_tipo = imenos.item_numero + imenos.item_sucursal + imenos.item_tipo
                        WHERE YEAR(fmenos.fact_fecha) = 2012
                        GROUP BY imenos.item_producto
                        ORDER BY SUM(imenos.item_cantidad) ASC)
                        )
GROUP BY c.clie_codigo, c.clie_razon_social
ORDER BY 1 ASC



-- 1C2025 24/06
SELECT YEAR(f.fact_fecha) AS año,
        fa.fami_id,

        fa.fami_detalle,

        (SELECT TOP 1 c1.clie_razon_social
        FROM Factura f1
        INNER JOIN Cliente c1 ON f1.fact_cliente = c1.clie_codigo
        INNER JOIN Item_Factura i1 ON f1.fact_numero = i1.item_numero
                            AND f1.fact_sucursal = i1.item_sucursal
                            AND f1.fact_tipo = i1.item_tipo
        INNER JOIN Producto p1 ON p1.prod_codigo = i1.item_producto
        INNER JOIN Familia fa1 ON p1.prod_familia = fa1.fami_id
        WHERE fa1.fami_id = fa.fami_id AND YEAR(f1.fact_fecha) = YEAR(f.fact_fecha)
        GROUP BY f1.fact_cliente, c1.clie_razon_social
        ORDER BY COUNT(DISTINCT i1.item_producto) ASC
        ) AS clie_razon_social,

        (SELECT TOP 1 SUM(i2.item_cantidad)
        FROM Factura f2
        INNER JOIN Item_Factura i2 ON f2.fact_numero = i2.item_numero
                            AND f2.fact_sucursal = i2.item_sucursal
                            AND f2.fact_tipo = i2.item_tipo
        INNER JOIN Producto p2 ON p2.prod_codigo = i2.item_producto
        INNER JOIN Familia fa2 ON p2.prod_familia = fa2.fami_id
        WHERE fa2.fami_id = fa.fami_id AND YEAR(f2.fact_fecha) = YEAR(f.fact_fecha)
        GROUP BY f2.fact_cliente
        ORDER BY COUNT(DISTINCT i2.item_producto) ASC 
        ) AS cant_unidades_compradas,

        COUNT(DISTINCT p.prod_codigo) AS productos_familia

FROM Factura f 
INNER JOIN Item_Factura i ON f.fact_numero = i.item_numero
                            AND f.fact_sucursal = i.item_sucursal
                            AND f.fact_tipo = i.item_tipo
INNER JOIN Producto p ON i.item_producto = p.prod_codigo
INNER JOIN Familia fa ON fa.fami_id = p.prod_familia
GROUP BY YEAR(f.fact_fecha), fa.fami_id, fa.fami_detalle
UNION ALL
SELECT YEAR(f.fact_fecha) AS año,
        fa.fami_id,

        fa.fami_detalle,

        (SELECT TOP 1 c1.clie_razon_social
        FROM Factura f1
        INNER JOIN Cliente c1 ON f1.fact_cliente = c1.clie_codigo
        INNER JOIN Item_Factura i1 ON f1.fact_numero = i1.item_numero
                            AND f1.fact_sucursal = i1.item_sucursal
                            AND f1.fact_tipo = i1.item_tipo
        INNER JOIN Producto p1 ON p1.prod_codigo = i1.item_producto
        INNER JOIN Familia fa1 ON p1.prod_familia = fa1.fami_id
        WHERE fa1.fami_id = fa.fami_id AND YEAR(f1.fact_fecha) = YEAR(f.fact_fecha)
        GROUP BY f1.fact_cliente, c1.clie_razon_social
        ORDER BY SUM(i1.item_cantidad * i1.item_precio) DESC
        ) AS clie_razon_social,

        (SELECT TOP 1 SUM(i2.item_cantidad)
        FROM Factura f2
        INNER JOIN Item_Factura i2 ON f2.fact_numero = i2.item_numero
                            AND f2.fact_sucursal = i2.item_sucursal
                            AND f2.fact_tipo = i2.item_tipo
        INNER JOIN Producto p2 ON p2.prod_codigo = i2.item_producto
        INNER JOIN Familia fa2 ON p2.prod_familia = fa2.fami_id
        WHERE fa2.fami_id = fa.fami_id AND YEAR(f2.fact_fecha) = YEAR(f.fact_fecha)
        GROUP BY f2.fact_cliente
        ORDER BY SUM(i2.item_cantidad * i2.item_precio) DESC
        ) AS cant_unidades_compradas,

        COUNT(DISTINCT p.prod_codigo) AS productos_familia

FROM Factura f 
INNER JOIN Item_Factura i ON f.fact_numero = i.item_numero
                            AND f.fact_sucursal = i.item_sucursal
                            AND f.fact_tipo = i.item_tipo
INNER JOIN Producto p ON i.item_producto = p.prod_codigo
INNER JOIN Familia fa ON fa.fami_id = p.prod_familia
GROUP BY YEAR(f.fact_fecha), fa.fami_id, fa.fami_detalle
ORDER BY año ASC, productos_familia ASC, fa.fami_id ASC




-- 1C2025 24/06
SELECT TOP 5 CONCAT(RTRIM(e.empl_apellido),',',SPACE(1),RTRIM(e.empl_nombre)) AS apellido_y_nombre,
        SUM(i.item_cantidad) AS total_unidades_vendidas,
        AVG(f.fact_total) AS promedio_por_factura,
        SUM(f.fact_total) AS monto_total_ventas
FROM Empleado e 
INNER JOIN Factura f ON f.fact_vendedor = e.empl_codigo
INNER JOIN Item_Factura i ON f.fact_numero = i.item_numero
                        AND f.fact_sucursal = i.item_sucursal
                        AND f.fact_tipo = i.item_tipo
--WHERE YEAR(f.fact_fecha) = DATEADD(YEAR, -1, GETDATE())
WHERE YEAR(f.fact_fecha) = 2012
AND (i.item_numero + i.item_tipo + i.item_sucursal) IN (SELECT i2.item_numero + i2.item_tipo + i2.item_sucursal
                                                        FROM Item_Factura i2 
                                                        GROUP BY i2.item_numero, i2.item_tipo, i2.item_sucursal
                                                        HAVING (COUNT(*)) > 2)
GROUP BY e.empl_codigo, e.empl_apellido, e.empl_nombre
ORDER BY COUNT(DISTINCT f.fact_cliente) ASC, monto_total_ventas DESC, e.empl_codigo ASC



-- ns otro parcial
--zonas con 2 depositos
SELECT z.zona_detalle,
        COUNT(DISTINCT d.depo_codigo) AS cant_depositos,
        COUNT(DISTINCT s.stoc_producto) AS cant_prod_distintos,
        COUNT(DISTINCT i.item_producto) AS cant_prod_distintos_vendidos
FROM Zona z 
INNER JOIN Deposito d ON d.depo_zona = z.zona_codigo
LEFT OUTER JOIN Stock s ON s.stoc_deposito = d.depo_codigo
LEFT OUTER JOIN Item_Factura i ON i.item_producto = s.stoc_producto
GROUP BY z.zona_codigo, z.zona_detalle
HAVING COUNT(DISTINCT d.depo_codigo) >= 2
ORDER BY (SELECT COUNT(e.empl_codigo) 
        FROM Empleado e
        INNER JOIN Departamento de ON e.empl_departamento = de.depa_codigo
        WHERE de.depa_zona = z.zona_codigo) DESC



--RECU 1C25 1/7
SELECT CONCAT(RTRIM(e.empl_apellido),',',SPACE(1),RTRIM(e.empl_nombre)) AS apellido_y_nombre,
        'Mejor Facturación' AS ranking
FROM Empleado e 
INNER JOIN Factura f ON e.empl_codigo = f.fact_vendedor
WHERE e.empl_codigo = (SELECT TOP 1 f2.fact_vendedor
                        FROM Factura f2 
                        WHERE YEAR(f2.fact_fecha) = (SELECT MAX(YEAR(f2.fact_fecha)) FROM Factura f2)
                        GROUP BY f2.fact_vendedor
                        ORDER BY SUM(f2.fact_total) DESC)
GROUP BY e.empl_codigo, e.empl_apellido, e.empl_nombre
UNION ALL
SELECT CONCAT(RTRIM(e.empl_apellido),',',SPACE(1),RTRIM(e.empl_nombre)) AS apellido_y_nombre,
        'Vendio Más Facturas' AS ranking
FROM Empleado e 
INNER JOIN Factura f ON e.empl_codigo = f.fact_vendedor
WHERE e.empl_codigo = (SELECT TOP 1 f2.fact_vendedor
                        FROM Factura f2 
                        WHERE YEAR(f2.fact_fecha) = (SELECT MAX(YEAR(f2.fact_fecha)) FROM Factura f2)
                        GROUP BY f2.fact_vendedor
                        ORDER BY COUNT(DISTINCT f2.fact_numero + f2.fact_sucursal + f2.fact_tipo) DESC)
GROUP BY e.empl_codigo, e.empl_apellido, e.empl_nombre

