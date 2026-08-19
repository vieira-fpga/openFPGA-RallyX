# Midway's Rally-X Parts and Operating Manual

Notes on *Midway's Rally-X Parts and Operating Manual*, Game Nos. 935, 936 & 937,
January 1981. Midway Mfg. Co., a Bally company, 10750 West Grand Avenue, Franklin
Park, Illinois 60131. Document `M NO. 0935-00300-0000`.

These pages record what the manual says about the 1980 arcade machine. Where the
manual is silent, these notes are silent.

## What kind of document this is

An operator's manual. Midway wrote it for a route technician with a screwdriver,
so it is precise about what an operator can see, set and touch, and silent about
almost everything else.

That shapes what the manual can tell you. There is no memory map, no port bit
table, no ROM checksum list, no cycle timing, and nothing about the custom parts
beyond a one-line function each. What it does have is the factory switch card,
the self-test behaviour, the ROM socket options, the cabinet wiring, a per-board
device inventory, and full schematics for both logic boards.

The manual covers three cabinets built around one board set:

| Game no. | Cabinet        |
| -------- | -------------- |
| 935      | Upright        |
| 936      | Cocktail table |
| 937      | Mini           |

## Contents

| Page                               | Contents                                                                 |
| ---------------------------------- | ------------------------------------------------------------------------ |
| [boards.md](boards.md)             | The two-board logic set, ROM and RAM socket map, inter-board connector   |
| [cabinet-io.md](cabinet-io.md)     | 44-pin edge connector, controls, video, audio, coin and credit path      |
| [diagnostics.md](diagnostics.md)   | Power-on self-test, test mode, error messages, the switch and sound test |
| [dip-switches.md](dip-switches.md) | The factory switch adjustment card                                       |
| [gameplay.md](gameplay.md)         | Scoring, fuel, the Special Check Point, the Challenging Stage            |
| [power.md](power.md)               | Transformer, regulators, supply rails and their current limits           |

## Scope

**The manual is Rally-X.** It is dated January 1981 and its switch card is headed
`(RALLY-X)`. New Rally-X was released later that year and no New Rally-X material
appears anywhere in these 52 pages.

**Both logic boards are drawn.** The manual carries full schematics for Board I
and Board II, as two two-sheet fold-outs on the four landscape pages near the
back. They are the densest pages in the document and are only partly transcribed
here. [boards.md](boards.md) records what has been read off them and what has
not.

**The manual describes sound and video by symptom, not by circuit.** It names
fourteen distinct sounds and describes what the screen does in test mode, but
never explains in prose how either is generated. The schematics show the
circuits. No text accompanies them.

**Roughly half the manual is mechanical.** The pages between the switch card and
the schematics are cabinet parts lists covering plexiglass, decals, coin doors,
leg levelers and wood, ordered by part number, one photograph page and one table
page per assembly. They are not transcribed here beyond the electrical items that
appear in them.

## Reading these notes

**Everything here is transcribed from a scan.** The source is a 52-page scanned
PDF with no text layer. Every table was read off a rendered page image. Where a
glyph did not resolve it is marked `(illegible)` rather than guessed.

**Derived statements are labelled.** A few facts here come from reading two pages
of the manual against each other rather than off one printed table. The RAM bus
split in [boards.md](boards.md) is the main one. Those say so at the point of
use. Nothing here is filled in from outside the manual.

**The manual is a primary source, not a verified one.** It is Midway's own
document, which makes it better than most of what circulates. It is still a
45-year-old operator's manual, and a few of its statements are incomplete or
internally inconsistent. Those are flagged where they appear rather than
resolved. Midway itself corrected one of them in a later service bulletin, which
is transcribed in
[../midway-service-notes/rally-x-bulletin.md](../midway-service-notes/rally-x-bulletin.md).

## Conventions

Board positions are given as the manual gives them, a column number and a row
letter, for example `6P` or `1B`. These are silkscreen positions and are the only
names the manual uses for parts. There are no reference designators.

Signal names are transcribed as drawn. An overbar in a schematic is written here
as a leading `/`, so a barred `RESET` is `/RESET`.

Wire colours use the manual's two-letter abbreviations: `R-W` is red/white,
`BLU-Y` blue/yellow, `BR-B` brown/black. They are recorded because on a real
board the colour is often easier to trace than the pin.

Text in block quotes is verbatim from the manual, including its typographical
errors.

## Provenance

Transcribed from `.ignore/rallyx.pdf`. Individual drawing numbers are cited on
the page that uses them.

The scan carries at least one handwritten annotation from a previous owner.
[diagnostics.md](diagnostics.md) reproduces it and marks it as such. It is not
Midway's word and is not corroborated by the manual.

Rally-X © 1980 NAMCO LTD. The manual is Midway's.
