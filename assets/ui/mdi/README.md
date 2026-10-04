# Material Design Icons

The workshop icons come from [Pictogrammers Material Design Icons](https://pictogrammers.com/library/mdi/),
package `@mdi/svg` version **7.4.47**, distributed under **Apache 2.0**.
`LICENSE` contains the upstream notice; `LICENSE-APACHE` contains the full license.
The unmodified SVGs and the exact upstream package URL are retained here.
`manifest.json` maps every addon texture to its source icon.

The `.tga` files in the parent directory use the original SVG paths, exported with
the workshop gold fill (`#efcd8d`) and transparency at 32 × 32 pixels. These are
uncompressed 32-bit textures compatible with WoW; the SVGs are build sources only.

To reproduce the textures, install `Pillow` and `resvg-py`, then run:

```powershell
python tools/render_ui_icons.py
```
