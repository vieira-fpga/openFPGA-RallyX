# Cross-game pages naming Rally-X

Most of both volumes is game-specific. A few pages are catalogue-wide tables, and
four of those name Rally-X.

Do not assume a shared page is the same printing in both volumes. Printed page 1
demonstrably is not, as [README.md](README.md) sets out. Pages 2, 3–6 and 7 below
were read from notes1 only. Their notes2 counterparts were not opened and may be
earlier revisions listing fewer games.

## Printed page 1: Roms and Rams Self Testing

A single table listing every Midway game and how an operator puts it into self
test. Headed `SERVICE BULLETIN / Roms and Rams Self Testing`, with columns `GAME`
and `SELF TEST SWITCH`. The two volumes carry different revisions of this page,
compared in [README.md](README.md). Rally-X appears in both:

| Volume | Row as printed                | Entry             |
| ------ | ----------------------------- | ----------------- |
| notes1 | `RALLY X`                     | `Slide Switch on` |
| notes2 | `Galaxian, Pac-Man & Rally X` | `Slide Switch on` |

The later revision splits the grouped row into one row per game. The entry is
unchanged.

`Slide Switch on` is the entry for the 1980-and-later machines: Galaxian,
Pac-Man, Rally X, Space Zap, Gorf, Wizard of Wor, and in the later revision also
Omega Race, Galaga, Bosconian, Kickman, Ms Pac-Man, Roby Roto, Tron and Solar
Fox. Earlier machines each name a specific dip switch and position instead, for
example Boot Hill `Switch #5 off` and Laguna Racer `Switch #7 off & #8 on`. The
page therefore records a generational change in how Midway exposed the self test,
from a dip switch position to a dedicated slide switch.

That change is not clean. Space Encounters sits among the slide-switch machines
with a dip-switch entry, `Switch #5 off & #6 on`, in both revisions, breaking the
run between Rally X and Space Zap. Whatever ordering the table follows, it is not
strictly chronological by test method.

Two notes close the page, and the second differs between revisions:

> NOTE: Activate coin door tilt switch to start self test.
>
> Invaders, Blue Shark & Lazarian has no Ram and Rom Test.   *(notes1)*
> Invaders & Blue Shark has no Ram and Rom Test.             *(notes2)*

The first is the more useful, and it is the only statement about what the coin
door tilt switch is for on any page examined. Rally-X's own operating manual
draws a tilt switch on all three cabinet harnesses and never says what it does,
as
[../midway-parts-operating-manual/cabinet-io.md](../midway-parts-operating-manual/cabinet-io.md)
records. The note here is written as a blanket instruction under the whole table
rather than against any particular game, so whether it applies to the
slide-switch machines, the dip-switch machines, or both is not stated.

Gun Fight is listed with `None`, and Sea Wolf with `Roms only / Switches #6, #7,
& #8 to off position`.

## Printed page 2: ROM & PROM Chart

A count of memory devices per game, split into two tables with different column
sets. Rally-X is in the second:

| Game      | 8K   | 16K  | 32K | 64K |
| --------- | ---- | ---- | --- | --- |
| `RALLY X` | `NO` | `NO` | `5` |     |

So five devices of one size and none of any other. Its neighbours: Pac-Man `6`
under 32K, Wizard of Wor `7`, Galaga `9`, Gorf `16` under 16K and `8` under 32K.

**The column headings are bit capacities, not byte capacities.** The chart does
not say so, but the first table annotates its columns with part numbers that
settle it: `4K (3604)`, `8K (2708)`, `16K (2716)`. A 2716 is 2K x 8, which is 16K
bits. A 2708 is 1K x 8, which is 8K bits. Read that way, Rally-X's entry is five
32K-bit devices, meaning five parts of 4K x 8.

That reading is derived from the first table's part-number annotations. The
second table, the one containing Rally-X, carries only counts and no part numbers
at all, so nothing on the Rally-X row itself states a device type.

