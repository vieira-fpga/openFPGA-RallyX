# Power supply

Board `A084-90414-C935`. Schematic drawing `M051-00935-C025` (4 Dec 1980),
assembly drawing `M051-00935-C028` (16 Jan 1981).

Recorded here because the supply rails constrain what the rest of the machine
can be. The logic runs on a single +5V rail with a 5A budget, and the audio and
coin circuits run on their own supplies well above it.

## Rails

The supply presents its outputs on a 19-position connector:

| Pin(s)             | Rail      | Rating                   |
| ------------------ | --------- | ------------------------ |
| 17, 18, 19         | +5V       | 5A max, fused at 7A (F3) |
| 4                  | +5V       |                          |
| 9                  | – Sense   | remote sense return      |
| 5–10, 13–14, 15–16 | COM       | common                   |
| 8                  | +72V      | 2A max                   |
| 7                  | +72V      | coin meters              |
| 3                  | +V IND    | ≈10V RMS at 3.5A         |
| 1                  | +V Audio  | ≈13V at 1.5A             |
| 12                 | – V Audio |                          |
| 11                 | – V IND   |                          |
| 6                  | KEY       | key slot, not a rail     |

The `– Sense` line on pin 9 is why pin `T` exists on the cabinet edge connector,
transcribed in [cabinet-io.md](cabinet-io.md). The regulator senses its ground
reference at the load rather than at the board, so voltage drop in the harness
does not pull the logic rail down.

## Regulation

Three regulators, not one. Four devices, because the +5V switcher splits into a
controller and a pass transistor:

| Device             | Position | Role                                 |
| ------------------ | -------- | ------------------------------------ |
| SG3532             | IC80     | Switching regulator controller, +5V  |
| 2N3055             | Q2       | Pass transistor for the +5V switcher |
| LM317              | Q1       | Adjustable linear regulator          |
| TIP31 (or MT87/91) | Q3       | Display lights                       |

The +5V logic rail is switched, not linear. An SG3532 controller drives a 2N3055
through a ferrite bead, with a 20,000 µF bulk capacitor on the input side and a
470 µF output capacitor. A divider of 560 Ω and 510 Ω around a 100 Ω trim pot
(R6) sets the output voltage, so the +5V rail is adjustable and can be out of
tolerance on a real board.

Fuses: F1 2A, F2 8A, F3 7A.

## Transformer

Primary tapped for 115V or 220V operation, selected by a `FOREIGN` / `DOMESTIC`
link on the wiring schematics.

Secondary taps, as drawn: 14.5V, 9V, centre tap, 9V, 14.5V, plus a separate 12V
winding for the display lights.

The manual mentions the extra taps in the installation instructions for all three
cabinets:

> Additional taps have been provided on the transformer to compensate for
> fluctuating line voltage.

The power switch sits in a different place on each cabinet, which is worth
knowing before hunting for it:

| Cabinet  | Power switch location |
| -------- | --------------------- |
| Upright  | Top of the cabinet    |
| Mini     | Back of the cabinet   |
| Cocktail | Bottom of the cabinet |

The power switch is separate from the line voltage safety switch, which is
transcribed in [cabinet-io.md](cabinet-io.md).

## Two things the schematic settles

**Audio leaves the logic boards as one analogue line.** The board emits `AUDIO`
on inter-board connector pin 61, listed in [boards.md](boards.md), into an
amplifier running from the separate ±13V audio rails, through the volume pot on
Board I, into the speaker. Everything between the sound circuitry and the speaker
is analogue and adjustable.

**The +5V logic rail is adjustable.** R6 is a 100 Ω trim pot in the feedback
divider of the switching regulator, so the rail's exact voltage is a field
adjustment rather than a fixed value. The manual gives no setting procedure, no
target voltage and no tolerance. It does not mention R6 in any text, only on the
schematic.
