# Eagle Sound Library Tagging Implementation Plan

## Overview

**Library:** Sound and Music.library
**Total Items:** 37,101
**Folders:** 132 (organized by asset pack/source)
**Goal:** Tag all items to enable intent-based, mood-based, and semantic searching

---

## Tag Groups (Already Created)

| Group ID | Name | Color | Purpose |
|----------|------|-------|---------|
| `MKQ69JE5PL3AM` | Type | 🔵 Blue | Fundamental audio classification |
| `MKQ69JISSVHX2` | Genre/Setting | 🟣 Purple | Aesthetic, era, or world setting |
| `MKQ69JKK94A9W` | Mood/Emotion | 🟡 Yellow | Emotional quality or feeling |
| `MKQ69JLD1H4CJ` | Action/Event | 🔴 Red | Gameplay trigger or event |
| `MKQ69JM04VLAQ` | Element/Material | 🟢 Green | Elemental/material type |
| `MKQ69JMKEVLTR` | Game System | 🩷 Pink | Game context or system |
| `MKQ69JN3N2YJ8` | Technical | 🟠 Orange | Audio properties |

---

## Master Tag Dictionary

### Type (Blue) - What IS this sound?
```
sfx              - Sound effect (non-musical)
music            - Musical composition
ambience         - Background atmosphere/environment
voice            - Human or creature vocalization
foley            - Realistic everyday sounds
transition       - Swooshes, risers, stingers between states
impact           - Collision, hit, or strike sounds
whoosh           - Movement through air
drone            - Sustained tonal atmosphere
stinger          - Short musical punctuation
loop             - Designed to repeat seamlessly
one-shot         - Single play, no loop
```

### Genre/Setting (Purple) - What world does this belong to?
```
fantasy          - Magical medieval/high fantasy
sci-fi           - Futuristic, technological
horror           - Dark, scary, unsettling
medieval         - Historical middle ages (non-magical)
casual           - Light, friendly, mobile-game style
retro            - 8-bit, 16-bit, chiptune aesthetic
cyberpunk        - Neon dystopian future
asian            - Eastern/oriental influenced
lo-fi            - Low fidelity, chill aesthetic
western          - Wild west themed
steampunk        - Victorian + steam technology
modern           - Contemporary real-world
dark-fantasy     - Grim, dark magical settings
space            - Outer space, cosmic
dungeon          - Underground, caves, crypts
tavern           - Inn, pub, social gathering
nature           - Forests, fields, outdoor natural
urban            - City, streets, civilization
underwater       - Aquatic, submerged
ethereal         - Otherworldly, spiritual, divine
```

### Mood/Emotion (Yellow) - How does this FEEL?
```
epic             - Grand, heroic, triumphant
tense            - Suspenseful, anxious
peaceful         - Calm, relaxing, serene
dark             - Ominous, threatening
playful          - Fun, whimsical, lighthearted
mysterious       - Intriguing, unknown
aggressive       - Angry, violent, intense
sad              - Melancholic, sorrowful
triumphant       - Victorious, celebratory
creepy           - Unsettling, eerie
energetic        - Fast, exciting, pumping
somber           - Serious, grave
whimsical        - Quirky, magical, fairy-tale
dramatic         - Emotionally intense
neutral          - No strong emotional direction
hopeful          - Optimistic, uplifting
desperate        - Urgent, last-stand feeling
majestic         - Royal, noble, grand
chaotic          - Disorderly, frantic
serene           - Deeply calm, zen-like
```

### Action/Event (Red) - What triggers this sound?
```
hit              - Successful attack landing
miss             - Attack whiffing
block            - Defensive parry/shield
spell-cast       - Magic ability activation
spell-impact     - Magic hitting target
footstep         - Walking/running movement
jump             - Leaping action
land             - Touching ground after jump
pickup           - Collecting item
drop             - Releasing/dropping item
equip            - Putting on gear
unequip          - Removing gear
use              - Consuming/activating item
open             - Opening container/door
close            - Closing container/door
unlock           - Unlocking mechanism
death            - Entity dying
spawn            - Entity appearing
level-up         - Gaining level/power
reward           - Receiving prize/loot
achievement      - Unlocking achievement
explosion        - Detonation/blast
projectile       - Projectile in flight
melee-swing      - Melee weapon swinging
draw-weapon      - Unsheathing weapon
sheathe          - Putting weapon away
reload           - Reloading weapon
charge           - Charging up attack/ability
release          - Releasing charged attack
buff             - Gaining positive effect
debuff           - Receiving negative effect
heal             - Restoring health
damage           - Taking damage
critical         - Critical hit
combo            - Combo continuation
combo-finish     - Combo ender
dodge            - Evasive maneuver
dash             - Quick movement
teleport         - Instant relocation
summon           - Calling forth entity
dismiss          - Sending away entity
transform        - Changing form
interact         - Generic interaction
craft            - Creating item
build            - Constructing structure
destroy          - Breaking object
collect          - Gathering resource
mine             - Mining ore/stone
chop             - Chopping wood
fish             - Fishing action
cook             - Cooking food
eat              - Eating food
drink            - Drinking liquid
```

