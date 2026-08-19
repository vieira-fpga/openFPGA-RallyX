# Logic Board I assembly drawing

Sheet 1. `ASS'Y DRAWING / LOGIC BD I`, part `A082-91385-C000`, drawing
`M051-00935-C030`, drawn C.L., 12/8/80.

## Placement grid

Columns 7 to 12, rows `A` to `R` skipping `G`, `I`, `O`, `Q`. Blank cells are
positions with no device drawn.

| Row | 7         | 8             | 9         | 10        | 11                 | 12          |
| --- | --------- | ------------- | --------- | --------- | ------------------ | ----------- |
| R   | `74LS161` | `74LS377`     | `NVC 293` | `74LS75`  | `74LS157`          |             |
| P   | `74LS86`  | `RXI-7`       | `74LS157` |           | `74LS157`          | `74LS161` † |
| N   | `74LS74`  | `74LS00`      | `74LS04`  | `74LS20`  | `RXI-1`            |             |
| M   | `74LS74`  | `RXI-6`       | `74LS75`  | `74LS00`  | *(latch, sub)*     | *(latch)*   |
| L   | `74LS08`  | `74LS377`     |           | `74LS02`  | `74LS138`          |             |
| K   | `RXI-3`   | `7489`        | *(RAM)*   | *(RAM)*   | `74LS367`          |             |
| J   | `74LS174` | `74LS163`     | *(RAM)*   | *(RAM)*   | `74LS367`          |             |
| H   | `74LS157` | `74LS273`     | `74LS163` | `74LS163` | `74LS367`          |             |
| F   | `74LS174` |               | `74LS163` | `74LS163` | `74LS367`          |             |
| E   | `74LS157` | `9332 B RX-E` | *(RAM)*   | *(RAM)*   | `8 POS. DIP. S.W.` | `741`       |
| D   | `74LS86`  |               | *(RAM)*   | *(RAM)*   | `4066`             |             |
| C   | `74LS157` |               | *(RAM)*   | *(RAM)*   | `4070`             |             |
| B   | `74LS194` |               | *(RAM)*   | *(RAM)*   |                    |             |
| A   | `74LS194` |               |           | `74LS163` | `4006`             | `MB 3730`   |

The positions marked *(RAM)* and *(latch)* carry no part number on the drawing.
They are marked `*` and `**`, and the legend below resolves them. That is the
whole point of those two notes: the board has more footprints than it has parts.

