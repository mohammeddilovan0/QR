// Web uygulamasının (repo kökündeki index.html) bir kopyasını www/ klasörüne koyar; uygulama bu kopyayla derlenir.
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..', '..'), www = path.join(__dirname, '..', 'www');
fs.rmSync(www, { recursive: true, force: true });
fs.mkdirSync(www);
for (const f of ['index.html', 'manifest.webmanifest', 'icon-180.png', 'icon-192.png', 'icon-512.png'])
  fs.copyFileSync(path.join(root, f), path.join(www, f));
console.log('www/ hazır');
