// Uygulama dosyalarını telefonda saklar ki internet yokken de açılsın.
// İnternet varsa önce yeni sürümü dener (güncellemeler kendiliğinden gelir), yoksa saklananı açar.
// Not: Verileriniz (işlemler, hesaplar) burada değil, uygulamanın kendi deposunda durur.
const CACHE = 'kisisel-hesap-v24';
const FILES = ['./', './index.html', './manifest.webmanifest', './icon-180.png', './icon-192.png', './icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET' || new URL(e.request.url).origin !== location.origin) return;
  // cache: 'no-cache' → tarayıcının kendi HTTP önbelleği (GitHub Pages ~10 dk tutar) atlanır,
  // böylece yeni sürüm uygulama açılır açılmaz gelir.
  e.respondWith(
    fetch(e.request, { cache: 'no-cache' })
      .then(res => {
        if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); }
        return res;
      })
      .catch(() => caches.match(e.request, { ignoreSearch: true }).then(r => r || caches.match('./index.html')))
  );
});

// Ayağa kalk hatırlatıcısı: köprüden gelen bildirimi göster (uygulama kapalıyken de).
self.addEventListener('push', e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) {}
  e.waitUntil(self.registration.showNotification(d.title || 'Kalk biraz 🧍', {
    body: d.body || 'Uzun süredir oturuyorsun. Kalk, birkaç adım yürü.',
    tag: 'kalk', renotify: true, icon: 'icon-192.png', badge: 'icon-192.png',
  }));
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true })
    .then(cs => cs.length ? cs[0].focus() : self.clients.openWindow('./')));
});
