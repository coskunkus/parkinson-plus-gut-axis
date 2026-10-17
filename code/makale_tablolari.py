# =====================================================================
# makale_tablolari.py
# Makaledeki butun tablolari run_all.R'in yazdigi TSV dosyalarindan
# uretir. Tablolara elle sayi girilmez; analiz yeniden kosulunca bu betik
# de yeniden calistirilir ve makale guncel sayilarla derlenir.
#
# Proje kokunden calistirilir (once Rscript code/run_all.R):
#     python code/makale_tablolari.py  [makale/tablolar klasoru]
#
# Varsayilan hedef: makale/tablolar klasoru; depo klasorunun yaninda
# (../makale) ya da bir ust duzeyde (../../makale) aranir.
# Yazdiklari (makaledeki numaralarla): tablo1, tablo2, tabloS1 (biyobelirtec
# duyarlilik), tabloS2 (besin), tabloS3 (anket kodlamasi), tabloS4 (Firth),
# tabloS5 (performans). makale_tablolari.R ile ayni ciktiyi verir.
# =====================================================================

import csv
import os
import re
import sys

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SONUC = os.path.join(KOK, "results")
_ADAY = [os.path.join(os.path.dirname(KOK), "makale"),
         os.path.join(os.path.dirname(os.path.dirname(KOK)), "makale")]
HEDEF = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    next((a for a in _ADAY if os.path.isdir(a)), _ADAY[0]), "tablolar")


