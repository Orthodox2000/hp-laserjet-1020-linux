# assets/

Diagrams used throughout the docs. All are **plain SVG** (text-based, theme-independent,
scalable, and diff-friendly) so they render on GitHub and anywhere else without binaries.

| File | Shown in | What it shows |
|------|----------|---------------|
| `banner.svg` | `README.md` | Title banner + supported platforms |
| `pipeline.svg` | `docs/04-cups-queue.md` | The full CUPS→foo2zjs→USB filter chain |
| `firmware-flow.svg` | `docs/03-firmware.md` | Why firmware is uploaded on every power-on |
| `sharing.svg` | `docs/05-windows-sharing.md`, `docs/06-cross-platform.md` | One server, all client platforms |
| `troubleshoot.svg` | `docs/07-troubleshooting.md` | "Nothing printed" decision tree |

## Editing

Any text editor works. Keep them dependency-free (no external fonts, no scripts) so GitHub's
SVG sanitizer renders them. To preview, open the file in a browser.

## Adding a new diagram

1. Add `assets/your-diagram.svg`.
2. Reference it from the relevant doc with `![alt](assets/your-diagram.svg)` (use a relative
   path from the doc, e.g. `../assets/your-diagram.svg` inside `docs/`).
3. Add a row to the table above.
