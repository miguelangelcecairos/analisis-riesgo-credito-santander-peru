# Riesgo de crédito y rentabilidad de Banco Santander Perú frente a la banca múltiple peruana (SQL)

Análisis en SQL de la rentabilidad, las provisiones y la calidad de cartera de **Banco Santander Perú** comparado con el resto de la banca múltiple del Perú, usando los estados financieros publicados por la SBS entre **septiembre 2025 y agosto 2026**.

**Autor:** Miguel Angel Cecairos Lopez · [LinkedIn](https://www.linkedin.com/in/miguelcecairos/)

## Preguntas que responde

1. ¿Cuánto del ingreso financiero de Santander se convierte en margen financiero bruto, cuánto gasta en operar y qué peso tienen las provisiones, frente al resto de la banca?
2. ¿Cómo es la calidad de su cartera (mora, cartera de alto riesgo, cobertura) y cuánto provisiona por cada sol de cartera (costo de riesgo)?

## Datos

- **Fuente:** SBS, *Información Estadística de Banca Múltiple → Estados Financieros por Empresa Bancaria* (archivos `B-2201`, un archivo por mes, con balance general y estado de ganancias y pérdidas).
- **Periodo:** 12 meses, de septiembre 2025 a agosto 2026. **Unidad:** miles de soles, columna `TOTAL` (moneda nacional + extranjera).
- **Cobertura:** 24 entidades en la base. Para las comparaciones se excluyen las filas agregadas ("Total Banca Múltiple"), la fila de BCP con sucursales en el exterior (duplicaría a BCP) y Banco Efectiva (solo aparece 3 meses). *Santander Consumer Bank* es otra entidad y queda dentro de "resto"; excluirla no cambia las conclusiones.

## Cómo se organiza

| Archivo | Qué hace |
|---|---|
| `load_sbs.py` | Convierte los archivos Excel de la SBS (formato ancho) a una base SQLite en formato largo: tablas `entidades`, `balance` y `estado_resultados`. |
| `consulta1_santander_flujo_mensual.sql` | Flujo mensual de Santander: ingresos, gastos, margen bruto, provisiones, gasto administrativo y resultado neto. |
| `consulta2_comparacion.sql` | Santander frente al resto: margen bruto %, gasto administrativo % y provisiones sobre margen bruto, mes a mes. |
| `consulta3_calidad_cartera.sql` | Mora, cartera de alto riesgo, cobertura y costo de riesgo de Santander frente al resto. |

## Cómo reproducirlo

1. Descargar los 12 archivos mensuales de la SBS y ponerlos en una carpeta.
2. Generar la base: `python load_sbs.py carpeta_con_xls sbs.db`
3. Abrir `sbs.db` en [DB Browser for SQLite](https://sqlitebrowser.org/) y ejecutar las consultas en la pestaña *Ejecutar SQL*.

## Puntos técnicos clave

- **Datos acumulados.** El estado de ganancias y pérdidas viene acumulado en el año. El flujo de cada mes se obtiene restando el acumulado del mes anterior con `LAG() OVER (PARTITION BY entidad, año ORDER BY periodo)` y `COALESCE` para enero. Septiembre 2025 se excluye porque faltan enero a agosto de 2025.
- **Balance = saldos.** Mora, cartera de alto riesgo y cobertura salen del balance, que no es acumulado y no necesita `LAG`.
- Técnicas SQL: CTEs, `JOIN`, `GROUP BY`, agregación condicional (`SUM(CASE WHEN ...)`), funciones de ventana, `COALESCE`.

Definiciones: cartera bruta = créditos vigentes + refinanciados y reestructurados + atrasados. Mora = atrasados / cartera bruta. Cartera de alto riesgo = (refinanciados + atrasados) / cartera bruta. Cobertura = provisiones de la cartera / atrasados. Costo de riesgo = provisiones para créditos directos del mes x 12 / cartera bruta. "Resto" = suma de las demás bancas antes de dividir (no un promedio de porcentajes). `pp` = puntos porcentuales.

## Resultados

### Rentabilidad y provisiones (consulta 2)

| Mes | Margen Santander | Margen resto | Dif. (pp) | Gasto adm. Santander | Gasto adm. resto | Dif. (pp) | Prov./margen Santander | Prov./margen resto |
|---|---|---|---|---|---|---|---|---|
| Oct 2025 | 55.1% | 75.0% | -19.9 | 25.4% | 34.5% | -9.2 | -1.2% | 18.5% |
| Nov 2025 | 77.5% | 78.2% | -0.7 | 36.4% | 38.3% | -1.9 | -0.4% | 16.9% |
| Dic 2025 | 73.7% | 80.1% | -6.4 | 43.4% | 39.8% | +3.6 | 22.7% | 17.5% |
| Ene 2026 | 63.6% | 78.4% | -14.8 | 27.8% | 33.6% | -5.8 | -5.2% | 14.0% |
| Feb 2026 | 70.6% | 79.0% | -8.4 | 23.6% | 38.4% | -14.8 | 2.1% | 15.1% |
| Mar 2026 | 48.9% | 71.6% | -22.7 | 19.6% | 31.9% | -12.3 | 20.5% | 13.8% |
| Abr 2026 | 57.6% | 76.6% | -19.0 | 26.1% | 34.4% | -8.4 | 2.0% | 15.4% |
| May 2026 | 86.8% | 88.8% | -2.0 | 24.8% | 39.3% | -14.5 | -3.6% | 16.6% |
| Jun 2026 | 68.5% | 79.7% | -11.3 | 23.2% | 36.2% | -13.0 | 2.9% | 15.6% |
| Jul 2026 | 66.5% | 78.9% | -12.4 | 28.3% | 35.6% | -7.3 | 1.7% | 17.8% |
| Ago 2026 | 64.0% | 78.5% | -14.5 | 31.9% | 35.5% | -3.6 | -4.6% | 20.1% |

### Calidad de cartera (consulta 3)

| Mes | Mora Santander | Mora resto | Alto riesgo Santander | Alto riesgo resto | Cobertura Santander | Cobertura resto |
|---|---|---|---|---|---|---|
| Oct 2025 | 3.13% | 3.4% | 3.3% | 5.2% | 151.7% | 167.4% |
| Nov 2025 | 2.89% | 3.27% | 3.05% | 5.1% | 154.2% | 171.1% |
| Dic 2025 | 2.33% | 3.28% | 4.46% | 5.09% | 188.6% | 170.8% |
| Ene 2026 | 2.47% | 3.21% | 4.64% | 5.05% | 182.6% | 173.1% |
| Feb 2026 | 2.53% | 3.12% | 4.67% | 4.94% | 186.5% | 175.9% |
| Mar 2026 | 2.66% | 3.0% | 5.21% | 4.79% | 184.3% | 178.9% |
| Abr 2026 | 2.7% | 2.91% | 5.29% | 4.64% | 184.8% | 181.1% |
| May 2026 | 2.62% | 2.85% | 5.33% | 4.54% | 191.9% | 183.2% |
| Jun 2026 | 2.64% | 2.86% | 5.33% | 4.47% | 193.0% | 182.0% |
| Jul 2026 | 2.49% | 2.86% | 5.08% | 4.4% | 195.8% | 180.5% |
| Ago 2026 | 2.45% | 2.83% | 4.98% | 4.4% | 195.8% | 182.0% |

### Hallazgos

- El **margen financiero bruto** de Santander fue **menor** que el del resto de la banca en **11 de 11 meses**, unos **12.0 pp** por debajo en promedio, y más volátil (de 48.9% a 86.8%).
- Su **gasto administrativo sobre ingresos** fue menor en **10 de 11 meses**, unos **7.9 pp** por debajo en promedio.
- Las **provisiones sobre margen bruto** fueron menores en **9 de 11 meses** (13.1 pp por debajo en promedio).
- La **mora** de Santander fue menor que la del resto en **11 de 11 meses** (2.45% frente a 2.83% en agosto 2026) y su **cobertura** fue mayor en **9 de 11** (195.8% frente a 182.0%).
- La **cartera de alto riesgo** de Santander subió de 3.3% (octubre 2025) a 5.0% (agosto 2026), mientras la del resto bajó de 5.2% a 4.4%. El aumento viene de los refinanciados y reestructurados (de S/ 9 M a S/ 143 M); los atrasados bajaron de S/ 171 M a S/ 138 M.
- *Hipótesis (no verificada con estos datos):* parte de la caída de la mora podría reflejar créditos que pasaron de atrasados a refinanciados. Verificarlo requeriría datos por crédito o por tramo de atraso.

## Cómo adaptarlo a otra entidad

Las consultas no dependen de Santander: la base contiene las 24 entidades y el nombre analizado se define **una sola vez**, en la CTE `params` al inicio de cada archivo (`SELECT 'Banco Santander Perú' AS entidad`).

1. Ver los nombres exactos disponibles: `SELECT nombre FROM entidades ORDER BY nombre;`
2. Cambiar el nombre en la CTE `params` de cada consulta.

*Validación:* con `'Mibanco'` las mismas consultas reproducen los resultados de la versión anterior de este análisis (margen mayor en 9 de 11 meses, +2.6 pp; gasto administrativo mayor en 10 de 11 meses, +3.0 pp).

## Limitaciones

- Solo 12 meses y solo banca múltiple (no incluye cajas ni financieras).
- **No incluye capital regulatorio** (ratio de capital global, patrimonio efectivo ni activos ponderados por riesgo): esos datos no están en los estados financieros usados. Tampoco es un reporte regulatorio SBS.
- Las provisiones consideradas son las de créditos directos; el costo de riesgo mensual es volátil porque incluye liberaciones de provisiones.
- El análisis es descriptivo; no explica las causas de las diferencias entre entidades.

## Nota sobre el desarrollo

Proyecto elaborado con apoyo de una herramienta de inteligencia artificial (Claude) para el diseño de las consultas y del script de carga. Los datos cargados se validaron con controles de consistencia: en todos los meses y entidades, activo = pasivo + patrimonio; el resultado neto del balance coincide con el del estado de ganancias y pérdidas; y el flujo de enero es igual al acumulado de enero.