### UI Events (Red - subset for interface)
```
ui-click         - Button press
ui-hover         - Mouse over element
ui-confirm       - Confirming action
ui-cancel        - Canceling action
ui-error         - Invalid action feedback
ui-success       - Successful action feedback
ui-open          - Opening menu/panel
ui-close         - Closing menu/panel
ui-navigate      - Moving between options
ui-select        - Selecting option
ui-type          - Typing text
ui-notification  - Alert/notification
ui-purchase      - Buying item
ui-sell          - Selling item
ui-equip         - Equipping from UI
ui-drag          - Dragging element
ui-drop          - Dropping element
ui-scroll        - Scrolling content
ui-tab           - Switching tabs
ui-toggle        - Toggle on/off
card-draw        - Drawing card
card-play        - Playing card
card-flip        - Flipping card
card-shuffle     - Shuffling deck
card-deal        - Dealing cards
dice-roll        - Rolling dice
dice-land        - Dice settling
chip-stack       - Stacking chips/tokens
chip-collect     - Collecting chips
```

### Element/Material (Green) - What's it made of?
```
fire             - Flames, burning, heat
ice              - Frost, freezing, cold
water            - Liquid, splashing, flowing
electric         - Lightning, sparks, voltage
earth            - Stone, rock, ground
wind             - Air, gusts, breeze
thunder          - Deep rumbling, storms
light            - Holy, radiant, bright
dark             - Shadow, void, corrupt
nature           - Plants, organic growth
poison           - Toxic, venomous
acid             - Corrosive, dissolving
arcane           - Pure magical energy
holy             - Divine, sacred
unholy           - Demonic, cursed
psychic          - Mental, telekinetic
metal            - Steel, iron, metallic
wood             - Timber, organic
glass            - Crystalline, shattering
stone            - Rock, mineral
cloth            - Fabric, textile
leather          - Animal hide
flesh            - Organic body
bone             - Skeletal
paper            - Parchment, cards
coin             - Currency, gold
gem              - Jewels, crystals
liquid           - Generic fluid
powder           - Dust, particles
chain            - Links, shackles
```

### Game System (Pink) - Where is this used?
```
combat           - Battle, fighting
inventory        - Item management
card-game        - Card mechanics
loot             - Treasure, rewards
crafting         - Item creation
dialogue         - Conversation
notification     - Alerts, updates
achievement      - Accomplishments
menu             - Main menu, pause
transition       - Scene changes
feedback         - Player action response
tutorial         - Learning, hints
shopping         - Store, merchant
quest            - Mission system
exploration      - Discovery, travel
puzzle           - Problem solving
minigame         - Sub-game activity
social           - Multiplayer, chat
progression      - Leveling, upgrades
death            - Game over, respawn
victory          - Win state
defeat           - Lose state
save             - Save/load system
settings         - Options, config
character        - Character select/creation
```

### Technical (Orange) - Audio properties
```
loop             - Seamlessly loopable
one-shot         - Single play
layerable        - Designed to mix with others
short            - Under 1 second
medium           - 1-5 seconds
long             - Over 5 seconds
24-bit           - High quality source
stereo           - Two channel
mono             - Single channel
loud             - High intensity
soft             - Low intensity
punchy           - Strong transient attack
sustained        - Long decay/release
reverb-wet       - Has reverb baked in
reverb-dry       - No reverb, needs processing
designed        - Heavily processed/synthetic
organic          - Natural recording
synthetic        - Electronically generated
```

---

## Implementation Phases

### Phase 0: Audio Analysis (Pre-Processing)

**IMPORTANT:** Run this phase BEFORE folder-based tagging to extract objective audio properties.

#### Prerequisites

Install required tools (already installed on this system):
```bash
brew install sox aubio ffmpeg
pip3 install librosa numpy
```

#### Audio Analyzer Script

Location: `scripts/eagle_audio_analyzer.py`

This script analyzes audio files and suggests tags based on:

