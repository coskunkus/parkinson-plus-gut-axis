# =====================================================================
# check_results.py
# Makalede raporlanan sayilarin ikinci dilde dogrulamasi.
#
# check_results.R, ana istatistikleri base R ile hesaplayip
# results/check_results_report.txt icindeki DEGERLER blogunda yazar.
# Bu betik ayni istatistikleri ham veriden Python ile bastan hesaplar
# ve iki sonucu karsilastirir. Boylece kagittan koda gecerken yapilan
# bir hata iki bagimsiz uygulamada birden hayatta kalamaz.
#
# Proje kokunden calistirilir:
#     python code/check_results.py
# Yazdigi: results/check_results_py_report.txt
#
# Once check_results.R calistirilmis olmalidir.
# =====================================================================

import os
import sys

import numpy as np
import pandas as pd
from scipy import stats

TOLERANS = 1e-3          # medyan ve rho icin
TOLERANS_P = 1e-4        # p degerleri icin

kok = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sonuclar = os.path.join(kok, "results")
rapor_r = os.path.join(sonuclar, "check_results_report.txt")

if not os.path.exists(rapor_r):
    sys.exit("Once 'Rscript code/check_results.R' calistirin.")


def veri_bul():
    adaylar = [os.path.join(kok, "data", "data.xlsx"), os.path.join(kok, "data.xlsx")]
    for a in adaylar:
        if os.path.exists(a):
            return a
    for kl in (os.path.join(kok, "data"), kok):
        if os.path.isdir(kl):
            for f in sorted(os.listdir(kl)):
                if f.lower().endswith(".xlsx") and not f.startswith("~"):
                    return os.path.join(kl, f)
    sys.exit("Veri dosyasi bulunamadi. data/data.xlsx olarak koyun.")


def r_degerleri(yol):
    """DEGERLER ve SON arasindaki bloku okur."""
    icinde, cikti = False, {}
    with open(yol, encoding="utf-8") as f:
        for satir in f:
            s = satir.rstrip("\n")
            if s.strip() == "DEGERLER":
                icinde = True
                continue
            if s.strip() == "SON":
                break
            if icinde and "\t" in s:
                parca = s.split("\t")
                cikti[(parca[0], parca[1])] = [float(x) for x in parca[2:]]
    return cikti


ESLE = {
    "lbp": None,                  # adi dosyadan dosyaya degisti, asagida aranir
    "fatp5": "fat5",              # sutun adlari kucuk harfe indirilir
    "total_scfa": "toplam kisaa zincirli yag asitler",
    "acetic": "asetikasit",
    "propionic": "propiyonik asit",
    "butyric": "butirik asit",
    "age": "yas/yil",
}
GRUP = {"kontrol": "C", "parkinson": "PD", "parkinsonplus": "PPD"}


def sadeles(ad):
    """Sutun adlarini Turkce karakterden arindirir, kucultur."""
    cev = str.maketrans("cgiiosuCGIIOSU", "cgiiosuCGIIOSU")
    ad = (ad.replace("ç", "c").replace("ğ", "g").replace("ı", "i")
            .replace("İ", "I").replace("ö", "o").replace("ş", "s")
            .replace("ü", "u").replace("Ç", "C").replace("Ğ", "G")
            .replace("Ö", "O").replace("Ş", "S").replace("Ü", "U"))
    return ad.translate(cev).strip().lower()


