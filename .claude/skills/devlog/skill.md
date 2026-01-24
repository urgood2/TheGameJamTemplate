---
name: devlog
description: Create TikTok/X short-form devlog videos - guides through capturing moments, scripting voice lines, recording, assembly, preview in Remotion Studio, and rendering
---

# Devlog Video Creation Workflow

Create short-form video content for TikTok/X from gameplay captures.

## Prerequisites

- OBS Studio with replay buffer configured
- Remotion installed: `cd devlog/remotion && npm install`
- Session created: `./devlog/bin/new-session.sh`
- (Optional) Whisper for auto-ordering: `pip install openai-whisper`

## SFX & Music Library

### Primary: Eagle MCP (37,101 audio files!)

**Library:** `/Volumes/AssetsEagle/Sound and Music.library`

**Search by text query:**
```
mcp__eagle-mcp__item_query({ query: "whoosh transition" })
mcp__eagle-mcp__item_query({ query: "glitch error" })
mcp__eagle-mcp__item_query({ query: "pop notification" })
```

**Browse folders:**
```
mcp__eagle-mcp__folder_get({ getAllHierarchy: true })
```

**Get items from specific folder:**
```
mcp__eagle-mcp__item_get({ folders: ["FOLDER_ID"] })
```

**Key folders for devlog:**
| Folder Name | Use For |
|-------------|---------|
| Motion Fx | UI sounds, transitions, typing |
| Just Whoosh 4 | Swooshes, fast movements |
| Just Impacts | Hits, emphasis |
| Just Transitions | Scene changes |
| SFX - Casual Game Sound Kit | Achievements, UI |
| Music - Cyberpunk Loops | Energetic background |
| Music - Lo-Fi | Chill background |

**Search queries for devlog content:**
| Moment | Query |
|--------|-------|
| Hook/tension | `"riser tension suspense"` |
| Reveal/ta-da | `"success achievement tada"` |
| Bug/glitch | `"glitch error"` |
| Transition | `"whoosh swish"` |
| UI click | `"click pop bubble"` |
| Comedy | `"cartoon funny pop"` |
| Background music | `"loop energetic"` or `"loop chill"` |

### Fallback: Local Motion Fx Folder

If Eagle MCP is unavailable, use local folder:

**Source Path:** `/Users/joshuashin/Projects/TexturePackerRepo/assets/Motion Fx`
**Index:** See `sfx-index.md` in this skill folder for full categorization.
**CLI:** `./devlog/bin/list-sfx.sh search <term>`

Quick SFX picks by use case:
| Moment | Recommended SFX |
|--------|-----------------|
| Hook/tension | `Transitions/Whoosh/WHSH_Fade in whoosh.wav` |
| Reveal/ta-da | `User Interface - UI/Pop Ups/TOONPop_Cartoon pop.wav` |
| Bug/glitch | `User Interface - UI/Errors/UIGlitch_Error glitch.wav` |
| Transition | `Transitions/Swish/SWSH_Fast swish.wav` |
| Success | `User Interface - UI/Alerts and Notifications/UIAlert_Game success.wav` |
| Comedy | `User Interface - UI/Pop Ups/TOONPop_Funny pop up.wav` |

## The Workflow

### Phase 1: Capture (Always-On)

Ensure OBS replay buffer is running during development:
- **Start buffer:** `Cmd+F9`
- **Save moment:** `Cmd+F10` (saves last 5 minutes)
- Clips save to: `devlog/sessions/raw/`

### Phase 2: Script Voice Lines

When user describes a captured moment:

1. **Understand the moment** - Ask what happened, why it's interesting
2. **Suggest 3-5 voice lines** - Short bursts (5-10 seconds each)
   - Hook line first ("So I found a bug...")
   - Description/context
   - The turn/realization
   - Conclusion/payoff
3. **Present via review skill** - Always use `/review` to show voice lines
4. **Iterate** - Adjust based on feedback until approved

Example voice line structure:
```
line_01: "So I found a bug in my game..."     (hook)
line_02: "Look at this."                       (show)
line_03: "But honestly? It looks kinda cool."  (turn)
line_04: "I think I'm keeping it."             (payoff)
```

### Phase 3: Record Voice Lines

