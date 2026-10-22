// Yerel web denemesi: build/web'i sunar, /api/* isteklerini JetDiji'ye aktarır.
// Canlı barındırmadaki (vercel.json) yönlendirmenin aynısı.
//   node tool/web_proxy.mjs [port]
import http from 'node:http';
import https from 'node:https';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'build', 'web');
const upstream = process.env.API_UPSTREAM ?? 'api-mobile.preprod.jetdiji.com';
const port = Number(process.argv[2] ?? 8088);
// Yalnız bu Mac'ten erişilsin; yerel ağdaki başka cihazlar oturum isteklerini göremesin.
const host = process.env.HOST ?? '127.0.0.1';
const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png',
  '.css': 'text/css', '.otf': 'font/otf', '.ttf': 'font/ttf', '.svg': 'image/svg+xml',
};

http.createServer((req, res) => {
  if (req.url.startsWith('/api/')) {
    const headers = { ...req.headers, host: upstream };
    delete headers.origin;
    delete headers.referer;
    const up = https.request({ host: upstream, path: req.url, method: req.method, headers }, (r) => {
      res.writeHead(r.statusCode, r.headers);
      r.pipe(res);
    });
    up.on('error', (e) => { res.writeHead(502); res.end(String(e)); });
    req.pipe(up);
    return;
  }
  let clean;
  try {
    clean = decodeURIComponent(req.url.split('?')[0]);
  } catch {
    res.writeHead(400);
    res.end();
    return;
  }
  let file = path.join(root, clean);
  // `root + sep` ile karşılaştır: `/build/web2` gibi kardeş klasörler de dışarıda kalsın.
  if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    file = path.join(root, 'index.html');
  }
  res.writeHead(200, { 'content-type': types[path.extname(file)] ?? 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
}).listen(port, host, () => console.log(`http://localhost:${port}  (/api -> ${upstream})`));
