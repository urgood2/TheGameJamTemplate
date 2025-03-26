🔤 **Text Effects Quick Reference**

| Effect     | Description                  | Arguments (in order)                                      |
|------------|------------------------------|------------------------------------------------------------|
| `color`    | Set text color               | `name` (e.g., "red", "blue")                               |
| `shake`    | Random jitter                | `x amplitude`, `y amplitude`                               |
| `pulse`    | Scale up/down                | `min scale`, `max scale`, `speed`, `stagger`              |
| `rotate`   | Sway rotation                | `speed`, `angle`                                           |
| `float`    | Vertical sine wave           | `speed`, `amplitude`, `offset per char`                   |
| `bump`     | Snap pop on threshold        | `speed`, `amplitude`, `threshold`, `stagger`              |
| `wiggle`   | Quick rotation jitter        | `speed`, `angle`, `stagger`                               |
| `slide`    | Slide in with fade           | `duration`, `stagger`, `alpha mode`, `direction`          |
| `pop`      | Scale in/out pop             | `duration`, `stagger`, `mode`                             |
| `spin`     | Continuous rotation          | `speed`, `stagger`                                        |
| `fade`     | Alpha oscillation            | `speed`, `min alpha`, `max alpha`, `stagger`, `frequency` |
| `highlight`| Flash/brightness pulse       | `speed`, `brightness`, `stagger`, `dir`, `mode`, `width`, `color` |
| `rainbow`  | HSV hue cycling              | `speed`, `stagger`, `threshold step`                      |
| `expand`   | Axis scale wiggle            | `min scale`, `max scale`, `speed`, `stagger`, `axis`      |
| `bounce`   | Drop + bounce                | `gravity`, `height`, `duration`, `stagger`                |
| `scramble` | Random chars → final char    | `duration`, `stagger`, `rate`                             |



# Text Effects Reference

This document explains the available text effects, their parameters, default values, and usage examples.

---

## 🔴 `color`
**Description:** Changes the color of the character.

**Params:**  
1. `name` — `"red"`, `"blue"`, etc.

**Example:**
```text
[color me](color=red)
```

---

## 🔃 `shake`
**Description:** Oscillates the character’s position.

**Params:**  
1. `xAmplitude` (float)  
2. `yAmplitude` (float)

**Example:**
```text
[Shake](shake=2,2)
```

---

## 💓 `pulse`
**Description:** Scales the character up and down in place.

**Params:**  
1. `minScale` (float, default `0.8`)  
2. `maxScale` (float, default `1.2`)  
3. `speed` (float, default `2.0`)  
4. `stagger` (float, default `0.0`)

**Example:**
```text
[Pulse](pulse=0.9,1.1,2,0.2)
```

---

## 🔀 `rotate`
**Description:** Rotates characters back and forth.

**Params:**  
1. `speed` (Hz, default `2.0`)  
2. `angle` (degrees, default `25.0`)

**Example:**
```text
[Spinning](rotate=3.0,30)
```

---

## ☁️ `float`
**Description:** Makes characters bob vertically like floating.

**Params:**  
1. `speed` (default `2.5`)  
2. `amplitude` (default `5.0`)  
3. `offsetPerChar` (default `4.0`)

**Example:**
```text
[Floating](float=2.5,6.0,3)
```

---

## 🩳 `bump`
**Description:** Pops character upward on a sine threshold.

**Params:**  
1. `speed` (default `6.0`)  
2. `amplitude` (default `3.0`)  
3. `threshold` (default `0.8`)  
4. `stagger` (default `1.2`)

**Example:**
```text
[Stomp](bump=6.0,8.0,0.9,0.2)
```

---

## 🌀 `wiggle`
**Description:** Shakes rotation angle quickly.

**Params:**  
1. `speed` (default `10.0`)  
2. `angle` (default `10.0`)  
3. `stagger` (default `1.0`)

**Example:**
```text
[Wiggle](wiggle=12,15,0.5)
```

---

## 🚀 `slide`
**Description:** Slides characters from a direction while fading.

**Params:**  
1. `duration` (default `0.3`)  
2. `stagger` (default `0.1`)  
3. `alphaMode`: `in` or `out`  
4. `direction`: `l`, `r`, `t`, `b`

**Example:**
```text
[Slide In](slide=0.5,0.1,in,l)
```

---

## 💥 `pop`
**Description:** Scales character in or out dramatically.

**Params:**  
1. `duration` (default `0.3`)  
2. `stagger` (default `0.1`)  
3. `mode`: `in` or `out`

**Example:**
```text
[Pop!](pop=0.5,0.1,in)
```

---

## 🔁 `spin`
**Description:** Continuously rotates each character.

**Params:**  
1. `speed` (rotations/sec, default `1.0`)  
2. `stagger` (default `0.5`)

**Example:**
```text
[Spinning](spin=1.5,0.3)
```

---

## 🌫 `fade`
**Description:** Oscillates character alpha over time.

**Params:**  
1. `speed` (default `3.0`)  
2. `minAlpha` (default `0.4`)  
3. `maxAlpha` (default `1.0`)  
4. `stagger` (default `0.5`)  
5. `frequency` (default `3.0`)

**Example:**
```text
[Fade](fade=4.0,0.2,1.0,0.3)
```

---

## 🌟 `highlight`
**Description:** Pulses brightness or color.

**Params:**  
1. `speed` (default `4.0`)  
2. `brightness` (0–1, default `0.4`)  
3. `stagger` (default `0.5`)  
4. `direction`: `left` or `right`  
5. `mode`: `bleed` or `threshold`  
6. `thresholdWidth` (default `0.7`)  
7. `highlightColor` (hex, optional)

**Example:**
```text
[Glow](highlight=5.0,0.5,0.2,left,threshold,0.5,FFDD00)
```

---

## 🌈 `rainbow`
**Description:** Cycles through HSV hues.

**Params:**  
1. `speed` (degrees/sec, default `60`)  
2. `stagger` (default `10.0`)  
3. `thresholdStep` (degrees, optional)

**Example:**
```text
[Rainbow](rainbow=100,5,60)  // Six-color rainbow
```

---

## ↔️ `expand`
**Description:** Scales character along an axis.

**Params:**  
1. `minScale` (default `0.8`)  
2. `maxScale` (default `1.2`)  
3. `speed` (default `2.0`)  
4. `stagger` (default `0.0`)  
5. `axis`: `x`, `y`, or `both`

**Example:**
```text
[Stretch](expand=0.9,1.3,3.0,0.2,y)
```

---

## 🏊 `bounce`
**Description:** Characters fall and bounce once.

**Params:**  
1. `gravity` (default `700`)  
2. `startHeight` (default `-20`)  
3. `duration` (default `0.5`)  
4. `stagger` (default `0.1`)

**Example:**
```text
[Bounce](bounce=600,-30,0.6,0.15)
```

---

## 🔎 `scramble`
**Description:** Flickers random characters before resolving to final value.

**Params:**  
1. `duration` (default `0.4`)  
2. `stagger` (default `0.1`)  
3. `rate` (default `15.0`) → flips/sec

**Example:**
```text
[Scramble](scramble=0.8,0.1,20)
```

