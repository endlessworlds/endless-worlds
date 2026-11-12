Hosts the web build at https://game.solulu.dev (Cloudflare Worker + static assets, solulu's Cloudflare account).

Deploy the latest `main` build from CI:

```sh
RUN=$(gh run list -R endlessworlds/endless-worlds --workflow godot-ci.yml --status success -L 1 --json databaseId -q '.[0].databaseId')
rm -rf dist tmp && gh run download $RUN -R endlessworlds/endless-worlds -n github-pages -D tmp
mkdir dist && tar -xf tmp/artifact.tar -C dist && rm -rf tmp
gzip -9 dist/index.wasm   # over the 25 MiB per-file limit; worker.js serves the .gz
npx wrangler deploy
```
