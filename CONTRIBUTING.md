# Katkı rehberi

Kişisel Hesap'a katkı vermek istediğiniz için teşekkürler. Hata bildirimleri, öneriler ve pull request'ler memnuniyetle karşılanır.

## Projeyi yerelde çalıştırma

Web uygulaması derleme ya da kurulum gerektirmez; her şey `index.html` dosyasındadır.

```sh
git clone https://github.com/mohammeddilovan0/QR.git
cd QR
python3 -m http.server 8000
```

Tarayıcıda `http://localhost:8000` adresini açın; değişiklikten sonra sayfayı yenilemek yeterlidir. Veriler tarayıcının bu adres için ayırdığı yerel depoda tutulur, yani denemeleriniz telefonunuzdaki verileri etkilemez.

**iPhone uygulaması** (`ios-app/`):

- Mac'te Node ve Xcode ile: `cd ios-app && npm install && npm run sync`, ardından `ios-app/ios/App/App.xcodeproj` dosyasını Xcode'da açıp çalıştırın. Ayrıntılar: [ios-app/README.md](ios-app/README.md).
- `index.html`'i değiştirdiyseniz, Xcode ile doğrudan derlenebilmesi için `ios-app/ios/App/App/public/index.html` kopyasını da güncelleyin (`npm run sync` ya da dosyayı kopyalayarak). GitHub derlemesi bu kopyalamayı zaten kendisi yapar.
- Mac'iniz yoksa: `index.html` ya da `ios-app/` değişen pull request'lerde GitHub Actions iOS derlemesini çalıştırır; `.ipa` dosyası iş akışının çıktısı (`KisiselHesap-ipa`) olarak indirilebilir. Herkese açık indirme bağlantısı yalnızca `main`'e birleşince güncellenir.

**Köprü** (`kopru/worker.js`): Değişiklikleri kendi Cloudflare hesabınızda deneyin; kurulum için [kopru/KURULUM.md](kopru/KURULUM.md).

## Hata bildirme ve öneri (issue)

1. Önce açık issue'lara bakın; aynısı varsa yeni issue açmak yerine oraya yorum ekleyin.
2. **New issue** deyip **Hata bildirimi** ya da **Özellik isteği** şablonunu seçin.
3. Hata bildiriminde uygulamayı nerede kullandığınızı (iPhone uygulaması, ana ekrana eklenmiş web uygulaması ya da tarayıcı), hatayı tekrarlama adımlarını ve ne beklediğinizi yazın; varsa ekran görüntüsü ekleyin.

**Gizlilik:** Bu bir kişisel finans uygulaması. API anahtarı, yedek dosyası, gerçek bakiye ya da kişi adı paylaşmayın; ekran görüntülerinde bu bilgileri kapatın.

## Pull request gönderme

1. Repoyu fork'layın ve `main`'den yeni bir dal açın.
2. Değişikliği küçük ve tek bir konuya odaklı tutun.
3. Tarayıcıda deneyin; arayüz değişikliklerini telefon genişliğinde, açık ve koyu temada da kontrol edin.
4. Arayüz metinleri Türkçedir; yeni metinleri de Türkçe yazın.
5. Pull request açıklamasında neyi neden değiştirdiğinizi ve nasıl denediğinizi yazın; arayüz değişikliklerine ekran görüntüsü ekleyin. İlgili bir issue varsa bağlantısını verin.

Gönderdiğiniz katkılar projenin [MIT lisansı](LICENSE) altında yayımlanır.
