# Rally-X logic board assembly drawings

Notes on the two-sheet document filed as
`Rally-X_Schematics_(Fold_out_Earlier_Style)_(Logic_Board_I_&_II).pdf`.

**These are assembly drawings, not schematics.** Both sheets are titled
`ASS'Y DRAWING` in their own title blocks. There is no circuit diagram, no net,
and no signal name anywhere in the document. It is a component placement map and
a bill-of-materials legend. The words "Schematics" and "Earlier Style" come from
the filename, which is an archivist's label. Neither phrase appears on either
sheet.

The real schematics are in Midway's parts and operating manual, transcribed in
[../midway-parts-operating-manual/boards.md](../midway-parts-operating-manual/boards.md).

## The two sheets

| Sheet | Title block   | Board part no.    | Drawing no.       | Drawn | Date    |
| ----- | ------------- | ----------------- | ----------------- | ----- | ------- |
| 1     | `LOGIC BD I`  | `A082-91385-C000` | `M051-00935-C030` | C.L.  | 12/8/80 |
| 2     | `LOGIC BD II` | `A082-91387-C000` | `M051-00935-C029` | C.L.  | 12/9/80 |

Both carry `USED ON RALLY-X`, `NO. REQ'D 1 PER`, and the Midway Mfg. Co.,
Franklin Pk., Ill. title block. The revisions block on each sheet is empty, so
these are the drawings as first issued.

| Page                                   | Contents                                       |
| -------------------------------------- | ---------------------------------------------- |
| [logic-board-i.md](logic-board-i.md)   | Sheet 1, placement grid and legend, Board I    |
| [logic-board-ii.md](logic-board-ii.md) | Sheet 2, placement grid and legend, Board II   |

## What an assembly drawing gives you

Each sheet draws the board outline with every device as a labelled box at its
silkscreen position, plus a `NOTE:` legend covering socket types, passive values,
and part substitutions. That makes this document authoritative for three things
nothing else states:

- **Which device sits at which position**, for both boards.
- **Which positions are socketed and with what pin count**, including a count of
  each socket type per board.
- **Which positions accept alternate parts**, and what the alternates are. That
  covers the RAM and latch substitutions on Board I and the custom-chip plug-in
  replacements on both boards.

It gives you nothing about behaviour. There are no signals, no buses, no timing,
and no description of what any part does.

## Position notation

Positions are a column number and a row letter, for example `9R`, `1B` or `6P`.
Board I uses columns 7 to 12. Board II uses columns 1 to 6.

Designators are normally printed to the left of their box. Where a resistor or
capacitor occupies that space, the drawing omits the designator entirely. Four
boxes across the two sheets are affected, one on Board I and three on Board II.
Positions for those are assigned by alignment with row and column neighbours and
are marked `†` in the grids. The Board I case also carries a displaced label that
does not parse against its own sheet's column range, discussed in
[the `12P` label](logic-board-i.md#the-12p-label).

Row letters run `A B C D E F H J K L M N P R`. The drawings skip `G`, `I`, `O`
and `Q`, the usual convention for avoiding characters that read as digits. Rows
are lettered bottom-to-top on both sheets, so `R` is the top row.

## Reading these notes

Both sheets are scans without a text layer. The grids in these notes were read
off rendered page images at up to 4.5x, position by position.

Both grids have been read at zoom in full. Every position in both tables was
verified against a crop rendered at 4.2x to 6x, covering columns 7 to 12 on
Board I and 1 to 6 on Board II, top row to bottom, including the long RAM columns
and the sparse bottom rows. No position is carried over from the low-resolution
full-sheet render.

The socket legends give an independent check on top of that. Each sheet states
how many sockets of each pin count the board carries, and on both sheets those
counts match the number of positions marked with the corresponding symbol: six on
Board I, twenty-two on Board II.

What remains is ordinary transcription risk on the TTL part numbers, which no
count in the document constrains. A `74LS161` read for a `74LS163` would survive
both checks above. The distinction between those two parts in particular rests on
a single character in a 45-year-old scan.

Sparse or ambiguous areas at the sheet margins, meaning a few discrete
components, connector designations and hand-added marks, are called out as
untranscribed rather than guessed.

## Provenance

Transcribed from `.ignore/Rally-X_Schematics_(Fold_out_Earlier_Style)_(Logic_Board_I_&_II).pdf`,
a two-page scan of drawings roughly 22 x 17 inches. PDF metadata records
creation on 2006-06-17 by "anonymous". That is the scan's date, not the
drawings'.

Rally-X © 1980 NAMCO LTD. The drawings are Midway's.
