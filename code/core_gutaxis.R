# =====================================================================
# core_gutaxis.R
# Parkinson Plus bagirsak-beyin ekseni calismasi: ortak cekirdek.
#
# Bu dosya tek basina bir cikti uretmez. run_all.R ve check_results.R
# bu dosyayi source eder, boylece veri okuma, temizleme, denetim ve
# istatistik fonksiyonlarinin tek bir uygulamasi olur.
#
# Proje kokunden calistirilir:
#     source("code/core_gutaxis.R")
#
# Veri dosyasi depoda yer almaz. data/data.xlsx olarak konur, ya da
# DATA_FILE degiskenine tam yol yazilir.
# =====================================================================

# ---- 0. Kurulum -----------------------------------------------------
# Veri dosyasi. Once bu adla aranir, bulunamazsa klasordeki herhangi bir
# xlsx kullanilir. Isterseniz DATA_FILE degiskenine tam yolu yazin.
VERI_ADI  <- "data.xlsx"
DATA_FILE <- ""

# Beden kutle indeksi kaynagi:
#   "hesaplanan" = boy ve kilodan yeniden hesaplanir (dogru olan)
#   "kayitli"    = veri dosyasindaki bki sutunu kullanilir
# Iki deger arasindaki 0.5 kg/m2'yi asan farklar raporun A bolumunde
# listelenir (14.10.2026 verisinde boyle bir kayit yoktur).
BKI_KAYNAK <- "hesaplanan"

# Aranacak klasorler: once calisma dizini, sonra asagidaki sabit klasor.
# Yol ASCII kacis dizileriyle yazilmistir (\u0131 = noktasiz i,
# \u00e7 = c cedilla, \u015f = s cedilla). Boylece bu dosyanin hangi
# karakter kodlamasiyla okundugu onemli olmaz.
KLASOR_SABIT <- "G:/Drive'\u0131m/yeni-\u00e7al\u0131\u015fmalar/82. calisma hakan ekmekci"

TOHUM <- 42        # tek ana tohum; her rastgele adim bundan tureyen
set.seed(TOHUM)   # kendi tohumunu kurar, boylece adim sirasi sonucu degistirmez

paketler <- c("readxl", "ggplot2", "patchwork", "logistf", "pROC")
for (p in paketler) {
  if (!requireNamespace(p, quietly = TRUE))
    install.packages(p, repos = "https://cloud.r-project.org")
  library(p, character.only = TRUE)
}

RENK <- c(C = "#0055A4", PD = "#E8420C", PPD = "#00997B")
GRUP_SIRA <- c("C", "PD", "PPD")
GRUP_AD   <- c(C = "Control", PD = "PD", PPD = "PPD")

# Proje koku: koddan bir ust klasor. Kod code/ altinda durur, bu yuzden
# hangi klasorden calistirildigina bakmaksizin kok dogru bulunur.
PROJE_KOK <- local({
  # Proje koku. Once calisma klasoru denenir (setwd ile verilen), sonra
  # source() ile verilen dosya yolu. normalizePath kullanilmaz: Windows'ta
  # Turkce karakterli yollarda (Drive'im, calismalar gibi) yolu bozabiliyor.
  adaylar <- c(getwd(), dirname(getwd()))
  of <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (is.character(of)) adaylar <- c(adaylar, dirname(dirname(of)), dirname(of))
  for (a in adaylar) if (file.exists(file.path(a, "code", "core_gutaxis.R"))) return(a)
  getwd()
})
if (basename(PROJE_KOK) == "code") PROJE_KOK <- dirname(PROJE_KOK)

aranacak <- unique(c(file.path(PROJE_KOK, "data"), PROJE_KOK,
                     getwd(), KLASOR_SABIT))
aranacak <- aranacak[dir.exists(aranacak)]