| Analysis | Tool | Tags Generated |
|----------|------|----------------|
| Duration | ffprobe | `short`, `medium`, `long`, `very-short` |
| Channels | ffprobe | `mono`, `stereo` |
| BPM/Tempo | aubio | `slow`, `medium-tempo`, `fast`, `120bpm`, etc. |
| Loudness | sox | `loud`, `soft` |
| Dynamics | sox (crest factor) | `punchy`, `transient`, `sustained`, `compressed` |
| Spectral | librosa | `bright`, `dark`, `bass-heavy`, `electronic` |
| Harmonic content | librosa | `melodic`, `harmonic`, `rhythmic`, `drums` |
| Key detection | librosa | `key-c`, `key-a-sharp`, etc. |
| Energy variation | librosa | `loop` (low variation = loop-friendly) |

#### Running Audio Analysis

**Option 1: Batch Analysis (Recommended)**

1. Export all file paths from Eagle:
   ```
   Use: mcp__eagle-mcp__item_get with fullDetails=true
   Extract: filePath from each item
   Save to: /tmp/eagle_audio_files.txt (one path per line)
   ```

2. Run batch analysis:
   ```bash
   python3 scripts/eagle_audio_analyzer.py --batch /tmp/eagle_audio_files.txt --json > /tmp/audio_analysis.json
   ```

3. Parse results and apply tags:
   ```python
   import json
   with open('/tmp/audio_analysis.json') as f:
       results = json.load(f)

   for item in results:
       item_id = item['eagle_id']  # You'll need to map filepath → Eagle ID
       tags = item['suggested_tags']
       # Use mcp__eagle-mcp__item_add_tags to apply
   ```

**Option 2: Per-File Analysis (Slower, more accurate)**

For each audio file:
```bash
python3 scripts/eagle_audio_analyzer.py "/path/to/audio.wav" --json
```

#### Genre Classification Strategy

Since we don't have ML-based genre classification, we use **rule-based inference** from spectral features:

| Feature Combination | Inferred Genre Tags |
|---------------------|---------------------|
| High spectral centroid (>2500 Hz) + fast tempo | `electronic`, `bright` |
| Low spectral centroid (<1200 Hz) + slow tempo | `ambient`, `dark`, `bass-heavy` |
| High zero-crossing rate (>0.15) | `noisy`, `percussive` |
| Low zero-crossing rate (<0.03) | `smooth`, `tonal` |
| Harmonic ratio > 70% | `melodic`, `harmonic` |
| Percussive ratio > 60% | `rhythmic`, `drums` |
| Low energy variation + long duration | `loop` (good for looping) |
| High crest factor (>12) + short duration | `impact`, `one-shot`, `punchy` |

#### Tempo-Based Tags (Music Only)

| BPM Range | Tags |
|-----------|------|
| < 80 BPM | `slow`, `peaceful` |
| 80-110 BPM | `medium-tempo` |
| 110-140 BPM | `fast`, `energetic` |
| > 140 BPM | `very-fast`, `intense` |

Also adds specific BPM tag rounded to nearest 5: `120bpm`, `140bpm`, etc.

#### Expected Output

After Phase 0, each file will have ~5-10 objective tags like:
- `stereo`, `short`, `punchy`, `bright`, `percussive` (for SFX)
- `stereo`, `long`, `loop`, `125bpm`, `fast`, `energetic`, `key-c` (for music)

#### Estimated Time

- 37,000 files at ~1-2 seconds each (fast mode, no librosa): ~10-20 hours
- 37,000 files at ~3-5 seconds each (full librosa analysis): ~30-50 hours
- **Recommendation:** Run fast mode first, then full analysis on music files only

---

### Phase 1: Bulk Tagging by Folder Name Pattern

Use folder names to apply base tags automatically. Process ALL 132 folders.

#### Folder Pattern → Tag Mapping

