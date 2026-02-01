# Itch.io Landing Page Spec

**Created:** 2026-01-02
**Status:** Draft
**Primary Goal:** Conversion (email signups → Steam wishlists at launch)

---

## Executive Summary

A conversion-optimized landing page for a spell-combining survivors game demo. The page leads with an embedded web demo (the strongest conversion tool), captures emails above and below the fold, and communicates polish through visual design and clear feature communication.

**Core positioning:** "Vampire Survivors meets Noita's spell combining"
**Target audience:** Fans of Vampire Survivors, Noita, roguelike deckbuilders
**First impression goal:** Polish/Trust ("This is quality")
**Bounce risk to address:** "Too confusing" – visitors must immediately understand what kind of game this is

---

## Page Structure

```
┌─────────────────────────────────────────────────┐
│  HEADER: Logo/Title + Tagline                   │
│  EMAIL CTA: Simple signup (above fold)          │
├─────────────────────────────────────────────────┤
│                                                 │
│           EMBEDDED WEB DEMO                     │
│           (Hero - full width)                   │
│                                                 │
├─────────────────────────────────────────────────┤
│  FEATURES: 3 Pillars with GIFs                  │
├─────────────────────────────────────────────────┤
│  COMMUNITY: Discord invite + Social proof       │
├─────────────────────────────────────────────────┤
│  ROADMAP: "We're listening" + Coming Soon       │
├─────────────────────────────────────────────────┤
│  FOOTER: Email CTA (repeat) + Links             │
└─────────────────────────────────────────────────┘
```

---

## Section-by-Section Specification

### 1. Header Section

**Purpose:** Establish identity and capture immediate interest.

**Elements:**
- Game logo/title (name TBD)
- Tagline: Short, genre-clarifying statement
- Optional: Version badge (e.g., "Demo v0.4.2") for polish signal

**Tagline Options (humble/inviting tone):**
- "A spell-combining survivors game"
- "Survive the horde. Combine your spells. Discover chaos."
- "Where Vampire Survivors meets Noita"

**Asset Spec:**
| Asset | Dimensions | Format | Notes |
|-------|------------|--------|-------|
| Logo/Title | 600×150px | PNG (transparent) | Horizontal lockup |
| Favicon | 180×180px | PNG | itch.io uses this size |

---

### 2. Email CTA (Above Demo)

**Purpose:** Capture visitors who may not play the demo but are interested.

**Design:**
- Single horizontal form: `[Email input] [Subscribe button]`
- Minimal copy: "Get notified at launch + occasional updates"
- No checkboxes, no friction
- Subtle, doesn't overshadow demo

**Technical:**
- Embed form from email provider (see recommendations below)
- ButtonDown recommended for simplicity and indie-friendly pricing
- Alternatives: Mailchimp (free tier), ConvertKit (more features)

**Email Service Recommendation:**

| Service | Free Tier | Embed Support | Recommendation |
|---------|-----------|---------------|----------------|
| ButtonDown | 100 subscribers | Yes | Best for simplicity |
| Mailchimp | 500 subscribers | Yes | Most widely used |
| ConvertKit | 1,000 subscribers | Yes | Best for sequences |

---

### 3. Embedded Demo (Hero)

**Purpose:** The primary conversion mechanism. Players who experience the synergy "click moment" (<2 minutes) are primed to convert.

**Technical Spec:**
- Full-width iframe embed (itch.io native)
- Recommended size: **960×640px** minimum (16:10 aspect ratio)
- Maximum comfortable: **1280×720px** (16:9)
- Auto-focus on load (so keyboard works immediately)
- Clear "Click to Play" overlay if needed for browser audio unlock

**itch.io Settings:**
```
Embed options:
☑ Embed in page (WebGL)
☑ Automatically start on page load: OFF (let user initiate)
☑ Enable fullscreen button: ON
☑ Mobile friendly: Test and note limitations
```

**Loading Experience:**
- Show a styled loading bar or spinner matching game aesthetic
- Preload hint: "Click to start" → "Loading spells..." → Game
- If load exceeds 10 seconds, consider a "Taking longer than expected" message with tips

**Post-Run Behavior:**
When player dies or hits content gate:
- Show in-game prompt: "Want more spells? Join the community!"
- Link to Discord or back to page email signup
- Provide "Play Again" option (keep them engaged)

---

### 4. Features Section (3 Pillars)

**Purpose:** For visitors who scroll before playing, communicate the game's identity clearly.

**Structure:**
Each pillar = Icon/GIF + Header + 2-3 sentence description

#### Pillar 1: Spell Synergies
**Header:** "Combine Your Spells"
**Copy:** "Every spell interacts with every other spell. Fire ignites oil. Ice shatters frozen enemies. Discover combinations the developers didn't plan."
**GIF:** Show a spell combo in action (e.g., fire + oil explosion, chain lightning)

#### Pillar 2: Survivors Action
**Header:** "Survive the Horde"
**Copy:** "Waves of enemies. Auto-attacking spells. Dodge, position, and watch your build come alive. Runs take 15-20 minutes."
**GIF:** Screen showing action chaos with UI visible (demonstrate "readable complexity")

