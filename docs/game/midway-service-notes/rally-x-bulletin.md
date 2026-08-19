# Rally-X service bulletin: RAM test message code

Dated **11 June 1981**. The only document indexed under Rally-X's name in either
volume's contents, and it appears in both:

| Volume | Printed pages | Table of contents entry | Letterhead     |
| ------ | ------------- | ----------------------- | -------------- |
| notes1 | 43–44         | `RALLY-X CODE`          | Belmont Avenue |
| notes2 | 12–13         | `RALLY X RAM CODE`      | Grand Avenue   |

The two are the same bulletin. Body text, numbering, signature and `FIGURE #1`
are identical word for word and cell for cell. Only the letterhead differs, and
the two volumes index it under slightly different names in their contents.

Header block, as printed:

```
                    S E R V I C E   B U L L E T I N

        GAME:      RALLY X
        SUBJECT:   RAM TEST MESSAGE CODE
```

Signed `ANDY DUCAY / SERVICE MANAGER`, reference `AD/dd`.

## The text

Reproduced in full. It is four numbered points and runs to under 150 words.

> 1. The position of rams given in our Ram Test Message on page 6 of the Parts
>    and Operating Manual is incorrect.
>
> 2. The correct Ram Test Message Code is shown in figure #1.
>
> 3. Each of the 2114 Rams are checked during the Ram Test and when any
>    irregularity is found a test message (e.g. Ram 0L) is displayed and the test
>    series stops. If there is no irregularities in the rams the sound and switch
>    test begins.
>
> 4. The Ram Test is only for the 2114 Rams.

Points 3 and 4 restate what the Parts and Operating Manual already says about the
RAM test, transcribed in
[../midway-parts-operating-manual/diagnostics.md](../midway-parts-operating-manual/diagnostics.md).
Only points 1 and 2 are new: the manual's table is wrong, and this one replaces
it.

## FIGURE #1

The corrected table, as printed:

| Test Message | Position of RAM on PCB |
| ------------ | ---------------------- |
| `RAM 0L`     | `6C`                   |
| `RAM 0H`     | `6A`                   |
| `RAM 1L`     | `6D`                   |
| `RAM 1H`     | `6B`                   |
| `RAM 2L`     | `6K`                   |
| `RAM 2H`     | `6J`                   |
| `RAM 3L`     | `6L`                   |
| `RAM 3H`     | `6H`                   |
| `RAM 4L`     | `6M`                   |
| `RAM 4H`     | `6F`                   |
| `RAM 5L`     | `6N`                   |
| `RAM 5H`     | `6E`                   |

## What actually changed

The bulletin says the positions are incorrect. Compare its table against the one
it supersedes and the positions are not what changed.

Both tables list the same twelve board positions in the same order:
`6C 6A 6D 6B 6K 6J 6L 6H 6M 6F 6N 6E`. What differs is the message numbering. The
manual numbers the RAM banks `1` to `6`. This bulletin numbers them `0` to `5`.
Every row is therefore shifted by one bank number against the manual, while
pointing at the same chip.

```
   manual        RAM 1L  RAM 1H  RAM 2L  ...  RAM 6L  RAM 6H
   bulletin      RAM 0L  RAM 0H  RAM 1L  ...  RAM 5L  RAM 5H
   position        6C      6A      6D    ...    6N      6E
```

So the practical effect is on reading the screen, not on locating the chip. A
machine displaying `RAM 0L` is reporting position `6C`, and the manual has no row
for `RAM 0L` at all. Point 3's worked example changes accordingly, from the
manual's `Ram 1L` to `Ram 0L`.

The bulletin's own wording, "the position of rams ... is incorrect", describes
the symptom an operator would hit rather than the nature of the error. It does
not acknowledge that the numbering base is what moved, and it does not say which
of the two tables reflects what the ROM actually displays. It only asserts that
this one is correct.

The bulletin cites "page 6" without saying which revision of the Parts and
Operating Manual it means, and no page examined says whether later printings of
that manual were corrected.
