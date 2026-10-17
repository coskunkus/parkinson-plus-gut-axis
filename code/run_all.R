# =====================================================================
# run_all.R
# Makaledeki her sey: veri kalite denetimi, Tablo 1-5, korelasyonlar,
# Firth modelleri, duyarlilik analizi ve dort figur.
#
# Proje kokunden calistirilir:
#     Rscript code/run_all.R
# ya da RStudio icinde bu dosya acikken Source.
#
# Yazdiklari:
#     results/run_all_report.txt (ve tarihli kopyasi), results/*.tsv
#     figures/Figure1..Figure4  (eps, pdf, png)
#     ../makale/tablolar/*.tex  (makale tablolari, makale_tablolari.R ile)
#
# Bir dakikanin altinda biter. Monte Carlo calismasi yoktur, bu yuzden
# ayri bir simulasyon kosucusu da yoktur.
# =====================================================================

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
source(file.path(kok, "code", "core_gutaxis.R"), encoding = "UTF-8")

# ---- 5. Tablo 1 -----------------------------------------------------
t1 <- rbind(
  satir_yap("age", "Yas (yil)"),
  kategorik_satir("sex", "Cinsiyet, n (%)"),
  satir_yap("height", "Boy (cm)"),
  satir_yap("weight", "Kilo (kg)"),
  satir_yap("bmi", sprintf("Beden kutle indeksi (%s)", BKI_KAYNAK)),
  satir_yap("glucose", "Aclik glukozu (mg/dL)"),
  satir_yap("chol", "Kolesterol (mg/dL)"),
  satir_yap("tg", "Trigliserit (mg/dL)"),
  satir_yap("ldl", "LDL kolesterol, hesaplanan (mg/dL)"),
  satir_yap("hdl", "HDL kolesterol (mg/dL)"),
  if ("b12" %in% names(d)) satir_yap("b12", "B12 vitamini (pg/mL)"),
  kategorik_satir("smoking", "Sigara, n (%)"),
  kategorik_satir("alcohol", "Alkol, n (%)"),
  kategorik_satir("phys_act", "Fiziksel aktivite, n (%)"),
  kategorik_satir("sleep", "Uyku kalitesi, n (%)"),
  kategorik_satir("stress", "Stres duzeyi, n (%)", sira = c("Low", "Moderate", "High", "Very high")),
  kategorik_satir("n_meals", "Gunluk ana ogun sayisi, n (%)"),
  kategorik_satir("n_snacks", "Gunluk ara ogun sayisi, n (%)"),
  kategorik_satir("skip_meal", "Atlanan ana ogun, n (%)"),
  kategorik_satir("supplement", "Vitamin mineral takviyesi, n (%)"),
  kategorik_satir("fam_overweight", "Ailede fazla kilolu, n (%)"))

# ---- 6. Tablo 2 -----------------------------------------------------
besinler <- c(red_meat = "Kirmizi et (g)", white_meat = "Beyaz et (g)",
  eggs = "Yumurta (g)", processed_meat = "Islenmis et (g)",
  legumes = "Kurubaklagil (g)", milk = "Sut (mL)", yogurt = "Yogurt (mL)",
  cheese = "Peynir (g)", onion_garlic = "Sogan-sarimsak (g)",
  leafy_greens = "Yesil yaprakli sebze (g)", french_fries = "Patates kizartmasi (g)",
  fruits = "Meyve (g)", whole_grains = "Tam tahil (g)",
  white_bread = "Beyaz ekmek (g)", pasta = "Makarna-eriste (g)",
  rice = "Pirinc (g)", bulgur = "Bulgur (g)", pastries = "Hamur isi (g)",
  olive_oil = "Zeytinyagi (mL)", other_oil = "Diger sivi yag (mL)",
  olives = "Zeytin (g)", margarine = "Margarin (g)", butter = "Tereyagi (g)",
  walnuts = "Ceviz (g)", dessert = "Tatli (g)", tea = "Cay (mL)",
  coffee = "Kahve (mL)", fruit_juice = "Hazir meyve suyu (mL)",
  soda = "Gazli icecek (mL)")
besinler_en <- c(red_meat = "Red meat", white_meat = "White meat", eggs = "Eggs",
  processed_meat = "Processed meat", legumes = "Legumes", milk = "Milk",
  yogurt = "Yogurt", cheese = "Cheese", onion_garlic = "Onion and garlic",
  leafy_greens = "Leafy greens", french_fries = "French fries", fruits = "Fruits",
  whole_grains = "Whole grains", white_bread = "White bread",
  pasta = "Pasta, noodles", rice = "Rice", bulgur = "Bulgur",
  pastries = "Pastries", olive_oil = "Olive oil",
  other_oil = "Other vegetable oil", olives = "Olives", margarine = "Margarine",
  butter = "Butter", walnuts = "Walnuts", dessert = "Dessert", tea = "Tea",
  coffee = "Coffee", fruit_juice = "Ready-made fruit juice",
  soda = "Carbonated beverage")
