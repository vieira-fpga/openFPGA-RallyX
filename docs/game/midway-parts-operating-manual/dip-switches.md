# Switch adjustments

The factory dip switch table, transcribed from the instruction card reproduced at
manual page 8, drawing `M051-00935-A014`. The card is headed
`SWITCH ADJUSTMENTS` and the first block is labelled `(RALLY-X)`.

This is the manufacturer's own card: eight switches, numbered SW1 to SW8, with
the factory's own wording for every option.

The card is headed `(RALLY-X)` and this manual predates New Rally-X. Nothing on
this page describes New Rally-X.

The switches live on Game Logic Board I. The manual points the operator at "a
separate instruction card in back box area", and page 8 is that card.

## SW1 and SW2: method of play

| SW1 | SW2 | Setting           |
| --- | --- | ----------------- |
| OFF | OFF | 1 coin, 1 credit  |
| OFF | ON  | 1 coin, 2 credits |
| ON  | OFF | 2 coins, 1 credit |
| ON  | ON  | Free play         |

## SW3, SW4 and SW5: difficulty and number of cars per credit

| SW3 | SW4 | SW5 | Setting                 |
| --- | --- | --- | ----------------------- |
| ON  | ON  | ON  | LOW difficulty, 2 cars  |
| ON  | ON  | OFF | LOW difficulty, 3 cars  |
| ON  | OFF | ON  | MID difficulty, 1 car   |
| ON  | OFF | OFF | MID difficulty, 2 cars  |
| OFF | ON  | ON  | MID difficulty, 3 cars  |
| OFF | ON  | OFF | HIGH difficulty, 1 car  |
| OFF | OFF | ON  | HIGH difficulty, 2 cars |
| OFF | OFF | OFF | HIGH difficulty, 3 cars |

Difficulty and starting car count are one setting, not two. Three difficulties
and three car counts would make nine pairings, and the card lists eight. MID and
HIGH each offer 1, 2 and 3 cars. LOW offers 2 and 3 only, so a 1-car game at LOW
difficulty cannot be selected. The eight rows are the whole option space.

The card writes "1 CARS" for the single-car rows. Transcribed as "1 car" here.

## SW6 and SW7: bonus cars

The bonus threshold depends on how many cars the game was started with, so each
switch combination is three thresholds:

| SW6 | SW7 | 1-car game | 2-car game | 3-car game |
| --- | --- | ---------- | ---------- | ---------- |
| ON  | OFF | 10,000     | 15,000     | 20,000     |
| OFF | ON  | 20,000     | 30,000     | 40,000     |
| OFF | OFF | 30,000     | 40,000     | 60,000     |

`SW6 = ON, SW7 = ON` is not printed on the card. Three of the four combinations
are listed and the fourth is simply absent. It is most likely "no bonus car",
which is the setting other sources describe Rally-X as having, but this manual
does not say so, and it is left unstated here rather than filled in from
elsewhere.

## SW8: play mode

| SW8 | Setting       |
| --- | ------------- |
| OFF | Play mode     |
| ON  | Locks picture |

"Locks picture" is Midway's wording and it is the only description given.

## What the card does not give

The card is an operator's aid and stops exactly where an operator's needs stop.

**No electrical sense.** It says `ON` and `OFF`, which are physical positions of
a rocker. It never states which way a closed switch reads on the data bus.

**No bit positions and no addresses.** The switches are numbered SW1 to SW8 and
that is the only identity they are given anywhere in the manual. There is no
statement of which bit of which port a switch lands on, and no port map exists
elsewhere in the document to work it out from.

**No switch pack location beyond the board.** The sketch on the cabinet pages
shows a single switch pack on Board I with an arrow pointing at it, drawn without
a position designator.

**No default settings.** The card lists the options and marks none of them as the
factory setting. Nothing in the manual states how a machine shipped.

## Volume

Not a switch. The volume pot is on Game Logic Board I next to the adjustment
switches, and it sets the level of all sounds together. See
[boards.md](boards.md).
