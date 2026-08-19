# The logic board set

Rally-X is two logic boards joined by a 72-pin connector, plus a power supply
board and two small credit boards. The two logic boards mount in a card rack. Its
parts list calls them `GAME LOGIC BOARD ASSY. - BOARD #1` and `- BOARD #2`, held
by two retainers, two side supports and four nylon guides.

The manual never draws the pair as a block diagram. The split below is
reconstructed from the two board schematics and the device inventory on manual
page 40.

```
        +-------------------------------------------------+
        |  Game Logic Board I    A082-91385-C000           |
        |    adjustment switches, volume pot               |
        |    char ROM 8A..8E, RAM 9B..10E, NVC285          |
        |    colour PROMs, LS259 latch, audio output       |
        |    drawing M051-00935-C023                       |
        +----------------------+--------------------------+
                               | 72-pin inter-board connector
        +----------------------+--------------------------+
        |  Game Logic Board II   A082-91387-C000           |
        |    program ROM 1B..1L, RAM 6A..6N, NVC293 @ 6P   |
        |    drawing M501-00935-C024                       |
        +----------------------+--------------------------+
                               | 44-pin cabinet edge connector
                               v
                    controls, monitor, speaker, coin
```

Board I carries the 44-pin cabinet connector. Board II does not. Every cabinet
input and both video and audio outputs land on Board I.

## The boards, by part number

| Part number       | Board                  | Notes                                                                |
| ----------------- | ---------------------- | -------------------------------------------------------------------- |
| `A082-91385-C000` | Game Logic Board I     | Switches, volume pot, char ROM, cabinet connector. `M051-00935-C023` |
| `A082-91387-C000` | Game Logic Board II    | Program ROM, RAM, NVC293. `M501-00935-C024`                          |
| `A084-90414-C935` | Power supply           | See [power.md](power.md)                                             |
| `A082-91109-A000` | Credit Bypass P.C.     | In all three cabinets                                                |
| `A082-91348-C000` | Credit Multiplier P.C. | Optional. Title block says "USED ON PAC-MAN"                         |

The two logic schematic numbers differ in their prefix as drawn. Board I's reads
`M051-` and Board II's reads `M501-`. Every other drawing number in the manual
uses `M051-`, so Board II's is probably a draughting error on the original, but
it is transcribed as it appears.

Both schematics are two-sheet fold-outs, drawn by "M.M." and dated 1/8/81
(Board I) and 1/9/81 (Board II). Their title blocks carry a small legend:
a rectangle means a logic pin, a wedge means a board connector, and `P` marks a
pull-up.

The Credit Multiplier is a shared Midway part, not a Rally-X design. Its title
block names Pac-Man and its drawings carry `M051-00932-*` numbers from that
game's document series. It is a 555, a 74193, two 7474s and a 7414 that turn one
coin pulse into several, and it has nothing to do with game logic.

## The operator controls are on Board I

Both the volume pot and the adjustment (dip) switches are on **Board I**, not
Board II. The manual repeats this on all three cabinet pages with the same
sketch:

```
   +-------------------------------------------+
   |     GAME LOGIC BRD. I (F)                 |
   |     P.C. A082-91385-C000                  |
   |                                           |
   |          ADJUSTMENT ---> [||||||||]       |
   |             SWITCHES                      |
   |                                           |
   |                     VOLUME ---> (O)       |
   |                    CONTROL                |
   +----__----------__-------------------------+
```

The volume pot controls the level of *all* sounds. There is no per-channel trim.

## Program ROM sockets

Board II has eight ROM sockets in column 1: `1B`, `1C`, `1D`, `1E`, `1H`, `1J`,
`1K`, `1L`. They are wired as four logical ROMs of 4K each, and each logical ROM
takes one of three device types.

| Logical ROM | 2K devices (MB8516/2716) | 4K devices (µPD2332, TMM333) | 8K devices (µPD2364) |
| ----------- | ------------------------ | ---------------------------- | -------------------- |
| ROM 1       | `1B` + `1C`              | `1B`                         | `1D` (with ROM 2)    |
| ROM 2       | `1D` + `1E`              | `1D`                         | `1D` (with ROM 1)    |
| ROM 3       | `1H` + `1J`              | `1H`                         | `1K` (with ROM 4)    |
| ROM 4       | `1K` + `1L`              | `1K`                         | `1K` (with ROM 3)    |

