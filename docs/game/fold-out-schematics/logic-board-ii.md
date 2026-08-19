# Logic Board II assembly drawing

Sheet 2. `ASS'Y DRAWING / LOGIC BD II`, part `A082-91387-C000`, drawing
`M051-00935-C029`, drawn C.L., 12/9/80.

## Placement grid

Columns 1 to 6, rows `A` to `R` skipping `G`, `I`, `O`, `Q`. Blank cells are
positions with no device drawn.

| Row | 1             | 2           | 3         | 4         | 5         | 6         |
| --- | ------------- | ----------- | --------- | --------- | --------- | --------- |
| R   |               | `74LS283`   | `74LS174` | `74LS74`  | `74LS368` | `74LS107` |
| P   | `74LS273`     | `74S89`     | `RXI-5`   | `74LS138` | `74LS74`  | `NVC 293` |
| N   | `CD 4066`     | `74S89`     | `74LS158` | `RXI-2`   | `74LS00`  | `2114-2`  |
| M   |               | `RXI-4` †   | `74LS283` | `74LS377` | `74LS08`  | `2114-2`  |
| L   |               | `74LS157` † | `74LS161` | `74LS86`  | `74LS368` | `2114-2`  |
| K   | `9332 B RX-K` | `74LS157`   | `74LS157` | `74LS283` | `74LS20`  | `2114-2`  |
| J   |               | `74LS157` † | `74LS283` | `74LS86`  | `74LS283` | `2114-2`  |
| H   | `9332 B RX-H` | `74LS157`   | `74LS283` | `74LS86`  | `74LS283` | `2114-2`  |
| F   |               | `74LS374`   |           | `74LS161` | `74LS161` | `2114-2`  |
| E   |               |             |           | `74LS04`  | `74LS245` | `2114-2`  |
| D   | `9332 B RX-D` | `NVC 285`   |           | `74LS374` | `74LS245` | `2114-2`  |
| C   |               |             |           |           | `74LS08`  | `2114-2`  |
| B   | `9332 B RX-B` | `Z-80A-4`   |           | `74LS139` | `74LS32`  | `2114-2`  |
| A   |               |             |           |           | `74LS139` | `2114-2`  |

`X1`, the crystal, is drawn at row `R` level between columns 3 and 4, marked
`18.432 MHz`. It carries the designator `X1` rather than a column-row position.

† Three boxes in column 2 carry no printed designator. `R71/470`, `CP 5` and
`CP 4` occupy the space to their left where a designator would go, and the
drawing simply omits it. Their positions here are assigned by alignment with
their row and column neighbours. The boxes sit on the same gridlines as
everything else, so the assignment is unambiguous, but it is inference rather
than transcription. The same thing happens once on the Board I sheet.

## Sockets

> `T` : 24 PIN SOCKET (4 EA)
> `TT` : 28 PIN SOCKET (1 EA)
> `TTT` : 18 PIN SOCKET (13 EA)
> `TTTT` : 16 PIN SOCKET (3 EA)
> `TTTTT` : 40 PIN SOCKET (1 EA)

Twenty-two socketed positions. Every count matches the grid exactly, which is the
strongest check available on this transcription:

| Symbol  | Pins | Count | Positions                                |
| ------- | ---- | ----- | ---------------------------------------- |
| `T`     | 24   | 4     | `1B`, `1D`, `1H`, `1K` (the mask ROMs)   |
| `TT`    | 28   | 1     | `2D` (the `NVC 285`)                     |
| `TTT`   | 18   | 13    | twelve `2114-2` in column 6, plus `6P`   |
| `TTTT`  | 16   | 3     | `2M`, `3P`, `4N` (the `RXI-` parts)      |
| `TTTTT` | 40   | 1     | `2B` (the `Z-80A-4`)                     |

The 18-pin count is the useful one. Thirteen, being twelve RAMs and the
`NVC 293`. Column 6 holds exactly twelve `2114-2` positions, `6A` through `6N`
skipping the unused letters, and `6P` above them holds the custom.

## The processor

Position `2B` carries a `Z-80A-4` in a 40-pin socket. `X1` at row `R` is marked
`18.432 MHz`.

Both are drawn without comment. The drawing does not divide the crystal down,
does not state a processor clock, and does not say what else the crystal feeds.
`X1` sits at the opposite end of the board from the processor, with `R17/1 K`,
`R18/220`, `R19/220` and `C1/100PF` grouped around it.

## The `*` note: sync bus controller or plug-in board

