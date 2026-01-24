# Devlog SFX Library

Sound effects for TikTok/short-form devlog videos.

## Folder Structure

```
sfx/
├── whoosh/       # Transitions, fast movements
├── impact/       # Hits, punches, emphasis
├── ui/           # Clicks, pops, notifications
├── magic/        # Sparkles, power-ups, enchantments
├── tension/      # Risers, suspense builders
├── reveal/       # Ta-da, unveil, surprise
├── comedy/       # Bonk, fail sounds, silly
└── transition/   # Scene changes, cuts
```

## Naming Convention

```
<category>_<descriptor>_<variant>.wav
```

Examples:
- `whoosh_fast_01.wav`
- `impact_heavy_02.wav`
- `reveal_sparkle_01.wav`

## Usage in Manifests

Add SFX to segments:

```json
{
  "segments": [
    {
      "voice": "line_01.wav",
      "media": "clip.mp4",
      "subtitle": "So I found a bug...",
      "sfx": "../../sfx/tension/riser_short_01.wav",
      "sfxVolume": 0.6
    }
  ]
}
```

## Claude Integration

When assembling videos, Claude can suggest SFX based on:
- **Hook lines** → tension/riser
- **Reveals** → reveal/sparkle
- **Fails/bugs** → comedy/bonk
- **Transitions** → whoosh or transition
- **UI moments** → ui/click

## Recommended Sources

- [Freesound.org](https://freesound.org) (CC0/CC-BY)
- [Pixabay](https://pixabay.com/sound-effects/) (Royalty-free)
- [Zapsplat](https://zapsplat.com) (Free tier)
- Motion graphics packs (Envato, Motion Array)