t2 <- do.call(rbind, lapply(names(besinler), function(v) satir_yap(v, besinler[[v]])))

# ---- 7. Tablo 3 -----------------------------------------------------
biyo <- c(lbp = "LBP (ng/mL)", fatp5 = "FATP5 (ng/mL)",
  total_scfa = "Toplam SCFA", acetic = "Asetik asit", propionic = "Propiyonik asit",
  butyric = "Butirik asit", isobutyric_lod = "Izobutirik asit (LOD/2)",
  valeric_lod = "Valerik asit (LOD/2)", isovaleric_lod = "Izovalerik asit (LOD/2)")
t3 <- do.call(rbind, lapply(names(biyo), function(v) satir_yap(v, biyo[[v]])))

# ---- 8. Korelasyonlar ----------------------------------------------
kor_deg <- c("fatp5","lbp","total_scfa","acetic","propionic","butyric",
             "olive_oil","fruit_juice","tg")
kor_et  <- c("FATP5","LBP","Total SCFA","Acetic","Propionic","Butyric",
             "Olive oil","Fruit juice","Triglycerides")
nk <- length(kor_deg)
K <- KP <- KN <- matrix(NA, nk, nk, dimnames = list(kor_et, kor_et))
for (i in 1:nk) for (j in 1:nk) {
  ct <- suppressWarnings(cor.test(d[[kor_deg[i]]], d[[kor_deg[j]]],
                                  method = "spearman", exact = FALSE))
  K[i, j] <- ct$estimate; KP[i, j] <- ct$p.value
  KN[i, j] <- sum(!is.na(d[[kor_deg[i]]]) & !is.na(d[[kor_deg[j]]]))
}
kor_test <- suppressWarnings(cor.test(d$fatp5, d$lbp, method = "spearman", exact = FALSE))

# ---- 9. Firth modelleri --------------------------------------------
d$loglbp <- log(d$lbp)
d$sex_m  <- as.numeric(d$sex == "Erkek")
tahmin <- c("age","sex_m","bmi","olive_oil","butyric","loglbp","fatp5")
tah_et <- c("Yas","Erkek cinsiyet","BKI","Zeytinyagi","Butirik asit","LBP (log)","FATP5")

# Tekrarli capraz dogrulama: tek kat atamasina bagli belirsizligi gostermek
# icin bes katli CV, TEKRAR_CV farkli rastgele bolmeyle yinelenir.
TEKRAR_CV <- 200

