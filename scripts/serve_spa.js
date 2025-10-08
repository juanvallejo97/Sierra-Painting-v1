// Simple SPA static server without external deps
const http = require('http');
const fs = require('fs');
const path = require('path');

const port = process.argv[2] ? parseInt(process.argv[2], 10) : 8080;
const root = path.resolve(__dirname, '..', 'build', 'web');
const indexPath = path.join(root, 'index.html');

function sendFile(res, filePath, contentType) {
  res.writeHead(200, { 'Content-Type': contentType || 'text/html; charset=utf-8' });
  fs.createReadStream(filePath).pipe(res);
}

const server = http.createServer((req, res) => {
  const reqPath = decodeURIComponent(req.url.split('?')[0]);
  let filePath = path.join(root, reqPath);

  // If path is directory, use index.html inside it
  if (filePath.endsWith(path.sep)) {
    filePath = path.join(filePath, 'index.html');
  }

  fs.stat(filePath, (err, stats) => {
    if (!err && stats.isFile()) {
      const ext = path.extname(filePath).toLowerCase();
      const map = {
        '.html': 'text/html; charset=utf-8',
        '.js': 'application/javascript; charset=utf-8',
        '.css': 'text/css; charset=utf-8',
        '.json': 'application/json; charset=utf-8',
        '.svg': 'image/svg+xml',
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.woff2': 'font/woff2',
      };
      sendFile(res, filePath, map[ext]);
    } else {
      // Fallback to index.html for SPA routes
      if (fs.existsSync(indexPath)) {
        sendFile(res, indexPath, 'text/html; charset=utf-8');
      } else {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not found');
      }
    }
  });
});

server.listen(port, () => console.log(`SPA server listening on http://127.0.0.1:${port}`));

process.on('SIGINT', () => {
  server.close(() => process.exit(0));
});
