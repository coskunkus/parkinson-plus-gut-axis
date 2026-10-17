# =====================================================================
# publish_github.R
# Yalnizca kodu GitHub deposuna gonderir. Veri, rapor ve figurler
# gonderilmez; .gitignore bunlari zaten disarida tutar.
#
# Kullanim
#   Proje kokunde calistirin:
#       Rscript code/publish_github.R
#   Depo adresi asagida tanimlidir. Baska bir depoya gondermek icin
#   DEPO_URL degiskenini degistirin ya da adresi arguman olarak verin:
#       Rscript code/publish_github.R https://github.com/kullanici/depo.git
#
#   Depo GitHub'da README ile acildiysa betik once uzak kayitlari alip
#   uzerine bindirir, elle bir sey yapmaniz gerekmez.
#
# Kimlik dogrulama git'in kendi ayarlarindan gelir. Bu betik parola ya
# da token saklamaz.
# =====================================================================

DEPO_URL <- "https://github.com/coskunkus/parkinson-plus-gut-axis.git"
DAL      <- "main"
MESAJ    <- sprintf("Analiz kodu guncellendi (%s)", format(Sys.Date()))

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
setwd(kok)

if (Sys.which("git") == "") stop("git bulunamadi. Once git kurun.")

calistir <- function(..., sessiz = FALSE) {
  komut <- paste(...)
  if (!sessiz) cat(">", komut, "\n")
  kod <- system(komut)
  if (kod != 0) stop("Komut basarisiz: ", komut)
}

# Adres sirasi: degisken, komut satiri argumani, mevcut origin
arg <- commandArgs(trailingOnly = TRUE)
if (DEPO_URL == "" && length(arg) >= 1) DEPO_URL <- arg[1]
if (DEPO_URL == "" && dir.exists(".git")) {
  mevcut <- suppressWarnings(system("git remote get-url origin",
                                    intern = TRUE, ignore.stderr = TRUE))
  if (length(mevcut) == 1 && nzchar(mevcut)) DEPO_URL <- mevcut
}

# Adres yoksa hicbir sey yapilmaz. Yarim kalmis bir depo birakmamak icin
# bu kontrol git init'ten ONCE gelir.
if (DEPO_URL == "") {
  stop("Depo adresi yok.\n",
       "  1. GitHub'da bos bir depo acin.\n",
       "  2. Adresini bu betigin basindaki DEPO_URL degiskenine yazin,\n",
       "     ya da betigi adresle calistirin:\n",
       "       Rscript code/publish_github.R https://github.com/kullanici/depo.git")
}

if (!dir.exists(".git")) {
  calistir("git init")
  calistir("git branch -M", DAL)
}

# Uzak adres yoksa ekle, farkliysa guncelle
mevcut <- suppressWarnings(system("git remote get-url origin",
                                  intern = TRUE, ignore.stderr = TRUE))
if (!length(mevcut) || !nzchar(mevcut[1])) {
  calistir("git remote add origin", shQuote(DEPO_URL))
} else if (mevcut[1] != DEPO_URL) {
  calistir("git remote set-url origin", shQuote(DEPO_URL))
}

# Yalnizca kod ve aciklama dosyalari eklenir
dosyalar <- c("code/core_gutaxis.R", "code/run_all.R",
              "code/makale_tablolari.R", "code/makale_tablolari.py",
              "code/check_results.R", "code/check_results.py",
              "code/publish_github.R", "README.md", ".gitignore")
dosyalar <- dosyalar[file.exists(dosyalar)]
if (!length(dosyalar)) stop("Gonderilecek kod dosyasi bulunamadi.")
calistir("git add", paste(shQuote(dosyalar), collapse = " "))

# Gonderilecek dosyalari ekrana yaz, veri sizmadigindan emin olmak icin
cat("\nGonderilecek dosyalar:\n")
print(system("git diff --cached --name-only", intern = TRUE))

durum <- system("git diff --cached --quiet", ignore.stdout = TRUE)
if (durum == 0) {
  cat("\nDegisiklik yok, yeni bir kayit olusturulmadi.\n")
} else {
  calistir("git commit -m", shQuote(MESAJ))
}

# Depo GitHub'da README ya da lisans ile acildiysa uzak dalda bizde
# olmayan kayitlar bulunur ve dogrudan gonderim reddedilir. Once o
# kayitlari alip uzerine bindiriyoruz.
uzak <- suppressWarnings(system(paste("git ls-remote --heads origin", DAL),
                                intern = TRUE, ignore.stderr = TRUE))
if (length(uzak) && nzchar(uzak[1])) {
  cat("\nUzak dalda mevcut kayitlar var, once birlestiriliyor.\n")
  kod <- system(paste("git pull --rebase origin", DAL))
  if (kod != 0)
    stop("Birlestirme basarisiz. Cakisan dosyalari elle cozup tekrar deneyin.")
}

calistir("git push -u origin", DAL)
cat("\nKod gonderildi:", DEPO_URL, "\n")
cat("Veri, rapor ve figurler gonderilmedi.\n")
