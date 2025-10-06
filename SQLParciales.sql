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
