const { chromium } = require('playwright');
const { readFileSync, mkdirSync, writeFileSync, mkdtempSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { pathToFileURL } = require('node:url');
const { resolve } = require('node:path');

const here = __dirname;
const conf = JSON.parse(readFileSync(resolve(here, process.argv[2] ?? 'slides.json'), 'utf8'));
const [W, H] = conf.size;
const [RW, RH] = conf.raw;
const out = process.env.OUT ? resolve(process.env.OUT) : resolve(here, conf.out);
const only = process.argv[3];
mkdirSync(out, { recursive: true });

const url = (p) => pathToFileURL(p.startsWith('shot:') ? resolve(process.env.SCREENS ?? '', p.slice(5)) : resolve(here, p)).href;

const dev = conf.device;
const phone = { x: dev.x, y: dev.y, w: dev.w };
const k = phone.w / RW;
const bezel = dev.bezel;
const sb = dev.statusBar;

function dial(cx, cy, r) {
  const ticks = [];
  for (let i = 0; i < 120; i++) {
    const a = (i / 120) * Math.PI * 2;
    const long = i % 10 === 0;
    const r1 = r - (long ? 120 : 50);
    const r2 = r - 18;
    ticks.push(`<line x1="${cx + Math.cos(a) * r1}" y1="${cy + Math.sin(a) * r1}" x2="${cx + Math.cos(a) * r2}" y2="${cy + Math.sin(a) * r2}" stroke-width="${long ? 6 : 3}"/>`);
  }
  const w0 = -Math.PI / 2, w1 = Math.PI / 6, rw = r * 0.62;
  const wedge = `M${cx} ${cy}L${cx + Math.cos(w0) * rw} ${cy + Math.sin(w0) * rw}A${rw} ${rw} 0 0 1 ${cx + Math.cos(w1) * rw} ${cy + Math.sin(w1) * rw}Z`;
  return `
    <circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="rgba(185,204,255,.22)" stroke-width="5"/>
    <circle cx="${cx}" cy="${cy}" r="${r * 0.86}" fill="none" stroke="rgba(185,204,255,.10)" stroke-width="2"/>
    <g stroke="rgba(185,204,255,.2)">${ticks.join('')}</g>
    <path d="${wedge}" fill="url(#wedge)"/>`;
}

function background(i, s) {
  const end = !s.screen;
  const cx = end ? W / 2 : i % 2 === 0 ? W : 0;
  const cy = end ? 1250 : 1750;
  const r = end ? 470 : 1180;
  return `
  <svg class="bg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
    <defs>
      <linearGradient id="base" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#070E24"/>
        <stop offset=".55" stop-color="#0E1D4C"/>
        <stop offset="1" stop-color="#16307A"/>
      </linearGradient>
      <radialGradient id="glow" cx="${end ? 0.5 : cx === 0 ? 0.15 : 0.85}" cy="${end ? 0.44 : 0.62}" r=".75">
        <stop offset="0" stop-color="#5B7FFF" stop-opacity=".38"/>
        <stop offset="1" stop-color="#5B7FFF" stop-opacity="0"/>
      </radialGradient>
      <radialGradient id="wedge" cx="${cx}" cy="${cy}" r="${r}" gradientUnits="userSpaceOnUse">
        <stop offset="0" stop-color="#9DB7FF" stop-opacity=".16"/>
        <stop offset="1" stop-color="#9DB7FF" stop-opacity=".02"/>
      </radialGradient>
      <filter id="grain"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" stitchTiles="stitch"/><feColorMatrix values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 .07 0"/></filter>
    </defs>
    <rect width="100%" height="100%" fill="url(#base)"/>
    <rect width="100%" height="100%" fill="url(#glow)"/>
    ${dial(cx, cy, r)}
    <rect width="100%" height="100%" filter="url(#grain)"/>
  </svg>`;
}

function statusBar(dark) {
  const c = dark ? '#fff' : '#000';
  const bg = dark ? '#0B1530' : '#fff';
  return `<div class="status" style="background:${bg};color:${c}">
    <span>9:41</span>
    <svg viewBox="0 0 78 14" width="${sb.icons * k}" fill="${c}">
      <rect x="0" y="9" width="3.4" height="4" rx="1"/><rect x="5" y="6.5" width="3.4" height="6.5" rx="1"/><rect x="10" y="4" width="3.4" height="9" rx="1"/><rect x="15" y="1.5" width="3.4" height="11.5" rx="1"/>
      <path d="M31 3.2a11 11 0 0 1 15 0l-1.5 1.6a8.8 8.8 0 0 0-12 0zM33.6 6a7.2 7.2 0 0 1 9.8 0l-1.6 1.6a4.9 4.9 0 0 0-6.6 0zM36.2 8.8a3.4 3.4 0 0 1 4.6 0L38.5 11.2z"/>
      <rect x="52.5" y="1.5" width="22" height="11" rx="3.3" fill="none" stroke="${c}" stroke-opacity=".4"/><rect x="54.5" y="3.5" width="18" height="7" rx="1.8"/><rect x="75.5" y="5" width="1.6" height="4" rx=".8" fill-opacity=".4"/>
    </svg>
  </div>`;
}

function loupe(s) {
  const [cx, cy, cw, ch] = s.loupe.crop;
  const z = k * s.loupe.zoom;
  const w = Math.min(cw * z, W - 80);
  const h = ch * z;
  const left = Math.max(40, Math.min(W - 40 - w, phone.x + cx * k - w / 2));
  const top = phone.y + cy * k - h / 2 + (s.loupe.dy ?? 0);
  return `<div class="loupe" style="left:${left}px;top:${top}px;width:${w}px;height:${h}px;border-radius:${Math.min(h / 2, 64)}px;
    background-image:url('${url(s.screen)}');background-size:${RW * z}px ${RH * z}px;background-position:${-(cx - cw / 2) * z + (w - cw * z) / 2}px ${-(cy - ch / 2) * z}px"></div>`;
}

function closing(s) {
  return `${s.owl ? '' : `<img class="mark" src="${url('../../ios/TimeKeeper/Assets.xcassets/AppIcon.appiconset/icon-1024.png')}">`}
  <p class="quote">${s.thought}</p><h1 class="end">${s.title}</h1><p class="line">${s.line}</p>`;
}

function page(s, i) {
  const ph = RH * k;
  return `<!doctype html><html lang="fr"><head><meta charset="utf-8"><style>
  @font-face{font-family:IS;src:url('${url('fonts/InstrumentSerif-Regular.woff2')}')}
  @font-face{font-family:IS;font-style:italic;src:url('${url('fonts/InstrumentSerif-Italic.woff2')}')}
  html,body{margin:0;width:${W}px;height:${H}px;overflow:hidden;background:#070E24}
  .bg{position:absolute;inset:0}
  .head{position:absolute;left:80px;right:80px;top:${conf.head.top}px;text-align:center}
  .head p{margin:0;font:400 ${conf.head.thought}px/1.04 IS,serif;color:#fff;letter-spacing:-.5px;text-wrap:balance}
  .head h1{margin:30px 0 0;font:italic 400 ${conf.head.answer}px/1.08 IS,serif;color:#B9CCFF;text-wrap:balance}
  .owl{position:absolute;filter:drop-shadow(0 30px 50px rgba(0,0,0,.45))}
  .phone{position:absolute;left:${phone.x - bezel}px;top:${phone.y - bezel}px;width:${phone.w}px;height:${ph}px;padding:${bezel}px;border-radius:${dev.radius}px;background:#0A0A0D;
    box-shadow:0 0 0 3px #2A2C33,0 60px 140px rgba(0,0,0,.55)}
  .screen{position:relative;width:${phone.w}px;height:${ph}px;border-radius:${dev.screenRadius}px;overflow:hidden;background:url('${s.screen ? url(s.screen) : ''}') 0 0/100% 100%}
  .status{position:absolute;left:0;right:0;top:0;height:${sb.h * k}px;display:flex;align-items:center;justify-content:space-between;padding:${sb.top * k}px ${sb.right * k}px 0 ${sb.left * k}px;box-sizing:border-box;font:600 ${sb.font * k}px Inter,sans-serif}
  .island{position:absolute;top:${34 * k}px;left:50%;width:${370 * k}px;height:${110 * k}px;margin-left:${-185 * k}px;border-radius:${60 * k}px;background:#000}
  .mark{position:absolute;left:${W / 2 - 190}px;top:1060px;width:380px;height:380px;border-radius:86px;box-shadow:0 40px 100px rgba(0,0,0,.5)}
  h1.end{position:absolute;left:0;right:0;margin:0;text-align:center;top:1540px;font:400 190px/1.02 IS,serif;color:#fff}
  h1.end em{color:#B9CCFF}
  .quote{position:absolute;left:0;right:0;top:330px;margin:0;text-align:center;font:400 104px/1.06 IS,serif;color:#fff}
  .line{position:absolute;left:0;right:0;top:2020px;margin:0;text-align:center;font:500 54px Inter,sans-serif;color:#B9CCFF;letter-spacing:.5px}
  .loupe{position:absolute;background-repeat:no-repeat;box-shadow:0 0 0 10px #fff,0 40px 90px rgba(3,8,30,.6),inset 0 0 0 1px rgba(0,0,0,.08)}
  </style></head><body>
  ${background(i, s)}
  ${s.screen ? `<div class="head"><p>${s.thought}</p><h1>${s.answer}</h1></div>
  <div class="phone"><div class="screen">${sb.always || s.dark ? statusBar(s.dark) : ''}${dev.island ? '<div class="island"></div>' : ''}</div></div>
  ${loupe(s)}` : closing(s)}
  ${s.owl ? `<img class="owl" src="${url(s.owl.src)}" style="left:${s.owl.x}px;top:${s.owl.y}px;height:${s.owl.h}px;${s.owl.flip ? 'transform:scaleX(-1)' : ''}">` : ''}
  </body></html>`;
}

(async () => {
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: RW / conf.shield.scale, height: RH / conf.shield.scale }, deviceScaleFactor: conf.shield.scale });
const p = await ctx.newPage();
await p.goto(url('shield.html'));
await p.screenshot({ path: resolve(here, conf.shield.out) });

const big = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
const q = await big.newPage();
const tmp = mkdtempSync(resolve(tmpdir(), 'tk-'));
for (const [i, s] of conf.slides.entries()) {
  if (only && !s.file.startsWith(only)) continue;
  const file = resolve(tmp, `${s.file}.html`);
  writeFileSync(file, page(s, i));
  await q.goto(pathToFileURL(file).href, { waitUntil: 'load' });
  await q.evaluate(() => document.fonts.ready);
  await q.screenshot({ path: resolve(out, `${s.file}.png`) });
}
await browser.close();
})();