> `*` NOTE : THIS LOCATION CAN UTILIZE EITHER
>            (A) CUSTOM CHIP NVC 285
>            OR (B) PLUG IN P.C. A082-91383-B000
>                Z-80 SYNC BUSS CONTROLLER (285)

Position `2D` takes either the `NVC 285` custom in its 28-pin socket, or a
plug-in daughter board `A082-91383-B000`. The drawing shows the custom fitted.

## The `**` note: video shifter or plug-in board

> `**` NOTE : THIS LOCATION CAN UTILIZE EITHER
>             (A) CUSTOM CHIP NVC 293
>             OR (B) PLUG IN P.C. A082-91388-A000
>                 VIDEO SHIFTER (293)

Position `6P`, same arrangement. This is the identical note to the one on Board
I, naming the same replacement board part number. The two boards each carry an
`NVC 293` position, and one spare video shifter board fits either.

Between the two sheets, every custom in the machine has a documented TTL
replacement: `A082-91383-B000` for the `NVC 285`, `A082-91388-A000` for the
`NVC 293`. The drawings state the option without saying when it would be taken.

## Mask ROMs

Four 24-pin `9332 B` devices in column 1, each labelled with its row letter:

| Position | Label  |
| -------- | ------ |
| `1B`     | `RX-B` |
| `1D`     | `RX-D` |
| `1H`     | `RX-H` |
| `1K`     | `RX-K` |

Board I carries a fifth, `RX-E` at `8E`, under the same convention. Five mask
ROMs across the pair, each named `RX-` plus the row letter of its socket.

**Column 1 has four ROM positions, not eight.** Positions `1C`, `1E`, `1J` and
`1L` are not drawn. The column goes `1B`, `1D`, `1H`, `1K` with gaps, and every
one is a 24-pin socket. This board takes 4K mask ROMs only. There is no provision
on it for pairs of smaller devices.

That conflicts with Midway's operating manual, whose ROM test table implies eight
sockets and three alternative populations. Compare
[../midway-parts-operating-manual/boards.md](../midway-parts-operating-manual/boards.md).
This sheet is dated 12/9/80 and the manual January 1981, so the likeliest reading
is that the eight-socket layout is a later revision of the board. Neither
document says so, and this is inference.

## The `RXI-` parts

Three 16-pin devices:

| Position | Label   |
| -------- | ------- |
| `3P`     | `RXI-5` |
| `2M`     | `RXI-4` |
| `4N`     | `RXI-2` |

Together with Board I's `RXI-1`, `-3`, `-6` and `-7`, the seven are numbered
across the board pair rather than per board. No sheet says what any of them
contains.

## Other items on the sheet

**Connectors.** Three `24 PIN KK-100 VERT.` connectors down the right-hand edge
of the outline. The lowest is annotated `(RIBBON CABLE ASS'Y)`, the only
connector on either sheet given a cable type.

**Transistor.** `Q6`, marked `2N3391A`, at the left edge near `1N`.

**Passives**, per the legend:

| Group                      | Value                        |
| -------------------------- | ---------------------------- |
| `CP0`–`CP23`               | .1 MF AX. CER.               |
| `RM2`, `RM4`, `RM5`, `RM6` | 1K, 9 or 10 pin SIP resistor |
| `RM1`, `RM3`               | 1K, 6 pin SIP resistor       |
| `C2`                       | 220 MF AL-ELECTRO            |
| `C1`                       | 100 PF                       |

Plus two blanket rules, "ALL CER. CAPS ARE AX. TYPE" and "RESISTOR UNIT : OHM",
and one mechanical note: `RICHO 3/4" STAND-OFF`.

## Comparison with Board I

The two sheets share a drawing style and a draughtsman but describe quite
different boards:

|                      | Board I                 | Board II                |
| -------------------- | ----------------------- | ----------------------- |
| Columns              | 7–12                    | 1–6                     |
| Socketed positions   | 6                       | 22                      |
| Mask ROMs            | 1 (`9332 B`)            | 4 (`9332 B`)            |
| `RXI-` parts         | 4                       | 3                       |
| RAM                  | 6 fitted, 12 footprints | 12 `2114-2`             |
| Customs              | `NVC 293`               | `NVC 285` and `NVC 293` |
| Processor            | none                    | `Z-80A-4`, `18.432 MHz` |
| Alternate-part notes | 3 (`*`, `**`, `XXX`)    | 2 (`*`, `**`)           |

Board II is the more heavily socketed of the two by a wide margin. Nearly every
significant device on it can be pulled, where Board I sockets only its ROM, its
four `RXI-` parts and its custom.