# tah: modeldeki degiskenler; ornek: tam vaka kumesini belirleyen degiskenler.
# Duyarlilik modelleri (ornegin LBP'siz) ana modelle ayni katilimcilarda
# kurulsun diye ornek her zaman tum tahmin degiskenleridir.
firth_model <- function(gruplar, olay, tohum, tah = tahmin, tah_ad = tah_et, ornek = tahmin) {
  force(tah); force(tah_ad); force(ornek)   # varsayilanlar global tahmin'den alinir
  tahmin <- tah
  dd <- d[d$group %in% gruplar, c("group", union(ornek, tahmin))]
  dd <- dd[complete.cases(dd), c("group", tahmin)]
  dd$y <- as.numeric(dd$group == olay)
  ham <- dd                                  # olceklenmemis kopya, kat ici kullanilir
  # Raporlanan model tum alt kume uzerinde olceklenir; OR degerleri o
  # alt kumenin 1 standart sapmasi icindir.
  for (v in tahmin) if (v != "sex_m") dd[[v]] <- as.numeric(scale(dd[[v]]))
  frm <- as.formula(paste("y ~", paste(tahmin, collapse = " + ")))
  m <- logistf(frm, data = dd)
  katsayi <- data.frame(Degisken = tah_ad,
    OR = sprintf("%.3f", exp(coef(m)[-1])),
    GA95 = sprintf("%.3f-%.3f", exp(m$ci.lower[-1]), exp(m$ci.upper[-1])),
    p = sapply(m$prob[-1], p_bicim), stringsAsFactors = FALSE)
  ph <- as.numeric(predict(m, type = "response"))
  r_ap <- roc(dd$y, ph, quiet = TRUE); ci_ap <- ci.auc(r_ap)
  ei <- coords(r_ap, "best", best.method = "youden",
               ret = c("threshold","sensitivity","specificity","accuracy"))[1, ]
  # Katlar bu fonksiyonun kendi tohumuyla atanir, boylece kodun baska bir
  # yerine rastgelelik eklense bile katlar degismez.
  set.seed(tohum)
  kat <- rep(NA, nrow(ham))
  for (sn in unique(ham$y)) {
    idx <- which(ham$y == sn); kat[idx] <- sample(rep(1:5, length.out = length(idx)))
  }
  # Olceklendirme her katta yalnizca egitim verisinden hesaplanir; test
  # katindaki gozlemler egitim ortalama ve standart sapmasiyla donusturulur.
  oof <- rep(NA, nrow(ham)); kat_auc <- c()
  for (f in 1:5) {
    eg <- ham[kat != f, ]; te <- ham[kat == f, ]
    for (v in tahmin) if (v != "sex_m") {
      mu <- mean(eg[[v]]); ss <- sd(eg[[v]])
      if (!is.finite(ss) || ss == 0) ss <- 1
      eg[[v]] <- (eg[[v]] - mu) / ss
      te[[v]] <- (te[[v]] - mu) / ss
    }
    mf <- logistf(frm, data = eg)
    oof[kat == f] <- as.numeric(predict(mf, newdata = te, type = "response"))
    if (length(unique(te$y)) > 1)
      kat_auc <- c(kat_auc, as.numeric(auc(roc(te$y, oof[kat == f], quiet = TRUE))))
  }
  if (!length(kat_auc)) kat_auc <- NA_real_
  r_cv <- roc(dd$y, oof, quiet = TRUE); ci_cv <- ci.auc(r_cv)
  # Tekrarli CV: her tekrarda katlar yeniden atanir; olceklendirme yine
  # yalnizca egitim katindan. Tahmin icin GA gerekmedigi icin pl = FALSE.
  tcv <- sapply(seq_len(TEKRAR_CV), function(rr) {
    set.seed(tohum * 1000 + rr)
    kt <- rep(NA, nrow(ham))
    for (sn in unique(ham$y)) {
      idx <- which(ham$y == sn); kt[idx] <- sample(rep(1:5, length.out = length(idx)))
    }
    oo <- rep(NA, nrow(ham))
    for (f in 1:5) {
      eg <- ham[kt != f, ]; te <- ham[kt == f, ]
      for (v in tahmin) if (v != "sex_m") {
        mu <- mean(eg[[v]]); ss <- sd(eg[[v]])
        if (!is.finite(ss) || ss == 0) ss <- 1
        eg[[v]] <- (eg[[v]] - mu) / ss; te[[v]] <- (te[[v]] - mu) / ss
      }
      oo[kt == f] <- as.numeric(predict(logistf(frm, data = eg, pl = FALSE), newdata = te, type = "response"))
    }
    as.numeric(auc(roc(ham$y, oo, quiet = TRUE)))
  })
  tq <- quantile(tcv, c(0.5, 0.025, 0.975), names = FALSE)
  list(katsayi = katsayi, roc_ap = r_ap, roc_cv = r_cv,
    performans = data.frame(n = nrow(dd),
      AUC = sprintf("%.3f", as.numeric(auc(r_ap))),
      AUC_GA95 = sprintf("%.3f-%.3f", ci_ap[1], ci_ap[3]),
      Duyarlilik = sprintf("%.3f", ei$sensitivity),
      Ozgulluk = sprintf("%.3f", ei$specificity),
      Dogruluk = sprintf("%.3f", ei$accuracy),
      Ort_kat_AUC = sprintf("%.3f", mean(kat_auc, na.rm = TRUE)),
      CV_AUC = sprintf("%.3f", as.numeric(auc(r_cv))),
      CV_AUC_GA95 = sprintf("%.3f-%.3f", ci_cv[1], ci_cv[3]),
      TCV_AUC_medyan = sprintf("%.3f", tq[1]),
      TCV_AUC_aralik = sprintf("%.3f-%.3f", tq[2], tq[3])))
}
mA <- firth_model(c("PD","C"),  "PD",  TOHUM + 1)
mB <- firth_model(c("PPD","C"), "PPD", TOHUM + 2)
mC <- firth_model(c("PPD","PD"),"PPD", TOHUM + 3)
# LBP'siz duyarlilik modelleri: FATP5 iliskisinin LBP'ye bagli olmadigini
# gostermek icin iki PPD modeli LBP cikarilarak, ayni katilimcilarda ve
# ayni kat tohumlariyla yeniden kurulur (makalede Tablo S1, C bolumu).
tah_lbpsiz <- setdiff(tahmin, "loglbp")
ad_lbpsiz <- tah_et[tahmin != "loglbp"]
mB0 <- firth_model(c("PPD","C"), "PPD", TOHUM + 2, tah = tah_lbpsiz, tah_ad = ad_lbpsiz)
mC0 <- firth_model(c("PPD","PD"),"PPD", TOHUM + 3, tah = tah_lbpsiz, tah_ad = ad_lbpsiz)
lbp_haric <- do.call(rbind, lapply(list(list("PPD vs C", mB0), list("PPD vs PD", mC0)), function(x) {
  k <- x[[2]]$katsayi[x[[2]]$katsayi$Degisken == "FATP5", ]; pf <- x[[2]]$performans
  data.frame(Model = x[[1]], n = pf$n, OR = k$OR, GA95 = k$GA95, p = k$p,
             AUC = pf$AUC, CV_AUC = pf$CV_AUC, TCV_AUC_medyan = pf$TCV_AUC_medyan,
             TCV_AUC_aralik = pf$TCV_AUC_aralik, stringsAsFactors = FALSE)
}))
t4 <- rbind(cbind(Model = "PD vs Kontrol", mA$katsayi),
            cbind(Model = "PPD vs Kontrol", mB$katsayi),
            cbind(Model = "PPD vs PD", mC$katsayi))