*Source: the ROM test table on manual page 6, cross-read with the socket
positions on drawing `M051-00935-C024`.*

A board built with 2K parts fills all eight sockets. With 4K mask ROMs it fills
four. With 8K parts it fills two. All three populations were shipped, and the
self-test reports the same four ROM numbers regardless of which is fitted.

The manual describes sockets and device types only. It does not say where any ROM
lands in the processor's address space, and there is no address map anywhere in
the document.

The schematic labels the sockets `2716` with `(2332)` and `(2364)` annotated
beside `1D` and `1K`, consistent with the table above.

Midway's own assembly drawing for this board, dated 12/9/80, draws four ROM
positions rather than eight, all of them 24-pin. See
[../fold-out-schematics/logic-board-ii.md](../fold-out-schematics/logic-board-ii.md).
The two documents disagree and neither acknowledges the other.

## RAM

Twelve static RAMs, marked `2114-2` on the schematic, paired into six banks. The
self-test names them by bank number and nibble, so `RAM 3H` is the high nibble of
bank 3 and `RAM 3L` is the low nibble. The manual gives the position of each:

| Bank | Low nibble (`L`) | High nibble (`H`) | Bus (from schematic) |
| ---- | ---------------- | ----------------- | -------------------- |
| 1    | `6C`             | `6A`              | CPU RAM data bus     |
| 2    | `6D`             | `6B`              | CPU RAM data bus     |
| 3    | `6K`             | `6J`              | Picture RAM data bus |
| 4    | `6L`             | `6H`              | Picture RAM data bus |
| 5    | `6M`             | `6F`              | Picture RAM data bus |
| 6    | `6N`             | `6E`              | Picture RAM data bus |

*Source: the RAM test table on manual page 6 for the positions. The bus split
comes from the bus labels on drawing `M051-00935-C024`.*

Midway renumbered the bank numbers in a service bulletin dated 11 June 1981,
which calls the same six banks `0` to `5`. The board positions did not change.
See [the bulletin](../midway-service-notes/rally-x-bulletin.md).

The nibble pairing in the test messages means the parts are four bits wide, and
the bus labels put two banks on the CPU side and four on the picture side. The
manual states neither capacity nor address range for either group.

The self-test walks all twelve, as [diagnostics.md](diagnostics.md) sets out.

## Device inventory

Manual page 40 is a per-board list of every device type with a one-line function.
It is the single most informative page in the manual about what the machine is.
It lists types, not positions or quantities.

**Logic Board I** carries `74LS00`, `74LS02`, `74LS04`, `74LS08`, `74LS20`,
`74LS74`, `74LS75`, `74LS86`, `74S89`, `74LS138`, `74LS157`, `74LS161`,
`74LS163`, `74LS174`, `74LS194`, `74LS259`, `74LS273`, `74LS367`, `74LS377`,
`4006`, `4066`, `4070` and `4099`, plus:

| Part              | Function as printed     |
| ----------------- | ----------------------- |
| `NVC293`          | Custom video shifter    |
| `A082-91388-A000` | Video shifter P.C.      |
| `9332`            | 4K x 8 Rom              |
| `2532`            | 4K x 8 Eprom            |
| `IM5623`          | 256 x 4 Prom            |
| `7603`            | 32 x 8 Prom - tri-state |
| `MBM2147`         | 1K x 1 Ram              |
| `93415`           | 1K x 1 Ram              |
| `82S25`           | 16 x 4 Ram              |
| `741`             | Operational amplifier   |
| `MB3730`          | Audio amplifier         |
| `2N3391`, `D40K1` | NPN transistor          |
| `IN914`           | Diode                   |

**Logic Board II** carries `74LS00`, `74LS04`, `74LS08`, `74LS20`, `74LS32`,
`74LS74`, `74LS86`, `74S89`, `74LS107`, `74LS138`, `74LS139`, `74LS157`,
`74LS158`, `74LS161`, `74LS174`, `74LS245`, `74LS273`, `74LS293`, `74LS368`,
`74LS374` and `74LS377`, plus:

