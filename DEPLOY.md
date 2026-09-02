# Deploying Halalan Wyrm to the web

The game exports to HTML5 and runs in a browser. `build/web/` is a plain static
site — any static host will serve it.

## Quick deploy (Windows PowerShell)

This is the one you actually run, in your own terminal, every time you've made
changes in the Godot editor and want the live site to show them. Copy each
block into PowerShell in the project folder (`D:\klhgamefinal`) and run it.

**Step 1 — export the game to a web build.**

```powershell
if (-not (Test-Path "build\web")) { New-Item -ItemType Directory -Path "build\web" | Out-Null }
& "D:\GODOT\standard\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --export-release "Web" "D:\klhgamefinal\build\web\index.html"
```

Two PowerShell-specific things baked into that command, both of which cause a
red error if left out:
- **The `&` at the front is required.** PowerShell treats a quoted path on its
  own as just a string — `&` (the "call operator") is what tells it to actually
  run that file. Leave it off and PowerShell tries to parse `--headless` as the
  `--` decrement operator instead, which is the "operator works only on
  variables or properties" error.
- **Paths use `D:\...`, never `/d/...`.** The `/d/` shorthand only exists in Git
  Bash; PowerShell doesn't understand it.

This takes a minute or two. When it finishes, `build\web\` will contain
`index.html`, `index.wasm`, `index.pck`, and a few other files.

**Step 2 — copy the deploy config into the build.**

```powershell
Copy-Item vercel.json build\web\ -Force
```

`vercel.json` tells Vercel to serve `.wasm` and `.pck` with the right content
type and caching headers. Skip this and the game may fail to start in the
browser even though the files uploaded fine.

**Step 3 — deploy to Vercel.**

```powershell
npx vercel deploy build\web --prod --yes
```

The first time ever, this will ask you to log in and link the project — follow
its prompts. `--prod` means "this is the real live site."

It prints **two** URLs at the end, and the difference matters:

```
  Production      https://web-xxxxxxxxx-jaysuz1s-projects.vercel.app
▲ Aliased         https://web-wheat-six-45.vercel.app
```

- The **Production** line is a snapshot of *this one deploy*. Vercel mints a
  fresh one every time, and it keeps serving the old build forever.
- The **Aliased** line — `https://web-wheat-six-45.vercel.app` — is the
  permanent public link. Vercel repoints it at the newest production deploy on
  every push.

**Give people the aliased one.** It never changes, so nobody ends up bookmarked
to a stale build.

**Step 3b — repoint the public link. This is the step that gets forgotten.**

```powershell
npx vercel alias set <the Production URL printed above> kaalamansahalalan.vercel.app
```

`kaalamansahalalan.vercel.app` is the link that actually gets shared, and it is
**not** one of the two URLs above. It is a manually assigned alias, which means
Vercel does *not* move it when a new production deploy goes out — it keeps
serving whichever deployment it was last pointed at, indefinitely and with no
warning. It had been stuck on an eight-day-old build for exactly this reason.

`web-wheat-six-45.vercel.app` does follow production automatically. So after
every deploy there are two links to think about: that one moves on its own, and
this one has to be told.

**Step 4 — check it's actually live.**

```powershell
(Invoke-WebRequest -Uri "https://web-wheat-six-45.vercel.app" -Method Head -UseBasicParsing).StatusCode
```

You want `200`. If you get `302`, Vercel's "Deployment Protection" got
switched back on — turn it off in your Vercel dashboard under **Project →
Settings → Deployment Protection → "Require Log In."**

That's the whole loop — **export, copy config, deploy, verify** — repeat all
four steps every time you want the live site to catch up with your changes.

## Build (reference / for Claude's Bash tool)

The steps below use POSIX/Bash syntax (`/d/...` paths, no `&` needed). They're
what Claude runs when asked to deploy from within a session, and are kept here
as the canonical reference for anyone scripting this outside PowerShell.

Exporting needs the **standard (non-.NET) Godot 4.7.1**, not the Mono build.
Godot 4's .NET builds cannot export to Web at all. This project is pure
GDScript, so the standard build handles it with nothing lost.

```bash
"/d/GODOT/standard/Godot_v4.7.1-stable_win64_console.exe" --headless --path "D:/klhgamefinal" --export-release "Web" "D:/klhgamefinal/build/web/index.html"
```

Output is ~60 MB: a 37.7 MB `index.wasm` (the engine) and a 21.5 MB `index.pck`
(the game). Hosts serve these brotli-compressed, so the real transfer is far
smaller.

The `.pck` grew from 7.8 MB as the art did. Keep `exclude_filter` in
`export_presets.cfg` doing its job: `export_filter="all_resources"` packs
*everything* Godot has imported, which includes every screenshot under
`output/`, the probe scenes under `tools/`, and the loose PNGs at the repo
root. Left unfiltered those added 17.7 MB of developer artefacts to a public
download -- and published them.

## Deploy to Vercel

```bash
cp vercel.json build/web/
npx vercel deploy --prod --yes --cwd build/web
npx vercel alias set <production URL from the output> kaalamansahalalan.vercel.app
```

**`--cwd build/web`, not a trailing path argument.** The CLI reads the project
link from its *working directory*, and the `.vercel` folder that holds it lives
in `build/web`, not at the repo root. `vercel deploy build/web` therefore runs
unlinked and fails with a bare `Not authorized`, which reads like an
authentication problem and is not one.

The alias line is not optional -- see Step 3b above.

**The copy is not optional.** `build/web` is deployed as the site root, so a
`vercel.json` sitting at the repo root is outside the upload and is silently
ignored -- the headers and cache rules below simply never apply, with no error
to tell you. Exporting wipes `build/web`, so the copy has to be repeated after
every export.

**Deployment Protection must be off for the game to be public.** Vercel enables
it by default on new projects: every request 302s to `vercel.com/sso-api` and
only someone logged into the owning account can load the page. Turn it off in
the Vercel dashboard under Settings -> Deployment Protection -> Vercel
Authentication -> Disabled. Verify with `curl -o /dev/null -w "%{http_code}"`
against the deployment URL -- a public site answers 200, a protected one 302.

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