t5 <- rbind(cbind(Model = "PD vs Kontrol", mA$performans),
            cbind(Model = "PPD vs Kontrol", mB$performans),
            cbind(Model = "PPD vs PD", mC$performans))

# ---- 10. Duyarlilik analizi ----------------------------------------
duyarlilik <- data.frame()
for (v in ffq_kalem) {
  a <- karsilastir(v, d_ham); b <- karsilastir(v, d)
  if (is.null(a) || is.null(b)) next
  durum <- if (a$p < 0.05 && b$p >= 0.05) "KAYBOLDU" else
           if (a$p >= 0.05 && b$p < 0.05) "YENI" else
           if (b$p < 0.05) "korundu" else "-"
  duyarlilik <- rbind(duyarlilik, data.frame(Besin = besinler[[v]],
    p_bosluk_NA = sprintf("%.4f", a$p), p_bosluk_sifir = sprintf("%.4f", b$p),
    n_NA = sprintf("%d/%d/%d", a$n["PPD"], a$n["PD"], a$n["C"]),
    Durum = durum, p_NA_3 = p_bicim(a$p), p_sifir_3 = p_bicim(b$p),
    stringsAsFactors = FALSE))
}

# ---- 10b. Biyobelirtec duyarlilik analizleri ------------------------
# (1) Post-hoc p degerleri (Dunn, Bonferroni) sayisal olarak.
ph_tablo <- do.call(rbind, lapply(names(biyo)[1:6], function(v) {
  r <- karsilastir(v)
  g <- function(a, b) { x <- r$posthoc[paste(a, b, sep = "-")]
    if (is.na(x)) x <- r$posthoc[paste(b, a, sep = "-")]; if (is.na(x)) NA else x }
  data.frame(Degisken = biyo[[v]], Genel_p = sprintf("%.5f", r$p),
             PD_C = sprintf("%.4f", g("PD", "C")), PPD_C = sprintf("%.4f", g("PPD", "C")),
             PPD_PD = sprintf("%.4f", g("PPD", "PD")), stringsAsFactors = FALSE)
}))
# (2) FATP5 kit ust standardinda (10 ng/mL) sansurlenir: ekstrapole edilen
#     degerler "en az 10" olarak ele alinir.
d$fatp5_sansur <- pmin(d$fatp5, 10)
r_s <- karsilastir("fatp5_sansur")
fatp5_sansur_ozet <- c(
  sprintf("  Kruskal-Wallis p = %.5f", r_s$p),
  sprintf("  Post-hoc: %s", paste(sprintf("%s = %.4f", names(r_s$posthoc), r_s$posthoc), collapse = ", ")),
  sprintf("  Medyan (IQR): %s", paste(names(r_s$desc), r_s$desc, sep = " ", collapse = " | ")))
tahmin_s <- replace(tahmin, tahmin == "fatp5", "fatp5_sansur")
fatp5_sansur_or <- do.call(rbind, lapply(list(c("PD","C","PD"), c("PPD","C","PPD"), c("PPD","PD","PPD")), function(gg) {
  dd <- d[d$group %in% gg[1:2], c("group", tahmin_s)]; dd <- dd[complete.cases(dd), ]
  dd$y <- as.numeric(dd$group == gg[3])
  for (v in tahmin_s) if (v != "sex_m") dd[[v]] <- as.numeric(scale(dd[[v]]))
  m <- logistf(as.formula(paste("y ~", paste(tahmin_s, collapse = " + "))), data = dd)
  k <- "fatp5_sansur"
  data.frame(Model = paste(gg[1], "vs", gg[2]), n = nrow(dd),
             OR = sprintf("%.3f", exp(coef(m)[k])),
             GA95 = sprintf("%.3f-%.3f", exp(m$ci.lower[k]), exp(m$ci.upper[k])),
             p = p_bicim(m$prob[k]), stringsAsFactors = FALSE)
}))
# (3) Toplam SCFA: ana asitlerinden biri eksik olan kayitlar cikarilinca.
eksik_ana <- is.na(d$acetic) | is.na(d$propionic) | is.na(d$butyric)
r_t <- karsilastir("total_scfa", d[!eksik_ana, ])
scfa_duyar <- c(
  sprintf("  Ana asitlerinden biri eksik kayit: %d (id: %s)", sum(eksik_ana & !is.na(d$total_scfa)),
          paste(d$id[eksik_ana & !is.na(d$total_scfa)], collapse = ", ")),
  sprintf("  Bunlar cikarilinca Kruskal-Wallis p = %.5f, n = %s", r_t$p,
          paste(r_t$n[c("PPD","PD","C")], collapse = "/")),
  sprintf("  Medyan (IQR): %s", paste(names(r_t$desc), r_t$desc, sep = " ", collapse = " | ")))