if (DATA_FILE == "" || !file.exists(DATA_FILE)) {
  for (kl in aranacak) {                    # once tam ad ile
    aday <- file.path(kl, VERI_ADI)
    if (file.exists(aday)) { DATA_FILE <- aday; break }
  }
}
if (DATA_FILE == "" || !file.exists(DATA_FILE)) {
  for (kl in aranacak) {                    # sonra herhangi bir xlsx
    a <- list.files(kl, pattern = "[.]xlsx$", ignore.case = TRUE, full.names = TRUE)
    a <- a[!grepl("^~", basename(a))]
    if (length(a) > 1)
      warning("Klasorde birden fazla xlsx var, ilki kullaniliyor: ",
              basename(a[1]), ". Tekrarlanabilirlik icin VERI_ADI veya ",
              "DATA_FILE ile dosyayi acikca belirtin.", call. = FALSE)
    if (length(a)) { DATA_FILE <- a[1]; break }
  }
}
if (DATA_FILE == "" || !file.exists(DATA_FILE)) {
  cat("\n--- TANI BILGISI ---\n")
  cat("Aranan klasorler:\n"); print(aranacak)
  cat("Calisma dizinindeki dosyalar:\n"); print(list.files(getwd()))
  stop("Veri dosyasi bulunamadi.\n",
       "  Cozum 1: data.xlsx dosyasini deponun data/ klasorune koyun.\n",
       "  Cozum 2: DATA_FILE degiskenine tam yolu yazin.")
}

# Ciktilar her zaman proje kokunun altina yazilir, verinin nerede
# durduguna bakilmaz. Boylece depo ile ciktilar ayni duzende kalir.
SONUCLAR <- file.path(PROJE_KOK, "results")   # txt raporlar
FIGURLER <- file.path(PROJE_KOK, "figures")   # eps, pdf, png
for (kl in c(SONUCLAR, FIGURLER))
  dir.create(kl, showWarnings = FALSE, recursive = TRUE)

cat("Veri dosyasi  :", DATA_FILE, "\n")
cat("Proje koku    :", PROJE_KOK, "\n")
cat("Ciktilar      :", SONUCLAR, "ve", FIGURLER, "\n\n")


# ---- 1. Veri okuma --------------------------------------------------
# Windows'ta R'in zip okuyucusu ve grafik aygitlari, yolunda apostrof veya
# Turkce karakter bulunan dosyalari acamaz. Asagidaki fonksiyon, yolu
# tamamen ASCII olan bir gecici klasor dondurur; veri once oraya
# kopyalanip okunur, figurler once orada uretilip sonra hedefe tasinir.
ascii_gecici <- function() {
  k <- tempdir()
  if (!grepl("[^ -~]", k)) return(k)
  for (alt in c("C:/rtmp", "D:/rtmp", "/tmp/rtmp")) {
    if (grepl("[^ -~]", alt)) next
    dir.create(alt, showWarnings = FALSE, recursive = TRUE)
    if (dir.exists(alt)) return(alt)
  }
  k
}
GECICI <- ascii_gecici()

# Veri dosyasi ASCII yollu gecici klasore kopyalanip oradan okunur
okunacak <- file.path(GECICI, "veri_gecici.xlsx")
kopyalandi <- file.copy(DATA_FILE, okunacak, overwrite = TRUE)
if (!kopyalandi) {                      # ikinci deneme: bayt bayt kopyala
  kopyalandi <- !inherits(try({
    gir <- file(DATA_FILE, "rb")
    baytlar <- readBin(gir, "raw", n = file.size(DATA_FILE))
    close(gir)
    cik <- file(okunacak, "wb"); writeBin(baytlar, cik); close(cik)
  }, silent = TRUE), "try-error")
}
if (!kopyalandi) {
  warning("Veri dosyasi gecici klasore kopyalanamadi, dogrudan okunuyor.")
  okunacak <- DATA_FILE
}
d <- tryCatch(as.data.frame(read_excel(okunacak)),
  error = function(e) {
    stop("Veri dosyasi okunamadi: ", conditionMessage(e), "\n",
         "  Cozum: data.xlsx dosyasini Turkce karakter ve kesme isareti\n",
         "  icermeyen bir klasore kopyalayin (ornek: C:/ck/data.xlsx) ve\n",
         "  kodun basindaki DATA_FILE degiskenine o yolu yazin.")
  })
if (okunacak != DATA_FILE) unlink(okunacak)
names(d) <- trimws(names(d))

# Sutun adlari ASCII'ye indirgenerek eslestirilir. Boylece bu kodun
# hangi karakter kodlamasiyla okundugu onemli olmaz: kodun icinde Turkce
# karakter yoktur, veri dosyasindaki adlar ise calisma aninda normalize
# edilir (ASCII disi karakterler atilir, kucuk harfe cevrilir,
# noktalama silinir).
ascii_ad <- function(x) {
  x <- gsub("[^ -~]", "", x)           # ASCII disi karakterleri at
  tolower(gsub("[^A-Za-z0-9]", "", x)) # harf ve rakam disini at
}

