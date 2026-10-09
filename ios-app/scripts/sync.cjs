// Web uygulamasını iOS projesine kopyalar ve yerel eklentiyi (bildirimler) repoya alır,
// böylece Mac'te Node/npm kurmadan sadece Xcode ile derlenebilir.
const { execSync } = require('child_process'), fs = require('fs'), path = require('path');
const here = path.join(__dirname, '..');
execSync('node scripts/www.cjs && npx cap sync ios', { cwd: here, stdio: 'inherit' });
const src = path.join(here, 'node_modules/@capacitor/local-notifications'), dst = path.join(here, 'ios/plugins/CapacitorLocalNotifications');
fs.rmSync(dst, { recursive: true, force: true });
fs.mkdirSync(dst, { recursive: true });
fs.cpSync(path.join(src, 'ios/Sources'), path.join(dst, 'ios/Sources'), { recursive: true });
fs.copyFileSync(path.join(src, 'LICENSE'), path.join(dst, 'LICENSE'));
// Test hedefi olmadan aynı paket tanımı.
fs.writeFileSync(path.join(dst, 'Package.swift'),
  fs.readFileSync(path.join(src, 'Package.swift'), 'utf8').replace(/,\s*\.testTarget\([\s\S]*?\)\s*(?=\])/, '\n    '));
const pkg = path.join(here, 'ios/App/CapApp-SPM/Package.swift');
fs.writeFileSync(pkg, fs.readFileSync(pkg, 'utf8')
  .replace('../../../node_modules/@capacitor/local-notifications', '../../plugins/CapacitorLocalNotifications')
  // Kendi eklentimiz (imza bitiş tarihi, ios/plugins/KisiselImza): cap sync bunu bilmez, elle eklenir.
  .replace(/(path: "\.\.\/\.\.\/plugins\/CapacitorLocalNotifications"\))/, '$1,\n        .package(name: "KisiselImza", path: "../../plugins/KisiselImza")')
  .replace(/(\.product\(name: "CapacitorLocalNotifications", package: "CapacitorLocalNotifications"\))/, '$1,\n                .product(name: "KisiselImza", package: "KisiselImza")'));
const conf = path.join(here, 'ios/App/App/capacitor.config.json'), c = JSON.parse(fs.readFileSync(conf, 'utf8'));
if (!c.packageClassList.includes('ImzaPlugin')) c.packageClassList.push('ImzaPlugin');
fs.writeFileSync(conf, JSON.stringify(c, null, '\t') + '\n');
console.log('iOS projesi güncel');
