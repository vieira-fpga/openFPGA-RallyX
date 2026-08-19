# Cabinet I/O

Everything the logic board set exchanges with the outside world crosses one
44-pin edge connector: five control inputs per player, three start and credit
inputs, four video lines, one audio line, the coin path, and power.

The connector is on Game Logic Board I. Transcribed from the three cabinet wiring
schematics, and cross-checked against the connector list on Board I's own logic
schematic, which [boards.md](boards.md) covers:

| Cabinet        | Game no. | Drawing           |
| -------------- | -------- | ----------------- |
| Upright        | 935      | `M051-00935-A033` |
| Cocktail table | 936      | `M051-00936-A002` |
| Mini           | 937      | `M051-00937-A002` |

All three are dated 1/27/81 and all three drive the same board pair.

## The 44-pin edge connector

Pins are numbered `1`–`22` on one side and lettered on the other, the usual
arcade convention. Two key slots are cut, between `C` and `D` and between `E`
and `F`.

### Numbered side

| Pin | Signal             | Wire    | Notes                                     |
| --- | ------------------ | ------- | ----------------------------------------- |
| 1   | Logic GND          | `R-B`   | tied to pin `A`                           |
| 2   | Logic GND          | `R-B`   | tied to pin `B`                           |
| 3   | +5V                | `R-W`   | tied to pin `C`                           |
| 4   | +5V                | `R-W`   |                                           |
| 6   | Coin meter         | `G-W`   | drives the mechanical counter             |
| 8   | Player 2 Start     | `B-Y`   |                                           |
| 9   | P2 Move Up         | `BLU-Y` | **cocktail only**                         |
| 10  | P2 Move Down       | `O-R`   | **cocktail only**                         |
| 11  | P2 Move Right      | `R-BLU` | **cocktail only**                         |
| 12  | P2 Move Left       | `O-G`   | **cocktail only**                         |
| 13  | P2 Smoke button    | `BLU-R` | **cocktail only**                         |
| 14  | Test switch        | `O-W`   |                                           |
| 15  | Cabinet-type strap | `Y-G`   | grounded on the cocktail only, see below  |
| 16  | Monitor ground     | `RED`   | monitor colour interface pin 3            |
| 17  | Video green        | `GRN`   | monitor colour interface pin 5            |
| 18  | Composite sync     | `ORN`   | monitor sync connector pin 1              |
| 19  | Speaker            | `W-Y`   |                                           |
| 20  | +12V from supply   | `W-BRN` | supply, not signal, see below             |
| 21  | Logic GND          | `Y-G`   | tied to pin `Z`                           |
| 22  | Logic GND          | `Y-G`   |                                           |

### Lettered side

| Pin | Signal             | Wire    | Notes                             |
| --- | ------------------ | ------- | --------------------------------- |
| `A` | Logic GND          | `R-B`   | tied to pin 1                     |
| `B` | Logic GND          | `R-B`   | tied to pin 2                     |
| `C` | +5V                | `R-W`   | tied to pin 3. Key slot after     |
| `D` | +5V                | `R-W`   |                                   |
| `E` | (to Credit Bypass) | `BLU-B` | Key slot after                    |
| `H` | Coin switch        | `O-G`   |                                   |
| `J` | Player 1 Start     | `BR-B`  |                                   |
| `K` | P1 Move Up         | `W-B`   |                                   |
| `L` | P1 Move Down       | `BR-W`  |                                   |
| `M` | P1 Move Right      | `Y-R`   |                                   |
| `N` | P1 Move Left       | `BLU-W` |                                   |
| `P` | P1 Smoke button    | `W-R`   |                                   |
| `R` | Credit switch      | `W-O`   | the cash-box test button          |
| `T` | Common ground      | `R-G`   | the supply senses at this point   |
| `U` | Video red          | `R-Y`   | monitor colour interface pin 6    |
| `V` | Video blue         | `BLU`   | monitor colour interface pin 4    |
| `W` | Speaker            | `G-B`   |                                   |
| `Y` | Logic GND          | `Y-G`   |                                   |
| `Z` | Logic GND          | `Y-G`   | tied to pin 21                    |

### The board's own names for these pins

