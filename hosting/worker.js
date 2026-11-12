// Cloudflare static assets cap files at 25 MiB; index.wasm is ~36 MB, so it ships gzipped and is served here.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== "/index.wasm") return env.ASSETS.fetch(request);
    const gz = await env.ASSETS.fetch(new URL("/index.wasm.gz", url));
    if (!gz.ok) return gz;
    return new Response(gz.body, {
      encodeBody: "manual", // body is already gzip; don't compress it again
      headers: {
        "Content-Type": "application/wasm",
        "Content-Encoding": "gzip",
        "Cache-Control": "public, max-age=3600",
      },
    });
  },
};
