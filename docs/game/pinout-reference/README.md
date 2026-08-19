# Rally-X pinout (third-party text file)

Notes on `Rally-X-Pinout.txt`, a 119-line plain-text edge connector pinout for
Logic Board I.

**This is not a Midway document.** It is one person's transcription, last revised
in 1996, carrying a signed correction and an unresolved question in the author's
own words. It has been checked pin by pin against Midway's own drawings, and it
holds up. See
[Why it looks wrong against the cabinet harness](#why-it-looks-wrong-against-the-cabinet-harness).

## Provenance

The file has no title block. What it does carry:

| Field            | Value                                              |
| ---------------- | -------------------------------------------------- |
| Heading          | `Rally-X Pinouts`                                  |
| Attribution line | `Midway, 9 January 1981`                           |
| Subject          | `Logic Board I, part. no. A082-91385-C000`         |
| Revision         | `modified 96/11/18 by Paul T. (aq929@torfree.net)` |
| Revision note    | `- parts/solder side was reversed`                 |

The revision line is the important one. It records that an earlier version of
this file had the parts and solder sides swapped, mirroring every letter and
number pairing, and that someone corrected it in November 1996. There is no way
from this file to tell how long the wrong version circulated or whether copies of
it are still in circulation.

`Midway, 9 January 1981` is a claim about the source the author worked from, not
a property of this file. Board I's own logic schematic is dated 1/8/81 and Board
II's 1/9/81, so the cited date matches the other board's drawing while the part
number matches this one. Nothing in the file resolves that.

The author is otherwise unidentified. The `torfree.net` domain places the
revision on a community internet provider of the period rather than at any
manufacturer or trade body. That is an inference from the address, which is all
the file gives.

## The pinout as given

Transcribed exactly, including the author's parenthetical notes and question
marks. Blank cells are blank in the source.

| Parts side         | Pin | Pin  | Solder side              |
| ------------------ | --- | ---- | ------------------------ |
| `(+5V) Gnd`        | `A` | `1`  | `Gnd (+5V)`              |
| `(+5V) Gnd`        | `B` | `2`  | `Gnd (+5V)`              |
| `+5V`              | `C` | `3`  | `+5V`                    |
| `+5V`              | `D` | `4`  | `+5V`                    |
| `(?) Credit Mult.` | `E` | `5`  | `Power Credit Mult. (?)` |
| `(Not Used)`       | `F` | `6`  | `Coin Meter`             |
| `Coin Sw.`         | `H` | `7`  | `NC (?)*`                |
| `1P Start`         | `J` | `8`  | `2P Start`               |
| `P1 Up`            | `K` | `9`  | `P2 Up`                  |
| `P1 Down`          | `L` | `10` | `P2 Down`                |
| `P1 Right`         | `M` | `11` | `P2 Right`               |
| `P1 Left`          | `N` | `12` | `P2 Left`                |
| `P1 Smoke`         | `P` | `13` | `P2 Smoke`               |
| `Credit Sw.`       | `R` | `14` | `Test Pos.`              |
|                    | `S` | `15` | `Gnd (Cocktail only)`    |
| `(Common) Gnd`     | `T` | `16` | `Gnd (Monitor)`          |
| `Red`              | `U` | `17` | `Green`                  |
| `Blue`             | `V` | `18` | `Comp. Sync`             |
| `Spkr`             | `W` | `19` | `Spkr`                   |
| `+12V`             | `X` | `20` | `+12V`                   |
| `(+12V) Gnd`       | `Y` | `21` | `Gnd (+12V)`             |
| `(+12V) Gnd`       | `Z` | `22` | `Gnd (+12V)`             |

## The author's footnote

Reproduced in full, because it is the clearest signal in the file about how much
of it is inference:

> \* NC may *not* mean "No Care" for this pinout. I can't figure out what it does
> exactly, but it does have traces in the schematic similar to the other buttons,
> controls, and switches. Elsewhere on the schematic (pin F) there is a "N.C."
> which is, I'm sure, a "No Care" pin.

Two things follow. The author was reading a schematic and inferring, not copying
a manufacturer's table, which is why the file carries `(?)` on pins `E` and `5`
as well. And the author distinguishes two different `NC` marks, and is confident
about one and not the other.

## Where it agrees with the manufacturer's drawings

Checked against the connector list on Board I's logic schematic
(`M051-00935-C023`) and the three cabinet wiring schematics, both transcribed in
[../midway-parts-operating-manual/cabinet-io.md](../midway-parts-operating-manual/cabinet-io.md).

The whole control and coin group matches exactly: `H` coin switch, `J`/`8` start,
`K`–`P` and `9`–`13` the two players' controls, `R` credit switch, `14` test, `6`
coin meter, `W`/`19` speaker, `C`/`D`/`3`/`4` +5V, `A`/`B`/`1`/`2` ground, `17`
green, `V` blue, `18` composite sync.

Two agreements are worth calling out because they are non-obvious.

**Pin 15.** The file gives `Gnd (Cocktail only)`. Midway's board drawing names it
`TO GND FOR C.T. ONLY`. Both treat it as a cabinet-type strap rather than a plain
ground, which the cabinet wiring diagrams alone would not tell you.

**Pin 7.** The file marks it `NC (?)` and spends its only footnote on it.
Midway's board drawing marks pin 7 `NC` outright. The author's uncertainty was
reasonable and the conclusion was right.

## Why it looks wrong against the cabinet harness

An earlier pass through these notes recorded eight entries as *conflicts* with
Midway, on the strength of the three cabinet wiring schematics. That was a
misreading of those schematics, not a fault in this file. The file is right on
all eight.

The cabinet wiring schematics label the monitor and supply lines by wire colour:
`RED`, `BLU`, `GRN`, `R-Y`, `W-BRN` and `R-G`, in the same convention they use
for `R-W` red/white and `BR-B` brown/black everywhere else. Board I's own logic
schematic (`M051-00935-C023`) lists the same connector with functional signal
names. On the pins in question those two things do not line up, and the board's
list is the authority:

| Pin                  | This file          | Board I connector list           | Verdict                  |
| -------------------- | ------------------ | -------------------------------- | ------------------------ |
| `T`                  | `(Common) Gnd`     | `COMM. GND`                      | agrees                   |
| `16`                 | `Gnd (Monitor)`    | `MONITOR GND`                    | agrees                   |
| `U`                  | `Red`              | `RED GUN`                        | agrees                   |
| `17`                 | `Green`            | `GRN GUN`                        | agrees                   |
| `V`                  | `Blue`             | `BLUE GUN`                       | agrees                   |
| `X`, `20`            | `+12V`             | `+12 V IN FR. P.S.`              | agrees                   |
| `Y`, `Z`, `21`, `22` | `Gnd (+12V)`       | `C.T. GND` / `12 V`              | agrees                   |
| `E`, `5`             | `Credit Mult. (?)` | `CREDIT MULT`, `PWR CREDIT MULT` | agrees. The `(?)` can go  |

The video pins are the instructive case. The harness runs a red/yellow wire to
pin `U` and a solid red wire to pin `16`. Read as signal names, those look like
red video on `16`. Read as wire colours, which is what they are, the board puts
the red gun on `U` and monitor ground on `16`, exactly as this file says.

So the file's author was working from the logic schematic, which is the better
source, and got the video and supply groups right. The `(?)` marks on pins `E`
and `5` were unnecessary caution. The board list names both.

## What it still does not resolve

**Pin `F`.** The file gives `(Not Used)` and the footnote reasons that pin `F` is
marked `N.C.` on the schematic. Board I's list does carry a `COIN METER` label in
that group, but the four labels there sit slightly out of step with their pin
boxes, so the scan does not settle whether `COIN METER` belongs to `F` or to `6`.
The file's `(Not Used)` for `F` and `Coin Meter` for `6` is one reading of an
ambiguous drawing, not a contradiction of it.

**Pin `S`.** Left blank on the parts side here. Board I's list does not name it
either.

## Using this file

Every pin in it that can be checked against Board I's connector list checks out,
including the video and supply groups that a comparison against the cabinet
harness alone makes look wrong. For the 44-pin connector it is a sound reference.

Two cautions remain, both about the file itself rather than its content. An
earlier revision had the parts and solder sides reversed, so check any copy found
elsewhere for the `96/11/18` line before trusting it. And it covers Logic Board
I's edge connector only, not the 72-pin inter-board connector and not Board II.