| Pattern Match | Tags to Apply |
|---------------|---------------|
| Starts with `SFX -` | `sfx` |
| Starts with `Music -` | `music` |
| Starts with `Soundscapes -` | `ambience`, `loop` |
| Starts with `OGG -` | (no automatic tag, format only) |
| Starts with `WAV -` | (no automatic tag, format only) |
| Contains `Ambien` | `ambience` |
| Contains `Spell` | `spell-cast`, `spell-impact`, `magic` |
| Contains `Fantasy` | `fantasy` |
| Contains `Sci-Fi` or `SciFi` | `sci-fi` |
| Contains `Horror` | `horror`, `dark`, `creepy` |
| Contains `Medieval` | `medieval` |
| Contains `Casual` | `casual`, `playful` |
| Contains `Retro` or `8 Bit` or `8-Bit` | `retro` |
| Contains `Cyberpunk` | `cyberpunk`, `sci-fi` |
| Contains `Asian` | `asian` |
| Contains `Lo-Fi` or `LoFi` | `lo-fi` |
| Contains `Epic` | `epic` |
| Contains `Dark` | `dark` |
| Contains `Impact` | `impact` |
| Contains `Whoosh` | `whoosh`, `transition` |
| Contains `Transition` | `transition` |
| Contains `Fire` | `fire` |
| Contains `Ice` | `ice` |
| Contains `Electric` | `electric` |
| Contains `Thunder` | `thunder` |
| Contains `Water` | `water` |
| Contains `Earth` | `earth` |
| Contains `Wind` | `wind` |
| Contains `Sword` | `melee-swing`, `metal` |
| Contains `Gun` | `projectile` |
| Contains `Explosion` | `explosion` |
| Contains `Monster` or `Creature` | `voice` |
| Contains `Voice` or `Vocal` | `voice` |
| Contains `UI` or `GUI` | `ui-click`, `menu`, `feedback` |
| Contains `Card` | `card-game` |
| Contains `Inventory` | `inventory` |
| Contains `Loot` or `Treasure` | `loot`, `reward` |
| Contains `Coin` or `Gold` or `Gem` | `coin`, `pickup`, `reward` |
| Contains `Footstep` | `footstep` |
| Contains `Dungeon` | `dungeon` |
| Contains `Tavern` | `tavern` |
| Contains `Space` | `space`, `sci-fi` |
| Contains `Loop` | `loop` |
| Contains `Buff` | `buff` |
| Contains `Level Up` | `level-up` |
| Contains `Achievement` | `achievement`, `reward` |
| Contains `Craft` | `crafting` |
| Contains `Portal` | `teleport`, `magic` |
| Contains `Archery` or `Bow` | `projectile` |
| Contains `Punch` or `Kick` | `hit`, `melee-swing`, `combat` |
| Contains `Gathering` or `Mining` | `collect`, `mine` |

---

### Phase 2: Specific Folder Tagging

Apply precise tags to each folder based on content analysis.

#### Complete Folder → Tags Mapping

