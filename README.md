# Kişisel Hesap

Gelir-gider, borç/alacak, kur, altın ve yatırım takibi için Türkçe arayüzlü kişisel bütçe uygulaması. Tarayıcıda çalışan tek dosyalık bir web uygulaması (PWA) ve onun [Capacitor](https://capacitorjs.com) ile hazırlanmış iPhone sürümünden oluşur. Irak dinarı (IQD) ve ABD doları (USD) ile çalışır.

*English: A Turkish-language personal finance app (a single-file PWA plus an iPhone build made with Capacitor) for tracking income, expenses, debts, exchange rates, gold and investments in Iraqi dinar and US dollar.*

## Özellikler

- **Özet:** Net servet (hesaplar + alacaklar − borçlar + yatırımlar), hesap bakiyeleri, kategorilere göre harcama ve dönemlere göre harcama grafiği.
- **İşlemler:** Gelir, harcama ve hesaplar arası transfer kaydı; tarih ve saat, kategori ve alt kategori, filtreleme, toplu seçimle kategori değiştirme.
- **Hesaplar ve kategoriler:** Dinar ve dolar hesapları, alt hesaplar, basılı tutup sürükleyerek sıralama.
- **Borç / Alacak:** Kişi bazında borç ve alacaklar, ödeme ve tahsilat kayıtları.
- **Piyasa**
  - **Kur:** Irak serbest piyasa dolar kuru. Köprü bağlıysa Borsa Erbil Telegram kanalından her dakika (Erbil, Bağdat, Basra); bağlı değilse [HusseinKh90/Iraq-parallel-exchange-rate](https://github.com/HusseinKh90/Iraq-parallel-exchange-rate) verisinden günlük.
  - **Altın:** Ons fiyatı ([gold-api.com](https://gold-api.com); canlı akış Binance PAXG/USDT), 24, 22, 21 ve 18 ayar gram ve miskal (5 gr) fiyatları, dinar karşılığı.
  - **Yatırım:** Kripto, altın ve hisse alış/satış kayıtları; ortalama maliyet ve kâr/zarar. İsteğe bağlı olarak salt okunur (Read) bir OKX API anahtarıyla OKX hesabındaki Funding, Trading ve Earn bakiyeleri canlı gösterilir.
- **Daha fazla:** Hatırlatıcılar (fatura, ödeme, randevu…), birikim hedefleri, ayağa kalk hatırlatıcısı, silinenler (geri alma) ve ayarlar.
- **Yedekleme:** Ayarlar'dan JSON yedek dosyası alınır ve geri yüklenir. iPhone uygulaması, iCloud Drive'da seçilen bir klasöre her değişiklikte kendiliğinden yedek alabilir.
- **iPhone widget'ları:** "Hesap" (bakiye, bu ay harcanan, SideStore imza süresi) ve "Uygulama süresi".
- **Çevrimdışı çalışma:** Service worker (`sw.js`) uygulama dosyalarını saklar; internet yokken de açılır.

## Veriler nerede?

İşlemler, hesaplar, borçlar ve diğer kayıtlar yalnızca cihazda, tarayıcının yerel deposunda (`localStorage`) saklanır; bir sunucuya gönderilmez. Uygulama yalnızca şu bağlantıları kurar:

| Ne için | Nereye |
|---|---|
| Günlük kur | `raw.githubusercontent.com` (HusseinKh90/Iraq-parallel-exchange-rate) |
| Canlı kur | Köprü (aşağıda) |
| Web'de ayağa kalk bildirimleri | Köprü; bildirim aboneliği ve hatırlatma saatleri köprünün deposunda tutulur |
| Altın fiyatı | `api.gold-api.com`, Binance |
| Kripto fiyatları | OKX, Binance |
| OKX hesabı (bağlanırsa) | OKX; API anahtarı yalnızca cihazda saklanır, yedeğe girmez |

Varsayılan köprü adresi proje sahibinin kendi Cloudflare Worker'ıdır (`https://kur.mohammeddilovan0.workers.dev`). Kendi köprünüzü kurmak için: [kopru/KURULUM.md](kopru/KURULUM.md).

## Çalıştırma

### Web uygulaması

Derleme adımı ve bağımlılık yoktur; uygulamanın tamamı (HTML, CSS, JavaScript) `index.html` dosyasındadır. Repo kökünü herhangi bir statik sunucuyla sunmak yeterlidir:

```sh
git clone https://github.com/mohammeddilovan0/QR.git
cd QR
python3 -m http.server 8000
```

Ardından tarayıcıda `http://localhost:8000` adresini açın. Service worker (çevrimdışı önbellek) yalnızca `https://` ya da `localhost` üzerinden çalışır. HTTPS üzerinden yayınlanan sürüm, telefonda ana ekrana eklenerek uygulama gibi kullanılabilir.

### iPhone uygulaması

- **Hazır dosya:** `.github/workflows/ios.yml`, `main` dalına her gönderimde imzasız bir `.ipa` derler ve [`ios` sürümüne](https://github.com/mohammeddilovan0/QR/releases/tag/ios) `KisiselHesap.ipa` olarak koyar. Dosya [SideStore](https://docs.sidestore.io) ile kurulur.
- **Xcode ile:** `ios-app/ios/App/App.xcodeproj` açılır, **Signing & Capabilities → Team** seçilir, iPhone seçilip **Run** denir.
- **Web değişikliklerini iOS kopyasına almak** (Node gerekir):

  ```sh
  cd ios-app && npm install && npm run sync
  ```

Ayrıntılar ve verileri eski uygulamadan taşıma: [ios-app/README.md](ios-app/README.md).

### Köprü (isteğe bağlı)

`kopru/worker.js`, ücretsiz planda çalışan bir Cloudflare Worker'dır. İki işi vardır: izin verilen açık Telegram kanallarının son mesajlarını JSON olarak vermek (canlı kur) ve web sürümünde uygulama kapalıyken ayağa kalk hatırlatmalarını Web Push bildirimi olarak göndermek. Kurulum adımları: [kopru/KURULUM.md](kopru/KURULUM.md).

## Klasör yapısı

```text
.
├── index.html             # Web uygulamasının tamamı (HTML, CSS ve JavaScript tek dosyada)
├── sw.js                  # Service worker: dosyaları saklar, çevrimdışı açılmayı sağlar
├── manifest.webmanifest   # PWA bilgileri (ad, simgeler, renkler)
├── icon-180.png, icon-192.png, icon-512.png   # Uygulama simgeleri
├── ios-app/               # iPhone uygulaması (Capacitor)
│   ├── ios/App/           # Xcode projesi, widget (ImzaWidget) ve yerel Swift kodu
│   ├── ios/plugins/       # Yerel eklentiler: KisiselImza (imza süresi, yedek klasörü) ve CapacitorLocalNotifications (bildirimler)
│   ├── scripts/           # www.cjs, sync.cjs, sounds.cjs yardımcı betikleri
│   └── README.md          # Kurulum ve geliştirici notları
├── kopru/                 # Cloudflare Worker köprüsü
│   ├── worker.js
│   └── KURULUM.md         # Kurulum rehberi
├── .github/
│   ├── workflows/ios.yml  # iPhone .ipa derlemesi (GitHub Actions)
│   └── ISSUE_TEMPLATE/    # Hata bildirimi ve özellik isteği şablonları
├── CONTRIBUTING.md        # Katkı rehberi
└── LICENSE                # MIT lisansı
```

## Katkı

Hata bildirimi, öneri ve pull request'ler için: [CONTRIBUTING.md](CONTRIBUTING.md).

## Lisans

[MIT](LICENSE) © 2025 mohammeddilovan0

`ios-app/ios/plugins/CapacitorLocalNotifications/` klasörü Ionic'in [@capacitor/local-notifications](https://github.com/ionic-team/capacitor-plugins) eklentisinden alınmıştır ve kendi MIT lisansıyla (aynı klasördeki `LICENSE`) gelir.
