-- Consulta 1: flujo mensual de Banco Santander Perú (miles de soles)
-- El estado de ganancias y pérdidas de la SBS viene ACUMULADO en el año:
-- el flujo del mes = acumulado del mes - acumulado del mes anterior (reinicia en enero).
-- Para analizar otra entidad, cambiar solo el nombre en la CTE "params".
WITH params AS (SELECT 'Banco Santander Perú' AS entidad),
acum AS (
    SELECT s.periodo,
           SUM(CASE WHEN s.cuenta = 'INGRESOS FINANCIEROS'                 THEN s.monto_miles_soles END) AS ingresos,
           SUM(CASE WHEN s.cuenta = 'GASTOS FINANCIEROS'                   THEN s.monto_miles_soles END) AS gastos_fin,
           SUM(CASE WHEN s.cuenta = 'MARGEN FINANCIERO BRUTO'              THEN s.monto_miles_soles END) AS margen_bruto,
           SUM(CASE WHEN s.cuenta = 'PROVISIONES PARA CRÉDITOS DIRECTOS'   THEN s.monto_miles_soles END) AS prov_creditos,
           SUM(CASE WHEN s.cuenta = 'GASTOS ADMINISTRATIVOS'               THEN s.monto_miles_soles END) AS gasto_adm,
           SUM(CASE WHEN s.cuenta = 'RESULTADO NETO DEL EJERCICIO'         THEN s.monto_miles_soles END) AS resultado_neto
    FROM estado_resultados s
    JOIN entidades e USING (entidad_id)
    WHERE s.nivel = 0 AND s.moneda = 'TOTAL'
      AND e.nombre = (SELECT entidad FROM params)
    GROUP BY s.periodo
),
flujo AS (
    SELECT periodo,
           ingresos        - COALESCE(LAG(ingresos)        OVER (PARTITION BY substr(periodo,1,4) ORDER BY periodo), 0) AS ingresos_mes,
           gastos_fin      - COALESCE(LAG(gastos_fin)      OVER (PARTITION BY substr(periodo,1,4) ORDER BY periodo), 0) AS gastos_fin_mes,
           margen_bruto    - COALESCE(LAG(margen_bruto)    OVER (PARTITION BY substr(periodo,1,4) ORDER BY periodo), 0) AS margen_bruto_mes,
           prov_creditos   - COALESCE(LAG(prov_creditos)   OVER (PARTITION BY substr(periodo,1,4) ORDER BY periodo), 0) AS prov_creditos_mes,
           gasto_adm       - COALESCE(LAG(gasto_adm)       OVER (PARTITION BY substr(periodo,1,4) ORDER BY periodo), 0) AS gasto_adm_mes,
           resultado_neto  - COALESCE(LAG(resultado_neto)  OVER (PARTITION BY substr(periodo,1,4) ORDER BY periodo), 0) AS resultado_neto_mes
    FROM acum
)
SELECT periodo,
       ROUND(ingresos_mes)       AS ingresos,
       ROUND(gastos_fin_mes)     AS gastos_fin,
       ROUND(margen_bruto_mes)   AS margen_bruto,
       ROUND(prov_creditos_mes)  AS prov_creditos,
       ROUND(gasto_adm_mes)      AS gasto_adm,
       ROUND(resultado_neto_mes) AS resultado_neto,
       ROUND(100.0 * margen_bruto_mes / ingresos_mes, 1) AS margen_bruto_pct
FROM flujo
WHERE periodo > '2025-09-30'   -- sep-2025 se excluye: faltan ene-ago 2025 y su flujo no se puede calcular
ORDER BY periodo;