# ---- 11. Figurler ---------------------------------------------------
# MDCP: figurlerdeki yazi en az 11 pt olmali. Butun metin, eksen ve lejant
# yazilari 11 pt, panel basliklari 12 pt; geom_text boyutu mm cinsindendir.
YAZI <- 11
YAZI_MM <- YAZI / ggplot2::.pt
MIN11 <- theme(text = element_text(size = YAZI), axis.text = element_text(size = YAZI),
               axis.title = element_text(size = YAZI), legend.text = element_text(size = YAZI),
               legend.title = element_text(size = YAZI), plot.title = element_text(size = YAZI + 1))
tema <- theme_classic(base_size = YAZI) + MIN11 +
  theme(legend.position = "none") +
  LEJANT_SADE
yildiz <- function(p) if (is.na(p)) "" else if (p < 0.001) "***" else
  if (p < 0.01) "**" else if (p < 0.05) "*" else "ns"

panel_ciz <- function(var, baslik, eksen, log_mu = FALSE) {
  r <- karsilastir(var)
  dd <- d[!is.na(d[[var]]), c("group", var)]; names(dd)[2] <- "x"
  g <- ggplot(dd, aes(group, x, color = group, fill = group)) +
    stat_boxplot(geom = "errorbar", width = 0.25, linewidth = 0.4) +
    geom_boxplot(alpha = 0.35, width = 0.5, outlier.shape = NA) +
    geom_jitter(width = 0.16, size = 1.3, alpha = 0.85) +
    scale_color_manual(values = RENK) + scale_fill_manual(values = RENK) +
    scale_x_discrete(labels = GRUP_AD) +
    labs(title = baslik, x = NULL, y = eksen) + tema
  ust <- max(dd$x, na.rm = TRUE)
  anahtar <- c("C-PD", "PD-PPD", "C-PPD")
  konum <- list(c(1, 2), c(2, 3), c(1, 3))
  for (k in 1:3) {
    if (is.null(r$posthoc) || !length(r$posthoc)) break
    p <- r$posthoc[anahtar[k]]
    if (is.na(p)) p <- r$posthoc[paste(rev(strsplit(anahtar[k], "-")[[1]]), collapse = "-")]
    if (length(p) == 0 || is.na(p)) next
    x1 <- konum[[k]][1]; x2 <- konum[[k]][2]
    if (log_mu) { y <- ust * 2.2^k; alt <- y / 1.25
    } else { y <- ust * (1.05 + 0.13 * k); alt <- y - ust * 0.035 }
    g <- g +
      annotate("segment", x = x1, xend = x2, y = y, yend = y, linewidth = 0.3, color = "grey30") +
      annotate("segment", x = x1, xend = x1, y = alt, yend = y, linewidth = 0.3, color = "grey30") +
      annotate("segment", x = x2, xend = x2, y = alt, yend = y, linewidth = 0.3, color = "grey30") +
      annotate("text", x = (x1 + x2) / 2, y = y * if (log_mu) 1.15 else 1.02,
               label = yildiz(p), size = YAZI_MM, vjust = 0)
  }
  if (log_mu) g <- g + scale_y_log10()
  g
}
f1 <- (panel_ciz("fatp5", "A  FATP5", "Serum FATP5 (ng/mL)") |
       panel_ciz("lbp", "B  LBP", "Serum LBP (ng/mL, log scale)", TRUE) |
       panel_ciz("total_scfa", "C  Total SCFA", "Total SCFA (mM)")) /
      (panel_ciz("acetic", "D  Acetic acid", "Acetic acid (mM)") |
       panel_ciz("propionic", "E  Propionic acid", "Propionic acid (mM)") |
       panel_ciz("butyric", "F  Butyric acid", "Butyric acid (mM)"))
kaydet(f1, "Figure1_biomarkers", 8.5, 7.0)

ort <- sapply(GRUP_SIRA, function(g)
  sapply(names(besinler), function(v) mean(d[[v]][d$group == g], na.rm = TRUE)))