The tables above were read off the cabinet wiring schematics, which label pins by
wire colour and destination. Board I's logic schematic (`M051-00935-C023`) lists
the same connector with Midway's functional signal names, and where the two
differ the board drawing is the better source.

Controls, coin and audio:

| Pin  | Board I name   | Pin  | Board I name           |
| ---- | -------------- | ---- | ---------------------- |
| `14` | `TEST POS.`    | `9`  | `P2 UP`                |
| `H`  | `COIN S.W.`    | `10` | `P2 DN`                |
| `J`  | `1 PLY SELECT` | `11` | `P2 RT`                |
| `K`  | `P1 UP`        | `12` | `P2 LT`                |
| `L`  | `P1 DN`        | `13` | `P2 SMOKE`             |
| `M`  | `P1 RT`        | `15` | `TO GND FOR C.T. ONLY` |
| `N`  | `P1 LT`        | `19` | `SPKR`                 |
| `P`  | `P1 SMOKE`     | `W`  | `SPKR`                 |
| `R`  | `CREDIT S.W.`  | `7`  | `NC`                   |
| `8`  | `2 PLY SELECT` |      |                        |

Video, supply and ground. This half of the list is drawn as bracketed groups
rather than one label per pin:

| Pin(s)                  | Board I name              |
| ----------------------- | ------------------------- |
| `T`                     | `COMM. GND`               |
| `16`                    | `MONITOR GND`             |
| `A`, `1`, `B`, `2`      | `C.T. GND` / `5 V`        |
| `C`, `3`, `D`, `4`      | `+5 V IN FR. P.S.`        |
| `X`, `20`               | `+12 V IN FR. P.S.`       |
| `Y`, `21`, `Z`, `22`    | `C.T. GND` / `12 V`       |
| `V`                     | `BLUE GUN`                |
| `17`                    | `GRN GUN`                 |
| `U`                     | `RED GUN`                 |
| `18`                    | `COMP. SYNC TO MONITOR`   |
| `5`                     | `PWR CREDIT MULT`, fed from `+5V` |
| `E`                     | `CREDIT MULT`, fed from `/RESET`  |
| `F`                     | `COIN METER`              |
| `6`                     | `COIN C`                  |

The four labels `PWR CREDIT MULT`, `CREDIT MULT`, `COIN METER` and
`COMP. SYNC TO MONITOR` sit slightly out of step with the pin boxes they
annotate, so the `F` and `6` pairing above is the least certain row in the table.
What is unambiguous is the wiring drawn into each pin: `+5V` into `5`, `/RESET`
into `E`, `COIN C` into `6`, and `CMPSYNC` through `R32` into `18`.

Three corrections fall out of this list:

**Pin 7 is `NC`.** Not merely undrawn on the cabinet harnesses. The board drawing
marks it explicitly as no-connect.

**Pin 15 is a cabinet-type strap, not just a ground.** The board names it
`TO GND FOR C.T. ONLY`, grounded on the cocktail table and left open otherwise.
It is an input that tells the board which cabinet it is in, and it is the only
such input on the connector. The cabinet wiring schematics obscure this by
drawing it as one more logic ground on the cocktail sheet and omitting it
elsewhere.

**The grounds are four separate nets, not one.** `A`/`1`/`B`/`2` are the 5 V
ground and `Y`/`21`/`Z`/`22` the 12 V ground, both labelled `C.T. GND`. `T` is
`COMM. GND` and `16` is `MONITOR GND`. The cabinet harnesses draw every one of
them with the same `Y-G` or `R-B` wire and the same `LOGIC GND` caption. That
hides the split entirely.

The start buttons are named `1 PLY SELECT` and `2 PLY SELECT` rather than
"start", and the test switch `TEST POS.` rather than "test".

Letters `F` and `S` do not appear on the cabinet harnesses. Board I's connector
list names `F`, subject to the label placement above. Nothing in the manual names
`S`.

On the cabinet wiring schematics the monitor colour interface entries are **wire
colours, not signal names**. `RED`, `BLU`, `GRN` and `R-Y` are red, blue, green
and red/yellow wires, in the same convention the rest of the harness uses (`R-W`
red/white, `BR-B` brown/black). Reading them as video signals gets two pins
backwards. The wire labelled `RED` runs to pin `16`, which the board calls
monitor ground, and the red/yellow wire runs to pin `U`, which the board calls
the red gun. Take the signal names from the board's own connector list, not from
the harness.

