# Kur köprüsü kurulumu (Cloudflare, ücretsiz)

Bu köprü, Kur sekmesindeki **Canlı: Borsa Erbil** kısmının Telegram kanalının son mesajını okuyabilmesi için gerekir. Bir kez kurulur.

1. https://dash.cloudflare.com/sign-up adresinden ücretsiz hesap aç (e-posta + şifre yeterli).
2. Sol menüden **Workers & Pages** → **Create** → **Create Worker** (Hello World) → isim olarak `kur` yaz → **Deploy**.
3. Açılan sayfada **Edit code**'a bas. Soldaki `worker.js` dosyasının içeriğini tamamen sil, bu klasördeki [`worker.js`](worker.js) dosyasının içeriğini yapıştır → sağ üstten **Deploy**.
4. Üstte görünen adresi kopyala (ör. `https://kur.KULLANICIADIN.workers.dev`). Tarayıcıda sonuna `?ch=Borsa_Erbil` ekleyip açarsan son mesajları görürsün.
5. Uygulamada **Kur** sekmesi → **Canlı: Borsa Erbil** → adresi yapıştır → **Bağla**.

Ücretsiz plan günde 100.000 isteğe kadar yeter; kişisel kullanım bunun çok altında kalır.
