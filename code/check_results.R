# =====================================================================
# check_results.R
# Makalede raporlanan sayilarin bagimsiz dogrulamasi, R tarafi.
#
# Bu calismada turetilmis kapali form formul yoktur, bu yuzden kontrol
# formul dogrulamasi degil sonuc dogrulamasidir. Iki is yapar.
#   1. Veri ici tutarlilik: toplam SCFA alti asidin toplami mi, BKI boy
#      ve kilodan cikiyor mu, LDL Friedewald ile uyusuyor mu, anket
#      bosluk kurali dogru uygulanmis mi.
#   2. Ana istatistikleri core'un fonksiyonlarini kullanmadan, yalnizca
#      base R ile yeniden hesaplar ve DEGERLER blogunda yazar. Ayni
#      hesaplar check_results.py icinde Python ile ikinci kez yapilir,
#      boylece bir hata iki dilde birden hayatta kalamaz.
#
# Proje kokunden calistirilir:
#     Rscript code/check_results.R
# Yazdigi: results/check_results_report.txt
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

satir <- c()
ekle_s <- function(...) satir <<- c(satir, sprintf(...))
gecti <- 0; kaldi <- 0
kontrol <- function(ad, kosul, ayrinti = "") {
  if (isTRUE(kosul)) { gecti <<- gecti + 1; ekle_s("PASS  %-46s %s", ad, ayrinti) }
  else               { kaldi <<- kaldi + 1; ekle_s("FAIL  %-46s %s", ad, ayrinti) }
}

ekle_s("=== 1. VERI ICI TUTARLILIK ===")

# Toplam SCFA alti asidin toplami mi
alti <- rowSums(cbind(d$acetic, d$propionic, d$butyric,
                      d$isobutyric, d$valeric, d$isovaleric), na.rm = TRUE)
fark <- abs(d$total_scfa - alti)
kontrol("Toplam SCFA = alti asidin toplami", sum(fark > 0.01, na.rm = TRUE) == 0,
        sprintf("en buyuk fark %.4f", max(fark, na.rm = TRUE)))

# BKI boy ve kilodan
bki <- d$weight / (d$height / 100)^2
kontrol("BKI yeniden hesaplanabiliyor", all(is.finite(bki[!is.na(d$weight) & !is.na(d$height)])),
        sprintf("kayitli deger ile uyusmayan: %d kisi",
                sum(abs(d$bmi_kayitli - bki) > 0.5, na.rm = TRUE)))

# LDL Friedewald
if (all(c("chol","hdl","tg","ldl") %in% names(d))) {
  fr <- d$chol - d$hdl - d$tg / 5
  f2 <- abs(d$ldl - fr)
  kontrol("LDL Friedewald formuluyle uyusuyor", mean(f2 < 1, na.rm = TRUE) > 0.95,
          sprintf("uyusan oran %.3f", mean(f2 < 1, na.rm = TRUE)))
}

# Anket bosluk kurali: formu olmayanlarda tum kalemler NA
anketsiz <- rowSums(!is.na(d_ham[, ffq_kalem])) == 0
kontrol("Anketi olmayanlarda tum kalemler NA",
        all(is.na(as.matrix(d[anketsiz, ffq_kalem]))),
        sprintf("anketsiz kisi: %d", sum(anketsiz)))
kontrol("Anketi olanlarda bosluk kalmadi",
        !any(is.na(as.matrix(d[!anketsiz, ffq_kalem]))),
        sprintf("anketli kisi: %d", sum(!anketsiz)))

# Grup buyuklukleri
kontrol("Grup buyuklukleri 32 / 33 / 33",
        sum(d$group == "PPD") == 32 && sum(d$group == "PD") == 33 &&
        sum(d$group == "C") == 33,
        sprintf("PPD %d, PD %d, C %d", sum(d$group == "PPD"),
                sum(d$group == "PD"), sum(d$group == "C")))

ekle_s("")
ekle_s("=== 2. ANA ISTATISTIKLER, BASE R ILE BAGIMSIZ HESAP ===")
ekle_s("Bu blok check_results.py tarafindan okunur ve Python ile")
ekle_s("yeniden hesaplanan degerlerle karsilastirilir.")
ekle_s("")
ekle_s("DEGERLER")

hedef <- c(lbp = "lbp", fatp5 = "fatp5", total_scfa = "total_scfa",
           acetic = "acetic", propionic = "propionic", butyric = "butyric",
           age = "age")
for (ad in names(hedef)) {
  v <- d[[hedef[ad]]]
  gr <- lapply(c("PPD","PD","C"), function(g) v[d$group == g & !is.na(v)])
  p  <- kruskal.test(list(gr[[1]], gr[[2]], gr[[3]]))$p.value
  ekle_s("%s\tn\t%d\t%d\t%d", ad, length(gr[[1]]), length(gr[[2]]), length(gr[[3]]))
  ekle_s("%s\tmedyan\t%.4f\t%.4f\t%.4f", ad,
         median(gr[[1]]), median(gr[[2]]), median(gr[[3]]))
  ekle_s("%s\tkruskal_p\t%.6f", ad, p)
}
ok <- !is.na(d$fatp5) & !is.na(d$lbp)
sp <- suppressWarnings(cor.test(d$fatp5[ok], d$lbp[ok], method = "spearman"))
ekle_s("fatp5_lbp\tspearman_rho\t%.4f", as.numeric(sp$estimate))
ekle_s("fatp5_lbp\tspearman_p\t%.6f", sp$p.value)
ekle_s("fatp5_lbp\tn\t%d", sum(ok))
ekle_s("SON")
ekle_s("")
ekle_s("=== OZET ===")
ekle_s("Gecen: %d   Kalan: %d", gecti, kaldi)
ekle_s(if (kaldi == 0) "TUM KONTROLLER GECTI" else "DIKKAT: EN AZ BIR KONTROL BASARISIZ")

gec <- file.path(GECICI, "check_results_report.txt")
con <- file(gec, open = "wt", encoding = "UTF-8"); writeLines(satir, con); close(con)
if (!file.copy(gec, file.path(SONUCLAR, "check_results_report.txt"), overwrite = TRUE)) {
  con <- file(file.path(SONUCLAR, "check_results_report.txt"), open = "wt", encoding = "UTF-8")
  writeLines(satir, con); close(con)
}
cat(paste(satir, collapse = "\n"), "\n")
cat("\nRapor:", file.path(SONUCLAR, "check_results_report.txt"), "\n")
