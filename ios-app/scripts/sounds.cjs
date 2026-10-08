// Hatırlatıcı seslerini, web uygulamasının kendi ürettiği seslerden WAV dosyası olarak çıkarır (bildirim sesi olarak pakete girer).
// Kullanım: node scripts/sounds.cjs <playwright yolu> (repo kökü http://localhost:8765'te sunulurken)
const { chromium } = require(process.argv[2] || 'playwright');
const fs = require('fs'), path = require('path');
(async () => {
  const b = await chromium.launch(), p = await (await b.newContext({ bypassCSP: true })).newPage();
  await p.route(/^https:/, r => r.abort());
  await p.goto('http://localhost:8765/'); await p.waitForTimeout(1500);
  const out = await p.evaluate(async () => {
    const r = {};
    for (const [k, u] of Object.entries(sndUrl)) {
      const a = new Uint8Array(await (await fetch(u)).arrayBuffer());
      let s = ''; for (const x of a) s += String.fromCharCode(x); r[k] = btoa(s);
    }
    return r;
  });
  const dir = path.join(__dirname, '..', 'ios', 'App', 'App');
  for (const [k, v] of Object.entries(out)) fs.writeFileSync(path.join(dir, `kalk-${k}.wav`), Buffer.from(v, 'base64'));
  // "Sessiz" seçeneği için 0,2 sn sessizlik.
  const n = 4410, w = Buffer.alloc(44 + n * 2);
  w.write('RIFF', 0); w.writeUInt32LE(36 + n * 2, 4); w.write('WAVEfmt ', 8); w.writeUInt32LE(16, 16); w.writeUInt16LE(1, 20); w.writeUInt16LE(1, 22);
  w.writeUInt32LE(22050, 24); w.writeUInt32LE(44100, 28); w.writeUInt16LE(2, 32); w.writeUInt16LE(16, 34); w.write('data', 36); w.writeUInt32LE(n * 2, 40);
  fs.writeFileSync(path.join(dir, 'kalk-yok.wav'), w);
  console.log(Object.keys(out).join(', '), '+ yok');
  await b.close();
})();