The `(2X)`, `(2XL)`, `(Z80)` and `(NAMCO)` prefixes in the left margin of the
first table mark processor or board families. No such prefix appears against any
entry in the second table.

## Printed pages 3–6: Game Numbers

A four-page catalogue of `GAME (UPRIGHT)`, `DATE` and `GAME NUMBER`, running from
Gun Fight in 1975 to Solar Fox in 1982. The Rally-X row:

| Game      | Date   | Game number |
| --------- | ------ | ----------- |
| `RALLY X` | `1981` | `935`       |

Its neighbours in the 1981 block are Gorf `873`, Wizard of Wor `961`, Omega Race
`929`, Galaga `508` and Kickman `969`. The numbers are not issued in release
order and are not sequential by date. Galaga's `508` sits below Gun Fight's `597`
from six years earlier.

The heading is `GAME (UPRIGHT)`, and only one number is given per title. Cabinet
variants are not listed, so the cocktail and mini are absent.

The table dates Rally-X to 1981. It is a list of Midway game numbers rather than
a release chronology, and the column is headed only `DATE`. It does not say
whether that is a design, release or catalogue date.

One transcription oddity on the page: Space Invaders Deluxe is dated `1089`,
plainly a typo for 1980, and is left as printed here.

## Printed page 7: Different Power Supplies

A two-column list of `GAME` and `POWER SUPPLY NUMBER`.

| Game      | Power supply number  |
| --------- | -------------------- |
| `RALLY X` | `PC A084-90414-C935` |

Galaga is listed with the same supply number. Several other supplies are shared
across two or three games. Space Zap, Gorf and Wizard of Wor all take
`PC A082-90411-A000`. Kickman and Tron both take `PC A082-90412-B000`. 18 Wheeler
and Submarine both take `PC A082-90406-B000`.

The page also groups the whole 1975–1980 range under one entry,
`GUN FIGHT TO SPACE ENCOUNTERS / 8080 SYSTEM (1975-1980)`, with a single supply
number. It is the only place on any page examined that names a processor
generation as a grouping.

## Glossary of computer terms

The last page of each volume. Read here from notes2, printed page 87. notes1
lists a `GLOSSARY OF TERMS` at printed page 91 in its contents, but that page was
not opened, so whether the two are the same printing is unknown.

A general glossary of microprocessor terminology aimed at service staff: Silicon
Valley, hardware, software, bit, byte, memory, ROM, RAM, address, LSI technology,
CPU, microprocessor, register, then short profiles of the Intel 8080, Motorola
6800, Fairchild F-8 and Zilog. The page's own heading is
`Glossary of Computer Terms`, where both tables of contents call it
`GLOSSARY OF TERMS`.

It names no games and contains nothing machine-specific. It is recorded here only
because the Zilog entry is the one place on any page examined that characterises
the processor family:

> The Z-80 executes 158 different instructions, which increase to 696 operation
> codes, compared to 78 instructions and 244 operation codes for the 8080A (the
> first version of the 8080).

## Not read

Other entries in both tables of contents look catalogue-wide from their titles.
`CUSTOM CHIPS`, `PROM STRAPPING SINGLE SUPPLY`, `LOGIC BOARD IC REPLACEMENT`,
`PARTS & OPERATING MANUAL LOCATION`, `MONITOR YOKE WIRING`, `MONITOR
MANUFACTURERS`, `VIDEO GAME MONITORS` and `CARD RACK SYSTEM TEST CARDS` were not
opened.

That gap is worth taking seriously rather than treating as tidy-up. Every
catalogue-wide page examined so far has turned out to carry a Rally-X row, in
four cases out of four, and none of them announces the fact in its
table-of-contents title. The pages above are the same kind of page. Assume they
contain Rally-X entries until someone reads them.

`CUSTOM CHIPS` is the one to read first. The operating manual gives the `NVC285`
and `NVC293` a one-line function each and nothing more, so a catalogue-wide page
under that title is the best remaining chance of learning anything else about
them.
