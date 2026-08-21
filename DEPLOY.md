# Deploying Halalan Wyrm to the web

The game exports to HTML5 and runs in a browser. `build/web/` is a plain static
site — any static host will serve it.

## Build

Exporting needs the **standard (non-.NET) Godot 4.7.1**, not the Mono build.
Godot 4's .NET builds cannot export to Web at all. This project is pure
GDScript, so the standard build handles it with nothing lost.

```bash
"/d/GODOT/standard/Godot_v4.7.1-stable_win64_console.exe" --headless --path "D:/klhgamefinal" --export-release "Web" "D:/klhgamefinal/build/web/index.html"
```

Output is ~46 MB: a 39 MB `index.wasm` (the engine) and a 7.8 MB `index.pck`
(the game). Hosts serve these gzipped, so the real transfer is far smaller.

## Deploy to Vercel

```bash
npx vercel deploy build/web --prod
```

The first run asks you to log in and name the project. `vercel.json` at the repo
root supplies the headers and MIME types described below.

## Deploy anywhere else

The build is static, so it also drops straight onto Netlify, Cloudflare Pages,
GitHub Pages, or itch.io. Upload the **contents** of `build/web/` (not the
folder itself) so `index.html` lands at the root.

## Why the export is single-threaded

`export_presets.cfg` sets `variant/thread_support=false`.

A multi-threaded Godot web build needs `SharedArrayBuffer`, which browsers only
grant to pages served with **cross-origin isolation**:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Hosts that cannot set response headers — GitHub Pages among them — simply
cannot run such a build, and the failure is a blank canvas with a console error
rather than anything obvious. The single-threaded build has no such
requirement and runs on any static host. For a 2D word game there is no
threaded workload to lose.

`vercel.json` sets those headers anyway. They are harmless here and mean
switching `thread_support` back to `true` needs no other change.

## Gotcha: plain data files are not "resources"

`export_filter="all_resources"` misses anything Godot does not treat as a
resource. The two dictionaries in `data/wordlists/` are plain `.txt` and were
silently dropped from the first build — the game ran, but `WordValidator` came
up empty, visible only as a browser console warning. Hence:

```
include_filter="*.txt"
```

Add to this filter when introducing any new non-resource data file, and check
the browser console after exporting.

## Testing the build locally

```bash
python -m http.server 8123 --directory build/web
```

Then open <http://127.0.0.1:8123>. Because the build is single-threaded, a plain
static server is enough — no special headers needed.