ESLE <- c(
  "anketnumaras" = "id",
  "parknsontr" = "group",
  "cinsiyet" = "sex",
  "yayl" = "age",
  "boycm" = "height",
  "kilokg" = "weight",
  "bkicm2kg" = "bmi_kayitli",
  "bkkgm2" = "bmi_kayitli",            # data2.xlsx'teki yazim: bki(kg/m2)
  "toplamksaazincirliyaasitler" = "total_scfa",
  "lipopolisakkarit" = "lbp",
  "lpoposakkaritbalaycproteinlbp" = "lbp",   # data2.xlsx'teki uzun yazim
  "fat5" = "fatp5",
  "asetikasit" = "acetic",
  "propiyonikasit" = "propionic",
  "btirikasit" = "butyric",
  "isobtirikasit" = "isobutyric",
  "valerik" = "valeric",
  "isovalerikasit" = "isovaleric",
  "glukoz" = "glucose",
  "kolesterol" = "chol",
  "trigliserit" = "tg",
  "ldl" = "ldl",
  "hdl" = "hdl",
  "drektldl" = "ldl_direct",
  "alt" = "alt",
  "ast" = "ast",
  "kreatnn" = "creat",
  "re" = "urea",
  "wbc" = "wbc",
  "hgb" = "hgb",
  "hct" = "hct",
  "plt" = "plt",
  "rbc" = "rbc",
  "b12" = "b12",
  "ferritin" = "ferritin",
  "folikasit" = "folate",
  "tsh" = "tsh",
  "krmzetgr" = "red_meat",
  "beyazetgr" = "white_meat",
  "yumurtagr" = "eggs",
  "ilenmietgr" = "processed_meat",
  "kurubaklagilgr" = "legumes",
  "stml" = "milk",
  "yourtml" = "yogurt",
  "peynirgr" = "cheese",
  "sonsarmsakgr" = "onion_garlic",
  "yeilyapraklsebzelergr" = "leafy_greens",
  "patateskzartmasgr" = "french_fries",   # anket maddesi: patates kizartmasi
  "meyvegr" = "fruits",
  "tamtahlgr" = "whole_grains",
  "beyazekmekgr" = "white_bread",
  "makarnaeritegr" = "pasta",
  "piringr" = "rice",
  "bulgurgr" = "bulgur",
  "hamuriigr" = "pastries",
  "zeytingr" = "olives",
  "zeytinyaml" = "olive_oil",
  "diersvyaml" = "other_oil",
  "margarin" = "margarine",
  "tereyagr" = "butter",
  "cevizgr" = "walnuts",
  "tatlgr" = "dessert",
  "ayml" = "tea",
  "kahveml" = "coffee",
  "hazrmeyvsuyuml" = "fruit_juice",
  "gazliecekml" = "soda",
  "ailedefazlakiloluvarm" = "fam_overweight",
  "vitaminmineraltakviyesi" = "supplement",
  "hangiananatlarsn" = "skip_meal",
  "kaananyaparsn" = "n_meals",
  "kaaranyaparsn" = "n_snacks",
  "fizikselaktivite" = "phys_act",
  "uykukalitesi" = "sleep",
  "stresdzeyi" = "stress",
  "sigarakullanm" = "smoking",
  "alkolkullanm" = "alcohol")
# Veri dosyasi hasta adi tasiyorsa bu sutun okunur okunmaz dusurulur.
# Depo ve ciktilar paylasima acildigi icin kimlik bilgisi bellege bile
# alinmamalidir.
KIMLIK <- c("smsoysm", "isimsoyisim", "adsoyad", "ad", "soyad", "hastaadi")
kimlik_var <- ascii_ad(names(d)) %in% KIMLIK
if (any(kimlik_var)) {
  cat(sprintf("UYARI: kimlik sutunu dusuruldu: %s\n",
              paste(names(d)[kimlik_var], collapse = ", ")))
  d <- d[, !kimlik_var, drop = FALSE]
}

anahtar <- ascii_ad(names(d))
eslesen <- anahtar %in% names(ESLE)
names(d)[eslesen] <- unname(ESLE[anahtar[eslesen]])
cat(sprintf("Sutun eslestirme: %d / %d sutun tanindi.\n", sum(eslesen), ncol(d)))

d$group <- factor(c(kontrol = "C", parkinson = "PD", parkinsonplus = "PPD")[d$group],
                  levels = GRUP_SIRA)
if (all(is.na(d$group))) stop("Grup sutunu taninamadi. 'Parknsontur' sutununu kontrol edin.")
if (!"id" %in% names(d)) d$id <- seq_len(nrow(d))

