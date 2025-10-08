#!/usr/bin/env node
// Tiny SPA static server. Serves files from build/web and falls back to index.html
import { createServer } from 'http';
import { promises as fs } from 'fs';
import path from 'path';

const PORT = process.env.PORT ? Number(process.env.PORT) : 8080;
const ROOT = path.resolve(process.cwd(), 'build', 'web');

function contentTypeFromExt(ext) {
  switch (ext) {
    case '.html': return 'text/html; charset=utf-8';
    case '.js': return 'application/javascript; charset=utf-8';
    case '.css': return 'text/css; charset=utf-8';
    case '.json': return 'application/json; charset=utf-8';
    case '.png': return 'image/png';
    case '.jpg':
    case '.jpeg': return 'image/jpeg';
    case '.svg': return 'image/svg+xml';
    case '.woff2': return 'font/woff2';
    case '.wasm': return 'application/wasm';
    default: return 'application/octet-stream';
  }
}

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    let pathname = decodeURIComponent(url.pathname);
    if (pathname.includes('..')) {
      res.writeHead(400);
      res.end('Bad request');
      return;
    }

    let filePath = path.join(ROOT, pathname);
    try {
      const stat = await fs.stat(filePath);
      if (stat.isDirectory()) filePath = path.join(filePath, 'index.html');
    } catch (e) {
      // file doesn't exist — fallback to index.html (SPA)
      filePath = path.join(ROOT, 'index.html');
    }

    const data = await fs.readFile(filePath);
    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, { 'Content-Type': contentTypeFromExt(ext) });
    res.end(data);
  } catch (err) {
    // final fallback
    try {
      const index = await fs.readFile(path.join(ROOT, 'index.html'));
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(index);
    } catch (e) {
      res.writeHead(500);
      res.end('Server error');
    }
  }
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`SPA server listening on http://127.0.0.1:${PORT} (root: ${ROOT})`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('Shutting down SPA server');
  server.close(() => process.exit(0));
});
