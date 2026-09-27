
## 4. Developer's guide

### 4.1 Overview

`TOD.BAS` is a single program using `OPTION EXPLICIT` and `OPTION DEFAULT INTEGER` (the map packing relies on 64-bit integers). Arrays are indexed from 0 (the MMBasic default). The main loop is simply:

```
DO
  TitleScr      ' new game or load
  PlayGame      ' runs until over<>0, then shows EndScr
LOOP
```

### 4.2 Code map

The source is split into commented sections, in this order:

| Section | Main routines |
|---|---|
| Declarations | constants, module tables, party arrays, game state, combat state |
| Graphics wrappers | `Clr` `Tx` `TxA` `Bx` `Bo` `Ln` `Ci` `Tr` `GetK` |
| Text helpers | `FS$` `NF` `Rest$` (CSV fields), `Msg` / `DrawLog` (5-line message log), `Prompt`, `TopBar`, `RL` (report line), `WrapTx` |
| Cell access | `CG` (get bits), `CS` (set bits), `KDir` |
| Module & party loading | `LoadModule`, `LoadParty`, `ApplyKits`, `FindItem` |
| Dungeon generation | `BuildDungeon` → per floor `GenFloor` (or `ParseMap` for drawn floors), `Carve`, `Link`, `Populate`, `PlaceSpecial`; `PickMon`, `MonCount`, `PickItem` |
| Items & party | `GiveItem`, `PickMI`, `UseMagic`, `IName$`, `Info$`, `Alive`, `PartyAlive`, `AllFound`, `Wound`, `Prot`, `AskP`, `GainXP`, `SwapP` |
| Drawing | `FigInit`/`DrawPl` (player figures, see below), `DrawMon`, `DrawHall` (perspective corridor, with `ExitKind`, `SideDoor` and `FrontDoor` for doors into rooms), `DrawArena`, `Panel`, `DrawRoomScr`, `Redraw`, `ShowMapScr` |
| Reports | `PlayerRpt`, `MagicRpt`/`MDesc$` (what an identified magic item does), `PartyRpt`, `MonRpt`, `HelpScr`, `Ind$`, `WName$`, `Store` |
| Exploration | `PlayGame` (key loop), `Walk`, `MoveTo`, `TakeStep`, `TimeStep`, `Stairs`, `Listen`, `Trade`, `Formation` |
| Rooms | `RoomEvents`, `Treasure`, `Reveal`, `Vault`, `Fountain`, `Statue` |
| Combat | `Missile` (the flying shot; it repaints the tiles it crosses), `SetupFight` (places monsters and party as the room is entered, before it is drawn), `Placed`, `Combat`, `DrawCombat`, `PTurn`, `Attack`, `DmgMon`, `Target`, `MTurn`, `MAttack`, `Negot`, `Occ`, `PlaceMon`, `SetSlots`, `PHit`, `MHit` |
| Save / load | `AddN`, `SaveGame`, `LoadGame` |
| Title & end | `TitleScr`, `NewGame`, `EndScr` |

### 4.3 The map cell

Each floor is `cell(floor, x, y)`, one 64-bit integer per grid cell with all its data packed into bit fields. `LoadModule` sizes the array to exactly the module's `FLOORS` and `GRID` (`ERASE cell` then `DIM cell(nfl,gw-1,gh-1)`), so loop over `gw-1`/`gh-1`, never fixed sizes. Always use `CG(x,y,shift,bits)` and `CS x,y,shift,bits,value`; both act on the current floor `fl`.

| Constant | Bit | Width | Holds |
|---|---|---|---|
| `BMK` | 0 | 4 | exits: bit 0 N, 1 E, 2 S, 3 W |
| `BTY` | 4 | 2 | 0 rock, 1 hallway, 2 room |
| `BFE` | 6 | 4 | feature: 1 chest, 2 vault, 3 fountain, 4 statue, 6 down, 7 up, 8 store |
| `BMO` | 10 | 5 | monster type (0 = none) |
| `BMC` | 15 | 3 | monster count (max 7) |
| `BSE` | 18 | 1 | seen by the party |
| `BQS` | 19 | 4 | quest object number |
| `BIM` | 23 | 8 | item number |
| `BGD` | 31 | 10 | gold ÷ 10 |
| `BMP` | 41 | 1 | this floor's map is here |

Directions are 0=N, 1=E, 2=S, 3=W with offsets in `DX()`/`DY()`. `Link x,y,d` opens a two-way exit between neighbouring cells. Stair positions are kept in `upx()/upy()/dnx()/dny()` per floor.

Hand-drawn `MAP` rows are not kept in memory. `LoadModule` only counts them per floor (`fmn()`); `ParseMap` reads them back from the module file while that floor is being built, so the `.ADV` file must stay on the card (it is needed anyway to continue a saved game).

**Memory**: MMBasic allocates variable memory in 256-byte pages, so every array or string costs at least 256 bytes. With *Quest of the King* loaded the game uses about 28 KB of variable memory (25 KB for *Pennies and Prizes*). Merging the many small arrays into a few tables would save a further 6–8 KB if it is ever needed.

### 4.4 Game state