ffq_kalem <- c("red_meat","white_meat","eggs","processed_meat","legumes","milk",
  "yogurt","cheese","onion_garlic","leafy_greens","french_fries","fruits",
  "whole_grains","white_bread","pasta","rice","bulgur","pastries","olive_oil",
  "other_oil","olives","margarine","butter","walnuts","dessert","tea","coffee",
  "fruit_juice","soda")
minor_scfa <- c("isobutyric","valeric","isovaleric")
sayisal <- c("age","height","weight","bmi_kayitli","glucose","chol","tg","ldl","hdl",
  "ldl_direct","alt","ast","creat","urea","wbc","hgb","hct","plt","rbc","b12",
  "ferritin","folate","tsh","fatp5","lbp","total_scfa","acetic","propionic",
  "butyric", minor_scfa, ffq_kalem, "n_meals","n_snacks")
for (v in sayisal) if (v %in% names(d)) d[[v]] <- suppressWarnings(as.numeric(d[[v]]))

kategorik <- c("sex","smoking","alcohol","sleep","stress","phys_act",
               "fam_overweight","supplement","skip_meal")
for (v in kategorik) if (v %in% names(d)) d[[v]] <- trimws(as.character(d[[v]]))

# Beklenen sutunlar var mi?
zorunlu <- c("group", "age", "height", "weight", "bmi_kayitli", "lbp", "fatp5",
             "total_scfa", "acetic", "propionic", "butyric", ffq_kalem)
eksik_sutun <- setdiff(zorunlu, names(d))
if (length(eksik_sutun))
  stop("Su sutunlar veride bulunamadi (isimleri kontrol edin):\n  ",
       paste(eksik_sutun, collapse = ", "))

# ---- 2. VERI KALITE DENETIMI ---------------------------------------
denetim <- c()
ekle <- function(...) denetim <<- c(denetim, ...)

ekle("KATILIMCI SAYISI",
     sprintf("  toplam %d  (%s)", nrow(d),
             paste(names(table(d$group)), table(d$group), sep = "=", collapse = ", ")))

# 2a. BKI kontrolu
d$bmi_hesap <- d$weight / (d$height / 100)^2
bki_fark <- abs(d$bmi_kayitli - d$bmi_hesap)
uyusmaz <- which(!is.na(bki_fark) & bki_fark > 0.5)
ekle("", "BKI KONTROLU (kayitli deger boy ve kilodan hesaplanan ile karsilastirildi)",
     sprintf("  uyusmayan kayit sayisi: %d / %d", length(uyusmaz), sum(!is.na(bki_fark))),
     sprintf("  bu kayitlarin grup dagilimi: %s",
             paste(names(table(d$group[uyusmaz])), table(d$group[uyusmaz]),
                   sep = "=", collapse = ", ")))
if (length(uyusmaz)) {
  ekle("  ayrinti (id, boy, kilo, kayitli BKI, hesaplanan BKI):")
  ekle(capture.output(print(data.frame(
    id = d$id[uyusmaz], boy = d$height[uyusmaz], kilo = d$weight[uyusmaz],
    kayitli = round(d$bmi_kayitli[uyusmaz], 2),
    hesaplanan = round(d$bmi_hesap[uyusmaz], 2)), row.names = FALSE)))
}
ekle(sprintf("  BKI kaynagi olarak '%s' deger kullanildi (BKI_KAYNAK degiskeni).", BKI_KAYNAK))
d$bmi <- if (BKI_KAYNAK == "hesaplanan") d$bmi_hesap else d$bmi_kayitli

# 2b. Toplam SCFA
alti <- rowSums(cbind(d$acetic, d$propionic, d$butyric,
                      d$isobutyric, d$valeric, d$isovaleric), na.rm = TRUE)
uc   <- rowSums(cbind(d$acetic, d$propionic, d$butyric), na.rm = TRUE)
ekle("", "TOPLAM SCFA KONTROLU",
     sprintf("  toplam ile alti asidin toplami arasindaki en buyuk fark: %.4f",
             max(abs(d$total_scfa - alti), na.rm = TRUE)),
     sprintf("  toplam ile uc ana asidin toplami arasindaki en buyuk fark: %.4f",
             max(abs(d$total_scfa - uc), na.rm = TRUE)),
     "  SONUC: toplam SCFA alti asidin toplamidir; tespit limiti altinda",
     "  kalanlar sifir sayilarak eklenmistir, yani minor asitler zaten",
     "  toplamin icindedir.")

