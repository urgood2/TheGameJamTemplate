# Crusenho Flat UI Pack (Generated)

This directory contains a generated in-repo UI pack used for compatibility validation:

- `atlas.png`: packed atlas generated from loose sprites plus animated sheet slices.
- `pack.json`: manifest consumed by `ui.register_pack`.
- `pack.json.animations`: asset-driven animation cycles (consumed by `ui.crusenho_pack_demo`).
- `regions.json`: debug map of atlas regions by source sprite stem.
- `LICENSE.txt`: source pack license copy.

Source used to generate this pack:

- `/Users/joshuashin/Downloads/Complete_UI_Essential_Pack_Free/01_Flat_Theme/Sprites`
- `/Users/joshuashin/Downloads/Complete_UI_Essential_Pack_Free/01_Flat_Theme/Spritesheets/Spritesheet_UI_Flat_Animated.png`

Regeneration command:

```bash
python3 scripts/generate_crusenho_ui_pack.py \
  --source "/Users/joshuashin/Downloads/Complete_UI_Essential_Pack_Free/01_Flat_Theme/Sprites" \
  --out-dir "assets/ui_packs/crusenho_flat"
```

Attribution:

- Author: Crusenho Agus Hennihuno
- Store: [https://crusenho.itch.io](https://crusenho.itch.io)
- License: CC BY 4.0 (`LICENSE.txt`)
