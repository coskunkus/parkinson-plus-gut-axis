# =====================================================================
# makale_tablolari.R
# Makaledeki butun tablolari run_all.R'in yazdigi TSV dosyalarindan
# uretir. Hesap yapmaz, yalnizca bicim cevirir: Ingilizce etiketler,
# +/- yerine $\pm$, araliklarda uzun tire, post-hoc harfleri ust simge,
# P degerleri dergi biciminde. Tablolara elle sayi girilmez.
#
# run_all.R bu dosyayi en sonda kendisi calistirir. Tek basina da
# calistirilabilir (proje kokunden):
#     Rscript code/makale_tablolari.R
#
# Hedef: makale/tablolar klasoru. Depo klasorunun yaninda (../makale) ya da
# bir ust duzeyde (../../makale, depo repo/ altinda duruyorsa) aranir. Klasor
# yoksa tablolar uretilmez, uyari yazilir.
# Yazdiklari (makaledeki numaralarla): tablo1, tablo2 ve
#   tabloS1 = biyobelirtec post-hoc ve duyarlilik analizleri
#   tabloS2 = bir aylik besin tuketimi
#   tabloS3 = anket kodlamasi duyarlilik analizi
#   tabloS4 = Firth modelleri
#   tabloS5 = model performansi ve capraz dogrulama
# =====================================================================