- **Position**: `fl`, `px`, `py`, `pd` (facing), `inrm` (1 = room view), `ent` (side entered from).
- **Progress**: `steps`, `gold`, `rat` (rations), `dif`, `mapf()` (maps found), `qs()` (0 hidden, 1 found, 2 destroyed), `qt()` (countdowns), `ident()` (magic items identified).
- **Party** (index 1–`np`): `pn$ pcl pco php pwd pxp plv pbn pcw par psh phl`, weapons `pw(i,0..1)` with ammo `pam(i,0..1)`, magic items `pmi(i,0..9)`.
- **Ending**: `over` = 0 playing, 1 party dead, 2 quest failed, 3 abandoned, 4 won (`won`=1).
- **Combat**: monster type `cmt`, count `nmc`, positions `cmx/cmy`, hit points `chp`; player positions `cpx/cpy`.

### 4.5 Screen layout (320×320, FONT 1 = 8×12)

| Area | Position |
|---|---|
| Top bar | y 0–17 |
| Arena / hallway | 9×9 tiles of 24 px from (10, 24) |
| Side panel | x 236–319, 55 px per player |
| Prompt | y 245–256 |
| Message log | 5 lines, y 258–319, 40 characters each |

**Partial redraws.** The game keeps track of what is on screen (`scrv`: room, combat or hallway, plus which room and a signature from `ScrSig`). `Clr` marks the screen unknown, so any full-screen report or menu forces a complete redraw afterwards. Otherwise:

- `Redraw` (called after every key while exploring) repaints the room or hallway only if something it shows has changed; bumping a wall or pressing an unused key redraws nothing.
- In combat, `CombatView` draws everything only when needed. After that, a move repaints just the two tiles involved (`DrawTile`, which draws the floor, any room object from `DrawObj`, then whoever stands there). A killed monster or disabled player repaints one tile, and the aiming cursor repaints one tile per step. The side panel (`PanelIf`/`PanSig`) and top bar are repainted only when their contents change, and the log is drawn by `Msg`.

A typical combat keypress now paints about 7,000 pixels instead of clearing and repainting the whole 320×320 screen. The test harness checks this by redrawing each view in full at every keypress and comparing the two images pixel by pixel.

All drawing goes through the eight wrappers, so moving to another display size or font means changing the wrappers and the layout constants `TS`, `OX`, `OY`, `PANX` (and checking text widths).

### 4.6 Player figures

Each class has its own 16x20 bitmap: a fighter with helm, shield and sword, a wizard with pointed hat, beard and staff, a hooded rogue with a dagger, and a hero with a winged helm and cape. They are stored at the end of the program as `DATA` lines, one list per class, holding the bitmap cut into filled rectangles. Each rectangle is packed into one number as `((((x*32+y)*32+w)*32+h)*8+colour)`, where colour 1 means "this player's own colour" and 2-6 are white, yellow, red, brown and cyan. `FigInit` reads them at start-up into `fig()`; `DrawCls x,y,class,colour` draws one (32-43 boxes), and `DrawPl x,y,player` is the wrapper the game uses. The title screen shows all four classes with `DrawCls`, and `PARTY.BAS` carries the same routines and `DATA` so the party creator shows the same figures.

### 4.7 Sound

All sound uses PicoMite's `PLAY TONE left,right,ms`, with the same frequency on both channels. Each program has two routines:

- `SndT freq,ms` starts a tone and then `PAUSE`s for its length, because a new `PLAY TONE` replaces one that is still playing. A frequency of 0 is a rest.
- `SndSeq notes$` plays a list such as `"523/100,0/50,880/40"` (frequency in Hz `/` duration in ms).

In `TOD.BAS`, game code only calls `Sfx "name"` (e.g. `Sfx "gold"`); all the effects' notes are in the one `SELECT CASE` inside `Sfx`, so sounds can be retuned in one place. The title screen plays the opening of the Swan theme from Tchaikovsky's *Swan Lake* (public domain) from `TitleTune`, which checks the keyboard while each note sounds; pressing **N**, **C** or **Q** stops it at once (`PLAY STOP`) and acts as that choice. Change its tempo with `CONST TBEAT` (milliseconds per quarter note). Sound is always on. `PLAY STOP` is called at the end-of-game screen and before `PARTY.BAS` runs the game. Effects play while the game waits, so keep new ones short.

### 4.8 File formats

**PARTY.DAT** (written by `PARTY.BAS`):
```
TODPARTY1
<number of players>
name,class,colour,hp,bonus      (one line per player; class 1-4, colour 1-4)
```

**TODSAVE.DAT** — comma-separated lines, each ending in a trailing comma:
1. `TODSAVE1,<module file>`
2. `fl,px,py,pd,inrm,ent,steps,gold,rat,dif,np`
3. one line per player: name, 11 stats, two weapon/ammo pairs, 10 magic items
4. `qt,qs` pairs for all 8 quest slots
5. `ident` flags for all 48 items
6. for each floor: `mapf,upx,upy,dnx,dny`, then one line per grid row holding the packed cell values

On loading, the module is read first (for item and monster tables), then the saved state overwrites everything else. If you add a new piece of game state, add it to both `SaveGame` and `LoadGame` and change the `TODSAVE1` header so old saves are refused.