| Part              | Function as printed             |
| ----------------- | ------------------------------- |
| `Z80`             | CPU                             |
| `18.432 mhz`      | Crystal                         |
| `NVC285`          | Custom Z80 sync buss controller |
| `A082-91383-B000` | Z80 sync buss controller P.C.   |
| `NVC293`          | Custom video shifter            |
| `A082-91388-A000` | Video shifter P.C.              |
| `9332`            | 4K x Rom                        |
| `2532`            | 4K x 8 Eprom                    |
| `IM5623`          | 256 x 4 Prom                    |
| `7603`            | 32 x 8 Prom - tri-state         |
| `2114`            | 1K x 4 Ram                      |
| `82S25`           | 16 x 4 Ram                      |
| `4066`            | Quad bilateral switch           |
| `2N3391`          | NPN transistor                  |

Four things this page settles that nothing else in the manual states:

**The processor is a Z80**, on Board II, with an 18.432 MHz crystal. Neither
appears anywhere else in the document, not in the text, not in the self-test
description, and not in any other parts list.

**Both customs have a stated function.** `NVC285` is a "Custom Z80 sync buss
controller" and `NVC293` a "Custom video shifter". These are one-line functional
descriptions, not internal descriptions. There is no pinout, no truth table and
no timing.

**Both customs have a TTL replacement board.** `A082-91383-B000` and
`A082-91388-A000` are listed as P.C. assemblies for the sync bus controller and
the video shifter respectively, immediately below the custom they replace. The
manual does not say when one would be fitted instead of the other.

**`NVC293` is listed on both boards**, while `NVC285` is listed only on Board II.
The list gives types rather than positions, so it does not say how many of each a
board carries.

Two entries look like draughting slips and are transcribed as printed. Board II's
`74LS293` is glossed "4 Bit full adder", where a 74LS283 is the adder and a
74LS293 is a counter. Board I's `MBM2147` and `93415` are glossed "1K x 1 Ram",
where both parts are ordinarily 1K x 4. The Board I schematic itself annotates
them `1K x 4`.

The two boards have overlapping but different TTL lists. Board I has the `74LS259`
addressable latch, the `4099`, the `4006` shift register and the CMOS analogue
parts. Board II has the `74LS245` transceiver and the `74LS374`. Neither the
`74LS259` nor the `4099` appears on Board II's list.

## What is on Board I

Board I is the larger of the two. Read off drawing `M051-00935-C023` at the
resolution the scan supports:

| Group             | Positions              | Devices                                                     |
| ----------------- | ---------------------- | ----------------------------------------------------------- |
| Graphics ROM      | `8A`–`8E`              | `2716`, with `8A` a `2364` and `8E` annotated `(2332)`      |
| Fast static RAM   | `9B`–`9E`, `10B`–`10E` | `MBM2147H` and `93415`, marked `1K x 4`                     |
| Colour PROMs      | near `7K`, `9H`        | `7603`, labelled `RXI-1` and `RXI-7`                        |
| Main latch        | `12M`                  | `259`, outputs include `FLIP`, `INT ON`, `SOUND ON`, `BANG` |
| Coin logic        | `11M`, `12L`           | `4099`, `9N`                                                |
| Audio output      | `1N`, `11D`, `11A/11C` | `4066` analogue switches, `MB3730` amplifier                |
| Cabinet connector | right edge             | 44-pin, see [cabinet-io.md](cabinet-io.md)                  |

Two things are worth separating out because the manual's own text contradicts or
omits them.

**The graphics ROMs are on Board I**, not with the program ROMs on Board II. That
is consistent with the self-test, which checks the four program ROMs on Board II
and states that the character ROM is not checked at all. See
[diagnostics.md](diagnostics.md).

**The `259` at `12M` is the machine's main latch.** Its outputs on the drawing
include `FLIP`, `INT ON`, `SOUND ON` and `BANG`. `FLIP`, `INT ON` and `SOUND ON`
also appear on the inter-board connector. `BANG` does not, and the audio
circuitry on Board I uses it locally.