```
MJ25NEEDUE8BT: TriggerSurvivors
  → sfx, combat, action, feedback

MIX745BYDTUH6: Ambient
  → ambience, loop

MIX745OIHVQUZ: Ambient Vol5 Music Pack
  → music, ambience, loop

MIX7460BF6Y2M: Anime_Game_24bit
  → sfx, asian, 24-bit, combat

MIX7460VBL6H5: Casual Game Achievements
  → sfx, casual, achievement, reward, feedback, playful

MIX7460X4YLF9: Casual Vol 2
  → sfx, casual, playful, feedback

MIX746D2N39L9: Epic Music Pack
  → music, epic, dramatic, fantasy

MIX746SG67RN6: Essentials Earth Spells
  → sfx, spell-cast, spell-impact, earth, fantasy, magic

MIX746SIASX6E: Essentials Electric Spells
  → sfx, spell-cast, spell-impact, electric, fantasy, magic

MIX746SJYABG6: Essentials Fire Spells
  → sfx, spell-cast, spell-impact, fire, fantasy, magic

MIX746SL1MW9I: Essentials Ice Spells
  → sfx, spell-cast, spell-impact, ice, fantasy, magic

MIX746SMM3C26: Essentials Thunder Spells
  → sfx, spell-cast, spell-impact, thunder, fantasy, magic

MIX746SOVXII0: Essentials Water Spells
  → sfx, spell-cast, spell-impact, water, fantasy, magic

MIX746SQG06MB: Essentials Wind Spells
  → sfx, spell-cast, spell-impact, wind, fantasy, magic

MIX746SRHI4ER: Fantasy Creatures
  → sfx, voice, fantasy, creature

MIX746UABI78E: Fantasy Match 3 Sounds
  → sfx, fantasy, casual, puzzle, feedback, playful

MIX746UH8YSBQ: Fantasy vol 2
  → music, fantasy

MIX74787LVTN5: Fantasy Vol4 Music Pack
  → music, fantasy

MIX747NBM7GZI: Futuristic City Ambience
  → ambience, sci-fi, cyberpunk, urban, loop

MIX747NCAO382: Gamemaster Audio - Gun Sound Pack - 24bit 96Khz
  → sfx, projectile, combat, 24-bit

MIX747NK0WHA4: Just Impacts - Basic
  → sfx, impact, short, combat

MIX747NS114GW: Just Impacts - Designed
  → sfx, impact, designed, combat

MIX747NYTK2EO: Just Impacts - Extension 01
  → sfx, impact, combat

MIX747O5ZLP80: Just Impacts - Extension 02
  → sfx, impact, combat

MIX747OF0QDO9: Just Impacts - Processed
  → sfx, impact, designed, combat

MIX747OLPPXTA: Just Transitions - Creepy Trailers
  → sfx, transition, horror, creepy, dark

MIX747OSI5RWH: Just Transitions - SciFi Movement
  → sfx, transition, sci-fi, whoosh

MIX747OXY1D77: Just Whoosh 4 - 1st Strike
  → sfx, whoosh, melee-swing, combat

MIX747P6RTJ1Q: Just Whoosh 4 - 2nd Strike
  → sfx, whoosh, melee-swing, combat

MIX747PF2O3Q8: Just Whoosh 4 - 3rd Strike
  → sfx, whoosh, melee-swing, combat

MIX747PN6Z5NV: Lo-Fi
  → music, lo-fi, peaceful, serene

MIX74808RB026: Magical Vol2 Music Pack
  → music, fantasy, magic, mysterious

MIX7487DM006I: Motion Fx
  → sfx, whoosh, transition

MIX7487M6OM6N: Music - Action Loops Old School Vibes
  → music, retro, energetic, loop, combat

MIX7487NZSVB8: Music - Adaptive Sci-Fi Music
  → music, sci-fi, loop, layerable

MIX7487P9BT1D: Music - Asian RPG Adventure Loops
  → music, asian, fantasy, exploration, loop

MIX7487QFNVEG: Music - Biosphere - Sci-Fi Ambience Loops
  → music, ambience, sci-fi, space, loop

MIX7487R06V77: Music - Blue Cosmos Music Pack
  → music, sci-fi, space, mysterious

MIX7487SXLGOG: Music - Casual Adventure Loops
  → music, casual, exploration, playful, loop

MIX7487TVD8Z7: Music - Casual Game Acoustic Guitar Loops
  → music, casual, peaceful, loop

MIX7487V8S28F: Music - Civilizations 1 - Sci Fi Loops
  → music, sci-fi, epic, loop

MIX7487XFPN9S: Music - Cyberpunk Loops
  → music, cyberpunk, sci-fi, energetic, loop, urban

MIX7487X0GC9U: Music - Dark Piano Loops
  → music, dark, somber, loop

MIX7487YR5NVV: Music - Dark Sci-Fi loops by V8
  → music, sci-fi, dark, tense, loop

MIX7487ZNUMEU: Music - Dystopia Loops
  → music, sci-fi, dark, tense, loop

MIX7488051BGR: Music - Fantasy RPG Music
  → music, fantasy, exploration, epic

MIX74883AQ4CG: Music - Not That Scary Horror Loops
  → music, horror, mysterious, loop

MIX74885ZKA4Q: Music - Sci-Fi Menu Loops
  → music, sci-fi, menu, loop

MIX748874F3ZE: Music - Sci-Fi Platformer And Puzzle
  → music, sci-fi, puzzle, playful

MIX74888F96HV: Music - Solitude
  → music, peaceful, sad, somber

MIX7488AHY5DQ: Music - Strange New Worlds
  → music, sci-fi, space, mysterious, exploration

MIX7488BGIF56: Music - The Omen
  → music, horror, dark, tense

MIX7488D0M5KI: Music - War Drums
  → music, combat, epic, aggressive

MIX7488EXLRFW: Music - Zen Puzzle Music
  → music, peaceful, puzzle, serene

MIX7488FRLR9U: Ni Sound Dark Games
  → sfx, dark, horror

MIX7488RT0VLC: OGG - Ambience Overlays Vol 1
  → ambience, layerable, loop

MIX7488T2XXRM: OGG - Temple Ambiences
  → ambience, fantasy, dungeon, mysterious, loop

MIX7488VUL2WR: SFX - Big Monster Growls Sound Effects
  → sfx, voice, creature, aggressive

MIX748913TPQO: SFX - Bloodbath Sound Effects Pack
  → sfx, combat, hit, flesh, dark, aggressive

MIX7489540J6D: SFX - Bombs And Explosions
  → sfx, explosion, combat, impact

MIX7489AD04DW: SFX - Card And Board Game Pack
  → sfx, card-game, foley, card-draw, card-play, card-shuffle

MIX7489DECBLD: SFX - Card Sound Effects by V8
  → sfx, card-game, foley, card-draw, card-play, card-flip

MIX7489HOLAY8: SFX - Casual Game Female UI Voice
  → voice, casual, ui-notification, feedback

MIX7489N3ZHCN: SFX - Casual Game Sound Kit
  → sfx, casual, feedback, ui-click, playful

MIX7489Q40J9D: SFX - Classic Card Game Foley
  → sfx, card-game, foley, organic

MIX7489WPSCMM: SFX - Coin Bag Sound Effects
  → sfx, coin, pickup, reward, foley

MIX7489ZMW9DQ: SFX - Coins And Gems Pack
  → sfx, coin, gem, pickup, reward

MIX748A2WGRR4: SFX - Cooking Game Sounds
  → sfx, casual, cook, foley

MIX748A5LZ2T6: SFX - Doors and Trap Activations
  → sfx, open, close, interact, dungeon

MIX748A83T64N: SFX - Educational Kids Game Voice Pack
  → voice, casual, tutorial, playful

MIX748AC4YP03: SFX - Elemental Magic Spells by V8
  → sfx, spell-cast, spell-impact, magic, fantasy

MIX748AFUGD5W: SFX - Essential Survival Game
  → sfx, survival, craft, collect

MIX748AJQ99PV: SFX - Fantasy Buff Sounds
  → sfx, buff, magic, fantasy

MIX748ALTT0L4: SFX - Fantasy Character Voices Pack
  → voice, fantasy, combat

MIX748AX5PVPQ: SFX - Fantasy Fire GUI Sounds
  → sfx, ui-click, fantasy, fire, menu

MIX748AZIE3KY: SFX - Fantasy Gathering Sounds
  → sfx, collect, foley, fantasy

MIX748B2SGVQH: SFX - Fantasy Pickaxe Mining
  → sfx, mine, collect, metal, stone

MIX748B4MWMN5: SFX - Fantasy Treasure Loot Sounds by V8
  → sfx, loot, reward, pickup, coin, gem

MIX748B8WORTX: SFX - Fire Spells
  → sfx, spell-cast, spell-impact, fire, magic

MIX748BDPFGXO: SFX - Food & Potions
  → sfx, eat, drink, heal, use

MIX748BFBTKH9: SFX - Gold Sound Effects Pack
  → sfx, coin, pickup, reward

MIX748BI0R2AH: SFX - Heroes Vol1 - Character Voices
  → voice, combat, fantasy

MIX748BMTQ5R1: SFX - Hints Stars Points and Rewards
  → sfx, reward, achievement, feedback, ui-notification

MIX748BPJIFS5: SFX - Human Male Vocal Efforts
  → voice, combat, hit, damage

MIX748BSUYQ0P: SFX - Humanoid Vocal Efforts Pack
  → voice, combat, hit, damage

MIX748BZPQJH1: SFX - Inventory Item Crafting
  → sfx, inventory, craft, equip

MIX748C1YX0V8: SFX - Kids Learning Game
  → sfx, casual, tutorial, playful, feedback

MIX748C9V3MD7: SFX - Level Up 8 Bit Sound Effects
  → sfx, retro, level-up, reward, feedback

MIX748CAOS08T: SFX - Lootbox Sound Effects
  → sfx, loot, reward, open, feedback

MIX748CCFEXC6: SFX - Magical Card Game
  → sfx, card-game, magic, fantasy

MIX748CEUKZ4E: SFX - Magical Moments
  → sfx, magic, fantasy, mysterious

MIX748CHWSUJH: SFX - Medieval Archery
  → sfx, projectile, medieval, combat

MIX748CJR4RDX: SFX - Medieval Armor Inventory
  → sfx, inventory, equip, metal, medieval

MIX748COVOFO8: SFX - Medieval Fantasy Inventory by V8
  → sfx, inventory, equip, fantasy, medieval

MIX748CRFNTVM: SFX - Medieval GUI Sounds
  → sfx, ui-click, menu, medieval

MIX748CTC906U: SFX - Medieval RPG Footsteps
  → sfx, footstep, medieval

MIX748CXFDB4V: SFX - Medieval Weapons Inventory
  → sfx, inventory, equip, draw-weapon, sheathe, metal

MIX748D2ED4PN: SFX - Monster Appearance Audio Cues
  → sfx, spawn, creature, fantasy

MIX748D4FBM15: SFX - Monster Hordes
  → sfx, voice, creature, aggressive

MIX748DC1M1O9: SFX - Monsters Dialogue
  → voice, creature, fantasy

MIX748DO9R7HM: SFX - Portal Sound Effects
  → sfx, teleport, magic, transition

MIX748DQDPB1F: SFX - Punches and Kicks
  → sfx, hit, melee-swing, combat, flesh

MIX748DVAUZVM: SFX - Puzzle Buttons Levers Switches
  → sfx, interact, puzzle, unlock, open

MIX748E4O6IBR: SFX - Retro Weapons And Explosions
  → sfx, retro, combat, explosion, projectile

MIX748E6DM79S: SFX - Savage Steel
  → sfx, hit, melee-swing, metal, combat, aggressive

MIX748EAHBQ0P: SFX - Sci Fi UI Sound Effects
  → sfx, ui-click, menu, sci-fi

MIX748ED8R69K: SFX - Sci-Fi Guns and Laser Beams
  → sfx, projectile, sci-fi, electric

MIX748EFB74IH: SFX - Sci-Fi Monsters And Creatures
  → sfx, voice, creature, sci-fi

MIX748EIVKI6S: SFX - Smart Striking
  → sfx, hit, impact, combat

MIX748EKPP2LJ: SFX - Sounds Of War 1
  → sfx, combat, explosion, aggressive

MIX748ENUPALW: SFX - Sounds Of War 2
  → sfx, combat, explosion, aggressive

MIX748EQ9KP6G: SFX - Sword
  → sfx, melee-swing, hit, metal, combat

MIX748ESLUIG1: SFX - Sword Magic
  → sfx, melee-swing, magic, metal, combat

MIX748EVYVSC6: SFX - Sword Sheathe and Unsheathe
  → sfx, draw-weapon, sheathe, metal

MIX748EWSV3WT: SFX - Sword Sound Effects by V8
  → sfx, melee-swing, hit, metal, combat

MIX748F0WAF2B: SFX - Typing And Text Display - Keyboard & Typewriter
  → sfx, ui-type, foley, dialogue

MIX748F11I0LG: SFX - Ultimate Horror
  → sfx, horror, dark, creepy

MIX748F41TE54: SFX - Ultimate Magic Spells
  → sfx, spell-cast, spell-impact, magic, fantasy

MIX748FAZLJ2J: SFX - Ultimate Monsters and Creatures
  → sfx, voice, creature

MIX748FGZCJLU: SFX - Whoosh - Ultimate Melee Weapons Swings
  → sfx, whoosh, melee-swing, combat

MIX748FJJC6EE: Soundscapes - Dungeon Crawler
  → ambience, dungeon, fantasy, dark, loop

MIX748FLGGP0M: Soundscapes - Medieval Fantasy RPG
  → ambience, medieval, fantasy, loop

MIX748FM0GBEI: Soundscapes - Medieval Tavern Ambience
  → ambience, tavern, medieval, loop

MIX748FNKAO53: Soundscapes - Sci-Fi Control Rooms
  → ambience, sci-fi, loop

MIX748FOHKSLQ: Soundscapes - Sci-Fi Dark Halls
  → ambience, sci-fi, dark, tense, loop

MIX748FP4WY7W: Soundscapes - Temple Ambiences
  → ambience, fantasy, dungeon, mysterious, loop

MIX748FQ3U3CD: Space Horror SFX
  → sfx, space, horror, dark, creepy, sci-fi

MIX748FUEY6V3: Squeaky-Bundle
  → sfx, foley, interact

MIX748G3Q8J6P: Synthwave Music Pack
  → music, cyberpunk, retro, energetic

MIX748X2JQWYH: WAV - Fantasy Spawn Sound Effects
  → sfx, spawn, fantasy, magic

MIX748U8H05GP: Universal Sound
  → sfx, feedback

MIX7NOGNMA46C: Quute UI - User Interface Sound Pack
  → sfx, ui-click, ui-hover, ui-confirm, ui-cancel, menu, feedback, casual
```

