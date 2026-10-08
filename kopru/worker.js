// Kişisel Hesap — köprü (Cloudflare Worker).
// 1) Kur: Uygulama Telegram sayfasını doğrudan okuyamadığı için (tarayıcı güvenliği) bu köprü,
//    izin verilen açık kanalların son mesajlarını alıp JSON olarak verir.
//    Kullanım: https://<köprü-adresi>/?ch=Borsa_Erbil  →  { channel, posts: [{ at, text }, ...] } (eskiden yeniye)
// 2) Ayağa kalk hatırlatıcısı: iPhone'da uygulama kapalıyken zamanlayıcı çalışmaz, bu yüzden
//    hatırlatmaları köprü her dakika kontrol edip Web Push bildirimi olarak gönderir (/push/...).
//    Bunun için köprüye bir KV deposu (HATIRLATICI) ve dakikalık zamanlayıcı (cron) bağlanır.
// Kurulum adımları: kopru/KURULUM.md

const CHANNELS = ['Borsa_Erbil', 'iqborsa', 'dollar_price', 'dollariraqi'];

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers': 'content-type',
};

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
    const url = new URL(request.url);
    if (url.pathname.startsWith('/push/')) return pushApi(request, env, url.pathname.slice(6));

    const headers = { ...CORS, 'content-type': 'application/json; charset=utf-8', 'cache-control': 'max-age=60' };
    const ch = url.searchParams.get('ch') || CHANNELS[0];
    // Sadece listedeki kanallar: köprü başkalarının açık vekil sunucusu olarak kullanılamasın.
    if (!CHANNELS.includes(ch)) {
      return new Response(JSON.stringify({ error: 'kanal izinli değil' }), { status: 400, headers });
    }
    try {
      const res = await fetch(`https://t.me/s/${ch}`, {
        headers: { 'user-agent': 'Mozilla/5.0' },
        cf: { cacheTtl: 60, cacheEverything: true },
      });
      if (!res.ok) throw new Error(`Telegram ${res.status}`);
      return new Response(JSON.stringify({ channel: ch, posts: parsePosts(await res.text()) }), { headers });
    } catch (e) {
      return new Response(JSON.stringify({ error: String(e.message || e) }), { status: 502, headers });
    }
  },

  // Her dakika (cron "* * * * *"): zamanı gelen hatırlatmaları gönder.
  async scheduled(event, env, ctx) {
    if (env.HATIRLATICI) ctx.waitUntil(tick(env, event.scheduledTime));
  },
};

function parsePosts(html) {
  const posts = [];
  for (const block of html.split('class="tgme_widget_message_wrap').slice(1)) {
    const m = block.match(/<div class="tgme_widget_message_text[^"]*"[^>]*>([\s\S]*?)<\/div>/);
    const t = block.match(/<time[^>]*datetime="([^"]+)"/);
    if (!m || !t) continue;
    const text = m[1]
      .replace(/<br\s*\/?>/g, '\n')
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ').replace(/&quot;/g, '"').replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&')
      .trim();
    if (text) posts.push({ at: t[1], text });
  }
  return posts.slice(-15);
}

/* ---------- ayağa kalk hatırlatıcısı ---------- */

// Abonelikler tek bir KV kaydında durur (ücretsiz planda dakikada bir "liste" çağrısı sınırı aşar, tek okuma aşmaz).
const SUBS = 'aboneler';
const MAX_SUBS = 10;
// Sadece gerçek tarayıcı bildirim servislerine gönderilir; köprü başka adreslere istek atmak için kullanılamasın.
const PUSH_HOST = /^(web\.push\.apple\.com|fcm\.googleapis\.com|updates\.push\.services\.mozilla\.com|[a-z0-9-]+\.notify\.windows\.com)$/;

const MSGS = [
  ['Kalk biraz 🧍', 'Uzun süredir oturuyorsun. Kalk, birkaç adım yürü.'],
  ['Hareket molası 🚶', 'Ayağa kalk, omuzlarını gevşet, biraz dolaş.'],
  ['Belin için kalk', 'Bir bardak su al, iki dakika ayakta kal.'],
  ['Esneme zamanı 🙆', 'Kalk, kollarını yukarı uzat, belini esnet.'],
];