**Option A: Record Freely + Auto-Order (Recommended)**

Just record all lines naturally, then let Claude match them to the script:

```bash
# 1. User records however they want (multiple files, any order)
#    Save to: devlog/sessions/YYYY-MM-DD/raw-voice/

# 2. Claude creates script file from approved voice lines
cat > /tmp/script.txt << 'EOF'
So I found a bug in my game...
Look at this glitch.
But honestly? It looks kinda cool.
I think I'm keeping it.
EOF

# 3. Auto-order (uses whisper if available, else Claude reviews manually)
./devlog/bin/order-audio.sh ./raw-voice/ /tmp/script.txt ./voice/

# 4. Review mapping, then apply:
python3 devlog/bin/apply-audio-mapping.py ./raw-voice/audio_mapping.json ./raw-voice/ ./voice/

# 5. Process:
./devlog/bin/process-voice.sh --all
```

**Option B: Single Recording + Split**

Record all lines in one take with pauses:

```bash
./devlog/bin/split-audio.sh recording.wav devlog/sessions/YYYY-MM-DD/voice/
./devlog/bin/process-voice.sh --all
```

**Option C: Guided Prompts**

```bash
./devlog/bin/record-voice-batch.sh /tmp/voice-lines.txt
./devlog/bin/process-voice.sh --all
```

**Option D: Individual Recording**

```bash
./devlog/bin/record-voice.sh line_01
./devlog/bin/record-voice.sh line_02
./devlog/bin/process-voice.sh --all
```

### Phase 4: Assemble Video

Create the manifest mapping voice lines to video clips:

1. **Check available clips:** `ls devlog/sessions/raw/`
2. **Get clip durations:** `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 <clip>`
3. **Suggest SFX** from `devlog/sfx/` based on content
4. **Create manifest** at `devlog/sessions/YYYY-MM-DD/meta/<name>.json`
5. **Present manifest via review skill** for approval

Manifest structure:
```json
{
  "fps": 30,
  "segments": [
    {
      "voice": "../voice/line_01_processed.wav",
      "media": "../../raw/replay_001.mp4",
      "mediaStartTime": 0,
      "duration": 3.0,
      "subtitle": "So I found a bug...",
      "sfx": "/path/to/sfx.wav",
      "sfxVolume": 0.5,
      "sfxOffset": 0.3,
      "transition": "fade",
      "kenBurns": "zoom-in",
      "textAnimation": "pop"
    }
  ],
  "style": {
    "subtitlePosition": "bottom",
    "showSubtitles": true,
    "accentColor": "#6366f1"
  },
  "upload": {
    "caption": "Caption here\n\n#gamedev #indiedev",
    "platforms": ["tiktok", "x"]
  }
}
```

### Transitions & Effects Reference

**Media Transitions** (`transition` field) - how segment enters:
| Value | Description | Best For |
|-------|-------------|----------|
| `fade` | Opacity crossfade (default) | Most segments |
| `cut` | Hard cut, no transition | Emphasis, surprise |
| `slide-left` | Slides in from right | Topic change |
| `slide-right` | Slides in from left | Flashback |
| `slide-up` | Slides up from bottom | Reveal |
| `slide-down` | Slides down from top | Drop/fall |
| `zoom-in` | Zooms in from small | Impact moment |
| `zoom-out` | Starts big, shrinks | Dream/memory |
| `wipe-left` | Horizontal wipe | Scene change |
| `blur` | Blur in/out | Soft transition |

**Ken Burns** (`kenBurns` field) - camera motion during segment:
| Value | Description | Best For |
|-------|-------------|----------|
| `zoom-in` | Slow zoom in (default) | Building tension |
| `zoom-out` | Slow zoom out | Reveal context |
| `pan-left` | Pan right to left | Following action |
| `pan-right` | Pan left to right | Following action |
| `pan-up` | Pan bottom to top | Ascending |
| `pan-down` | Pan top to bottom | Descending |
| `none` | Static, no motion | Still moments |

**Text Animation** (`textAnimation` field) - subtitle style:
| Value | Description | Best For |
|-------|-------------|----------|
| `pop` | Word-by-word bounce (default) | TikTok style, emphasis |
| `typewriter` | Character by character | Code, hacker vibe |
| `slide-up` | Words slide up | Clean, professional |
| `wave` | Wavy motion across words | Playful, quirky |
| `fade` | Simple fade in | Subtle |
| `none` | Static text | No animation |

