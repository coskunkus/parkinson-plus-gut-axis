# Parkinson Plus bagirsak-beyin ekseni calismasi: analiz kodu

Bu depo, klasik Parkinson hastaligi, Parkinson Plus sendromlari ve saglikli
kontrollerde serum lipopolisakkarit baglayici proteini (LBP), FATP5, diski
kisa zincirli yag asitleri ve besin tuketimini karsilastiran calismanin
analiz kodunu icerir.

**Veri depoda yer almaz.** Calisma hasta verisiyle yurutulmustur; veri dosyasi
yalnizca sorumlu yazardan makul talep uzerine saglanir. Depoda sadece kod
bulunur.

## Klasor duzeni

    code/       R ve Python betikleri
    data/       veri dosyasi buraya konur (depoya girmez)
    output/     makale kaynaklari ve derlenmis pdf
    results/    betiklerin yazdigi txt raporlar (calistirinca olusur)
    figures/    figurler, her biri eps, pdf ve png (calistirinca olusur)

## Betikler

`code/core_gutaxis.R` ortak cekirdek. Veri okuma, sutun eslestirme, veri
kalite denetimi, anket kodlamasi, tespit limiti islemleri, grup karsilastirma
ve Firth model fonksiyonlari burada. Tek basina cikti uretmez; diger betikler
bu dosyayi source eder, boylece tek bir uygulama olur.

`code/run_all.R` makaledeki her sey. Tablo 1-2 ve Tablo S1-S5'in sayilari, korelasyonlar, Firth
cezali lojistik regresyon, bes katli capraz dogrulama (tek on tanimli bolme
ve 200 rastgele bolmeyle tekrarli CV), anket kodlamasi duyarlilik analizi,
LBP'siz PPD modelleri (Tablo S1, C bolumu) ve dort figur. Birkac dakikada biter. Figur adlari
makaledeki numaralari izler: `Figure1_biomarkers`, `Figure2_correlations`,
`Figure3_roc` ve ek dosyadaki `FigureS1_diet_heatmap`. Monte Carlo
calismasi olmadigi icin ayri bir simulasyon kosucusu yoktur.

`code/makale_tablolari.R` makaledeki butun tablolari (`tablo1`, `tablo2`,
`tabloS1`-`tabloS5`, numaralar makaledekiyle ayni) `results/*.tsv`
dosyalarindan uretip `makale/tablolar/` klasorune yazar. Bu klasor deponun
yaninda (`../makale`) ya da bir ust duzeyde (`../../makale`) aranir.
`code/makale_tablolari.py` ayni ciktiyi Python ile uretir. Hesap yapmaz, yalnizca bicim cevirir
(Ingilizce etiketler, dergi bicimi). `run_all.R` bunu en sonda kendisi
calistirir, ayrica bir sey calistirmak gerekmez. Makale klasoru yoksa adim
atlanir.

`code/check_results.R` bagimsiz dogrulama, R tarafi. Veri ici tutarliligi
denetler (toplam SCFA alti asidin toplami mi, BKI boy ve kilodan cikiyor mu,
LDL Friedewald ile uyusuyor mu, anket bosluk kurali dogru uygulanmis mi) ve
ana istatistikleri cekirdegin fonksiyonlarini kullanmadan yalnizca base R ile
yeniden hesaplar.

`code/check_results.py` ayni istatistikleri ham veriden Python ile bastan
hesaplar ve R sonuclariyla karsilastirir. Iki bagimsiz uygulama ayni sayiyi
vermezse kontrol FAIL doner. Amac, koda gecerken yapilan bir hatanin iki dilde
birden hayatta kalmamasidir.

`code/publish_github.R` yalnizca kodu depoya gonderir.

## Calistirma

Veri dosyasini `data/data.xlsx` olarak koyun, sonra proje kokunden:

    Rscript code/run_all.R
    Rscript code/check_results.R
    python  code/check_results.py

Betikler `results/` ve `figures/` klasorlerini yoksa olusturur. Her betik
kendi txt raporunu yazar:

    results/run_all_report.txt
    results/check_results_report.txt
    results/check_results_py_report.txt

`run_all.R` raporu iki kez yazar: `results/run_all_report.txt` ve tarihli
kopyasi `results/run_all_report_YYYY-MM-DD.txt`. Makale her zaman en yeni
tarihli rapordan guncellenir.

### Veri dosyasi

Analizde kullanilan dosya `data.xlsx` (98 katilimci: 32 PPD, 33 PD, 33
kontrol; 16 Ekim 2026). LBP uc grupta ayni partide, ayni kit lotuyla ve cift
kuyucukta, FATP5 tek kuyucukta olculmustur. LDL Friedewald formulu ile
hesaplanmistir; iki kayitta formulle uyusmayan deger formule gore
duzeltilmistir.

30, 31 ve 32 numarali hastalarda toplam SCFA sutunu bos birakilmistir; kod bu
kayitlarda toplami, laboratuvarin kullandigi kuralla (alti asidin toplami,
limit alti sifir) tamamlar ve bunu raporun A bolumune yazar.

**Kimlik bilgisi.** Laboratuvardan gelen dosyalar hasta ad-soyad sutunu
icerir. Kod bu sutunu okur okumaz dusurur ve ekrana uyari yazar; yine de
veri dosyasi hicbir kosulda depoya konmamalidir.

## Tekrarlanabilirlik

Ana tohum kodun basinda `TOHUM` degiskeninde tanimlidir. Capraz dogrulama
katlari bu tohumdan turetilen kendi tohumlariyla atanir, boylece kodun baska
bir yerine rastgelelik eklense bile katlar degismez. Kat ici olceklendirmede
ortalama ve standart sapma yalnizca egitim verisinden hesaplanir.

`run_all_report.txt` dosyasinin sonundaki REPRODUCIBILITY bolumu, kullanilan
veri dosyasinin adini, boyutunu ve tarihini, satir ve sutun sayisini, grup
buyukluklerini, tohumu ve `sessionInfo()` ciktisini kaydeder. Ayni dosya, ayni
tohum ve ayni paket surumleriyle butun sayilar birebir tekrar uretilir.

Figurlerdeki tum metin Ingilizcedir. Rapor metni Turkcedir.

Gerekli paketler: readxl, ggplot2, patchwork, logistf, pROC. Python tarafi icin
pandas, numpy ve scipy.

## Not

Kod, veri dosyasindaki sutun adlarini Turkce karakterlerden arindirip
eslestirir, bu yuzden dosyanin karakter kodlamasi sonucu etkilemez. Windows'ta
R'in zip okuyucusu ve grafik aygitlari, yolunda apostrof veya Turkce karakter
bulunan dosyalari acamaz; kod bu yuzden veriyi once ASCII yollu gecici bir
klasore kopyalar ve figurleri once orada uretip sonra hedefe tasir.
