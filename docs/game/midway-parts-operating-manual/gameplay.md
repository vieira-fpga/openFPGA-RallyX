# Game behaviour

Transcribed from the `PLAYING INSTRUCTIONS` page, manual page 9. This is the
closest thing the manual has to a functional description of the game. It is one
page long, and what follows is all of it.

One or two players. In two-player mode on an upright, players alternate on the
same stick, as [cabinet-io.md](cabinet-io.md) explains.

## The pieces

- **"My Car"** is blue. The control lever moves it up, down, left and right.
- **Enemy cars** are red, and they pursue.
- The **smoke screen** works on the pursuing red cars. It is the single button.
- **Barriers** are static obstacles.
- A **radar screen** shows the check points and the chasers.

## Check points and scoring

There are 10 check points per round, one of which is the Special Check Point.
The game awards points on a rising ladder, by the order in which check points are
cleared, not by which one:

| Cleared | Points | Cleared | Points |
| ------- | ------ | ------- | ------ |
| 1st     | 100    | 6th     | 600    |
| 2nd     | 200    | 7th     | 700    |
| 3rd     | 300    | 8th     | 800    |
| 4th     | 400    | 9th     | 900    |
| 5th     | 500    | 10th    | 1,000  |

An accident, meaning a hit on a barrier or a red car, resets the ladder:

> When an accident occurs (hitting a barrier or red car) you must start over from
> the first 100 points.

The ladder position resets, not the score. A player who crashes after the 7th
check point goes back to earning 100 for the next one.

## The Special Check Point

Clearing it doubles everything accumulated so far, and the screen shows `X2`. The
manual is careful to say the doubled total is not safe:

> When the Special Check Point is cleared, the points accumulated up to that time
> are doubled (the screen shows X2). Of course when an accident occurs, this
> score is wiped out.

## Fuel

The fuel model is the most mechanically specific part of the page:

| Quantity                   | Value   |
| -------------------------- | ------- |
| Starting tank              | 60 L    |
| Cost of one smoke screen   | 3 L     |
| Bonus per litre remaining  | 100 pts |
| Low-fuel warning threshold | 10 L    |

The game pays the remaining-fuel bonus when all check points are cleared, at 100
points per litre. At 10 litres the fuel indicator turns red and a warning sounds.
That warning is the sound bound to P1 up in the switch and sound test, listed in
[diagnostics.md](diagnostics.md).

Running dry does not kill the player:

> When the gas is all used, the car's speed will gradually decrease and come to a
> stop.

A gradual decay to zero, not an instant stop.

## Challenging Stage

> Challenging Stage - Rounds 3, 7, 11, 15.…are "Challenging", here 8 red cars
> appear but cannot run until the fuel in "My Car" is used up. Because "My Car"
> runs at full speed, it's fuel is soon gone. Clear all check points before the
> blocking red cars can move. When this stage ends, starting with the next round
> the scene changes to city streets.

Several distinct facts in one paragraph:

- Challenging Stages are rounds 3, 7, 11, 15 and so on, every fourth round
  starting at 3.
- Eight red cars appear, immobile.
- They stay immobile until My Car's fuel runs out. Fuel is the timer for the
  stage.
- My Car runs at full speed for the duration, so the fuel goes quickly. The
  player does not control the throttle.
- After the first Challenging Stage ends, the scene changes to city streets from
  the next round on.

The last point describes a persistent change rather than a property of the stage.
Clearing the stage changes the scenery, and the scenery stays changed from the
next round on. The manual does not say whether it changes again after later
Challenging Stages.

## Music and sound cues

The switch and sound test in [diagnostics.md](diagnostics.md) enumerates the
game's distinct sounds, and reading it alongside this page identifies most of
them by game event:

| Event                       | Sound                     |
| --------------------------- | ------------------------- |
| Coin deposited              | coin sound                |
| 1 player start              | start music               |
| Before a Challenging Stage  | its own music             |
| Check point cleared         | check point sound         |
| Special Check Point cleared | special check point sound |
| Fuel at 10 L                | fuel warning              |
| Fuel converted to score     | fuel-added-to-score sound |
| Bonus car awarded           | bonus car sound           |
| Full pattern cleared        | pattern cleared sound     |
| Accident                    | crash noise               |
| High score achieved         | high score noise          |
| Driving                     | sound of car running      |
| Smoke screen deployed       | smoke screen sound        |
| Background                  | BGM                       |

Test mode reaches all fourteen. Thirteen of them come from a single switch each.
The smoke screen sound needs both smoke buttons together, which also flips the
display.

The pairing above is inference, not print. The manual gives the sound list on
page 7 and the game description on page 9 and never connects them. The mapping
holds because the sound names on page 7 read as game events already, for example
"sound made when check pt cleared". Two sounds are not grounded in page 9 at all.
The service sound is left out of the table because page 9 never mentions the
service switch. The high score noise is in the table on the strength of its own
name, because page 9 describes no high score table either.

## What the manual does not cover

No enemy AI description, no round layouts, no speed values, no explanation of how
the radar is drawn, no bonus car maximum, no high score table behaviour, and no
statement of the point value of anything other than check points and fuel. The
`PLAYING INSTRUCTIONS` page is one page long and this is all of it.