def oku(ad):
    yol = os.path.join(SONUC, ad + ".tsv")
    if not os.path.exists(yol):
        sys.exit("Bulunamadi: %s. Once 'Rscript code/run_all.R' calistirin." % yol)
    with open(yol, encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def hucre(s):
    """R ciktisindaki hucreyi LaTeX'e cevirir."""
    s = (s or "").strip()
    if not s:
        return ""
    harf = ""
    m = re.match(r"^(.*?\))\s+([ab]+)$", s) or re.match(r"^(.*?\d)\s+([ab]+)$", s)
    if m:
        s, harf = m.group(1), m.group(2)
    s = s.replace("+/-", "$\\pm$")
    s = re.sub(r"(\d)-(\d)", r"\1--\2", s)
    s = s.replace("<", "$<$")
    if harf:
        s += "$^{%s}$" % harf
    return s


def p_bicim(s):
    s = (s or "").strip()
    return s.replace("<", "$<$") if s else ""


def yaz(ad, satirlar):
    os.makedirs(HEDEF, exist_ok=True)
    with open(os.path.join(HEDEF, ad + ".tex"), "w", encoding="utf-8") as f:
        f.write("% Bu dosya code/makale_tablolari.py ile uretilmistir. Elle duzenlemeyin.\n")
        f.write("\n".join(satirlar) + "\n")


def grup_n():
    for r in oku("tablo1_demografi"):
        if r["Degisken"].startswith("Cinsiyet"):
            return [int(x) for x in r["n"].split("/")]
    sys.exit("Grup buyuklukleri bulunamadi.")


N = grup_n()
BASLIK = ("& PPD (n=%d) & PD (n=%d) & Control (n=%d) & $P$ \\\\" % tuple(N))

# ---------------- Tablo 1 ----------------
T1_AD = {
    "Yas (yil)": "Age (years)",
    "Cinsiyet, n (%)": "Sex, n (\\%)",
    "Boy (cm)": "Height (cm)",
    "Kilo (kg)": "Weight (kg)",
    "Beden kutle indeksi (hesaplanan)": "Body mass index (kg/m$^2$)",
    "Aclik glukozu (mg/dL)": "Fasting glucose (mg/dL)",
    "Kolesterol (mg/dL)": "Total cholesterol (mg/dL)",
    "Trigliserit (mg/dL)": "Triglycerides (mg/dL)",
    "LDL kolesterol, hesaplanan (mg/dL)": "LDL cholesterol, calculated (mg/dL)",
    "HDL kolesterol (mg/dL)": "HDL cholesterol (mg/dL)",
    "B12 vitamini (pg/mL)": "Vitamin B12 (pg/mL)",
    "Sigara, n (%)": "Smoking, n (\\%)",
    "Alkol, n (%)": "Alcohol use, n (\\%)",
    "Fiziksel aktivite, n (%)": "Physical activity, n (\\%)",
    "Uyku kalitesi, n (%)": "Sleep quality, n (\\%)",
    "Stres duzeyi, n (%)": "Stress level, n (\\%)",
    "Gunluk ana ogun sayisi, n (%)": "Daily main meals, n (\\%)",
}
ALT_AD = {"1-2 days/week": "1--2 days per week", "3-4 days/week": "3--4 days per week",
          "5+ days/week": "5 or more days per week"}
s = ["\\begin{tabular}{lccccc}", "\\toprule",
     "Characteristic " + BASLIK.replace("& $P$ \\\\", "& $P$ & n \\\\"), "\\midrule"]
icinde = False
for r in oku("tablo1_demografi"):
    ad = r["Degisken"]
    if ad.startswith("  "):
        if icinde:
            alt = ALT_AD.get(ad.strip(), ad.strip())
            s.append("\\quad %s & %s & %s & %s & & \\\\" % (
                alt, hucre(r["PPD"]), hucre(r["PD"]), hucre(r["Kontrol"])))
        continue
    icinde = ad in T1_AD
    if not icinde:
        continue
    s.append("%s & %s & %s & %s & %s & %s \\\\" % (
        T1_AD[ad], hucre(r["PPD"]), hucre(r["PD"]), hucre(r["Kontrol"]),
        p_bicim(r["p"]), r["n"]))
s += ["\\bottomrule", "\\end{tabular}"]
yaz("tablo1", s)

# ---------------- Tablo 2 ----------------
T2 = [("FATP5 (ng/mL)", "Fatty acid transport protein-5 (ng/mL)"),
      ("LBP (ng/mL)", "Lipopolysaccharide-binding protein (ng/mL)"),
      ("Toplam SCFA", "Total SCFA (mM)"),
      ("Asetik asit", "Acetic acid (mM)"),
      ("Propiyonik asit", "Propionic acid (mM)"),
      ("Butirik asit", "Butyric acid (mM)")]
t3 = {r["Degisken"]: r for r in oku("tablo3_biyobelirtec")}
s = ["\\begin{tabular}{lccccc}", "\\toprule",
     "Biomarker " + BASLIK.replace("& $P$ \\\\", "& $P$ & n \\\\"), "\\midrule"]
for k, en in T2:
    r = t3[k]
    s.append("%s & %s & %s & %s & %s & %s \\\\" % (
        en, hucre(r["PPD"]), hucre(r["PD"]), hucre(r["Kontrol"]), p_bicim(r["p"]), r["n"]))
s += ["\\bottomrule", "\\end{tabular}"]
yaz("tablo2", s)

# ---------------- Tablo S1 (besin) ----------------
BES_EN = ["Red meat (g)", "White meat (g)", "Eggs (g)", "Processed meat (g)", "Legumes (g)",
          "Milk (mL)", "Yogurt (mL)", "Cheese (g)", "Onion and garlic (g)",
          "Leafy green vegetables (g)", "French fries (g)", "Fruits (g)", "Whole grains (g)",
          "White bread (g)", "Pasta, noodles (g)", "Rice (g)", "Bulgur (g)", "Pastries (g)",
          "Olive oil (mL)", "Other vegetable oils (mL)", "Olives (g)", "Margarine (g)",
          "Butter (g)", "Walnuts (g)", "Dessert (g)", "Tea (mL)", "Coffee (mL)",
          "Ready-made fruit juice (mL)", "Carbonated beverages (mL)"]
t2 = oku("tablo2_besin")
if len(t2) != len(BES_EN):
    sys.exit("Besin tablosu satir sayisi beklenenden farkli.")
nb = [int(x) for x in t2[0]["n"].split("/")]
s = ["\\begin{tabular}{lcccc}", "\\toprule",
     "Food item & PPD (n=%d) & PD (n=%d) & Control (n=%d) & $P$ \\\\" % tuple(nb), "\\midrule"]
for en, r in zip(BES_EN, t2):
    s.append("%s & %s & %s & %s & %s \\\\" % (
        en, hucre(r["PPD"]), hucre(r["PD"]), hucre(r["Kontrol"]), p_bicim(r["p"])))
s += ["\\bottomrule", "\\end{tabular}"]
yaz("tabloS2", s)

# ---------------- Tablo S4 (Firth) ----------------
MOD = {"PD vs Kontrol": "PD vs. Control", "PPD vs Kontrol": "PPD vs. Control",
       "PPD vs PD": "PPD vs. PD"}
DEG = {"Yas": "Age", "Erkek cinsiyet": "Male sex", "BKI": "Body mass index",
       "Zeytinyagi": "Olive oil consumption", "Butirik asit": "Butyric acid",
       "LBP (log)": "LBP (log-transformed)", "FATP5": "FATP5"}
perf = {r["Model"]: r for r in oku("tablo5_performans")}
s = ["\\begin{tabular}{llccc}", "\\toprule",
     "Model & Variable & OR & 95\\% CI & $P$ \\\\", "\\midrule"]
onceki = None
for r in oku("tablo4_firth"):
    m = r["Model"]
    if m != onceki and onceki is not None:
        s.append("\\midrule")
    etk = "%s (n=%s)" % (MOD[m], perf[m]["n"]) if m != onceki else ""
    s.append("%s & %s & %s & %s & %s \\\\" % (
        etk, DEG[r["Degisken"]], r["OR"], r["GA95"].replace("-", "--"), p_bicim(r["p"])))
    onceki = m
s += ["\\bottomrule", "\\end{tabular}"]
yaz("tabloS4", s)

# ---------------- Tablo S5 (performans) ----------------
s = ["\\begin{tabular}{lccccccc}", "\\toprule",
     "Model & n & Apparent AUC (95\\% CI) & Sens. & Spec. & Acc. & CV AUC & Repeated CV AUC \\\\",
     "\\midrule"]
for r in oku("tablo5_performans"):
    s.append("%s & %s & %s (%s) & %s & %s & %s & %s & %s (%s) \\\\" % (
        MOD[r["Model"]], r["n"], r["AUC"], r["AUC_GA95"].replace("-", "--"),
        r["Duyarlilik"], r["Ozgulluk"], r["Dogruluk"], r["CV_AUC"],
        r["TCV_AUC_medyan"], r["TCV_AUC_aralik"].replace("-", "--")))
s += ["\\bottomrule", "\\end{tabular}"]
yaz("tabloS5", s)

# ---------------- Tablo S3 (anket kodlamasi) ----------------
DUR = {"KAYBOLDU": "Lost", "korundu": "Retained", "YENI": "Gained", "-": "--"}
t6 = oku("tablo6_anket_duyarlilik")
s = ["\\begin{tabular}{lcccc}", "\\toprule",
     "Food item & $P$, blanks as missing & n (PPD/PD/C) & $P$, blanks as zero & Outcome \\\\",
     "\\midrule"]
for en, r in zip(BES_EN, t6):
    s.append("%s & %s & %s & %s & %s \\\\" % (
        re.sub(r" \((g|mL)\)$", "", en), p_bicim(r["p_NA_3"]), r["n_NA"],
        p_bicim(r["p_sifir_3"]), DUR.get(r["Durum"], r["Durum"])))
s += ["\\bottomrule", "\\end{tabular}"]
yaz("tabloS3", s)

# ---------------- Tablo S1 (biyobelirtec duyarlilik) ----------------
PH = {"LBP (ng/mL)": "LBP", "FATP5 (ng/mL)": "FATP5", "Toplam SCFA": "Total SCFA",
      "Asetik asit": "Acetic acid", "Propiyonik asit": "Propionic acid",
      "Butirik asit": "Butyric acid"}
f4 = lambda x: "$<$0.001" if float(x) < 0.001 else ("$>$0.99" if float(x) > 0.99 else "%.3f" % float(x))
s = ["\\begin{tabular}{lcccc}", "\\toprule",
     "\\multicolumn{5}{l}{A. Post-hoc comparisons (Dunn test, Bonferroni-corrected)} \\\\",
     "\\midrule",
     "Biomarker & Overall $P$ & PD vs. control & PPD vs. control & PPD vs. PD \\\\", "\\midrule"]
for r in oku("tablo7_posthoc"):
    s.append("%s & %s & %s & %s & %s \\\\" % (
        PH[r["Degisken"]], f4(r["Genel_p"]), f4(r["PD_C"]), f4(r["PPD_C"]), f4(r["PPD_PD"])))
s += ["\\midrule",
      "\\multicolumn{5}{l}{B. FATP5 censored at the highest assay standard (10 ng/mL) in the Firth models} \\\\",
      "\\midrule",
      "Model & n & OR & 95\\% CI & $P$ \\\\", "\\midrule"]
SM = {"PD vs C": "PD vs. Control", "PPD vs C": "PPD vs. Control", "PPD vs PD": "PPD vs. PD"}
for r in oku("tablo8_fatp5_sansur"):
    s.append("%s & %s & %s & %s & %s \\\\" % (
        SM[r["Model"]], r["n"], r["OR"], r["GA95"].replace("-", "--"), p_bicim(r["p"])))
s += ["\\midrule",
      "\\multicolumn{5}{l}{C. FATP5 in the PPD models refitted without LBP (same participants)} \\\\",
      "\\midrule", "Model & n & OR & 95\\% CI & $P$ \\\\", "\\midrule"]
for r in oku("tablo9_lbp_haric"):
    s.append("%s & %s & %s & %s & %s \\\\" % (
        SM[r["Model"]], r["n"], r["OR"], r["GA95"].replace("-", "--"), p_bicim(r["p"])))
s += ["\\bottomrule", "\\end{tabular}"]
yaz("tabloS1", s)

print("Tablolar yazildi: %s" % HEDEF)