z <- t(apply(ort, 1, function(x) if (sd(x) == 0) x * 0 else (x - mean(x)) / sd(x)))
p_besin <- sapply(names(besinler), function(v) { r <- karsilastir(v); if (is.null(r)) NA else r$p })
sira <- order(z[, "C"] - pmax(z[, "PD"], z[, "PPD"]), decreasing = TRUE)
isi <- data.frame(
  besin = factor(rep(besinler_en[sira], 3), levels = rev(besinler_en[sira])),
  grup  = factor(rep(GRUP_AD[GRUP_SIRA], each = length(sira)), levels = GRUP_AD[GRUP_SIRA]),
  z = c(z[sira, "C"], z[sira, "PD"], z[sira, "PPD"]))
etiket <- data.frame(besin = factor(besinler_en[sira], levels = rev(besinler_en[sira])),
                     yildiz = sapply(p_besin[sira], function(p) { s <- yildiz(p); if (s == "ns") "" else s }))
f2 <- ggplot(isi, aes(grup, besin, fill = z)) +
  geom_tile(color = "white", linewidth = 1.2) +
  geom_text(data = etiket, aes(x = 3.7, y = besin, label = yildiz), inherit.aes = FALSE, size = YAZI_MM) +
  scale_fill_gradient2(low = "#2166AC", mid = "#F7F7F7", high = "#D6604D",
                       limits = c(-1.3, 1.3), oob = scales::squish, name = "Mean intake\n(z-score)") +
  coord_cartesian(xlim = c(0.5, 4), clip = "off") + labs(x = NULL, y = NULL) +
  theme_minimal(base_size = YAZI) + MIN11 +
  theme(panel.grid = element_blank(), axis.ticks = element_blank())
kaydet(f2, "FigureS1_diet_heatmap", 6.0, 9.5)

d3 <- d[!is.na(d$fatp5) & !is.na(d$lbp), ]
uy <- lm(fatp5 ~ log10(lbp), data = d3)
f3a <- ggplot(d3, aes(lbp, fatp5, color = group)) +
  geom_point(size = 2.0, alpha = 0.85) +
  geom_abline(intercept = coef(uy)[1], slope = coef(uy)[2],
              linetype = "dashed", color = "grey30", linewidth = 0.5) +
  scale_x_log10() + scale_color_manual(values = RENK, labels = GRUP_AD) +
  labs(title = "A  FATP5 vs. LBP", x = "Serum LBP (ng/mL, log scale)",
       y = "FATP5 (ng/mL)", color = NULL) +
  annotate("text", x = min(d3$lbp), y = min(d3$fatp5), hjust = 0, vjust = 1.2, size = YAZI_MM,
           label = sprintf("Spearman rho = %.3f, p = %.3f", kor_test$estimate, kor_test$p.value)) +
  theme_classic(base_size = YAZI) + MIN11 +
  theme(legend.position = "top", legend.direction = "horizontal") + LEJANT_SADE
ku <- expand.grid(i = 1:nk, j = 1:nk); ku <- ku[ku$i >= ku$j, ]
ku$rho <- K[cbind(ku$i, ku$j)]; ku$p <- KP[cbind(ku$i, ku$j)]
ku$xi <- factor(kor_et[ku$j], levels = kor_et)
ku$yi <- factor(kor_et[ku$i], levels = rev(kor_et))
ku$met <- ifelse(ku$i == ku$j, "", sprintf("%.2f%s", ku$rho, ifelse(ku$p < 0.05, "*", "")))
f3b <- ggplot(ku, aes(xi, yi, fill = rho)) + geom_tile(color = "white") +
  geom_text(aes(label = met), size = YAZI_MM, color = "grey20") +
  scale_fill_gradient2(low = "#2166AC", mid = "#F7F7F7", high = "#D6604D",
                       limits = c(-1, 1), name = "rho") +
  labs(title = "B  Spearman correlations", x = NULL, y = NULL) +
  theme_minimal(base_size = YAZI) + MIN11 +
  theme(panel.grid = element_blank(), axis.ticks = element_blank(),
        axis.text.x = element_text(angle = 45, hjust = 1, size = YAZI))
kaydet((f3a | f3b) + plot_layout(widths = c(1, 1.45)), "Figure2_correlations", 13.5, 6.4)

roc_df <- function(r, ad) data.frame(fpr = 1 - r$specificities, tpr = r$sensitivities, egri = ad)
# Lejant konumu: ggplot2 3.5 ve sonrasi "inside" ister, oncesi sayisal konum.
lejant_ic <- function(x, y) {
  if (utils::packageVersion("ggplot2") >= "3.5.0")
    theme(legend.position = "inside", legend.position.inside = c(x, y))
  else theme(legend.position = c(x, y))
}
roc_panel <- function(m, baslik) {
  r1 <- rbind(roc_df(m$roc_ap, sprintf("Apparent (AUC = %s)", m$performans$AUC)),
              roc_df(m$roc_cv, sprintf("5-fold CV (AUC = %s)", m$performans$CV_AUC)))
  ggplot(r1, aes(fpr, tpr, color = egri, linetype = egri)) +
    geom_abline(slope = 1, intercept = 0, color = "grey80", linewidth = 0.3) +
    geom_path(linewidth = 0.7) + scale_color_manual(values = c("#0055A4", "#E8420C")) +
    coord_equal() +
    labs(title = baslik, x = "1 - Specificity", y = "Sensitivity",
         color = NULL, linetype = NULL) +
    theme_classic(base_size = YAZI) + MIN11 + lejant_ic(0.58, 0.14) + LEJANT_SADE
}
f4 <- roc_panel(mA, "A  PD vs. Control") | roc_panel(mB, "B  PPD vs. Control") |
      roc_panel(mC, "C  PPD vs. PD")
