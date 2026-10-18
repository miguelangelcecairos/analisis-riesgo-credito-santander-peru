-- Consulta 2: Banco Santander Perú vs. resto de la banca múltiple, mes a mes.
--   margen_bruto_pct = margen financiero bruto / ingresos financieros
--   gasto_adm_pct    = gastos administrativos / ingresos financieros
--   prov_pct_margen  = provisiones para créditos directos / margen financiero bruto
-- "Resto" = suma de las demás bancas ANTES de dividir (no un promedio de porcentajes). pp = puntos porcentuales.
-- Para analizar otra entidad, cambiar solo el nombre en la CTE "params".
WITH params AS (SELECT 'Banco Santander Perú' AS entidad),
acum AS (
    SELECT s.entidad_id, e.nombre, s.periodo,
           SUM(CASE WHEN s.cuenta = 'INGRESOS FINANCIEROS'               THEN s.monto_miles_soles END) AS ingresos,
           SUM(CASE WHEN s.cuenta = 'MARGEN FINANCIERO BRUTO'            THEN s.monto_miles_soles END) AS margen_bruto,
           SUM(CASE WHEN s.cuenta = 'PROVISIONES PARA CRÉDITOS DIRECTOS' THEN s.monto_miles_soles END) AS prov_creditos,
           SUM(CASE WHEN s.cuenta = 'GASTOS ADMINISTRATIVOS'             THEN s.monto_miles_soles END) AS gasto_adm
    FROM estado_resultados s
    JOIN entidades e USING (entidad_id)
    WHERE s.nivel = 0 AND s.moneda = 'TOTAL'
      AND e.nombre NOT LIKE 'Total%'                                      -- filas agregadas
      AND e.nombre <> 'Banco de Crédito con Sucursales en el Exterior'    -- duplicaría a BCP
      AND e.nombre <> 'Banco Efectiva'                                    -- solo aparece 3 meses
    GROUP BY s.entidad_id, e.nombre, s.periodo
),
flujo AS (
    SELECT nombre, periodo,
           ingresos      - COALESCE(LAG(ingresos)      OVER w, 0) AS ingresos_mes,
           margen_bruto  - COALESCE(LAG(margen_bruto)  OVER w, 0) AS margen_bruto_mes,
           prov_creditos - COALESCE(LAG(prov_creditos) OVER w, 0) AS prov_mes,
           gasto_adm     - COALESCE(LAG(gasto_adm)     OVER w, 0) AS gasto_adm_mes
    FROM acum
    WINDOW w AS (PARTITION BY entidad_id, substr(periodo,1,4) ORDER BY periodo)
),
agg AS (
    SELECT f.periodo,
        SUM(CASE WHEN f.nombre =  p.entidad THEN ingresos_mes     END) AS ing_e,
        SUM(CASE WHEN f.nombre =  p.entidad THEN margen_bruto_mes END) AS mb_e,
        SUM(CASE WHEN f.nombre =  p.entidad THEN prov_mes         END) AS pv_e,
        SUM(CASE WHEN f.nombre =  p.entidad THEN gasto_adm_mes    END) AS ga_e,
        SUM(CASE WHEN f.nombre <> p.entidad THEN ingresos_mes     END) AS ing_r,
        SUM(CASE WHEN f.nombre <> p.entidad THEN margen_bruto_mes END) AS mb_r,
        SUM(CASE WHEN f.nombre <> p.entidad THEN prov_mes         END) AS pv_r,
        SUM(CASE WHEN f.nombre <> p.entidad THEN gasto_adm_mes    END) AS ga_r
    FROM flujo f, params p
    WHERE f.periodo > '2025-09-30'
    GROUP BY f.periodo
)
SELECT periodo,
       ROUND(100.0*mb_e/ing_e,1) AS margen_ent,  ROUND(100.0*mb_r/ing_r,1) AS margen_resto,
       ROUND(100.0*mb_e/ing_e - 100.0*mb_r/ing_r,1) AS dif_margen_pp,
       ROUND(100.0*ga_e/ing_e,1) AS gasto_adm_ent, ROUND(100.0*ga_r/ing_r,1) AS gasto_adm_resto,
       ROUND(100.0*ga_e/ing_e - 100.0*ga_r/ing_r,1) AS dif_gasto_pp,
       ROUND(100.0*pv_e/mb_e,1) AS prov_pct_margen_ent, ROUND(100.0*pv_r/mb_r,1) AS prov_pct_margen_resto,
       ROUND(100.0*pv_e/mb_e - 100.0*pv_r/mb_r,1) AS dif_prov_pp
FROM agg
ORDER BY periodo;
