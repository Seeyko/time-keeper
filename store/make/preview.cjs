const { chromium } = require('playwright');
const { readFileSync, writeFileSync, mkdtempSync } = require('node:fs');
const { execFileSync } = require('node:child_process');
const { tmpdir } = require('node:os');
const { pathToFileURL } = require('node:url');
const { resolve } = require('node:path');

const here = __dirname;
const conf = JSON.parse(readFileSync(resolve(here, 'preview.json'), 'utf8'));
const clips = resolve(process.env.CLIPS ?? '.');
const target = resolve(process.env.OUT ?? 'preview.mp4');
const [W, H] = conf.size;
const c = conf.clip;
const ch = Math.round((c.w * 2622) / 1206 / 2) * 2;
const fade = 0.3;
const url = (p) => pathToFileURL(resolve(here, p)).href;
const tmp = mkdtempSync(resolve(tmpdir(), 'tk-preview-'));

function dial(cx, cy, r) {
  const ticks = [];
  for (let i = 0; i < 120; i++) {
    const a = (i / 120) * Math.PI * 2;
    const long = i % 10 === 0;
    const r1 = r - (long ? 70 : 30);
    const r2 = r - 10;
    ticks.push(`<line x1="${cx + Math.cos(a) * r1}" y1="${cy + Math.sin(a) * r1}" x2="${cx + Math.cos(a) * r2}" y2="${cy + Math.sin(a) * r2}" stroke-width="${long ? 4 : 2}"/>`);
  }
  return `<circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="rgba(185,204,255,.22)" stroke-width="3"/>
    <circle cx="${cx}" cy="${cy}" r="${r * 0.86}" fill="none" stroke="rgba(185,204,255,.10)" stroke-width="2"/>
    <g stroke="rgba(185,204,255,.2)">${ticks.join('')}</g>`;
}

function page(s, i) {
  const cx = s.end ? W / 2 : i % 2 === 0 ? W : 0;
  return `<!doctype html><html lang="fr"><head><meta charset="utf-8"><style>
  @font-face{font-family:IS;src:url('${url('fonts/InstrumentSerif-Regular.woff2')}')}
  @font-face{font-family:IS;font-style:italic;src:url('${url('fonts/InstrumentSerif-Italic.woff2')}')}
  html,body{margin:0;width:${W}px;height:${H}px;overflow:hidden;background:#070E24}
  svg{position:absolute;inset:0}
  p{position:absolute;left:50px;right:50px;top:${s.end ? 1060 : 110}px;margin:0;text-align:center;font:400 ${s.end ? 112 : 76}px/1.06 IS,serif;color:#fff;text-wrap:balance}
  em{color:#B9CCFF}
  .phone{position:absolute;left:${c.x - c.bezel}px;top:${c.y - c.bezel}px;width:${c.w}px;height:${ch}px;padding:${c.bezel}px;border-radius:${c.radius}px;background:#0A0A0D;box-shadow:0 0 0 2px #2A2C33,0 40px 90px rgba(0,0,0,.55)}
  .owl{position:absolute;left:${W / 2 - 230}px;top:420px;height:460px;filter:drop-shadow(0 20px 40px rgba(0,0,0,.45))}
  .name{position:absolute;left:0;right:0;top:1360px;margin:0;text-align:center;font:500 40px Inter,sans-serif;color:#B9CCFF;letter-spacing:.5px}
  </style></head><body>
  <svg width="${W}" height="${H}"><defs>
    <linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#070E24"/><stop offset=".55" stop-color="#0E1D4C"/><stop offset="1" stop-color="#16307A"/></linearGradient>
    <radialGradient id="g" cx="${cx / W}" cy=".6" r=".75"><stop offset="0" stop-color="#5B7FFF" stop-opacity=".38"/><stop offset="1" stop-color="#5B7FFF" stop-opacity="0"/></radialGradient>
  </defs><rect width="100%" height="100%" fill="url(#b)"/><rect width="100%" height="100%" fill="url(#g)"/>${dial(cx, s.end ? 650 : 1150, s.end ? 330 : 780)}</svg>
  ${s.end ? `<img class="owl" src="${url('owl/lit.png')}"><p>${s.text}</p><div class="name">Time Keeper · Sans bouton « Ignorer »</div>` : `<p>${s.text}</p><div class="phone"></div>`}
  </body></html>`;
}