# Toplam sutunu bos olup asitleri olculmus kisilerde toplam, laboratuvarin
# kullandigi kuralla (alti asidin toplami, limit alti = 0) tamamlanir.
# Kosul: uc ana asidin hepsi olculmus olmalidir.
tamamla <- is.na(d$total_scfa) &
  !is.na(d$acetic) & !is.na(d$propionic) & !is.na(d$butyric)
if (any(tamamla)) {
  d$total_scfa[tamamla] <- alti[tamamla]
  ekle("  Toplam sutunu bos, asitleri olculmus kayitlar alti asidin toplamiyla",
       sprintf("  tamamlandi: %d kayit (id: %s)", sum(tamamla),
               paste(d$id[tamamla], collapse = ", ")))
}

# 2c. LDL Friedewald
fried <- d$chol - d$hdl - d$tg / 5
fd <- abs(d$ldl - fried)
ekle("", "LDL KONTROLU (Friedewald: kolesterol - HDL - trigliserit/5)",
     sprintf("  karsilastirilabilir kayit: %d, medyan mutlak fark: %.2f mg/dL",
             sum(!is.na(fd)), median(fd, na.rm = TRUE)),
     sprintf("  10 mg/dL'den buyuk sapma: %d kayit", sum(fd > 10, na.rm = TRUE)),
     "  SONUC: LDL olculmemis, Friedewald formulu ile hesaplanmistir.",
     "  Olculen deger ayri sutundadir (direkt LDL).")

# 2d. Tekrar ve aralik
ekle("", "TEKRARLI KAYIT",
     sprintf("  ayni anket numarasi: %d", sum(duplicated(d$id))),
     sprintf("  birebir ayni satir (id haric): %d",
             sum(duplicated(d[, setdiff(names(d), "id")]))))
aralik <- list(age = c(18, 100), height = c(130, 210), weight = c(30, 180),
               glucose = c(50, 400), chol = c(70, 400), hdl = c(15, 120),
               ldl = c(20, 300), tg = c(30, 900))
ekle("", "FIZYOLOJIK ARALIK KONTROLU")
for (v in names(aralik)) {
  x <- d[[v]]; k <- sum(x < aralik[[v]][1] | x > aralik[[v]][2], na.rm = TRUE)
  if (k > 0) ekle(sprintf("  %s: %d deger aralik disi", v, k))
}
ekle("  (listelenmeyen degiskenlerde aralik disi deger yoktur)")

# 2e. Gruba gore doluluk
lab_test <- c("glucose","chol","tg","ldl","hdl","ldl_direct","alt","ast",
              "creat","urea","wbc","hgb","hct","plt","rbc","b12","ferritin","folate","tsh")
lab_test <- lab_test[lab_test %in% names(d)]
dol <- data.frame(Test = lab_test,
  PPD = sapply(lab_test, function(v) sum(!is.na(d[[v]][d$group == "PPD"]))),
  PD  = sapply(lab_test, function(v) sum(!is.na(d[[v]][d$group == "PD"]))),
  C   = sapply(lab_test, function(v) sum(!is.na(d[[v]][d$group == "C"]))))
dol$Not <- ""
n_g <- table(d$group)
dol$Not[dol$PPD / n_g["PPD"] < 0.2 & dol$PD / n_g["PD"] > 0.8] <- "PPD'de yok, PD'de tam"
dol$Not[dol$PD / n_g["PD"] < 0.2 & dol$PPD / n_g["PPD"] > 0.8] <- "PD'de yok, PPD'de tam"
ekle("", "LABORATUVAR TESTLERININ GRUBA GORE DOLULUGU",
     sprintf("  (grup buyuklukleri: PPD=%d, PD=%d, C=%d)", n_g["PPD"], n_g["PD"], n_g["C"]))
ekle(capture.output(print(dol, row.names = FALSE)))
ekle("  Ayni hemogramdan gelen testlerin bir kisminin bir grupta hic",
     "  bulunmamasi teknik bir aktarim sorununa isaret eder.")

# 2f. Kit standart egrisi
# Sinirlar plakaya konan standartlardir: LBP 2.5-40 ng/mL (BT LAB E0360Hu,
# 2.5, 5, 10, 20, 40 ng/mL; ureticinin beyan ettigi olcum araligi 0.2-60),
# FATP5 0.156-10 ng/mL (BioSS BSKH62000).
STANDART <- list(lbp = c(2.5, 40), fatp5 = c(0.156, 10))
ekle("", "OLCUM ARALIGI KONTROLU (plakadaki en dusuk ve en yuksek standart)",
     "  LBP kiti   : 2.5 - 40 ng/mL (ureticinin beyan ettigi aralik 0.2 - 60 ng/mL)",
     "  FATP5 kiti : 0.156 - 10 ng/mL")
