# Game Devlog Content Pipeline

Streamlined workflow for creating TikTok/X short-form video content. Inspired by Johan Grunval's Bubble Battle marketing success.

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         YOUR DEVLOG WORKFLOW                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. CAPTURE (Always-on)          2. SAVE MOMENT                     │
│  ┌───────────────────┐           ┌───────────────────┐              │
│  │ OBS Replay Buffer │  ──────►  │ Press hotkey to   │              │
│  │ (runs in background)│          │ save last 5 min   │              │
│  └───────────────────┘           └───────────────────┘              │
│                                           │                         │
│                                           ▼                         │
│  3. COLLABORATE ON SCRIPT        4. RECORD VOICE LINES              │
│  ┌───────────────────┐           ┌───────────────────┐              │
│  │ Tell Claude what  │  ──────►  │ Record 3-5 short  │              │
│  │ moment you captured│          │ numbered lines    │              │
│  │ Claude suggests   │           │ line_01.wav, etc  │              │
│  │ voice lines       │           └───────────────────┘              │
│  └───────────────────┘                    │                         │
│                                           ▼                         │
│  5. CLAUDE ASSEMBLES             6. RENDER & UPLOAD                 │
│  ┌───────────────────┐           ┌───────────────────┐              │
│  │ Creates Remotion  │  ──────►  │ "Claude, render"  │              │
│  │ manifest, trims   │           │ CLI upload to     │              │
│  │ clips, syncs voice│           │ TikTok/X          │              │
│  └───────────────────┘           └───────────────────┘              │
│                                           │                         │
│                                           ▼                         │
│                              7. ADD TIKTOK SOUND                    │
│                              ┌───────────────────┐                  │
│                              │ Add trending audio│                  │
│                              │ in TikTok app     │                  │
│                              └───────────────────┘                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Reference

| Step | What You Do | What Claude Does |
|------|-------------|------------------|
| **Capture** | Play game with OBS running | - |
| **Save** | Press Cmd+F10 when something cool happens | - |
| **Script** | Describe the moment to Claude | Suggests 3-5 short voice lines |
| **Record** | Record voice lines as `line_01.wav`, `line_02.wav`, etc. | - |
| **Assemble** | Say "assemble this video" | Creates Remotion manifest, trims clips |
| **Render** | Say "render this video" | Runs Remotion, outputs final video |
| **Upload** | Say "upload this video" | CLI upload or opens upload pages |

---

## First-Time Setup

### 1. Install OBS Studio (Screen Recording)

```bash
# Install OBS via Homebrew
brew install --cask obs

# Or download from: https://obsproject.com/download
```

### 2. Configure OBS Replay Buffer

This is the key feature - OBS constantly records, and you press a hotkey to save the last 5 minutes.

**Launch OBS and configure:**

1. **Settings → Output → Replay Buffer:**
   - Enable Replay Buffer: ✓
   - Maximum Replay Time: 300 seconds (5 minutes)
   - Maximum Memory: 1024 MB (adjust based on RAM)

2. **Settings → Output → Recording:**
   - Recording Path: `~/Projects/TheGameJamTemplate/TheGameJamTemplate/devlog/sessions/raw/`
   - Recording Format: mp4
   - Encoder: Apple VT H264 Hardware Encoder (best for Mac)
   - Quality: High Quality, Medium File Size

3. **Settings → Video:**
   - Base Resolution: Your screen resolution
   - Output Resolution: 1920x1080 (will crop to 9:16 later)
   - FPS: 30

4. **Settings → Hotkeys:**
   - Save Replay: `Cmd + F10` (or your preference)
   - Start Replay Buffer: `Cmd + F9`
   - Stop Replay Buffer: `Cmd + F8`

5. **Add a Game Capture Source:**
   - Click + in Sources → macOS Screen Capture
   - Select your game window or display
   - Optionally add a second source for game audio

**Test it:**
```bash
# 1. Start OBS
# 2. Click "Start Replay Buffer" (or Cmd+F9)
# 3. Do something for 30 seconds
# 4. Press Cmd+F10
# 5. Check devlog/sessions/raw/ for the saved clip
```

### 3. Install Remotion (Video Composition)

```bash
cd devlog/remotion
npm install
```

### 4. Set Up Voice Recording

Your built-in Mac mic works fine with processing. Use QuickTime Player or the included script:

```bash
# Record a voice line (Ctrl+C to stop)
./devlog/bin/record-voice.sh line_01

# This saves to current session's voice/ folder
```

### 5. Install Upload CLI Tools (Optional)

```bash
# TikTok CLI (unofficial, may require auth setup)
pip install tiktok-uploader

# For X/Twitter, we'll use the browser upload flow
# (API restrictions make CLI posting complex)
```

---

## Daily Workflow

### Step 1: Start Your Session

```bash
# Create today's session folder
./devlog/bin/new-session.sh

# Start OBS replay buffer (or use OBS GUI)
# Keep it running in the background while you develop
```

### Step 2: Capture Moments

Just develop normally. When something cool happens:

1. **Press Cmd+F10** to save the replay buffer
2. **Jot a quick note** about what happened (optional but helpful)

Capture types that work well:
- **Combat/action**: Satisfying combos, boss moments, close calls
- **Visual polish**: New shaders, particles, animations looking good
- **Bugs/discoveries**: Funny glitches, unexpected interactions
- **Progress milestones**: Before/after comparisons

### Step 3: Collaborate on Script

When ready to make a video, tell Claude:

> "I captured a moment where [describe what happened]. Here's the clip: [path to saved replay]. Help me script this."

**Claude will:**
1. Watch/analyze your clip (if you describe it or share screenshots)
2. Suggest 3-5 short voice lines (5-10 seconds each)
3. Work back-and-forth until the script feels right

**Example exchange:**
```
You: "I captured a bug where enemies started stacking on top of each other
      and it actually looked like a cool swarm attack. Might keep it."

Claude: "Great emergent gameplay moment! Here are voice lines:

line_01: 'So I found a bug in my game...'
line_02: 'Enemies were stacking on each other like this.'
line_03: 'But honestly? It looks kinda cool.'
line_04: 'I think I'm keeping it.'

Want me to adjust any of these?"
```

### Step 4: Record Voice Lines

Record each line as a separate file with numbered naming:

```bash
./devlog/bin/record-voice.sh line_01
# Say: "So I found a bug in my game..."
# Press Ctrl+C

./devlog/bin/record-voice.sh line_02
# Say: "Enemies were stacking on each other like this."
# Press Ctrl+C

# Continue for all lines...
```

**Tips for good recordings:**
- Find a quiet moment (no AC/fans if possible)
- Speak clearly, slightly slower than normal
- Keep it casual and authentic - not radio announcer voice
- One clean take is fine, don't over-polish

### Step 5: Assemble the Video

Tell Claude:

> "Assemble this video. Clips are in [path], voice lines are line_01 through line_04."

**Claude will:**
1. Analyze your clips and voice lines
2. Create a Remotion manifest with proper timing
3. Trim clips to match voice line duration
4. Set up the 9:16 vertical crop
5. Apply the clean/friendly visual style

### Step 6: Render

Tell Claude:

> "Render this video"

**Claude will:**
```bash
cd devlog/remotion && npx remotion render DevlogVideo \
  --props="$(cat ../sessions/YYYY-MM-DD/meta/post.json)" \
  --output="../sessions/YYYY-MM-DD/out/final.mp4"
```

### Step 7: Upload

Tell Claude:

> "Upload this video"

**Claude will:**
- Attempt CLI upload to TikTok (if configured)
- Open browser upload pages as fallback
- Copy caption/hashtags to clipboard
- Remind you to add TikTok trending sound in the app

---

## Directory Structure

```
devlog/
├── bin/                        # Automation scripts
│   ├── new-session.sh          # Create dated session folder
│   ├── record-voice.sh         # Record voice line with naming
│   ├── process-voice.sh        # Normalize/clean voice audio
│   ├── trim.sh                 # Trim clip by timestamps
│   ├── crop-vertical.sh        # Convert to 9:16
│   └── upload-tiktok.sh        # CLI upload attempt
├── sessions/
│   ├── raw/                    # OBS replay buffer saves here
│   └── YYYY-MM-DD/             # Date-organized sessions
│       ├── clips/              # Trimmed highlights
│       ├── voice/              # line_01.wav, line_02.wav, etc.
│       ├── meta/               # Remotion manifests (JSON)
│       └── out/                # Final rendered videos
├── remotion/                   # Remotion project
│   ├── src/
│   │   ├── DevlogVideo.tsx     # Main composition
│   │   ├── components/         # Reusable elements
│   │   │   ├── TextOverlay.tsx # Clean text with friendly styling
│   │   │   ├── VoiceSync.tsx   # Voice line timing
│   │   │   └── VerticalCrop.tsx# 9:16 smart crop
│   │   └── styles/             # Cozy indie aesthetic
│   └── package.json
└── README.md                   # This file
```

---

## Remotion Manifest Format

Claude generates this for you:

```json
{
  "title": "Hook viewers in first 3 seconds",
  "fps": 30,
  "durationInSeconds": 45,
  "clips": [
    {
      "src": "../sessions/2024-01-15/clips/bug_swarm.mp4",
      "startFrame": 0,
      "durationInFrames": 90,
      "crop": { "x": 560, "y": 0, "width": 800, "height": 1080 }
    },
    {
      "src": "../sessions/2024-01-15/clips/bug_swarm.mp4",
      "startFrame": 90,
      "durationInFrames": 150,
      "crop": { "x": 400, "y": 0, "width": 800, "height": 1080 }
    }
  ],
  "voiceLines": [
    { "src": "../sessions/2024-01-15/voice/line_01.wav", "startFrame": 0 },
    { "src": "../sessions/2024-01-15/voice/line_02.wav", "startFrame": 90 },
    { "src": "../sessions/2024-01-15/voice/line_03.wav", "startFrame": 180 },
    { "src": "../sessions/2024-01-15/voice/line_04.wav", "startFrame": 270 }
  ],
  "style": {
    "textPosition": "bottom",
    "textStyle": "clean-friendly",
    "includeSubtitles": true
  },
  "upload": {
    "caption": "Found a bug, decided to keep it\n\n#gamedev #indiedev #gamedevelopment #programming",
    "platforms": ["tiktok", "x"]
  }
}
```