#### Pillar 3: Active Development
**Header:** "Built With Your Feedback"
**Copy:** "New spells, enemies, and synergies added regularly. Join the Discord to shape what comes next."
**GIF:** Optional – could show changelog scroll or skip GIF for this pillar

**Asset Spec:**
| Asset | Dimensions | Format | Notes |
|-------|------------|--------|-------|
| Feature GIF | 480×270px | GIF or WebP | 16:9, under 5MB each |
| Feature Icon | 64×64px | PNG | Optional, if not using GIFs |

**Layout Options:**
- **Horizontal row:** 3 columns on desktop, stack on mobile
- **Vertical stack:** Full-width GIF above text for each pillar
- Recommendation: Horizontal row (scans faster, fits "strategic text blocks" goal)

---

### 5. Community Section

**Purpose:** Convert interested players into community members.

**Elements:**
- Discord widget or styled button (primary)
- Social proof: Member count if substantial
- Tone: Inviting, not desperate ("Join fellow spell-slingers")

**Copy:**
```
## Join the Community

Share your wildest spell combos. Report bugs. Vote on what we build next.
Every piece of feedback shapes the game.

[Join Discord Button]

"The devs actually listen!" – Discord member
```

**Asset Spec:**
| Asset | Dimensions | Format | Notes |
|-------|------------|--------|-------|
| Discord button | N/A | Widget or styled link | Use Discord's official embed or custom button |
| Community screenshot | 600×400px | PNG/JPG | Optional: show active discussion |

**Discord Widget Options:**
```html
<!-- Official Discord Widget (light/dark themes available) -->
<iframe src="https://discord.com/widget?id=YOUR_SERVER_ID&theme=dark"
        width="350" height="500"
        allowtransparency="true" frameborder="0">
</iframe>

<!-- Or simple invite button (recommended for cleaner page) -->
<a href="https://discord.gg/YOUR_INVITE" class="discord-button">
  Join Discord
</a>
```

---

### 6. Roadmap Section

**Purpose:** Build trust through transparency, reinforce "we're listening" message.

**Structure:**
- Current version note (e.g., "Demo v0.4.2 – January 2026")
- 2-3 upcoming features teased
- No firm dates (avoid disappointment)
- Link to full roadmap/devlog if available

**Copy Template:**
```
## What's Coming

This demo is just the beginning. Here's what we're working on:

🔮 **More Spells** – 20+ new spells with unique synergies
⚔️ **Boss Encounters** – Test your build against screen-filling bosses
🎴 **Artifact System** – Passive items that change how spells combine

Want to influence what comes next? [Join the Discord →]
```

**Tone:** Excited but not overpromising. Humble framing: "We're building this together."

---

### 7. Footer Section

**Purpose:** Final conversion opportunity + necessary links.

**Elements:**
- Repeat email CTA (different copy): "Don't miss launch day"
- Version/changelog link
- Credits (if relevant)
- Press kit link (optional, for journalists)

**Copy:**
```
---

📬 **Stay Updated**
A few emails between now and launch. No spam.

[Email input] [Subscribe]

---

[Devlog] | [Press Kit] | [Credits]
Demo v0.4.2 | Made with ☕ and ⚡
```

---

## Asset Checklist & Dimensions

### Required Assets (Priority Order)

| Asset | Size | Format | Priority | Placeholder |
|-------|------|--------|----------|-------------|
| **Cover Image** | 630×500px | PNG/JPG | Critical | Solid color + title text |
| **Screenshots** | 1920×1080px | PNG | High | Capture during gameplay |
| **Feature GIFs** | 480×270px | GIF/WebP | High | Static screenshots initially |
| **Logo** | 600×150px | PNG | Medium | Styled text |
| **Favicon** | 180×180px | PNG | Medium | Scaled logo |
| **Background** | 1920×1080px | PNG/JPG | Low | Solid/gradient matching palette |

### itch.io-Specific Image Slots

| Slot | Required Size | Where It Shows |
|------|---------------|----------------|
| Cover image | 630×500px (or 315×250px min) | Browse pages, embeds, social |
| Screenshots | Any, 16:9 recommended | Gallery on game page |
| Background | 1920×1080px | Page background (optional) |
| Banner | 960×480px | Top of page (optional) |

### GIF Recording Guidelines

- **Resolution:** Record at 960×540 or higher, export at 480×270
- **Frame rate:** 15-20 FPS (balance quality vs file size)
- **Duration:** 3-8 seconds per GIF (loop well)
- **File size:** Under 5MB each (itch.io has 10MB limit)
- **Content focus:**
  - Pillar 1: A satisfying spell combo (cause → effect)
  - Pillar 2: Chaos with readable UI (show density)
  - Pillar 3: Optional (could skip or show update scroll)