This inventory is partial. The Board I fold-out is the densest drawing in the
manual, spanning two landscape sheets at a scale where much of the TTL is at the
edge of legibility in this scan. Positions and device types above are the ones
that resolved cleanly. Nothing here should be read as a complete parts list for
the board, and no attempt has been made to trace nets.

## Inter-board connector

Both schematics list the same 72 connector pins by name, down the right-hand edge
of Board II's drawing and down the left-hand edge of Board I's. This is the
interface between the two boards. The names are the drawings' own.

| Pin | Signal      | Pin | Signal     | Pin | Signal     |
| --- | ----------- | --- | ---------- | --- | ---------- |
| 1   | `+5V`       | 25  | `INTON`    | 49  | `DB0`      |
| 2   | `+5V`       | 26  | `AB7`      | 50  | `DB1`      |
| 3   | `+5V`       | 27  | `AB8`      | 51  | `DB2`      |
| 4   | `GND`       | 28  | `R//W`     | 52  | `DB3`      |
| 5   | `GND`       | 29  | `CK`       | 53  | `4H*`      |
| 6   | `GND`       | 30  | `A13`      | 54  | `4V*`      |
| 7   | `GND`       | 31  | `AB1`      | 55  | `2V*`      |
| 8   | `COD4`      | 32  | `AB2`      | 56  | `1V*`      |
| 9   | `COD3`      | 33  | `/HBLANK`  | 57  | `COD7`     |
| 10  | `COD5`      | 34  | `AB0`      | 58  | `COD6`     |
| 11  | `COD2`      | 35  | `AB3`      | 59  | `/WREQ`    |
| 12  | `COD1`      | 36  | `Y2`       | 60  | `/CMPSYNC` |
| 13  | `COD0`      | 37  | `Y3`       | 61  | `AUDIO`    |
| 14  | (illegible) | 38  | `Y1`       | 62  | `GND`      |
| 15  | `FLIP`      | 39  | `Y0`       | ..  | `GND`      |
| 16  | `SHIFT0`    | 40  | `MATCH`    | 70  | `GND`      |
| 17  | `SHIFT1`    | 41  | `SOUND ON` | 71  | `+5V`      |
| 18  | `SFTLD`     | 42  | `/VBLANK`  | 72  | `+5V`      |
| 19  | `/RESET`    | 43  | `DB4`      |     |            |
| 20  | `HBLANK`    | 44  | `DB7`      |     |            |
| 21  | `1H`        | 45  | `DB6`      |     |            |
| 22  | `/TC`       | 46  | `DB5`      |     |            |
| 23  | `6M`        | 47  | `4V`       |     |            |
| 24  | `/WRSHI`    | 48  | `/ROSTB`   |     |            |

Pins 62 to 69 are `GND` and pins 70, 71 and 72 are `+5V`.

*Source: drawing `M051-00935-C024`, right-edge connector list.*

Notes on reading this table:

- Pin 14's label did not resolve at any zoom the scan supports. It sits between
  `COD0` and `FLIP` and is probably another clock or code line, but that is a
  guess, and the cell is left blank rather than invented.
- Pins 53–56 carry a trailing mark after the name (`4H*`) that is distinct from
  the plain `4V` on pin 47. Both forms appear on the same drawing, so the mark
  means something, most likely a buffered or inverted copy. The drawing has no
  legend for it.
- `HBLANK` appears twice, once plain on pin 20 and once barred on pin 33. Both
  are drawn deliberately. They are not a transcription error.
- Pin numbering runs 1–72 with no letter side, unlike the cabinet edge connector
  in [cabinet-io.md](cabinet-io.md), which uses the mixed number and letter
  scheme.

The list is the only place in the manual where the hardware designers' own signal
names appear. Nothing else in the document uses them. The text refers to
"sounds", "the picture" and "the PC boards", never to `INTON` or `SFTLD`.

## Monitor

The upright ships a 19-inch dual-sync colour monitor made by Electrohome, Midway
part `0017-00003-0339`. The board drives it over the 6-position monitor colour
interface and a 3-position sync connector, both listed in
[cabinet-io.md](cabinet-io.md). The monitor's own service documentation is not
part of this manual.