async function pushApi(request, env, action) {
  const json = (o, status = 200) => new Response(JSON.stringify(o), { status, headers: { ...CORS, 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' } });
  if (!env.HATIRLATICI) return json({ error: 'kv-yok' }, 503);
  try {
    if (action === 'anahtar') return json({ key: (await vapid(env, true)).pub });
    if (request.method !== 'POST') return json({ error: 'POST gerekli' }, 405);
    const body = await request.json();
    const endpoint = String(body.endpoint || (body.sub && body.sub.endpoint) || '');
    if (!validEndpoint(endpoint)) return json({ error: 'geçersiz abonelik' }, 400);
    const subs = (await env.HATIRLATICI.get(SUBS, 'json')) || {};

    if (action === 'abone') {
      const s = body.sub;
      if (!s || !s.keys || !/^[\w-]{80,100}$/.test(s.keys.p256dh || '') || !/^[\w-]{16,32}$/.test(s.keys.auth || '')) return json({ error: 'geçersiz abonelik' }, 400);
      const prev = subs[endpoint];
      subs[endpoint] = {
        sub: { endpoint, keys: { p256dh: s.keys.p256dh, auth: s.keys.auth } },
        ayar: cleanAyar(body.ayar),
        origin: /^https:\/\/[\w.-]+(:\d+)?$/.test(body.origin || '') ? body.origin : '',
        at: Date.now(), last: prev ? prev.last : 0,
      };
      // En eski abonelikler atılır (ör. uygulama silinip yeniden kurulduysa kalan eski kayıtlar).
      const keys = Object.keys(subs).sort((a, b) => subs[b].at - subs[a].at);
      for (const k of keys.slice(MAX_SUBS)) delete subs[k];
      await env.HATIRLATICI.put(SUBS, JSON.stringify(subs));
      return json({ ok: true });
    }
    if (action === 'iptal') {
      if (subs[endpoint]) { delete subs[endpoint]; await env.HATIRLATICI.put(SUBS, JSON.stringify(subs)); }
      return json({ ok: true });
    }
    const rec = subs[endpoint];
    if (action === 'durum') return json({ kayitli: !!rec, last: rec ? rec.last : 0 });
    if (action === 'test') {
      if (!rec) return json({ error: 'abonelik bulunamadı' }, 404);
      const status = await send(await vapid(env), rec, { title: 'Deneme 🧍', body: 'Bildirimler çalışıyor. Zamanı gelince böyle hatırlatacağım.' });
      return json({ ok: status >= 200 && status < 300, status }, status >= 200 && status < 300 ? 200 : 502);
    }
    return json({ error: 'bilinmeyen işlem' }, 404);
  } catch (e) {
    return json({ error: String(e.message || e) }, 500);
  }
}

function validEndpoint(u) {
  try { const x = new URL(u); return x.protocol === 'https:' && PUSH_HOST.test(x.hostname) && u.length < 1024; } catch (e) { return false; }
}
const hm = s => { const m = /^(\d\d):(\d\d)$/.exec(s || ''); return m && +m[1] < 24 && +m[2] < 60 ? +m[1] * 60 + +m[2] : null; };
function cleanAyar(a) {
  a = a || {};
  const every = Math.round(+a.every);
  return {
    on: !!a.on,
    every: every >= 5 && every <= 240 ? every : 20,
    start: hm(a.start) === null ? '09:00' : a.start,
    end: hm(a.end) === null ? '22:00' : a.end,
    days: Array.isArray(a.days) ? [...new Set(a.days.map(Number).filter(d => d >= 0 && d <= 6 && Number.isInteger(d)))] : [0, 1, 2, 3, 4, 5, 6],
    tz: Number.isInteger(a.tz) && Math.abs(a.tz) <= 840 ? a.tz : -180,
    pause: +a.pause > 0 ? +a.pause : 0,
  };
}

/* Uygulamadaki due() ile aynı kural: çalışma saatleri içinde, başlangıçtan itibaren her "every" dakikada bir.
   Başlangıç anının kendisinde hatırlatma yok (09:00'da başlıyorsa ilki 09:20). Gece yarısını aşan aralık da olur (22:00–02:00). */
function due(a, ts) {
  if (!a.on || ts < a.pause) return false;
  const local = new Date(ts - a.tz * 60e3);
  const m = local.getUTCHours() * 60 + local.getUTCMinutes();
  const s = hm(a.start), e = hm(a.end);
  const span = ((e - s + 1440) % 1440) || 1440, off = (m - s + 1440) % 1440;
  if (off === 0 || off > span || off % a.every) return false;
  // Gün, aralığın başladığı gündür (gece yarısını geçen aralıkta da).
  const day = new Date(ts - a.tz * 60e3 - off * 60e3).getUTCDay();
  return a.days.includes(day);
}

async function tick(env, now) {
  const subs = await env.HATIRLATICI.get(SUBS, 'json');
  if (!subs) return;
  const list = Object.values(subs).filter(r => due(r.ayar, now));
  if (!list.length) return;
  const v = await vapid(env);
  if (!v) return;
  const [title, body] = MSGS[Math.floor(now / 60e3) % MSGS.length];
  let changed = false;
  await Promise.all(list.map(async r => {
    try {
      const st = await send(v, r, { title, body });
      // 404/410: abonelik artık geçersiz (uygulama silindi veya izin kapatıldı).
      if (st === 404 || st === 410) { delete subs[r.sub.endpoint]; changed = true; }
      else if (st >= 200 && st < 300) { r.last = now; changed = true; }
    } catch (e) {}
  }));
  if (changed) await env.HATIRLATICI.put(SUBS, JSON.stringify(subs));
}

/* ---------- Web Push (RFC 8291 şifreleme + RFC 8292 VAPID) ---------- */

const te = new TextEncoder();
const b64u = buf => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const unb64u = s => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((s.length + 3) % 4)), c => c.charCodeAt(0));
const concat = (...parts) => {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let i = 0; for (const p of parts) { out.set(p, i); i += p.length; }
  return out;
};
async function hmac(key, data) {
  const k = await crypto.subtle.importKey('raw', key, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return new Uint8Array(await crypto.subtle.sign('HMAC', k, data));
}

// Köprünün kendi bildirim anahtarı: ilk istekte üretilip KV'de saklanır, elle anahtar girmeye gerek kalmaz.
// Sadece uygulamanın "anahtar" isteği üretir; zamanlayıcı bulamazsa göndermez (yanlışlıkla anahtar değişmesin).
async function vapid(env, create) {
  let v = await env.HATIRLATICI.get('vapid', 'json');
  if (!v && create) {
    const k = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
    v = { jwk: await crypto.subtle.exportKey('jwk', k.privateKey), pub: b64u(await crypto.subtle.exportKey('raw', k.publicKey)) };
    await env.HATIRLATICI.put('vapid', JSON.stringify(v));
  }
  return v;
}

async function vapidHeader(v, endpoint, subject) {
  const h = b64u(te.encode(JSON.stringify({ typ: 'JWT', alg: 'ES256' })));
  const c = b64u(te.encode(JSON.stringify({ aud: new URL(endpoint).origin, exp: Math.floor(Date.now() / 1000) + 12 * 3600, sub: subject })));
  const key = await crypto.subtle.importKey('jwk', v.jwk, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, te.encode(`${h}.${c}`));
  return `vapid t=${h}.${c}.${b64u(sig)}, k=${v.pub}`;
}

async function encrypt(sub, text) {
  const uaPub = unb64u(sub.keys.p256dh), auth = unb64u(sub.keys.auth);
  const local = await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']);
  const asPub = new Uint8Array(await crypto.subtle.exportKey('raw', local.publicKey));
  const uaKey = await crypto.subtle.importKey('raw', uaPub, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const secret = new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: uaKey }, local.privateKey, 256));
  const ikm = await hmac(await hmac(auth, secret), concat(te.encode('WebPush: info\0'), uaPub, asPub, [1]));
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const prk = await hmac(salt, ikm);
  const cek = (await hmac(prk, concat(te.encode('Content-Encoding: aes128gcm\0'), [1]))).slice(0, 16);
  const nonce = (await hmac(prk, concat(te.encode('Content-Encoding: nonce\0'), [1]))).slice(0, 12);
  const key = await crypto.subtle.importKey('raw', cek, 'AES-GCM', false, ['encrypt']);
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce }, key, concat(te.encode(text), [2])));
  const head = new Uint8Array(21);
  head.set(salt); new DataView(head.buffer).setUint32(16, 4096); head[20] = 65;
  return concat(head, asPub, ct);
}

async function send(v, rec, msg) {
  const res = await fetch(rec.sub.endpoint, {
    method: 'POST',
    headers: {
      authorization: await vapidHeader(v, rec.sub.endpoint, rec.origin || 'mailto:kalk@example.com'),
      'content-encoding': 'aes128gcm',
      'content-type': 'application/octet-stream',
      ttl: '600', // 10 dk içinde ulaşamazsa gönderme; eski hatırlatma sonradan gelmesin
      urgency: 'high',
      topic: 'kalk', // telefona henüz ulaşmamış önceki hatırlatmanın yerine geçer
    },
    body: await encrypt(rec.sub, JSON.stringify(msg)),
  });
  return res.status;
}
