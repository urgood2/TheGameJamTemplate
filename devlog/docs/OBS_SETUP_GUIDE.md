# OBS Replay Buffer Setup Guide

This guide walks you through setting up OBS Studio for always-on game capture with replay buffer on macOS.

## What is Replay Buffer?

Instead of manually starting/stopping recording, OBS constantly records in memory. When something interesting happens, you press a hotkey to save the last N minutes as a file.

**Benefits:**
- Never miss a moment - recording is always on
- No need to predict when something cool will happen
- Low overhead - only writes to disk when you save
- Perfect for catching unexpected bugs, discoveries, and reactions

---

## Step 1: Install OBS Studio

```bash
# Option A: Homebrew (recommended)
brew install --cask obs

# Option B: Download directly
# Visit https://obsproject.com/download
```

---

## Step 2: First Launch & Permissions

When you first launch OBS on macOS:

1. **Screen Recording permission**: System will prompt - click "Open System Preferences"
2. Navigate to: **System Preferences → Privacy & Security → Screen Recording**
3. Enable **OBS** in the list
4. You may need to restart OBS after granting permission

---

## Step 3: Configure Output Settings

### Recording Settings

1. Open OBS → **Settings** (or `Cmd + ,`)
2. Go to **Output** tab
3. Set **Output Mode** to **Advanced** (top dropdown)
4. Click **Recording** sub-tab

Configure:
| Setting | Value | Why |
|---------|-------|-----|
| Type | Standard | Simple and reliable |
| Recording Path | `/Users/YOUR_USERNAME/Projects/TheGameJamTemplate/TheGameJamTemplate/devlog/sessions/raw` | Saves directly to project |
| Recording Format | mp4 | Universal compatibility |
| Video Encoder | Apple VT H264 Hardware Encoder | Uses Mac GPU, low CPU |
| Rate Control | VBR | Good quality/size balance |
| Bitrate | 6000-10000 Kbps | Adjust based on quality needs |
| Keyframe Interval | 2 | Good for trimming |
| Audio Encoder | AAC | Standard |
| Audio Bitrate | 160 | Good quality |

### Replay Buffer Settings

Stay in **Output** tab, click **Replay Buffer** sub-tab:

| Setting | Value | Why |
|---------|-------|-----|
| Enable Replay Buffer | ✓ (checked) | Enables the feature |
| Maximum Replay Time | 300 (seconds) | 5 minutes - plenty of buffer |
| Maximum Memory | 1024 MB | Adjust if you have limited RAM |

Click **Apply** (don't close yet).

---

## Step 4: Configure Video Settings

1. Go to **Video** tab

Configure:
| Setting | Value | Why |
|---------|-------|-----|
| Base (Canvas) Resolution | Your display resolution | Match your screen |
| Output (Scaled) Resolution | 1920x1080 | Good quality, reasonable file size |
| Downscale Filter | Lanczos (Sharpened scaling, 36 samples) | Best quality |
| Common FPS Values | 30 | Smooth, smaller files |

Click **Apply**.

---

## Step 5: Configure Hotkeys

1. Go to **Hotkeys** tab
2. Scroll to find **Replay Buffer** section

Set these hotkeys:
| Action | Suggested Hotkey | Purpose |
|--------|------------------|---------|
| Start Replay Buffer | `Cmd + F9` | Start capture session |
| Stop Replay Buffer | `Cmd + F8` | End capture session |
| Save Replay | `Cmd + F10` | **Main hotkey** - saves last 5 min |

**Tip:** Choose hotkeys that won't conflict with your game. F-keys work well.

Click **Apply**, then **OK**.

---

## Step 6: Add Your Game as a Source

1. In the main OBS window, find **Sources** panel (bottom left)
2. Click **+** to add a source
3. Choose **macOS Screen Capture**
4. Name it "Game Window" or similar
5. Configure:
   - **Method**: Window Capture (if your game runs windowed) or Display Capture
   - **Window**: Select your game's window
   - **Show Cursor**: Your preference

### Optional: Add Game Audio

If you want to capture game audio separately:

1. Click **+** in Sources
2. Choose **Audio Output Capture** (if available) or **macOS Audio Capture**
3. Select your game's audio output

---

## Step 7: Test Everything

1. Click **Start Replay Buffer** button (or press `Cmd + F9`)
   - You should see a red dot or indicator showing it's active
2. Do something on screen for 30 seconds
3. Press **Cmd + F10** (Save Replay)
4. Check the folder: `devlog/sessions/raw/`
5. You should see a new `.mp4` file

**Success!** The replay buffer is working.

---

## Daily Workflow

### Starting Your Dev Session

1. Launch OBS (keep it in background)
2. Press `Cmd + F9` to start replay buffer
3. Develop normally

### When Something Cool Happens

1. Press `Cmd + F10` immediately
2. The last 5 minutes are saved to `devlog/sessions/raw/`
3. Continue working - buffer is still running

### Ending Your Session

1. Press `Cmd + F8` to stop replay buffer
2. Or just quit OBS

---

## Troubleshooting

### "Screen Recording permission denied"
- System Preferences → Privacy & Security → Screen Recording
- Make sure OBS is enabled
- Restart OBS after changing permissions

### Replay not saving
- Check Settings → Output → Replay Buffer is enabled
- Verify the save path exists and is writable
- Make sure replay buffer is actually running (look for indicator)

### Low quality / choppy recording
- Lower the output resolution (try 1280x720)
- Reduce bitrate
- Close other resource-heavy applications

### Hotkeys not working
- Some apps capture global hotkeys - try different key combinations
- Check OBS is running (not minimized to dock)
- On macOS, you may need to allow OBS in Accessibility settings too

### Files too large
- Reduce bitrate (try 4000-6000 Kbps)
- Lower output resolution
- Reduce replay buffer time to 2-3 minutes

---

## Profile Setup (Optional)

You can save this as a profile for quick switching:

1. **Profile** menu → **New**
2. Name it "Game Devlog"
3. All your settings are saved to this profile
4. Switch back anytime with Profile menu

---

## Quick Reference

| Action | Hotkey |
|--------|--------|
| Start Replay Buffer | `Cmd + F9` |
| Stop Replay Buffer | `Cmd + F8` |
| **Save Replay** | `Cmd + F10` |

| Path | Purpose |
|------|---------|
| `devlog/sessions/raw/` | Where OBS saves replays |
| `devlog/sessions/YYYY-MM-DD/clips/` | Trimmed clips for videos |
| `devlog/sessions/YYYY-MM-DD/voice/` | Voice line recordings |

---

## Next Steps

Once OBS is set up:

1. Create a session: `./devlog/bin/new-session.sh`
2. Start replay buffer in OBS
3. Develop your game
4. Press `Cmd + F10` when something interesting happens
5. Tell Claude about the moment to script your video!
