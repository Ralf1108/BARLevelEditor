# Arena

[Level Editor manual](../README.md) · [Specification](../SPECIFICATION.md) (section 11e) · [Start page](../../README.md)

Let armies of different teams fight each other and watch: 100 Behemoths against 100 Juggernauts, long range against plasma cannons, anything. A tool like **G**, not a game mode: nothing is won or lost.

## In short

- **Menu:** the button **A** in the button column at the right edge of the editor (between **G** and **TD**)
- Set the **radius**, switch the players on, choose the **units** of each army and a **count** or a **budget**
- **Generate** and click on the map: the armies stand around that point, each facing it
- **Start**: all units march to the **Arena Point** and fight on the way. **Stop**: everything is back as before

## Set up the armies

- **Radius:** how far every army stands from the Arena Point (default 1000 Elmo)
- **Table:** one row per team (same numbers as the team buttons at the left). The first two rows are on. A row that is off is not generated and does not fight
- **Units:** the button is green and shows how many unit types are allowed. A new army allows nothing. Click it and the Place menu opens next to the page: a click on a unit (its **green check** at the upper right) allows it for this army. The checks at faction, group and tech allow all of them at once. At the top choose a player in the combo box and press **Copy from** to take over that list; **Clear Allowed Units** empties it. The 3D preview and the info text appear as in the Place menu
- **Count** (default 50): how many units each **Generate** adds. **Budget:** Metal and Energy, each can be left empty (unlimited). The first limit that is reached ends the army. The last column shows what is left of the budget (it counts all units of the team, also the ones you placed by hand, and it can be negative)
- **Budget for all rows** (M, E) and the **C** buttons under the column heads: one value for everybody (budget fields, or the first team for On, Count and Units), then adjust single rows
- Units are drawn at random from the allowed ones. Only units that move and turrets are offered, no factories or other buildings

## Place and fight

- **Generate:** click on the map. The point is set there and every army of a row that is on is placed around it. It is one click: press Generate again for another round. A unit that does not fit its spot goes to the nearest free ground. An army outside the map is pushed onto it (100 Elmo from the edge)
- **Arena Point:** a thick red circle. **Arena Point** button: click the map to set or move it. **Alt + drag** moves only the point, **Shift + Alt + drag** the whole setup, **Del** or **X** removes it
- **Clear:** removes the units that Generate placed, and the point. Units you placed yourself stay
- **Start** needs an Arena Point. All units of the rows that are on get a fight order to it. **Stop** loads the state before the start, so you can run it again
- **Ctrl+Z** undoes every step
- You can also place units with the normal Place menu, set an Arena Point and press **Start**