for (v in c("lbp", "fatp5")) {
  sn <- STANDART[[v]]
  say <- function(kosul) paste(sapply(GRUP_SIRA, function(g)
    sprintf("%s %d/%d", g, sum(kosul(d[[v]][d$group == g]), na.rm = TRUE),
            sum(!is.na(d[[v]][d$group == g])))), collapse = ", ")
  ekle(sprintf("  %s en yuksek standardin (%g) ustunde: %s", toupper(v), sn[2], say(function(x) x > sn[2])),
       sprintf("  %s en dusuk standardin (%g) altinda : %s", toupper(v), sn[1], say(function(x) x < sn[1])))
}
ekle("  Standart egrisi disindaki degerler dort parametreli egriden",
     "  ekstrapole edilmistir; LBP kiti orneklerin seyreltilmesine izin vermez.")

# ---- 3. Anket kodlamasi ve tespit limiti ---------------------------
d_ham <- d
anket_var <- rowSums(!is.na(d[, ffq_kalem])) > 0
for (v in ffq_kalem) {
  d[[v]][anket_var & is.na(d[[v]])] <- 0
  d[[v]][!anket_var] <- NA
}
ekle("", "ANKET KODLAMASI",
     sprintf("  formu dolduran: %d, formuna erisilemeyen: %d", sum(anket_var), sum(!anket_var)),
     sprintf("  formu olmayanlarin grup dagilimi: %s",
             paste(names(table(d$group[!anket_var])), table(d$group[!anket_var]),
                   sep = "=", collapse = ", ")),
     "  Anket formundaki 'tuketmiyorum' secenegi sifir degeri tasidigi ve",
     "  forma sifir yazilmayip bos birakildigi icin, formu dolduranlarda",
     "  bos kalemler sifir tuketim olarak kodlanmistir.")

# Laboratuvarin bildirdigi tespit limiti: S/N = 3 olcutune karsilik gelen
# derisim, 0.006 mM (15.10.2026 cevabi). Limit altindaki degerlere LOD/2 atanir.
SCFA_LOD <- 0.006
lod_yarisi <- setNames(rep(SCFA_LOD / 2, length(minor_scfa)), minor_scfa)
for (v in minor_scfa) d[[paste0(v, "_lod")]] <- ifelse(is.na(d[[v]]), lod_yarisi[[v]], d[[v]])
ekle("", "TESPIT LIMITI ALTINDAKI SCFA'LAR",
     "  Izobutirik, valerik ve izovalerik asitte cihaz limit altinda",
     "  negatif deger verdigi icin kayit bos birakilmistir. Laboratuvarin",
     sprintf("  bildirdigi LOD (S/N = 3) %.3f mM'dir; limit altindaki degerlere", SCFA_LOD),
     "  LOD/2 atanmistir:")
for (v in minor_scfa)
  ekle(sprintf("    %-12s limit alti %d/%d kayit, en kucuk olculen %.4f, kullanilan deger %.4f",
               v, sum(is.na(d[[v]])), nrow(d), min(d[[v]], na.rm = TRUE), lod_yarisi[[v]]))
if (any(sapply(minor_scfa, function(v) min(d[[v]], na.rm = TRUE)) < SCFA_LOD))
  warning("Bazi minor SCFA olcumleri bildirilen LOD'un altinda; LOD degerini kontrol edin.", call. = FALSE)

# ---- 4. Yardimci fonksiyonlar --------------------------------------
p_bicim <- function(p) if (is.na(p)) "-" else if (p < 0.001) "<0.001" else sprintf("%.3f", p)

dunn_bonf <- function(x, g) {
  g <- droplevels(factor(g, levels = GRUP_SIRA))
  r <- rank(x); n <- length(x)
  mr <- tapply(r, g, mean); ns <- tapply(r, g, length)
  say <- table(x); bag <- sum(say^3 - say) / (12 * (n - 1))
  ciftler <- combn(levels(g), 2); sonuc <- c()
  for (k in seq_len(ncol(ciftler))) {
    a <- ciftler[1, k]; b <- ciftler[2, k]
    se <- sqrt((n * (n + 1) / 12 - bag) * (1 / ns[a] + 1 / ns[b]))
    z <- (mr[a] - mr[b]) / se
    sonuc[paste(a, b, sep = "-")] <- min(2 * (1 - pnorm(abs(z))) * ncol(ciftler), 1)
  }
  sonuc
}