kaydet(f4, "Figure3_roc", 13.0, 4.8)

# ---- 12. report.txt -------------------------------------------------
eski_genislik <- getOption("width")
options(width = 200)          # tablolar satir sonunda kirilmasin
cizgi <- strrep("=", 72)
baslik <- function(a) c(cizgi, a, cizgi, "")
tablo_yaz <- function(df) c(capture.output(print(df, row.names = FALSE)), "")

rapor <- c(
  baslik("PARKINSON / PARKINSON PLUS / KONTROL - ANALIZ RAPORU"),
  sprintf("Tarih        : %s", format(Sys.time(), "%Y-%m-%d %H:%M")),
  sprintf("Veri dosyasi : %s", DATA_FILE),
  sprintf("Kod surumu   : 5 (14.10.2026 verisi; tekrarli CV, LBP'siz duyarlilik, figur adlari makale sirasinda)"),
  "",
  baslik("BOLUM A. VERI KALITE DENETIMI"), denetim, "",
  baslik("BOLUM B. TABLO 1. Demografik, yasam tarzi ve biyokimya"),
  "Surekli: normal ise ortalama +- SS (ANOVA), degilse medyan (IQR)",
  "(Kruskal-Wallis). Kategorik: n (%), ki-kare. Post-hoc harfleri:",
  "a = kontrolden farkli, b = PD'den farkli (p < 0.05).",
  "n sutunu her satirin gercek PPD/PD/C sayilarini gosterir.", "",
  tablo_yaz(t1),
  baslik("BOLUM C. TABLO 2. Bir aylik besin tuketimi"),
  "Bosluklar sifir tuketim olarak kodlanmistir (bkz. Bolum A).", "",
  tablo_yaz(t2),
  baslik("BOLUM D. ANKET KODLAMASI DUYARLILIK ANALIZI"),
  "Bosluklar veri yok sayilirsa ile sifir sayilirsa elde edilen p",
  "degerleri. n_NA sutunu, bosluklar veri yok sayildiginda kalan kisi",
  "sayisidir; bu sayinin dusuklugu o kodlamanin neden yaniltici",
  "oldugunu gosterir.", "",
  tablo_yaz(duyarlilik),
  baslik("BOLUM E. TABLO 3. Bagirsak biyobelirtecleri"),
  tablo_yaz(t3),
  baslik("BOLUM F. KORELASYONLAR (Spearman)"),
  sprintf("FATP5 - LBP: rho = %.3f, p = %.4f (n = %d)",
          kor_test$estimate, kor_test$p.value, nrow(d3)), "",
  "rho matrisi:", capture.output(print(round(K, 3))), "",
  "p degerleri:", capture.output(print(round(KP, 4))), "",
  "n (iki degiskeni de olan kisi sayisi):", capture.output(print(KN)), "",
  baslik("BOLUM G. TABLO 4. Firth cezali lojistik regresyon"),
  "OR degerleri surekli degiskenlerde 1 SS artis icindir. GA ve p",
  "profil cezali olabilirlik ile hesaplanmistir (logistf).", "",
  tablo_yaz(t4),
  baslik("BOLUM H. TABLO 5. Model performansi ve 5 katli capraz dogrulama"),
  sprintf("TCV: %d farkli rastgele bolmeyle tekrarlanan 5 katli CV; medyan ve", TEKRAR_CV),
  "2.5-97.5 persantil araligi (yalnizca kat atamasina bagli degiskenligi yansitir).", "",
  tablo_yaz(t5),
  baslik("BOLUM H2. BIYOBELIRTEC DUYARLILIK ANALIZLERI"),
  "1. Post-hoc p degerleri (Dunn testi, Bonferroni duzeltmeli; normal",
  "   dagilan degiskenlerde Tukey).", "",
  tablo_yaz(ph_tablo),
  "2. FATP5, kitin ust standardinda (10 ng/mL) sansurlendiginde",
  "   (ekstrapole edilen degerler 10 kabul edildi):",
  fatp5_sansur_ozet, "",
  "   Firth modellerinde sansurlu FATP5 (diger degiskenler ayni):", "",
  tablo_yaz(fatp5_sansur_or),
  "3. Toplam SCFA, ana asitlerinden biri eksik olan kayitlar cikarilinca:",
  scfa_duyar, "",
  "4. LBP cikarilmis PPD modelleri (ayni katilimcilar, ayni kat tohumlari);",
  "   FATP5 OR, GA ve p ile model performansi:", "",
  tablo_yaz(lbp_haric),
  baslik("BOLUM I. UYARILAR"),
  "1. Kit ust standardinin uzerindeki olcumler dilusyon yapilmadan",
  "   dort parametreli lojistik egriden ekstrapole edilmistir (sayilar",
  "   icin Bolum A). Bu egri ust standart civarinda doyuma gittigi icin",
  "   bu degerler yaklasiktir.",
  "2. LBP cift kuyucukta (uc grup ayni partide, kit lotu 20260818),",
  "   FATP5 tek kuyucukta olculmustur; CV degerleri kit prospektusunden",
  "   alinmistir.",
  "3. Minor SCFA'larda limit alti degerlere LOD/2 (0.003 mM) atanmistir;",
  "   LOD, S/N = 3 olcutune karsilik gelen derisimdir (0.006 mM).",
  "4. Parkinson Plus grubu alt tiplerine ayrilmamistir.",
  "",
  baslik("BOLUM J. REPRODUCIBILITY"),
  sprintf("Veri dosyasi   : %s", DATA_FILE),
  sprintf("Dosya boyutu   : %d bayt", as.integer(file.size(DATA_FILE))),
  sprintf("Dosya tarihi   : %s", format(file.mtime(DATA_FILE), "%Y-%m-%d %H:%M:%S")),
  sprintf("Satir x sutun  : %d x %d", nrow(d), ncol(d)),
  sprintf("Grup buyuklugu : PPD %d, PD %d, kontrol %d",
          sum(d$group == "PPD"), sum(d$group == "PD"), sum(d$group == "C")),
  sprintf("Ana tohum      : %d (capraz dogrulama katlari %d, %d, %d)",
          TOHUM, TOHUM + 1, TOHUM + 2, TOHUM + 3),
  sprintf("BKI kaynagi    : %s", BKI_KAYNAK),
  sprintf("Calisma zamani : %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  "Bu rapor yukaridaki dosyadan uretilmistir. Ayni dosya, ayni tohum ve",
  "asagidaki paket surumleriyle butun sayilar birebir tekrar uretilir.",
  "",
  capture.output(sessionInfo()))
gecici_rapor <- file.path(GECICI, "run_all_report.txt")
con <- file(gecici_rapor, open = "wt", encoding = "UTF-8")
writeLines(rapor, con)
close(con)
if (!file.copy(gecici_rapor, file.path(SONUCLAR, "run_all_report.txt"), overwrite = TRUE)) {
  con <- file(file.path(SONUCLAR, "run_all_report.txt"), open = "wt", encoding = "UTF-8")
  writeLines(rapor, con); close(con)
}
# Makale tablolari bu dosyalardan uretilir (elle aktarim yok).
tsv_yaz <- function(df, ad) {
  yol <- file.path(SONUCLAR, paste0(ad, ".tsv"))
  con <- file(yol, open = "wt", encoding = "UTF-8")
  write.table(df, con, sep = "\t", quote = FALSE, row.names = FALSE, na = "")
  close(con)
}
tsv_yaz(t1, "tablo1_demografi"); tsv_yaz(t2, "tablo2_besin")
tsv_yaz(t3, "tablo3_biyobelirtec"); tsv_yaz(t4, "tablo4_firth")
tsv_yaz(t5, "tablo5_performans"); tsv_yaz(duyarlilik, "tablo6_anket_duyarlilik")
tsv_yaz(ph_tablo, "tablo7_posthoc"); tsv_yaz(fatp5_sansur_or, "tablo8_fatp5_sansur")
tsv_yaz(lbp_haric, "tablo9_lbp_haric")
tarihli <- file.path(SONUCLAR, sprintf("run_all_report_%s.txt", format(Sys.Date(), "%Y-%m-%d")))
file.copy(file.path(SONUCLAR, "run_all_report.txt"), tarihli, overwrite = TRUE)
options(width = eski_genislik)
cat(sprintf("\nBitti.\n  Rapor  : %s\n  Figurler: %s\n",
            file.path(SONUCLAR, "run_all_report.txt"), FIGURLER))

# ---- 13. Makale tablolari ------------------------------------------
# TSV'lerden makale/tablolar/*.tex uretilir; makale klasoru yoksa atlanir.
mt <- file.path(kok, "code", "makale_tablolari.R")
if (file.exists(mt)) source(mt, encoding = "UTF-8") else
  message("makale_tablolari.R bulunamadi; makale tablolari uretilmedi.")