---

## Implementation Instructions for Tagging Agent

### Prerequisites

- Access to Eagle MCP tools
- This document for reference

### Step-by-Step Process

#### Step 1: Verify Tag Groups Exist

```
Use: mcp__eagle-mcp__tag_group_get
Expected: 7 tag groups (Type, Genre/Setting, Mood/Emotion, Action/Event, Element/Material, Game System, Technical)
```

#### Step 2: Process Folders in Batches

For each folder in the mapping above:

1. **Get all items in the folder:**
   ```
   Use: mcp__eagle-mcp__item_get
   Parameters: { folders: ["FOLDER_ID"], limit: 1000 }
   ```

2. **Apply tags to all items:**
   ```
   Use: mcp__eagle-mcp__item_add_tags
   Parameters: { ids: [array of item IDs], tags: [tags from mapping] }
   ```

3. **Handle pagination** if folder has >1000 items:
   - Use offset parameter to get next batch
   - Continue until all items are tagged

#### Step 3: Assign Tags to Tag Groups

After all items are tagged, organize tags into their groups:

```
Use: mcp__eagle-mcp__tag_group_add_tags

Operations:
- Type (MKQ69JE5PL3AM): sfx, music, ambience, voice, foley, transition, impact, whoosh, drone, stinger, loop, one-shot
- Genre/Setting (MKQ69JISSVHX2): fantasy, sci-fi, horror, medieval, casual, retro, cyberpunk, asian, lo-fi, space, dungeon, tavern, urban
- Mood/Emotion (MKQ69JKK94A9W): epic, tense, peaceful, dark, playful, mysterious, aggressive, sad, triumphant, creepy, energetic, somber, serene
- Action/Event (MKQ69JLD1H4CJ): hit, miss, block, spell-cast, spell-impact, footstep, pickup, equip, death, spawn, level-up, reward, explosion, projectile, melee-swing, draw-weapon, sheathe, buff, heal, damage, ui-click, ui-hover, ui-confirm, ui-cancel, card-draw, card-play, card-flip, card-shuffle, open, close, interact, collect, mine, craft, teleport
- Element/Material (MKQ69JM04VLAQ): fire, ice, water, electric, earth, wind, thunder, light, dark, nature, poison, arcane, holy, metal, wood, glass, stone, cloth, leather, flesh, bone, paper, coin, gem, liquid
- Game System (MKQ69JMKEVLTR): combat, inventory, card-game, loot, crafting, dialogue, notification, achievement, menu, transition, feedback, tutorial, puzzle, exploration, survival
- Technical (MKQ69JN3N2YJ8): loop, one-shot, layerable, short, medium, long, 24-bit, stereo, mono, punchy, sustained, designed, organic, synthetic
```