const mask = `<!doctype html><html><body style="margin:0;background:transparent"><div style="width:${c.w}px;height:${ch}px;border-radius:${c.screenRadius}px;background:#fff"></div></body></html>`;

const ff = (args) => execFileSync('ffmpeg', ['-y', '-loglevel', 'error', ...args], { stdio: 'inherit' });

(async () => {
  const browser = await chromium.launch();
  const p = await browser.newPage({ viewport: { width: W, height: H } });
  for (const [i, s] of conf.segments.entries()) {
    const file = resolve(tmp, `bg${i}.html`);
    writeFileSync(file, page(s, i));
    await p.goto(pathToFileURL(file).href, { waitUntil: 'load' });
    await p.evaluate(() => document.fonts.ready);
    await p.screenshot({ path: resolve(tmp, `bg${i}.png`) });
  }
  const m = await browser.newPage({ viewport: { width: c.w, height: ch } });
  writeFileSync(resolve(tmp, 'mask.html'), mask);
  await m.goto(pathToFileURL(resolve(tmp, 'mask.html')).href);
  await m.screenshot({ path: resolve(tmp, 'mask.png'), omitBackground: true });
  await browser.close();

  const parts = conf.segments.map((s, i) => {
    const part = resolve(tmp, `part${i}.mp4`);
    const out = `fade=t=in:d=${fade},fade=t=out:st=${s.dur - fade}:d=${fade},format=yuv420p`;
    if (s.end) {
      ff(['-framerate', `${conf.fps}`, '-loop', '1', '-t', `${s.dur}`, '-i', resolve(tmp, `bg${i}.png`), '-vf', `fps=${conf.fps},${out}`, '-c:v', 'libx264', '-preset', 'slow', '-crf', '16', part]);
    } else {
      const graph = [
        `[1:v]trim=start=${s.from}:duration=${s.dur},setpts=PTS-STARTPTS,fps=${conf.fps},scale=${c.w}:${ch},tpad=stop_mode=clone:stop_duration=${s.dur},trim=duration=${s.dur},format=rgba[v]`,
        `[2:v]format=rgba,alphaextract[a]`,
        `[v][a]alphamerge[r]`,
        `[0:v][r]overlay=${c.x}:${c.y}:shortest=1,${out}`,
      ].join(';');
      ff(['-framerate', `${conf.fps}`, '-loop', '1', '-t', `${s.dur}`, '-i', resolve(tmp, `bg${i}.png`), '-i', resolve(clips, s.clip), '-framerate', `${conf.fps}`, '-loop', '1', '-t', `${s.dur}`, '-i', resolve(tmp, 'mask.png'), '-filter_complex', graph, '-an', '-c:v', 'libx264', '-preset', 'slow', '-crf', '16', part]);
    }
    return part;
  });
  const list = resolve(tmp, 'list.txt');
  writeFileSync(list, parts.map((f) => `file '${f}'`).join('\n'));
  ff(['-f', 'concat', '-safe', '0', '-i', list, '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000', '-t', `${conf.segments.reduce((t, s) => t + s.dur, 0)}`,
    '-c:v', 'libx264', '-profile:v', 'high', '-level', '4.0', '-pix_fmt', 'yuv420p', '-r', `${conf.fps}`, '-b:v', '10M', '-maxrate', '12M', '-bufsize', '20M',
    '-c:a', 'aac', '-b:a', '256k', '-movflags', '+faststart', target]);
})();
