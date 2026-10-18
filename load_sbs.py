"""Carga archivos B-2201 (Balance General y Estado de Ganancias y Perdidas por
Empresa Bancaria, SBS) a una base SQLite en formato largo.

Uso: python -I load_sbs.py <carpeta_con_xls> <salida.db>
"""
import sys
import glob
import os
import sqlite3
import pandas as pd

MONEDAS = ["MN", "ME", "TOTAL"]


def parse_sheet(df):
    """Devuelve (periodo, filas) con filas = (entidad, cuenta, nivel, orden, moneda, monto)."""
    periodo = pd.to_datetime(df.iloc[2, 0]).date().isoformat()
    title_cols = [j for j, v in enumerate(df.iloc[1]) if pd.notna(v)]
    out = []
    n = df.shape[0]
    # cada bloque de encabezado: fila donde aparece la fila MN/ME/TOTAL
    mon_rows = [i for i in range(n)
                if sum(str(v).strip() == "MN" for v in df.iloc[i]) >= 3]
    for k, mr in enumerate(mon_rows):
        name_row = mr - 1
        end = mon_rows[k + 1] - 4 if k + 1 < len(mon_rows) else n
        # entidades de este bloque: celdas con nombre sobre una columna "MN"
        for c in range(df.shape[1]):
            if str(df.iloc[mr, c]).strip() != "MN":
                continue
            ent = df.iloc[name_row, c]
            if pd.isna(ent):
                continue
            ent = " ".join(str(ent).split()).rstrip("*").strip()
            label_col = max(t for t in title_cols if t <= c)
            for i in range(mr + 1, end):
                raw = df.iloc[i, label_col]
                if pd.isna(raw) and label_col != 0:
                    raw = df.iloc[i, 0]
                if pd.isna(raw):
                    continue
                raw = str(raw)
                cuenta = " ".join(raw.split())
                if cuenta.startswith(("Tipo de Cambio", "1/")):
                    continue
                nivel = (len(raw) - len(raw.lstrip(" "))) // 3
                for m, mon in enumerate(MONEDAS):
                    v = df.iloc[i, c + m]
                    if pd.isna(v):
                        continue
                    try:
                        monto = float(v)
                    except (TypeError, ValueError):
                        continue
                    out.append((ent, cuenta, nivel, i, mon, monto))
    return periodo, out


def main(carpeta, db_path):
    if os.path.exists(db_path):
        os.remove(db_path)
    con = sqlite3.connect(db_path)
    con.executescript("""
    CREATE TABLE entidades(
        entidad_id INTEGER PRIMARY KEY,
        nombre TEXT UNIQUE NOT NULL);
    CREATE TABLE balance(
        entidad_id INTEGER, periodo TEXT, bloque TEXT, cuenta TEXT,
        nivel INTEGER, orden INTEGER, moneda TEXT, monto_miles_soles REAL,
        UNIQUE(entidad_id, periodo, bloque, orden, moneda));
    CREATE TABLE estado_resultados(
        entidad_id INTEGER, periodo TEXT, cuenta TEXT,
        nivel INTEGER, orden INTEGER, moneda TEXT, monto_miles_soles REAL,
        UNIQUE(entidad_id, periodo, orden, moneda));
    """)
    ids = {}

    def ent_id(nombre):
        if nombre not in ids:
            cur = con.execute("INSERT INTO entidades(nombre) VALUES (?)", (nombre,))
            ids[nombre] = cur.lastrowid
        return ids[nombre]

    archivos = sorted(glob.glob(os.path.join(carpeta, "*.XLS")) +
                      glob.glob(os.path.join(carpeta, "*.xls")) +
                      glob.glob(os.path.join(carpeta, "*.xlsx")))
    for f in archivos:
        x = pd.ExcelFile(f)
        # hoja 1 = balance, hoja 2 = estado de ganancias y perdidas
        bal = x.parse(x.sheet_names[0], header=None)
        per, filas = parse_sheet(bal)
        bloque = "Activo"
        for ent, cuenta, nivel, orden, mon, monto in filas:
            # el balance trae dos tablas apiladas: activo y pasivo/patrimonio
            bloque = "Activo" if orden < 70 else "Pasivo y patrimonio"
            con.execute("INSERT OR IGNORE INTO balance VALUES (?,?,?,?,?,?,?,?)",
                        (ent_id(ent), per, bloque, cuenta, nivel, orden, mon, monto))
        er = x.parse(x.sheet_names[1], header=None)
        per2, filas2 = parse_sheet(er)
        for ent, cuenta, nivel, orden, mon, monto in filas2:
            con.execute("INSERT OR IGNORE INTO estado_resultados VALUES (?,?,?,?,?,?,?)",
                        (ent_id(ent), per2, cuenta, nivel, orden, mon, monto))
        print(os.path.basename(f), per, len(filas), "filas balance;", len(filas2), "filas resultados")
    con.commit()
    con.close()


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