#### Step 4: Verification

After completing all folders:

1. **Count tagged items:**
   ```
   Use: mcp__eagle-mcp__tag_get
   Check that tags have item counts > 0
   ```

2. **Spot check random folders:**
   - Pick 5 random folders
   - Verify items have expected tags

3. **Report summary:**
   - Total items tagged
   - Tags created
   - Any errors encountered

---

## Error Handling

### If item_add_tags fails:
- Check if item IDs are valid
- Reduce batch size (try 100 instead of 1000)
- Log failed items for retry

### If folder is empty:
- Skip and log
- Continue to next folder

### If duplicate tags:
- Eagle handles this automatically (no-op)
- Safe to re-run on same folder

---

## Estimated Time

- 132 folders × ~280 items average = ~37,000 items
- At 1000 items per batch with API calls: ~40-50 batches
- Estimated time: 10-15 minutes for full library

---

## Success Criteria

1. ✅ All 37,101 items have at least 2 tags
2. ✅ All tags are organized into appropriate tag groups
3. ✅ Searching by mood (e.g., "epic") returns relevant results
4. ✅ Searching by action (e.g., "spell-cast") returns relevant results
5. ✅ Searching by element (e.g., "fire") returns relevant results
6. ✅ Music files have BPM tags (e.g., "120bpm", "fast")
7. ✅ SFX files have dynamics tags (e.g., "punchy", "short")
8. ✅ Files have channel tags ("mono" or "stereo")