# Dergi uslubuna gore her zaman ortalama +/- ss ile verilecek degiskenler
# (yas ve BKI, testin secimi yine Shapiro-Wilk'e gore yapilir)
ORT_SS_ZORLA <- c("age", "bmi")

karsilastir <- function(var, veri = d) {
  dd <- veri[!is.na(veri[[var]]) & !is.na(veri$group), c("group", var)]
  names(dd)[2] <- "x"
  gr <- split(dd$x, dd$group)
  if (min(sapply(gr, length)) < 3) return(NULL)
  normal <- all(sapply(gr, function(v) length(unique(v)) > 2 &&
                         shapiro.test(v)$p.value > 0.05))
  if (normal) {
    p <- summary(aov(x ~ group, data = dd))[[1]][["Pr(>F)"]][1]
    tk <- TukeyHSD(aov(x ~ group, data = dd))$group
    ph <- setNames(tk[, "p adj"],
      sapply(strsplit(rownames(tk), "-"), function(s) paste(s[2], s[1], sep = "-")))
    tanim <- sapply(gr, function(v) sprintf("%.2f +/- %.2f", mean(v), sd(v)))
    test <- "ANOVA"
  } else {
    p <- kruskal.test(x ~ group, data = dd)$p.value
    ph <- if (p < 0.05) dunn_bonf(dd$x, dd$group) else c()
    tanim <- sapply(gr, function(v)
      sprintf("%.2f (%.2f-%.2f)", median(v), quantile(v, .25), quantile(v, .75)))
    test <- "Kruskal-Wallis"
  }
  if (var %in% ORT_SS_ZORLA) {
    tanim <- sapply(gr, function(v) sprintf("%.1f +/- %.1f", mean(v), sd(v)))
  }
  list(desc = tanim, p = p, posthoc = ph, test = test, n = sapply(gr, length))
}

harf <- function(ph) {
  s <- c(C = "", PD = "", PPD = "")
  al <- function(a, b) {
    if (is.null(ph) || !length(ph)) return(FALSE)
    v <- ph[paste(a, b, sep = "-")]
    if (is.na(v)) v <- ph[paste(b, a, sep = "-")]
    !is.na(v) && v < 0.05
  }
  if (al("PPD", "C"))  s["PPD"] <- paste0(s["PPD"], "a")
  if (al("PD",  "C"))  s["PD"]  <- paste0(s["PD"],  "a")
  if (al("PPD", "PD")) s["PPD"] <- paste0(s["PPD"], "b")
  s
}

satir_yap <- function(var, etiket, veri = d) {
  r <- karsilastir(var, veri)
  if (is.null(r)) return(NULL)
  h <- harf(r$posthoc)
  hucre <- sapply(c("PPD", "PD", "C"), function(g)
    paste0(r$desc[g], if (h[g] != "") paste0(" ", h[g]) else ""))
  data.frame(Degisken = etiket, PPD = hucre["PPD"], PD = hucre["PD"],
             Kontrol = hucre["C"], p = p_bicim(r$p),
             n = sprintf("%d/%d/%d", r$n["PPD"], r$n["PD"], r$n["C"]),
             Test = r$test, stringsAsFactors = FALSE)
}

# Kategori etiketleri ASCII anahtarla eslestirilip Ingilizceye cevrilir.
# Boylece rapor dosyasinda Turkce karakter kodlama sorunu olmaz ve
# tablolar dogrudan makaleye aktarilabilir.
ETIKET <- c(
  "kadn" = "Female",
  "erkek" = "Male",
  "evet" = "Yes",
  "hayr" = "No",
  "evethalaiiyorum" = "Yes",     # "Evet hala iciyorum" (yeni eklenen kayitlar)
  "hayrhiimedim" = "No",         # "Hayir hic icmedim"
  "evetdzenli" = "Yes",          # "Evet duzenli"
  "hiyapmyorum" = "None",        # "Hic yapmiyorum"
  "braktm" = "Former",
  "okiyi" = "Very good",
  "yi" = "Good",
  "orta" = "Moderate",
  "kt" = "Poor",
  "dk" = "Low",
  "yksek" = "High",
  "okyksek" = "Very high",
  "hi" = "None",
  "haftada12gn" = "1-2 days/week",
  "haftada34gn" = "3-4 days/week",
  "haftada5gnhergn" = "5+ days/week",
  "dzenlideil" = "Irregular",
  "sabah" = "Breakfast",
  "le" = "Lunch",
  "akam" = "Dinner")
