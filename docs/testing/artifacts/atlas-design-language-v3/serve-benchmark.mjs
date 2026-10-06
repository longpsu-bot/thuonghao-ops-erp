import { createServer } from "vite";
const port = Number(process.argv[2]);
const server = await createServer({
  root: process.argv[3],
  cacheDir: `node_modules/.vite-atlas-${port}`,
  server: { host: "127.0.0.1", port, strictPort: true, watch: null },
});
await server.watcher.close();
await server.listen();
server.printUrls();
