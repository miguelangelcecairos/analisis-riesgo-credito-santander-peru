-- Consulta 3: calidad de cartera y costo de riesgo de Banco Santander Perú vs. resto de la banca.
-- Fuente: balance (saldos, NO acumulados: no requiere LAG) + provisiones del estado de resultados (acumuladas: sí requiere LAG).
--   cartera_bruta   = créditos Vigentes + Refinanciados y Reestructurados + Atrasados
--   mora_pct        = Atrasados / cartera_bruta
--   alto_riesgo_pct = (Refinanciados + Atrasados) / cartera_bruta
--   cobertura_pct   = provisiones de la cartera (balance) / Atrasados
--   costo_riesgo_anual_pct = provisiones para créditos directos del mes x 12 / cartera_bruta
-- "Resto" = suma de las demás bancas antes de dividir. Para otra entidad, cambiar solo la CTE "params".
WITH params AS (SELECT 'Banco Santander Perú' AS entidad),
ent AS (
    SELECT entidad_id, nombre FROM entidades
    WHERE nombre NOT LIKE 'Total%'
      AND nombre <> 'Banco de Crédito con Sucursales en el Exterior'
      AND nombre <> 'Banco Efectiva'
),
cartera AS (
    SELECT b.entidad_id, b.periodo,
           SUM(CASE WHEN b.cuenta = 'Vigentes'                       THEN b.monto_miles_soles END) AS vigentes,
           SUM(CASE WHEN b.cuenta = 'Refinanciados y Reestructurados' THEN b.monto_miles_soles END) AS refinanciados,
           SUM(CASE WHEN b.cuenta = 'Atrasados'                       THEN b.monto_miles_soles END) AS atrasados,
           SUM(CASE WHEN b.cuenta = 'Provisiones' AND b.orden = 40    THEN b.monto_miles_soles END) AS provisiones   -- negativo en el balance
    FROM balance b
    WHERE b.bloque = 'Activo' AND b.nivel = 1 AND b.moneda = 'TOTAL'
    GROUP BY b.entidad_id, b.periodo
),
prov_acum AS (
    SELECT entidad_id, periodo, monto_miles_soles AS prov_acum
    FROM estado_resultados
    WHERE cuenta = 'PROVISIONES PARA CRÉDITOS DIRECTOS' AND nivel = 0 AND moneda = 'TOTAL'
),
prov_mes AS (
    SELECT entidad_id, periodo,
           prov_acum - COALESCE(LAG(prov_acum) OVER (PARTITION BY entidad_id, substr(periodo,1,4) ORDER BY periodo), 0) AS prov_mes
    FROM prov_acum
),
datos AS (
    SELECT e.nombre, c.periodo, c.vigentes, c.refinanciados, c.atrasados, -c.provisiones AS prov_stock, pm.prov_mes
    FROM ent e
    JOIN cartera  c  ON c.entidad_id  = e.entidad_id
    JOIN prov_mes pm ON pm.entidad_id = e.entidad_id AND pm.periodo = c.periodo
    WHERE c.periodo > '2025-09-30'
),
agg AS (
    SELECT d.periodo,
        SUM(CASE WHEN nombre =  p.entidad THEN vigentes + refinanciados + atrasados END) AS cb_e,
        SUM(CASE WHEN nombre =  p.entidad THEN atrasados          END) AS at_e,
        SUM(CASE WHEN nombre =  p.entidad THEN refinanciados      END) AS rf_e,
        SUM(CASE WHEN nombre =  p.entidad THEN prov_stock         END) AS ps_e,
        SUM(CASE WHEN nombre =  p.entidad THEN prov_mes           END) AS pm_e,
        SUM(CASE WHEN nombre <> p.entidad THEN vigentes + refinanciados + atrasados END) AS cb_r,
        SUM(CASE WHEN nombre <> p.entidad THEN atrasados          END) AS at_r,
        SUM(CASE WHEN nombre <> p.entidad THEN refinanciados      END) AS rf_r,
        SUM(CASE WHEN nombre <> p.entidad THEN prov_stock         END) AS ps_r,
        SUM(CASE WHEN nombre <> p.entidad THEN prov_mes           END) AS pm_r
    FROM datos d, params p
    GROUP BY d.periodo
)
SELECT periodo,
       ROUND(100.0*at_e/cb_e,2)            AS mora_ent,        ROUND(100.0*at_r/cb_r,2)            AS mora_resto,
       ROUND(100.0*(at_e+rf_e)/cb_e,2)     AS alto_riesgo_ent, ROUND(100.0*(at_r+rf_r)/cb_r,2)     AS alto_riesgo_resto,
       ROUND(100.0*ps_e/at_e,1)            AS cobertura_ent,   ROUND(100.0*ps_r/at_r,1)            AS cobertura_resto,
       ROUND(100.0*pm_e*12/cb_e,2)         AS costo_riesgo_ent, ROUND(100.0*pm_r*12/cb_r,2)        AS costo_riesgo_resto
FROM agg
ORDER BY periodo;