**Recommended combos for variety:**
- Hook: `transition: "fade"` + `kenBurns: "zoom-in"` + `textAnimation: "pop"`
- Reveal: `transition: "zoom-in"` + `kenBurns: "zoom-out"` + `textAnimation: "slide-up"`
- Comedy: `transition: "slide-left"` + `kenBurns: "pan-right"` + `textAnimation: "wave"`
- Punchline: `transition: "blur"` + `kenBurns: "pan-left"` + `textAnimation: "pop"`

### Phase 5: Preview in Remotion Studio

**Always preview before rendering:**

```bash
./devlog/bin/preview.sh devlog/sessions/YYYY-MM-DD/meta/<name>.json
```

This opens Remotion Studio where user can:
- Preview the full video
- Adjust segment timings
- Check subtitle sync
- Verify SFX placement

When satisfied, close Studio (Ctrl+C) and proceed to render.

### Phase 6: Render

After preview approval:
```bash
./devlog/bin/render.sh devlog/sessions/YYYY-MM-DD/meta/<name>.json
```

Output goes to: `devlog/sessions/YYYY-MM-DD/out/<name>.mp4`

### Phase 7: Upload

```bash
./devlog/bin/upload-helper.sh devlog/sessions/YYYY-MM-DD/meta/<name>.json
```

This:
- Opens TikTok and X upload pages
- Copies caption to clipboard
- Opens video in Finder

Remind user to add TikTok trending sound!

## Key Commands

| Action | Command |
|--------|---------|
| New session | `./devlog/bin/new-session.sh` |
| **Auto-order audio** | `./devlog/bin/order-audio.sh <audio_dir> <script.txt>` |
| Split batch audio | `./devlog/bin/split-audio.sh <input.wav> <output_dir>` |
| Record voice (guided) | `./devlog/bin/record-voice-batch.sh <lines.txt>` |
| Process voice | `./devlog/bin/process-voice.sh --all` |
| **Preview video** | `./devlog/bin/preview.sh <manifest.json>` |
| Render video | `./devlog/bin/render.sh <manifest.json>` |
| Upload helper | `./devlog/bin/upload-helper.sh <manifest.json>` |

## Audio Selection Strategy

**Step 1: Use Eagle MCP** (preferred - 37K+ sounds)
```
mcp__eagle-mcp__item_query({ query: "search terms" })
→ Returns items with filePath field
→ Use filePath directly in manifest sfx field
```

**Step 2: Auto-Selection by Content**

When assembling manifest, search Eagle and pick first good match:

| Content Type | Eagle Query | Example Result |
|-------------|-------------|----------------|
| Hook opening | `"riser tension fade in"` | `WHSH_Fade in whoosh.wav` |
| "Look at this" | `"pop bubble click"` | `UIClick_Bubble click.wav` |
| Bug reveal | `"glitch error"` | `UIGlitch_Error glitch.wav` |
| Feature demo | `"success achievement"` | `UIAlert_Game success.wav` |
| Code showing | `"typing keyboard"` | `CMPTKey_Mechanical keyboard.wav` |
| Transition | `"whoosh swish fast"` | `SWSH_Fast swish.wav` |
| Punchline | `"positive twinkle"` | `UIAlert_Positive twinkle accent.wav` |
| Background music | `"loop energetic"` | *(from Music folders)* |

**Fallback:** If Eagle MCP unavailable, use local folder:
`/Users/joshuashin/Projects/TexturePackerRepo/assets/Motion Fx`

## Important Notes

- **Always preview before render** - Use `preview.sh` to open Remotion Studio
- **Always use review skill** to present voice lines and manifests
- **Video files with spaces** in names need re-encoding before Remotion
- **Multiple clips** can be combined - each segment can reference different media
- **Caption copied to clipboard** after render completes

## Content Tips

- Hook in first 3 seconds
- Mention it's YOUR game early
- Tell stories, not features
- Target 30-60 seconds total
- Add SFX sparingly - enhance, don't overwhelm