# Raporda gorunecek sira
ETIKET_SIRA <- c("Male", "Female", "Yes", "Former", "No",
  "Very good", "Good", "Moderate", "Poor",
  "Low", "High", "Very high",
  "None", "1-2 days/week", "3-4 days/week", "5+ days/week",
  "Irregular", "Breakfast", "Lunch", "Dinner")

# Kategorik satir: etiketler VERIDEN okunur, koda gomulmez
kategorik_satir <- function(var, etiket, sira = NULL) {
  x <- d[[var]]
  if (is.numeric(x)) x <- as.character(x)
  cev <- ETIKET[ascii_ad(x)]                 # Ingilizce karsiligi
  x <- ifelse(is.na(cev), ascii_ad(x), cev)  # karsiligi yoksa ASCII hali
  tab <- table(x, d$group)
  if (is.null(sira)) sira <- ETIKET_SIRA
  var_olan <- sira[sira %in% rownames(tab)]
  kalan <- setdiff(rownames(tab), var_olan)
  tab <- tab[c(var_olan, kalan), , drop = FALSE]
  # Beklenen frekansi 5'in altinda hucre varsa Fisher-Freeman-Halton kesin testi
  beklenen <- tryCatch(suppressWarnings(chisq.test(tab)$expected), error = function(e) NULL)
  seyrek <- !is.null(beklenen) && any(beklenen < 5)
  if (seyrek) {
    p <- tryCatch(fisher.test(tab, workspace = 2e8)$p.value, error = function(e) {
      set.seed(TOHUM); fisher.test(tab, simulate.p.value = TRUE, B = 1e5)$p.value })
    test_adi <- "Fisher"
  } else {
    p <- tryCatch(suppressWarnings(chisq.test(tab)$p.value), error = function(e) NA)
    test_adi <- "Ki-kare"
  }
  Ns <- colSums(tab)
  out <- data.frame(Degisken = etiket, PPD = "", PD = "", Kontrol = "",
                    p = p_bicim(p),
                    n = sprintf("%d/%d/%d", Ns["PPD"], Ns["PD"], Ns["C"]),
                    Test = test_adi, stringsAsFactors = FALSE)
  for (i in seq_len(nrow(tab))) {
    out <- rbind(out, data.frame(Degisken = paste0("  ", rownames(tab)[i]),
      PPD = sprintf("%d (%.1f)", tab[i, "PPD"], 100 * tab[i, "PPD"] / Ns["PPD"]),
      PD  = sprintf("%d (%.1f)", tab[i, "PD"],  100 * tab[i, "PD"]  / Ns["PD"]),
      Kontrol = sprintf("%d (%.1f)", tab[i, "C"], 100 * tab[i, "C"] / Ns["C"]),
      p = "", n = "", Test = "", stringsAsFactors = FALSE))
  }
  out
}


# ---- Figur aygiti yardimcisi ----------------------------------------
# bulunan dosyalari acamaz. Bu yuzden figurler once gecici klasore
# yazilir, sonra hedef klasore kopyalanir.
kaydet <- function(g, ad, en, boy) {
  gecici <- GECICI
  for (uz in c("png", "pdf", "eps")) {
    gd <- file.path(gecici, paste0(ad, ".", uz))
    if (file.exists(gd)) file.remove(gd)
    sonuc <- try({
      if (uz == "eps") {
        ggsave(gd, g, width = en, height = boy,
               device = cairo_ps, fallback_resolution = 600)
      } else {
        ggsave(gd, g, width = en, height = boy, dpi = 600, bg = "white")   # MDCP: en az 600 dpi
      }
    }, silent = TRUE)
    if (inherits(sonuc, "try-error") || !file.exists(gd)) {
      if (uz != "eps") warning("Figur uretilemedi: ", ad, ".", uz)
      next
    }
    hedef <- file.path(FIGURLER, paste0(ad, ".", uz))
    if (!file.copy(gd, hedef, overwrite = TRUE))
      warning("Figur hedefe kopyalanamadi: ", hedef)
    file.remove(gd)
  }
}

# Skill kurali: lejantlarda cerceve ve dolgu yok (base R'deki bty = "n" karsiligi)
LEJANT_SADE <- theme(legend.background = element_blank(),
                     legend.key        = element_blank(),
                     legend.box.background = element_blank())