† The `74LS161` at `12P` is placed by alignment, not by its label. See
[the `12P` label](#the-12p-label) below before relying on it.

## The `*` note: RAM, two alternate rows

> `*` : PRIMARY – MBM2147H in LOC. 9B, 9C, 9D, 9E, 9J, 9K
>       SUB – MBM2147E in LOC. 9B, 9C, 9D, 9E, 9J, 9K
>       SUB – 93415 in LOC. 10B, 10C, 10D, 10E, 10J, 10K

Six RAMs, but twelve footprints. Column 9 and column 10 are alternates for each
other, not two banks:

- `MBM2147H` (primary) or `MBM2147E` (substitute) populate **column 9**.
- `93415` (substitute) populates **column 10**.

Only one column is populated on any given board. Reading the grid as twelve RAMs
would double the board's actual memory.

## The `**` note: addressable latch, two alternate positions

> `**` : PRIMARY – 74LS259 in LOC. 12M
>        SUB – CD 4099 in LOC. 11M

Same pattern, one part: a `74LS259` at `12M`, or a CMOS `CD4099` at `11M`. The
two positions are adjacent and only one is populated.

## The `XXX` note: custom chip or plug-in board

> `XXX` : THIS LOCATION CAN UTLIZE EITHER
>         (A) CUSTOM CHIP NVC 293
>         OR (B) PLUG IN P.C. A082-91388-A000 VIDEO SHIFTER (293)

Position `9R` takes either the `NVC 293` custom or a plug-in daughter board,
`A082-91388-A000`, described as a video shifter. The drawing marks the position
`XXX` and shows the custom fitted. ("UTLIZE" is the drawing's spelling.)

## Sockets

> `T` : 16 PIN SOCKET (4 EA)
> `TT` : 18 PIN SOCKET (1 EA)
> `TTT` : 24 PIN SOCKET (1 EA)

Six socketed positions in total, and the counts match the grid exactly:

| Symbol | Pins | Count | Positions               |
| ------ | ---- | ----- | ----------------------- |
| `T`    | 16   | 4     | `7K`, `8M`, `8P`, `11N` |
| `TT`   | 18   | 1     | `9R` (the `NVC 293`)    |
| `TTT`  | 24   | 1     | `8E` (the `9332 B`)     |

Everything else on the board is soldered. The four `RXI-` parts, the one mask ROM
and the one custom are the only socketed devices. The RAM and latch positions
covered by the `*` and `**` notes are not among them.

## The `RXI-` parts and the ROM

Four 16-pin `RXI-` devices are fitted, numbered non-contiguously:

| Position | Label   |
| -------- | ------- |
| `11N`    | `RXI-1` |
| `7K`     | `RXI-3` |
| `8M`     | `RXI-6` |
| `8P`     | `RXI-7` |

The gaps, meaning no `RXI-2`, `-4` or `-5`, are filled on Board II, which carries
those three. The seven `RXI-` parts are numbered across the pair, not per board.

One 24-pin mask ROM at `8E`, marked `9332 B` with the label `RX-E`. The label is
the socket's row letter: `RX-E` sits at row `E`. Board II follows the same
convention.

## Other items on the sheet

**Operator controls.** An `8 POS. DIP. S.W.` at `11E` and a `1K POT` drawn beside
it. This is the only place in this document that locates either.

**Audio.** `741` at `12E`, `MB 3730` at `12A`, with `4066` at `11D` and `4070` at
`11C` nearby.

**Connectors.** Three `24 PIN KK-100 VERT.` connectors down the left edge of the
board outline.

**Passives**, per the legend:

| Group                         | Value               |
| ----------------------------- | ------------------- |
| `D1`–`D5`                     | `IN914B`            |
| `R42`–`R58`                   | 220 Ohm             |
| `R69`, `R70`                  | 1 Ohm 1/2 W         |
| `CP24`–`CP48`, `C8`–`C24`     | .1 MF AX. CER.      |
| `C35`                         | 1 MF TANT           |
| `C5`, `C6`                    | Mylar caps          |
| `RM7`, `RM13`, `RM14`, `RM15` | 1K, 9 or 10 pin SIP |
| `RM8`, `RM10`, `RM12`         | 1K, 6 pin SIP       |

The legend closes with two blanket rules: "UNIT UNMARKED CAPS ARE MF & ALL CAPS
ARE AX. TYPE" and "ALL RESISTOR UNIT Ohm".

**Transistors.** `Q5` marked `2N3391A` and `Q6` marked `D40K1`, both near the top
right of the outline.

## The `12P` label

The `74LS161` in the top-right corner is the one position on this sheet whose
designator does not read cleanly, and it is worth stating exactly what is and is
not known about it.

**What the drawing shows.** The box sits directly right of `11P` and directly
above `12M`, which places it at column 12, row P by alignment. It has *no
designator on its left*, where every other box on the sheet carries one. The
resistor `R38/1 K` occupies that space. A label reading `2P` is printed to the
*right* of the box instead. At 16x the `2P` is clean, with clear whitespace on
both sides and no trace of a leading digit.

**Why the grid says `12P` anyway.** Column 12 row P is where the box physically
is, and `2P` is not a position in this sheet's column range.

More usefully, right-side labelling is a normal habit on this sheet rather than a
one-off. `MB 3730` at the bottom of column 12 has capacitors `C25`, `C26` and
`C27` to its left and is labelled `12 A` on the right, printed with both digits.
So the sheet does displace a designator when passives crowd it, and it does keep
the full column number when it does.

**The reading this leaves.** A dropped `1`. The `12 A` precedent shows the
sheet's own convention would have produced `12P` here, which makes the missing
digit the economical explanation. It remains an inference, because the scan shows
`2P` and nothing else, but it is an inference the sheet supports rather than one
imposed on it.

`2P` is a valid position on the other sheet, where it carries a `74S89`. That
makes "the label belongs to Board II" a tempting reading, but the two boards are
separate drawings of separate assemblies and nothing on either sheet connects
them. It is recorded here only so the coincidence is not mistaken for evidence.

The same label displacement happens elsewhere on both sheets whenever a passive
sits where a designator would go. See [Unlabelled boxes](#unlabelled-boxes).

## Unlabelled boxes

Where a resistor, resistor network or capacitor occupies the space to the left of
a device box, the drawing simply omits that device's designator. The box is drawn
and named by part number, but carries no position.

On this sheet that affects the `74LS161` discussed above. On the Board II sheet
it affects three boxes in column 2.

Positions for such boxes in the grids here are assigned by alignment with their
row and column neighbours. The assignment is unambiguous, because the boxes sit
on the same gridlines as everything else, but it is inference rather than
transcription. It is flagged wherever it occurs.

## The top-right corner

Around the `2P` counter sits a cluster of discrete parts that carry component
designators but no grid position:

| Item                | Value / part                 |
| ------------------- | ---------------------------- |
| `Q5`                | `2N3391A`                    |
| `D4`, `D5`          | (per legend, `IN914B`)       |
| `R67`, `R68`        | 10K                          |
| `R25`, `R38`, `R82` | 1K                           |
| `R59`–`R66`         | 220, 470 and 1K, alternating |
| `C33`, `C34`        | 220 MF and 10 MF AL-ELECTRO  |
| `C38`               | .001                         |
| `CP47`              | (per legend, .1 MF AX. CER.) |

A box marked `S. W.` sits to their right, drawn with a stem running to the board
edge. It is a switch of some kind, unnamed and unnumbered, and it is distinct
from the `8 POS. DIP. S.W.` at `11E`.