local({
  if (!exists("SONUCLAR") || !exists("PROJE_KOK")) {
    kok <- local({
  # Proje koku. Once calisma klasoru denenir (setwd ile verilen), sonra
  # source() ile verilen dosya yolu. normalizePath kullanilmaz: Windows'ta
  # Turkce karakterli yollarda (Drive'im, calismalar gibi) yolu bozabiliyor.
  adaylar <- c(getwd(), dirname(getwd()))
  of <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (is.character(of)) adaylar <- c(adaylar, dirname(dirname(of)), dirname(of))
  for (a in adaylar) if (file.exists(file.path(a, "code", "core_gutaxis.R"))) return(a)
  getwd()
})
    if (basename(kok) == "code") kok <- dirname(kok)
    PROJE_KOK <- kok
    SONUCLAR <- file.path(kok, "results")
  }
  adaylar <- c(file.path(dirname(PROJE_KOK), "makale"),
               file.path(dirname(dirname(PROJE_KOK)), "makale"))
  makale <- adaylar[dir.exists(adaylar)][1]
  if (is.na(makale)) {
    makale <- adaylar[1]
    warning("makale klasoru bulunamadi (", makale, "); tablolar uretilmedi.", call. = FALSE)
    return(invisible(NULL))
  }
  hedef <- file.path(makale, "tablolar")
  dir.create(hedef, showWarnings = FALSE, recursive = TRUE)

  oku <- function(ad) {
    yol <- file.path(SONUCLAR, paste0(ad, ".tsv"))
    if (!file.exists(yol)) stop("Bulunamadi: ", yol, ". Once run_all.R calistirilmali.")
    read.delim(yol, sep = "\t", quote = "", colClasses = "character",
               na.strings = character(0), check.names = FALSE,
               strip.white = FALSE, encoding = "UTF-8", fileEncoding = "UTF-8")
  }

  # R ciktisindaki hucreyi LaTeX'e cevirir
  hucre <- function(s) {
    s <- trimws(s)
    if (is.na(s) || s == "") return("")
    harf <- ""
    m <- regmatches(s, regexec("^(.*?\\))\\s+([ab]+)$", s, perl = TRUE))[[1]]
    if (!length(m)) m <- regmatches(s, regexec("^(.*?\\d)\\s+([ab]+)$", s, perl = TRUE))[[1]]
    if (length(m)) { s <- m[2]; harf <- m[3] }
    s <- gsub("+/-", "$\\pm$", s, fixed = TRUE)
    s <- gsub("(\\d)-(\\d)", "\\1--\\2", s, perl = TRUE)
    s <- gsub("<", "$<$", s, fixed = TRUE)
    if (harf != "") s <- paste0(s, "$^{", harf, "}$")
    s
  }
  p_lat <- function(s) { s <- trimws(s); if (is.na(s) || s == "") "" else gsub("<", "$<$", s, fixed = TRUE) }
  tire  <- function(s) gsub("-", "--", s, fixed = TRUE)
  yaz <- function(ad, satirlar) {
    con <- file(file.path(hedef, paste0(ad, ".tex")), open = "wt", encoding = "UTF-8")
    writeLines(c("% Bu dosya code/makale_tablolari.R ile uretilmistir. Elle duzenlemeyin.",
                 satirlar), con)
    close(con)
  }
  satir <- function(...) paste0(paste(..., sep = " & "), " \\\\")

  # Grup buyuklukleri (Tablo 1'deki cinsiyet satirindan)
  t1 <- oku("tablo1_demografi")
  N <- as.integer(strsplit(t1$n[startsWith(t1$Degisken, "Cinsiyet")][1], "/")[[1]])
  baslik_n <- sprintf("& PPD (n=%d) & PD (n=%d) & Control (n=%d) & $P$ & n \\\\", N[1], N[2], N[3])

  # ---------------- Tablo 1 ----------------
  T1_AD <- c(
    "Yas (yil)" = "Age (years)",
    "Cinsiyet, n (%)" = "Sex, n (\\%)",
    "Boy (cm)" = "Height (cm)",
    "Kilo (kg)" = "Weight (kg)",
    "Beden kutle indeksi (hesaplanan)" = "Body mass index (kg/m$^2$)",
    "Aclik glukozu (mg/dL)" = "Fasting glucose (mg/dL)",
    "Kolesterol (mg/dL)" = "Total cholesterol (mg/dL)",
    "Trigliserit (mg/dL)" = "Triglycerides (mg/dL)",
    "LDL kolesterol, hesaplanan (mg/dL)" = "LDL cholesterol, calculated (mg/dL)",
    "HDL kolesterol (mg/dL)" = "HDL cholesterol (mg/dL)",
    "B12 vitamini (pg/mL)" = "Vitamin B12 (pg/mL)",
    "Sigara, n (%)" = "Smoking, n (\\%)",
    "Alkol, n (%)" = "Alcohol use, n (\\%)",
    "Fiziksel aktivite, n (%)" = "Physical activity, n (\\%)",
    "Uyku kalitesi, n (%)" = "Sleep quality, n (\\%)",
    "Stres duzeyi, n (%)" = "Stress level, n (\\%)",
    "Gunluk ana ogun sayisi, n (%)" = "Daily main meals, n (\\%)")
  ALT_AD <- c("1-2 days/week" = "1--2 days per week", "3-4 days/week" = "3--4 days per week",
              "5+ days/week" = "5 or more days per week")
  s <- c("\\begin{tabular}{lccccc}", "\\toprule", paste("Characteristic", baslik_n), "\\midrule")
  icinde <- FALSE
  for (i in seq_len(nrow(t1))) {
    r <- t1[i, ]; ad <- r$Degisken
    if (startsWith(ad, "  ")) {
      if (icinde) {
        alt <- trimws(ad); if (alt %in% names(ALT_AD)) alt <- ALT_AD[[alt]]
        s <- c(s, sprintf("\\quad %s & %s & %s & %s & & \\\\", alt,
                          hucre(r$PPD), hucre(r$PD), hucre(r$Kontrol)))
      }
      next
    }
    icinde <- ad %in% names(T1_AD)
    if (!icinde) next
    s <- c(s, satir(T1_AD[[ad]], hucre(r$PPD), hucre(r$PD), hucre(r$Kontrol), p_lat(r$p), r$n))
  }
  yaz("tablo1", c(s, "\\bottomrule", "\\end{tabular}"))

  # ---------------- Tablo 2 ----------------
  T2 <- c("FATP5 (ng/mL)" = "Fatty acid transport protein-5 (ng/mL)",
          "LBP (ng/mL)" = "Lipopolysaccharide-binding protein (ng/mL)",
          "Toplam SCFA" = "Total SCFA (mM)",
          "Asetik asit" = "Acetic acid (mM)",
          "Propiyonik asit" = "Propionic acid (mM)",
          "Butirik asit" = "Butyric acid (mM)")
  t3 <- oku("tablo3_biyobelirtec")
  s <- c("\\begin{tabular}{lccccc}", "\\toprule", paste("Biomarker", baslik_n), "\\midrule")
  for (k in names(T2)) {
    r <- t3[t3$Degisken == k, ][1, ]
    s <- c(s, satir(T2[[k]], hucre(r$PPD), hucre(r$PD), hucre(r$Kontrol), p_lat(r$p), r$n))
  }
  yaz("tablo2", c(s, "\\bottomrule", "\\end{tabular}"))

  # ---------------- Tablo S2 (besin) ----------------
  BES_EN <- c("Red meat (g)", "White meat (g)", "Eggs (g)", "Processed meat (g)", "Legumes (g)",
    "Milk (mL)", "Yogurt (mL)", "Cheese (g)", "Onion and garlic (g)",
    "Leafy green vegetables (g)", "French fries (g)", "Fruits (g)", "Whole grains (g)",
    "White bread (g)", "Pasta, noodles (g)", "Rice (g)", "Bulgur (g)", "Pastries (g)",
    "Olive oil (mL)", "Other vegetable oils (mL)", "Olives (g)", "Margarine (g)",
    "Butter (g)", "Walnuts (g)", "Dessert (g)", "Tea (mL)", "Coffee (mL)",
    "Ready-made fruit juice (mL)", "Carbonated beverages (mL)")
  t2 <- oku("tablo2_besin")
  if (nrow(t2) != length(BES_EN)) stop("Besin tablosu satir sayisi beklenenden farkli.")
  nb <- as.integer(strsplit(t2$n[1], "/")[[1]])
  s <- c("\\begin{tabular}{lcccc}", "\\toprule",
         sprintf("Food item & PPD (n=%d) & PD (n=%d) & Control (n=%d) & $P$ \\\\", nb[1], nb[2], nb[3]),
         "\\midrule")
  for (i in seq_along(BES_EN))
    s <- c(s, satir(BES_EN[i], hucre(t2$PPD[i]), hucre(t2$PD[i]), hucre(t2$Kontrol[i]), p_lat(t2$p[i])))
  yaz("tabloS2", c(s, "\\bottomrule", "\\end{tabular}"))

  # ---------------- Tablo S4 (Firth) ----------------
  MOD <- c("PD vs Kontrol" = "PD vs. Control", "PPD vs Kontrol" = "PPD vs. Control",
           "PPD vs PD" = "PPD vs. PD")
  DEG <- c("Yas" = "Age", "Erkek cinsiyet" = "Male sex", "BKI" = "Body mass index",
           "Zeytinyagi" = "Olive oil consumption", "Butirik asit" = "Butyric acid",
           "LBP (log)" = "LBP (log-transformed)", "FATP5" = "FATP5")
  t5 <- oku("tablo5_performans")
  t4 <- oku("tablo4_firth")
  s <- c("\\begin{tabular}{llccc}", "\\toprule",
         "Model & Variable & OR & 95\\% CI & $P$ \\\\", "\\midrule")
  onceki <- ""
  for (i in seq_len(nrow(t4))) {
    m <- t4$Model[i]
    if (onceki != "" && m != onceki) s <- c(s, "\\midrule")
    etk <- if (m != onceki) sprintf("%s (n=%s)", MOD[[m]], t5$n[t5$Model == m]) else ""
    s <- c(s, satir(etk, DEG[[t4$Degisken[i]]], t4$OR[i], tire(t4$GA95[i]), p_lat(t4$p[i])))
    onceki <- m
  }
  yaz("tabloS4", c(s, "\\bottomrule", "\\end{tabular}"))

  # ---------------- Tablo S5 (performans) ----------------
  # CV AUC: on tanimli tek kat atamasi. Tekrarli CV: 200 rastgele bolmenin
  # medyani ve 2.5-97.5 persantilleri (kat atamasina bagli degiskenlik).
  s <- c("\\begin{tabular}{lccccccc}", "\\toprule",
         "Model & n & Apparent AUC (95\\% CI) & Sens. & Spec. & Acc. & CV AUC & Repeated CV AUC \\\\",
         "\\midrule")
  for (i in seq_len(nrow(t5))) {
    r <- t5[i, ]
    s <- c(s, satir(MOD[[r$Model]], r$n, sprintf("%s (%s)", r$AUC, tire(r$AUC_GA95)),
                    r$Duyarlilik, r$Ozgulluk, r$Dogruluk, r$CV_AUC,
                    sprintf("%s (%s)", r$TCV_AUC_medyan, tire(r$TCV_AUC_aralik))))
  }
  yaz("tabloS5", c(s, "\\bottomrule", "\\end{tabular}"))

  # ---------------- Tablo S3 (anket kodlamasi) ----------------
  DUR <- c("KAYBOLDU" = "Lost", "korundu" = "Retained", "YENI" = "Gained", "-" = "--")
  t6 <- oku("tablo6_anket_duyarlilik")
  s <- c("\\begin{tabular}{lcccc}", "\\toprule",
         "Food item & $P$, blanks as missing & n (PPD/PD/C) & $P$, blanks as zero & Outcome \\\\",
         "\\midrule")
  for (i in seq_along(BES_EN)) {
    d <- t6$Durum[i]; if (d %in% names(DUR)) d <- DUR[[d]]
    s <- c(s, satir(sub(" \\((g|mL)\\)$", "", BES_EN[i]), p_lat(t6$p_NA_3[i]), t6$n_NA[i],
                    p_lat(t6$p_sifir_3[i]), d))
  }
  yaz("tabloS3", c(s, "\\bottomrule", "\\end{tabular}"))

  # ---------------- Tablo S1 (biyobelirtec duyarlilik) ----------------
  PH <- c("LBP (ng/mL)" = "LBP", "FATP5 (ng/mL)" = "FATP5", "Toplam SCFA" = "Total SCFA",
          "Asetik asit" = "Acetic acid", "Propiyonik asit" = "Propionic acid",
          "Butirik asit" = "Butyric acid")
  f4 <- function(x) { x <- as.numeric(x)
    if (x < 0.001) "$<$0.001" else if (x > 0.99) "$>$0.99" else sprintf("%.3f", x) }
  t7 <- oku("tablo7_posthoc")
  s <- c("\\begin{tabular}{lcccc}", "\\toprule",
         "\\multicolumn{5}{l}{A. Post-hoc comparisons (Dunn test, Bonferroni-corrected)} \\\\",
         "\\midrule",
         "Biomarker & Overall $P$ & PD vs. control & PPD vs. control & PPD vs. PD \\\\", "\\midrule")
  for (i in seq_len(nrow(t7)))
    s <- c(s, satir(PH[[t7$Degisken[i]]], f4(t7$Genel_p[i]), f4(t7$PD_C[i]),
                    f4(t7$PPD_C[i]), f4(t7$PPD_PD[i])))
  SM <- c("PD vs C" = "PD vs. Control", "PPD vs C" = "PPD vs. Control", "PPD vs PD" = "PPD vs. PD")
  s <- c(s, "\\midrule",
         "\\multicolumn{5}{l}{B. FATP5 censored at the highest assay standard (10 ng/mL) in the Firth models} \\\\",
         "\\midrule", "Model & n & OR & 95\\% CI & $P$ \\\\", "\\midrule")
  t8 <- oku("tablo8_fatp5_sansur")
  for (i in seq_len(nrow(t8)))
    s <- c(s, satir(SM[[t8$Model[i]]], t8$n[i], t8$OR[i], tire(t8$GA95[i]), p_lat(t8$p[i])))
  s <- c(s, "\\midrule",
         "\\multicolumn{5}{l}{C. FATP5 in the PPD models refitted without LBP (same participants)} \\\\",
         "\\midrule", "Model & n & OR & 95\\% CI & $P$ \\\\", "\\midrule")
  t9 <- oku("tablo9_lbp_haric")
  for (i in seq_len(nrow(t9)))
    s <- c(s, satir(SM[[t9$Model[i]]], t9$n[i], t9$OR[i], tire(t9$GA95[i]), p_lat(t9$p[i])))
  yaz("tabloS1", c(s, "\\bottomrule", "\\end{tabular}"))

  cat("Makale tablolari yazildi:", hedef, "\n")
})