**Tools:**
- [LICEcap](https://www.cockos.com/licecap/) – Simple GIF recording
- [ScreenToGif](https://www.screentogif.com/) – More control
- [Gifski](https://gif.ski/) – High-quality GIF encoding

---

## Copy Document

### Tagline Options (Pick One)
1. "A spell-combining survivors game"
2. "Survive the horde. Combine your spells."
3. "Where auto-battler meets spell synergy"
4. "Every spell interacts. Every run surprises."

### Description (For itch.io "About" Field)

```markdown
**[GAME NAME]** is a survivors-style action game where every spell
interacts with every other spell.

Inspired by Vampire Survivors' accessible action and Noita's emergent
spell combinations, [GAME NAME] challenges you to build absurd spell
synergies as waves of enemies crash against your defenses.

**Key Features:**
- 🔮 Spell Synergies – Fire ignites oil, ice shatters frozen enemies
- ⚔️ Survivors Action – Auto-attacks, positioning, 15-minute runs
- 🛠️ Active Development – New content regularly, shaped by community feedback

**This is a demo.** The full game is in development.
Join the Discord to follow along and influence what we build.

[Play in browser – no download required]
```

### Email CTA Copy Variants

**Above demo (pre-play):**
> "Get launch updates (just a few emails, no spam)"

**After demo/footer (post-play):**
> "Enjoyed the demo? Get notified when the full game drops."

**In-game death screen:**
> "Want more spells? Sign up for launch updates."

---

## Technical Considerations

### Web Build Optimization

Since the demo is web-only:

1. **Initial load size matters.** Target under 20MB compressed initial download.
2. **Test audio.** Browsers block autoplay – ensure first click unlocks audio.
3. **Mobile:** Decide if supported. If not, show graceful message ("Best played on desktop").
4. **Fullscreen:** Enable itch's fullscreen button for immersion.

### SEO / Discoverability

For mixed traffic strategy (external + organic itch):

**Tags to use:**
- survivors, roguelike, roguelite, action, bullet-hell
- deckbuilder (if applicable), spell, magic, synergy
- indie, singleplayer, web-playable

**Description keywords:**
- Include "Vampire Survivors" and "Noita" explicitly (comparison anchoring)
- Use "spell combining," "synergy," "survivors-like"

**Classification:**
- Genre: Action
- Sub-genre: Roguelike, Survivors
- Input: Keyboard (+ gamepad if supported)

---

## Success Metrics

### Primary Metrics (Track These)

| Metric | Tool | Target |
|--------|------|--------|
| Email signups | Email provider dashboard | Track growth rate |
| Discord joins | Discord server insights | Track from page traffic |
| Demo plays | itch.io analytics | Plays / unique visitors |
| Play time | In-game analytics (if implemented) | Average session length |

### Secondary Metrics

| Metric | What It Tells You |
|--------|-------------------|
| Bounce rate | Is the page confusing? |
| Scroll depth | Are they reading features? |
| Return visits | Is the demo sticky? |

### Qualitative Signals

- Discord feedback sentiment
- Comments on itch.io page
- Social media mentions
- Streamer reactions (if any)

---

## Implementation Checklist

### Phase 1: Minimum Viable Page
- [ ] Create itch.io project
- [ ] Upload web build
- [ ] Write basic description with 3 pillars
- [ ] Add placeholder cover image (solid color + title)
- [ ] Set up email provider (ButtonDown recommended)
- [ ] Embed email form above demo
- [ ] Add Discord link
- [ ] Set pricing: Free, no payment
- [ ] Submit to relevant itch.io tags

### Phase 2: Visual Polish
- [ ] Create proper cover image (630×500px)
- [ ] Record feature GIFs (3)
- [ ] Take screenshots (3-5)
- [ ] Design logo
- [ ] Customize page colors to match game aesthetic
- [ ] Add version badge

### Phase 3: Conversion Optimization
- [ ] Add email CTA to footer
- [ ] Implement in-game death screen CTA
- [ ] Add testimonials/quotes if available
- [ ] Write devlog post introducing the game
- [ ] Set up itch.io analytics tracking

### Phase 4: Maintenance (Ongoing)
- [ ] Update screenshots with major releases
- [ ] Post devlog for major updates
- [ ] Update roadmap section
- [ ] Respond to comments

---

## Appendix: itch.io Page Settings Reference

```
Project type: HTML (web playable)
Kind of project: Game
Release status: In development

Pricing: $0 (free)
Payment mode: No payments

Uploads:
- Web build (HTML5 zip, marked "This file will be played in the browser")

Page settings:
- Theme: Custom colors matching game
- Layout: Default (game at top)
- Font: Default or custom match

Visibility:
- Public (once ready)
- Listed in search results: Yes
```

---

## Open Questions / Future Considerations

1. **Name:** Game name will affect header treatment and SEO
2. **Steam page timing:** When to create Steam page for wishlist CTAs
3. **Press kit:** Consider creating for influencer/press outreach
4. **Localization:** Any plans for non-English support?
5. **Analytics:** Consider lightweight in-game analytics for play metrics

---

*Spec complete. Ready for asset creation and implementation.*

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
