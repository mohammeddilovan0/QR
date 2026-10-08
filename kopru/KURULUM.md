# Kur köprüsü kurulumu (Cloudflare, ücretsiz)

Bu köprü, Kur sekmesindeki **Canlı: Borsa Erbil** kısmının Telegram kanalının son mesajını okuyabilmesi için gerekir. Bir kez kurulur.

1. https://dash.cloudflare.com/sign-up adresinden ücretsiz hesap aç (e-posta + şifre yeterli).
2. Sol menüden **Workers & Pages** → **Create** → **Create Worker** (Hello World) → isim olarak `kur` yaz → **Deploy**.
3. Açılan sayfada **Edit code**'a bas. Soldaki `worker.js` dosyasının içeriğini tamamen sil, bu klasördeki [`worker.js`](worker.js) dosyasının içeriğini yapıştır → sağ üstten **Deploy**.
4. Üstte görünen adresi kopyala (ör. `https://kur.KULLANICIADIN.workers.dev`). Tarayıcıda sonuna `?ch=Borsa_Erbil` ekleyip açarsan son mesajları görürsün.
5. Uygulamada **Kur** sekmesi → **Canlı: Borsa Erbil** → adresi yapıştır → **Bağla**.

Ücretsiz plan günde 100.000 isteğe kadar yeter; kişisel kullanım bunun çok altında kalır.

## Ayağa kalk hatırlatıcısı

Uygulama açıkken hatırlatıcı köprüsüz çalışır. iPhone'da uygulama **kapalıyken** de bildirim gelmesi için köprünün hatırlatmaları göndermesi gerekir. Köprü zaten kuruluysa 3 adım:

1. **Kodu güncelle:** Cloudflare'de `kur` worker'ını aç → **Edit code** → içeriği silip bu klasördeki yeni [`worker.js`](worker.js)'i yapıştır → **Deploy**.
2. **Depo ekle:** Sol menü **Storage & Databases → KV** → **Create** → isim `HATIRLATICI` → **Add**. Sonra `kur` worker'ı → **Settings → Bindings → Add → KV namespace** → *Variable name* `HATIRLATICI`, namespace olarak az önce açtığını seç → **Deploy/Save**.
3. **Zamanlayıcı ekle:** `kur` worker'ı → **Settings → Trigger Events** (veya *Triggers*) → **Add → Cron Triggers** → *Every minute* (`* * * * *`) → **Add/Save**.

Sonra uygulamada **Daha fazla → Ayağa kalk** → **Bildirimleri aç** → **Deneme bildirimi gönder**. Deneme geliyor ama zamanı gelen hatırlatmalar gelmiyorsa 3. adım (zamanlayıcı) eksiktir.

Notlar: Bildirim yalnızca ana ekrana eklenmiş uygulamada çalışır (iOS 16.4+). Kapalıyken iPhone kendi bildirim sesini çalar; seçtiğin ses uygulama açıkken çalar. Ücretsiz plan yeter.