def main():
    yol = veri_bul()
    d = pd.read_excel(yol)
    d.columns = [sadeles(c) for c in d.columns]
    grup = d[sadeles("Parknsontur")].map(GRUP) if sadeles("Parknsontur") in d.columns \
        else d[[c for c in d.columns if "parknson" in c][0]].map(GRUP)

    # LBP sutunu: eski dosyada "lipopolisakkarit", yeni dosyada "... (LBP)"
    lbp_ad = [c for c in d.columns if "(lbp)" in c or c.startswith("lipopolisakkarit")]
    if not lbp_ad:
        sys.exit("LBP sutunu bulunamadi.")
    ESLE["lbp"] = lbp_ad[0]

    # Toplam SCFA bos ama uc ana asit olculmusse, alti asidin toplami
    # (limit alti = 0) ile tamamlanir. Kural R tarafindakiyle aynidir,
    # uygulama bagimsizdir.
    alti = ["asetikasit", "propiyonik asit", "butirik asit",
            "isobutirik asit", "valerik", "isovalerik asit"]
    ts = "toplam kisaa zincirli yag asitler"
    if all(a in d.columns for a in alti) and ts in d.columns:
        sayi = d[alti].apply(pd.to_numeric, errors="coerce")
        bos = d[ts].isna() & sayi[alti[:3]].notna().all(axis=1)
        d.loc[bos, ts] = sayi.loc[bos].fillna(0).sum(axis=1)

    beklenen = r_degerleri(rapor_r)
    satir, gecti, kaldi = [], 0, 0

    def kontrol(ad, a, b, tol):
        nonlocal gecti, kaldi
        ok = np.all(np.abs(np.array(a) - np.array(b)) < tol)
        if ok:
            gecti += 1
            satir.append("PASS  %-34s R=%s  PY=%s" % (ad, fmt(b), fmt(a)))
        else:
            kaldi += 1
            satir.append("FAIL  %-34s R=%s  PY=%s" % (ad, fmt(b), fmt(a)))

    def fmt(x):
        return " ".join("%.4f" % v for v in np.atleast_1d(x))

    satir.append("=== R VE PYTHON SONUCLARININ KARSILASTIRILMASI ===")
    satir.append("Veri dosyasi: %s" % yol)
    satir.append("")

    for ad, sut in ESLE.items():
        if sut not in d.columns:
            satir.append("ATLANDI  %s (sutun bulunamadi: %s)" % (ad, sut))
            continue
        v = pd.to_numeric(d[sut], errors="coerce")
        gr = [v[grup == g].dropna() for g in ("PPD", "PD", "C")]
        if (ad, "n") in beklenen:
            kontrol(ad + " n", [len(x) for x in gr], beklenen[(ad, "n")], 0.5)
        if (ad, "medyan") in beklenen:
            kontrol(ad + " medyan", [x.median() for x in gr],
                    beklenen[(ad, "medyan")], TOLERANS)
        if (ad, "kruskal_p") in beklenen:
            p = stats.kruskal(*gr).pvalue
            kontrol(ad + " Kruskal p", [p], beklenen[(ad, "kruskal_p")], TOLERANS_P)

    f = pd.to_numeric(d[ESLE["fatp5"]], errors="coerce")
    l = pd.to_numeric(d[ESLE["lbp"]], errors="coerce")
    ok = f.notna() & l.notna()
    rho, p = stats.spearmanr(f[ok], l[ok])
    if ("fatp5_lbp", "spearman_rho") in beklenen:
        kontrol("FATP5-LBP rho", [rho], beklenen[("fatp5_lbp", "spearman_rho")], TOLERANS)
        kontrol("FATP5-LBP p", [p], beklenen[("fatp5_lbp", "spearman_p")], TOLERANS_P)
        kontrol("FATP5-LBP n", [int(ok.sum())], beklenen[("fatp5_lbp", "n")], 0.5)

    satir.append("")
    satir.append("=== OZET ===")
    satir.append("Gecen: %d   Kalan: %d" % (gecti, kaldi))
    satir.append("TUM KONTROLLER GECTI" if kaldi == 0
                 else "DIKKAT: EN AZ BIR KONTROL BASARISIZ")

    os.makedirs(sonuclar, exist_ok=True)
    with open(os.path.join(sonuclar, "check_results_py_report.txt"), "w",
              encoding="utf-8") as fh:
        fh.write("\n".join(satir) + "\n")
    print("\n".join(satir))
    print("\nRapor: %s" % os.path.join(sonuclar, "check_results_py_report.txt"))
    return 1 if kaldi else 0


if __name__ == "__main__":
    sys.exit(main())