---

## Video Specs

| Property | Value | Reason |
|----------|-------|--------|
| Aspect Ratio | 9:16 (1080x1920) | TikTok/Reels native |
| Duration | 30-60 seconds | Optimal for engagement |
| FPS | 30 | Smooth, reasonable file size |
| Voice Style | Short bursts | 3-5 phrases, 5-10s each |
| Music | None (add TikTok sound) | Trending sounds boost reach |
| Visual Style | Clean but friendly | Rounded corners, playful colors, readable |

---

## Content Strategy (from Johan Grunval)

1. **Hook in first 3 seconds**: "I almost deleted this from my game, but..."
2. **Mention it's YOUR game early**: Viewers should know you're the developer
3. **Tell stories, not features**: Bugs that became features, friend reactions, design decisions
4. **Don't clickbait**: Actually deliver on the intrigue
5. **TikTok first, YouTube second**: Test on TikTok, deploy best performers to YouTube at launch
6. **One workday per short**: Story is the value, not production quality

### Story Hooks That Work

| Type | Example Hook |
|------|--------------|
| Bug story | "So I found a bug in my game..." |
| Decision | "I almost deleted this ability..." |
| Discovery | "I didn't expect this to happen..." |
| Progress | "3 months ago vs today..." |
| Reaction | "My friend tried my game and..." |

---

## Troubleshooting

**OBS replay buffer not saving:**
- Check Settings → Output → Replay Buffer is enabled
- Verify the save path exists and is writable
- Make sure you started the replay buffer (not just recording)

**Voice too quiet after processing:**
- `process-voice.sh` normalizes to -16 LUFS
- Adjust the target loudness in the script if needed

**Remotion render fails:**
- Run `cd devlog/remotion && npm install` first
- Check that all file paths in manifest exist
- Verify FFmpeg is installed: `ffmpeg -version`

**Video looks stretched/cropped wrong:**
- The 9:16 crop is calculated from center by default
- Edit the `crop` values in manifest to adjust focus area

---

## Keyboard Shortcuts Summary

| Action | Shortcut |
|--------|----------|
| Save replay (OBS) | Cmd + F10 |
| Start replay buffer | Cmd + F9 |
| Stop replay buffer | Cmd + F8 |
| Stop voice recording | Ctrl + C |

---

## Checklist: Your First Devlog Video

- [ ] Install OBS and configure replay buffer (see First-Time Setup)
- [ ] Install Remotion dependencies: `cd devlog/remotion && npm install`
- [ ] Create first session: `./devlog/bin/new-session.sh`
- [ ] Start replay buffer in OBS
- [ ] Play your game until something interesting happens
- [ ] Press Cmd+F10 to save the moment
- [ ] Tell Claude about the moment and collaborate on script
- [ ] Record voice lines as line_01.wav, line_02.wav, etc.
- [ ] Ask Claude to assemble the video
- [ ] Ask Claude to render
- [ ] Upload to TikTok, add a trending sound
- [ ] Cross-post to X

---

## Example Session Transcript

```
You: I just captured a cool moment - the shader glitch I've been
     debugging actually made the enemies look like they're phasing
     in and out of existence. Saved to replay buffer.

Claude: Nice! That's a great "bug to feature" story. Let me suggest
        some voice lines:

        line_01: "I've been debugging this shader for two days"
        line_02: "And I finally found the bug"
        line_03: "But... look at this"
        line_04: "I think the bug is the feature now"

        Want to adjust any of these?

You: Change line_03 to "But wait... look at what it does"

Claude: Updated! Ready to record:
        - line_01: "I've been debugging this shader for two days"
        - line_02: "And I finally found the bug"
        - line_03: "But wait... look at what it does"
        - line_04: "I think the bug is the feature now"

You: [Records voice lines]

You: Done recording. Assemble this video. Clip is in
     devlog/sessions/raw/Replay_2024-01-15_14-32-01.mp4

Claude: [Analyzes clip, creates manifest, trims to key moments]

        Manifest created. The video is:
        - 42 seconds total
        - Opens on the glitchy shader effect
        - Voice lines sync to visual moments
        - Caption: "The bug is the feature now #gamedev #indiedev"

        Ready to render?

You: Render it

Claude: [Runs Remotion render]

        Done! Video saved to:
        devlog/sessions/2024-01-15/out/shader_bug_feature.mp4

        Ready to upload?

You: Upload to TikTok and X

Claude: [Attempts upload, copies caption]

        Uploaded to TikTok! Don't forget to add a trending sound.
        Caption copied to clipboard for X.
        Opening X upload page...
```