## Controls

Four-way joystick and one button per player. The button is the smoke screen.

**The upright and mini wire Player 1 only.** Player 2's five inputs on pins
`9`–`13` exist solely on the cocktail, where the second control shelf plugs into
them. The cocktail schematic brackets those five pins and labels them
`PLAYER #2 CONTROL`. On an upright, two-player games alternate on the Player 1
stick and pins `9`–`13` are dead.

The two start buttons are wired on all three cabinets regardless: `J` for one
player, `8` for two.

## Video

Four lines to the monitor plus separate composite sync:

```
   board                             monitor
   pin U   red gun       (R-Y wire) -> colour interface 6
   pin 17  green gun     (GRN wire) -> colour interface 5
   pin V   blue gun      (BLU wire) -> colour interface 4
   pin 16  monitor gnd   (RED wire) -> colour interface 3
   pin 18  ORN  --------------------> sync connector 1
```

Composite sync is its own 3-position connector, separate from colour. The
inter-board connector in [boards.md](boards.md) calls this signal `/CMPSYNC`. The
cabinet harness carries it on the orange wire.

## Audio

One audio line off the board on pin 19, returning on pin `W`, into a 6" x 9"
8-ohm 9-watt speaker (Midway part `0017-00003-0187`). Audio supply comes back the
other way on pin 20. The board's connector list calls that rail
`+12 V IN FR. P.S.` and the power supply schematic calls it
`+V AUDIO ≈13V at 1.5 AMP`, one rail under two names.

There is one amplifier and one speaker. The volume pot on Board I sets the level
of everything.

## Coin and credit path

Three separate things get called "credit" in this manual and they are not the
same.

**Coin switch** (pin `H`). The actual coin mechanism switch in the door. Deposits
a coin, advances the mechanical coin meter on pin 6, and awards credits according
to the coinage dip setting.

**Credit switch** (pin `R`). A push button in the cash box area, reachable by
opening the coin door. The manual is explicit about what makes it different:

> This switch is provided as a test aid and awards one credit without advancing
> coin meter.

**Credit Bypass P.C.** (`A082-91109-A000`, via pin `E`). A small board in the
harness of all three cabinets, between the coin switches and the game board.

The optional **Credit Multiplier** board is a fourth thing again and is not
fitted by default. See [boards.md](boards.md).

## Test switch

Pin 14. On the **mini and cocktail** this is a slide switch to the right of the
cash box, next to the credit push button. It is normally `OFF`. Sliding it to
`ON` puts the game in test mode.

The **upright** page of the manual describes only the credit push button and
never mentions a test slide, though the upright wiring schematic clearly shows a
switch on pin 14 labelled `TEST` / `ON`. Either the upright's switch is elsewhere
in the cabinet or its page is simply incomplete. The manual does not resolve
this.

What the test switch does is in [diagnostics.md](diagnostics.md).

## Tilt

A tilt switch appears on all three wiring schematics, on a blue wire, wired in
series with the control ground rail rather than to its own connector pin. The
manual never mentions tilt in any of its text. There is no setup instruction, no
test procedure and no parts callout. It is drawn and then ignored.

A later Midway service bulletin does mention it, and gives it a job: "Activate
coin door tilt switch to start self test." That bulletin covers the whole Midway
catalogue rather than Rally-X specifically, and it is transcribed in
[../midway-service-notes/cross-game-pages.md](../midway-service-notes/cross-game-pages.md).

## Line voltage safety switch

Not a logic signal, but the thing most likely to confuse someone servicing a real
cabinet, and the manual leads with it on every cabinet page:

| Cabinet       | Location                               | Opens when           |
| ------------- | -------------------------------------- | -------------------- |
| Upright, mini | Right rear side, in the back door area | Back door is removed |
| Cocktail      | In the cabinet, left of the coin door  | Coin door is opened  |

To restore power while servicing, pull the switch fully out. The transformer also
has extra taps to compensate for a low or high supply line, as
[power.md](power.md) records.