---

## Genre Classification: Limitations & Future Improvements

### Current Approach (Rule-Based)

We use spectral feature analysis to infer genre-like tags. This is **approximate** but runs locally without external APIs.

**What works well:**
- Distinguishing electronic vs. acoustic
- Detecting bright vs. dark timbres
- Identifying percussive vs. tonal content
- Tempo classification

**What doesn't work:**
- Specific sub-genre detection (e.g., "synthwave" vs. "vaporwave")
- Cultural/regional genre identification
- Mood nuances beyond basic categories

### Future Enhancement Options

1. **Install Essentia ML Models** (Medium effort)
   - Essentia has pre-trained models for genre, mood, danceability
   - Requires native ARM build or Docker
   - Accuracy: ~70-80% for broad genres

2. **Cloud Audio Analysis API** (Low effort, costs $)
   - Google Cloud Audio Intelligence
   - Amazon Rekognition Audio
   - Very high accuracy, but costs per file

3. **Local ML Model** (High effort)
   - Train custom classifier on your library
   - Requires labeled training data
   - Best accuracy for your specific use case

4. **Hybrid Approach** (Recommended)
   - Use rule-based for all files (fast, free)
   - Use cloud API for high-value/ambiguous files
   - Manual tagging for priority assets

---

## Quick Reference: Tag Application Order

For best results, apply tags in this order:

1. **Phase 0:** Audio analysis tags (objective, automated)
2. **Phase 1:** Folder pattern tags (broad categories)
3. **Phase 2:** Folder-specific tags (precise context)
4. **Phase 3:** Tag group organization (visual cleanup)
5. **Phase 4:** Verification and spot-checks

This layering ensures:
- Objective tags (BPM, duration) are never overwritten
- Context tags (fantasy, combat) add semantic meaning
- Duplicate tags are handled gracefully by Eagle

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
