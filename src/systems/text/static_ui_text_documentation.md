# Static UI Text Tags Guide

This document describes the specific tags and options supported by your **Static UI Text System**, reflecting exactly the segments handled in your `getTextFromString` implementation and the `parseText` logic.
__Since everything is broken up into sub-elements, the entire window should be re-constructed on a language change.__

Tested example:
```
"[Hello here's a longer test\nNow test this](color=red;background=gray) \nWorld Test\nYo man this [good](color=pink;background=red) eh? [img](uuid=gear.png;scale=0.8;fg=WHITE;shadow=false)\nYeah this be an [image](color=red;background=gray)\n Here's an animation [anim](uuid=idle_animation;scale=0.8;fg=WHITE;shadow=false)"

```

---

## Tag Overview

All styled segments use the bracketed syntax:

```
[<keyword or text>](key1=value1;key2=value2;...)
```

* `<keyword or text>`: Either a special tag (`img`, `anim`) or the literal text to style.
* Attributes are provided as `key=value` pairs separated by semicolons (`;`).

Plain text outside of `[...]()` is rendered normally.

---

## Supported Segment Types

### 1. Styled Text

* **Syntax:** `[VisibleText](color=ColorName; background=ColorName)`
* **Attributes:**

  * `color` (string): Foreground color name or hex code.
  * `background` (string): Background color behind the text.

**Example**:

```text
[Warning](color=red; background=black) Proceed carefully.
```

Renders “Warning” in red text on a black background, followed by normal text.

---

### 2. Inline Image

* **Keyword:** `img`
* **Syntax:** `[img](uuid=ResourceID; scale=Float; fg=ColorName; shadow=true|false)`
* **Attributes:**

  * `uuid` (string): Identifier or path for the image asset.
  * `scale` (float, optional): Uniform scale multiplier (default: `1.0`).
  * `fg` (string, optional): Tint color for the image (default: `WHITE`).
  * `shadow` (bool, optional): Whether to draw a drop shadow (default: `true`).

**Example**:

```text
Collect [img](uuid=coin.png; scale=0.5; fg=GOLD; shadow=false) coins!
```

Inserts the `coin.png` icon at half size, tinted gold, with no shadow.

---

### 3. Inline Animation

* **Keyword:** `anim`
* **Syntax:** `[anim](uuid=ResourceID; scale=Float; fg=ColorName; shadow=true|false)`
* **Attributes:**

  * `uuid` (string): Identifier for the animation asset.
  * `scale` (float, optional): Playback scaling factor (default: `1.0`).
  * `fg` (string, optional): Tint color for the animated sprite (default: `WHITE`).
  * `shadow` (bool, optional): Whether to render with a drop shadow (default: `true`).

**Example**:

```text
Loading [anim](uuid=spinner; scale=0.8; fg=WHITE; shadow=true)...
```

Shows the `spinner` animation at 80% scale with a white tint and a shadow.

---

## Multi-line Handling

* The parser splits on `\n` and treats each line as a separate row.
* Tags may span text with embedded line breaks; each line becomes its own container.

**Example**:

```text
First line [Note](color=blue)
Second line [img](uuid=icon.png; scale=1)
```

Results in two rows: one styled text row, and one image row.

---

## Parsing Details

1. **Tag detection**: Regex `\[([^\]]+)\]\(([^\)]+)\)` identifies `[...]()` segments.
2. **Attribute parsing**: Splits on `;`, then on `=`, storing all values as strings.
3. **Segment creation**:

   * `img` → `StaticStyledTextSegmentType::IMAGE`
   * `anim` → `StaticStyledTextSegmentType::ANIMATION`
   * others → `StaticStyledTextSegmentType::TEXT`

Refer to `static_ui_text_system::parseText()` and `getTextFromString()` for the concrete implementation.

---

*End of guide.*
