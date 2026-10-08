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
fs.writeFileSync(pkg, fs.readFileSync(pkg, 'utf8').replace('../../../node_modules/@capacitor/local-notifications', '../../plugins/CapacitorLocalNotifications'));
console.log('iOS projesi güncel');
