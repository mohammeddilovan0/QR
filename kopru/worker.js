// Kişisel Hesap — kur köprüsü (Cloudflare Worker).
// Uygulama Telegram sayfasını doğrudan okuyamadığı için (tarayıcı güvenliği) bu köprü,
// izin verilen açık kanalların son mesajlarını alıp JSON olarak verir.
// Kullanım: https://<köprü-adresi>/?ch=Borsa_Erbil  →  { channel, posts: [{ at, text }, ...] } (eskiden yeniye)
// Kurulum adımları: kopru/KURULUM.md

const CHANNELS = ['Borsa_Erbil', 'iqborsa', 'dollar_price', 'dollariraqi'];

export default {
  async fetch(request) {
    const headers = {
      'access-control-allow-origin': '*',
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'max-age=60',
    };
    const ch = new URL(request.url).searchParams.get('ch') || CHANNELS[0];
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
