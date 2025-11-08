SELECT p.prod_detalle,
        r.rubr_detalle AS rubr_descripcion,
        SUM(i.item_cantidad) AS cant_total_item_vendido,
        SUM(i.item_cantidad * i.item_precio) * 100 / (SELECT SUM(i2.item_cantidad * i2.item_precio)
                                                    FROM Item_Factura i2
                                                    INNER JOIN Factura f2 ON i2.item_numero = f2.fact_numero
                                                                        AND i2.item_sucursal = f2.fact_sucursal
                                                                        AND i2.item_tipo = f2.fact_tipo
                                                    WHERE i2.item_producto = p.prod_codigo
                                                    AND YEAR(f2.fact_fecha) = 2012) AS porcentaje_ventas,
        (CASE WHEN s.stoc_cantidad = 0 THEN (SELECT TOP 1 c.clie_razon_social
                                            FROM Cliente c 
                                            INNER JOIN Factura f3 ON f3.fact_cliente = c.clie_codigo
                                            INNER JOIN Item_Factura i3 ON i3.item_numero = f3.fact_numero
                                                                        AND i3.item_sucursal = f3.fact_sucursal
                                                                        AND i3.item_tipo = f3.fact_tipo
                                            WHERE i3.item_producto = p.prod_codigo
                                            GROUP BY c.clie_codigo, c.clie_razon_social, f3.fact_fecha
                                            ORDER BY f3.fact_fecha DESC)
        ELSE ''
        END) AS ultimo_cliente_compra
From Deposito d 
INNER JOIN Stock s ON s.stoc_deposito = d.depo_codigo
INNER JOIN Producto p ON p.prod_codigo = s.stoc_producto
INNER JOIN Item_Factura i ON p.prod_codigo = i.item_producto
INNER JOIN Factura f ON i.item_numero = f.fact_numero
                    AND i.item_sucursal = f.fact_sucursal
                    AND i.item_tipo = f.fact_tipo
LEFT OUTER JOIN Rubro r ON r.rubr_id = p.prod_rubro
WHERE d.depo_codigo = '05' AND i.item_sucursal = '0005'
AND YEAR(f.fact_fecha) = 2012
GROUP BY p.prod_codigo, p.prod_detalle, s.stoc_cantidad, r.rubr_id, r.rubr_detalle
ORDER BY MAX(i.item_precio) DESC, p.prod_codigo ASC