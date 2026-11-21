const { chromium } = require('playwright');
const { mkdirSync, writeFileSync, mkdtempSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { pathToFileURL } = require('node:url');
const { resolve } = require('node:path');

const here = __dirname;
const root = resolve(here, '../..');
const out = resolve(root, '.github/readme');
mkdirSync(out, { recursive: true });
const url = (p) => pathToFileURL(resolve(root, p)).href;
const tmp = mkdtempSync(resolve(tmpdir(), 'readme-'));

const store = ['01-encore-5-minutes', '02-juste-fermer', '03-un-site-pas-le-navigateur', '04-assouplir-24h', '05-impossible-a-supprimer', '06-nouvelle-journee', '07-ton-temps-te-revient'];
const onboarding = ['03-jours-par-an', '04-ecran-de-blocage', '08-minutes', '10-verrou', '12-accueil'];

function dial(cx, cy, r) {
  const ticks = [];
  for (let i = 0; i < 120; i++) {
    const a = (i / 120) * Math.PI * 2;
    const long = i % 10 === 0;
    const r1 = r - (long ? 90 : 38);
    const r2 = r - 14;
    ticks.push(`<line x1="${cx + Math.cos(a) * r1}" y1="${cy + Math.sin(a) * r1}" x2="${cx + Math.cos(a) * r2}" y2="${cy + Math.sin(a) * r2}" stroke-width="${long ? 5 : 2.5}"/>`);
  }
  return `<circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="rgba(185,204,255,.2)" stroke-width="4"/>
    <circle cx="${cx}" cy="${cy}" r="${r * 0.86}" fill="none" stroke="rgba(185,204,255,.09)" stroke-width="2"/>
    <g stroke="rgba(185,204,255,.18)">${ticks.join('')}</g>`;
}

function background(w, h) {
  return `<svg style="position:absolute;inset:0" width="${w}" height="${h}">
    <defs>
      <linearGradient id="base" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#070E24"/><stop offset=".6" stop-color="#0E1D4C"/><stop offset="1" stop-color="#16307A"/></linearGradient>
      <radialGradient id="glow" cx=".5" cy=".55" r=".6"><stop offset="0" stop-color="#5B7FFF" stop-opacity=".4"/><stop offset="1" stop-color="#5B7FFF" stop-opacity="0"/></radialGradient>
      <filter id="grain"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" stitchTiles="stitch"/><feColorMatrix values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 .07 0"/></filter>
    </defs>
    <rect width="100%" height="100%" fill="url(#base)"/>
    <rect width="100%" height="100%" fill="url(#glow)"/>
    ${dial(w / 2, h * 0.58, h * 0.72)}
    <rect width="100%" height="100%" filter="url(#grain)"/>
  </svg>`;
}

const doc = (w, h, body, bg = '') => `<!doctype html><html><head><meta charset="utf-8"><style>
  html,body{margin:0;width:${w}px;height:${h}px;overflow:hidden;background:${bg || 'transparent'}}
  .card{position:absolute;border-radius:44px;box-shadow:0 40px 90px rgba(0,0,0,.55),0 0 0 2px rgba(185,204,255,.12)}
  .phone{position:absolute;background:#0A0A0D;padding:16px;border-radius:84px;box-shadow:0 40px 90px rgba(0,0,0,.55),0 0 0 3px #2A2D36}
  .phone img{display:block;border-radius:68px}
  </style></head><body>${body}</body></html>`;

function hero() {
  const w = 2400, h = 1240, ch = 1060, cw = ch * 1320 / 2868;
  const fan = [
    { f: store[2], dx: -2, rot: -9, s: 0.82 },
    { f: store[1], dx: -1, rot: -4.5, s: 0.91 },
    { f: store[0], dx: 0, rot: 0, s: 1 },
    { f: store[3], dx: 1, rot: 4.5, s: 0.91 },
    { f: store[4], dx: 2, rot: 9, s: 0.82 },
  ];
  const cards = fan
    .sort((a, b) => a.s - b.s)
    .map(({ f, dx, rot, s }) => {
      const cw2 = cw * s, ch2 = ch * s;
      const left = w / 2 + dx * 430 - cw2 / 2;
      const top = (h - ch) / 2 + 20 + Math.abs(dx) * 46 + (ch - ch2) / 2;
      return `<img class="card" src="${url(`store/${f}.png`)}" style="left:${left}px;top:${top}px;width:${cw2}px;height:${ch2}px;transform:rotate(${rot}deg)">`;
    });
  return { name: 'hero.jpg', w, h, html: doc(w, h, background(w, h) + cards.join('')) };
}

function strip() {
  const w = 2400, h = 1080, sh = 820, sw = sh * 1206 / 2622, gap = 56;
  const total = onboarding.length * (sw + 32) + (onboarding.length - 1) * gap;
  const phones = onboarding.map((f, i) => {
    const left = (w - total) / 2 + i * (sw + 32 + gap);
    return `<div class="phone" style="left:${left}px;top:${(h - sh) / 2 - 16}px"><img src="${url(`screenshots/onboarding/${f}.png`)}" style="width:${sw}px;height:${sh}px"></div>`;
  });
  return { name: 'onboarding.jpg', w, h, html: doc(w, h, background(w, h) + phones.join('')) };
}

function logo() {
  const s = 360;
  return { name: 'logo.png', w: s, h: s, transparent: true, html: doc(s, s, `<img src="${url('ios/TimeKeeper/Assets.xcassets/AppIcon.appiconset/icon-1024.png')}" style="width:${s}px;height:${s}px;border-radius:${s * 0.2237}px;display:block">`) };
}

function wordmark(theme) {
  const w = 1200, h = 330;
  const [ink, soft] = theme === 'dark' ? ['#FFFFFF', '#B9CCFF'] : ['#111318', '#1F3A8A'];
  return { name: `wordmark-${theme}.png`, w, h, transparent: true, html: doc(w, h, `<style>
    @font-face{font-family:IS;src:url('${url('store/make/fonts/InstrumentSerif-Regular.woff2')}')}
    @font-face{font-family:IS;font-style:italic;src:url('${url('store/make/fonts/InstrumentSerif-Italic.woff2')}')}
    div{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center}
    h1{margin:0;font:400 170px/1 IS,serif;color:${ink};letter-spacing:-2px}
    p{margin:22px 0 0;font:italic 400 64px/1.1 IS,serif;color:${soft}}
  </style><div><h1>Time Keeper</h1><p>Le bloqueur sans bouton « Ignorer ».</p></div>`) };
}

function owl() {
  const s = 300;
  return { name: 'owl.png', w: s, h: s, transparent: true, html: doc(s, s, `<img src="${url('store/make/owl/lit.png')}" style="width:${s}px;height:${s}px;object-fit:contain;display:block">`) };
}

function thumbs() {
  const w = 440, h = Math.round(w * 2868 / 1320);
  return store.map((f) => ({ name: `store/${f}.jpg`, w, h, html: doc(w, h, `<img src="${url(`store/${f}.png`)}" style="width:${w}px;height:${h}px;display:block">`, '#070E24') }));
}

(async () => {
  const browser = await chromium.launch();
  mkdirSync(resolve(out, 'store'), { recursive: true });
  for (const p of [hero(), strip(), logo(), wordmark('light'), wordmark('dark'), owl(), ...thumbs()]) {
    const page = await browser.newPage({ viewport: { width: p.w, height: p.h } });
    const file = resolve(tmp, 'page.html');
    writeFileSync(file, p.html);
    await page.goto(pathToFileURL(file).href);
    await page.waitForLoadState('networkidle');
    await page.evaluate(() => document.fonts.ready);
    const jpg = p.name.endsWith('.jpg');
    await page.screenshot({ path: resolve(out, p.name), type: jpg ? 'jpeg' : 'png', quality: jpg ? 84 : undefined, omitBackground: !!p.transparent });
    await page.close();
  }
  await browser.close();
})();
