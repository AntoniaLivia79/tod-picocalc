# Tunnels of Doom — PicoMite / PicoCalc edition

A simplified port of Kevin Kenney's 1982 TI-99/4A dungeon adventure, written in PicoMite (MMBasic) BASIC for the PicoCalc and its 320×320 LCD.

| File | Purpose |
|---|---|
| `TOD.BAS` | The game, including party creation |
| `QUEST.ADV` | "Quest of the King", the classic adventure (4 floors, monsters, time limits) |
| `ADVED.BAS` | Adventure editor — create and edit `.ADV` modules on the PicoCalc, with a graphical map editor and random generation |
| `PENNIES.ADV` | "Pennies and Prizes", a gentle children's adventure (no monsters) |
| `screens/` | Screenshots rendered from the game's own drawing commands |

---

## 1. Introduction

Tunnels of Doom is a party-based dungeon crawl. You lead up to four adventurers down through a multi-level dungeon, exploring hallways in a first-person view and fighting in an overhead room view. Your goal is set by the adventure module you load: in *Quest of the King* you must rescue the King and recover his Rainbow Orb before time runs out, then return to the surface.

![Title screen](screens/1_title.png)

Along the way you will find:

- **Hallways** drawn in 3D perspective, where wandering monsters may ambush you.
- **Rooms** holding monsters, gold, equipment, magic items and floor maps.
- **Treasure chests** (sometimes trapped) and **vaults** that open with a three-digit combination.
- **Fountains** whose water may heal, strengthen, curse or poison the drinker.
- **Living statues** that will identify an unknown magic item for a price — or crush it.
- **General stores** on the surface and on selected floors.

Differences from the original: the game fits in one program of about 1,600 lines, so some things are simplified. Graphics are drawn with simple shapes and sound effects are simple tones; the map, combat arena and screens are laid out for a 320×320 display. In exchange, adventures are loaded from plain text files, so you can write your own.

### Requirements

- A PicoMite-family device with a 320×320 display (PicoCalc), or any PicoMite with a display at least 320×320.
- Audio output for `PLAY TONE` (the PicoCalc's speakers).
- `TOD.BAS` and the `.ADV` files copied to the root of the SD card (the game looks for `*.ADV`, `PARTY.DAT` and `TODSAVE.DAT` in the current directory).

The game logic has been tested extensively on MMB4L (the Linux build of MMBasic), including dungeon generation, long random play sessions, save/load round-trips and the full menu flow. Screen appearance, speed and memory use have **not** been verified on real PicoCalc hardware.

---

## 2. Playing the game

### 2.1 Start a quest and choose a party

Run `TOD.BAS`. On the title screen:

- **N** — new quest: pick an adventure from the list of `.ADV` files, then choose your party (below), read the introduction, and choose difficulty 1 (easy) to 3 (hard). Harder games give less starting gold and larger monster groups.
- **C** — continue the saved game.
- **Q** — quit.

**Choosing a party.** After you pick an adventure, the game shows the party you used last (kept in `PARTY.DAT`), with each character's class named the way this adventure names it. Press **ENTER** to set out with them, **N** to create a new party, or **ESC** to go back.

![Party screen](screens/6_party.png)

**Creating a party:**

1. Choose the number of players (1–4).
2. For each player enter a name (up to 10 letters), a class and a colour.
3. The party screen shows each player's rolled **hit points (HP)** and **bonus**. Press **R** to re-roll everyone, **ENTER** to keep the party, or **ESC** to start over.
4. The party is saved to `PARTY.DAT`, ready for this quest and the next.

There are always four class *slots*, but each adventure can name them its own way. In *Quest of the King* they are Fighter, Wizard, Rogue and Hero; in *Mines of Moria* Ranger, Wizard, Hobbit and Elf; in *Wizardry* Fighter, Mage, Thief and Lord.

| Slot | Standard name | Hit points | Special |
|---|---|---|---|
| 1 | Fighter | most | best with weapons and armour |
| 2 | Wizard | fewest | the only slot (with slot 4) that can read scrolls |
| 3 | Rogue | middling | much less likely to set off chest traps (slot 4 shares this) |
| 4 | Hero | most of all | does everything, but only allowed in a one-player party |

Exactly which weapons and armour each class may use is decided by the adventure module. A party keeps its characters' slots, not their names, so the same party can go on any adventure. Party members always start a new quest at level 1.

### 2.2 The store

![Module introduction](screens/2_intro.png)

You begin at the **general store**. Press a player number (1–4) to choose a buyer, then a letter to buy an item. Long lists run to several pages: **<** and **>** turn the page, and the letters start again at A on each one. **ESC** deselects the buyer, and a second **ESC** leaves the store. Once a buyer is chosen, the list is colour-coded for that player: yellow for items they can use, grey for ones their class cannot (and ammunition for a weapon they may not carry), with a `*` after the name of anything they already have (a key line below the list explains this) (ammunition only if a matching weapon has some loaded; rations are shared by the party and never marked). Weapons, armor, ammunition, rations and healing are all for sale. A player carries two weapons at most: if both hands are full, the game lists them ("1 Sword   2 Short Bow (20)") and asks which to replace, and **ESC** keeps both — in the store your gold is not spent. **ESC** leaves the store and you descend into the dungeon.

### 2.3 Moving around

There are two views.

**Room view** (overhead). The arrow keys move the party straight out through an exit on that side.

![Room view](screens/3_room_view.png)

**Hallway view** (first person). Openings in the walls lead to more hallway; wooden doors, on the side walls or straight ahead, lead into rooms. **UP** walks forward, **LEFT/RIGHT** turn, **DOWN** turns around. The top bar shows which way you are facing.

![Hallway view](screens/4_hallway_view.png)

| Key | Action |
|---|---|
| Arrows | move / turn |
| `>` or `.` | go down stairs (in the stairs-down room) |
| `<` or `,` | go up stairs (in the stairs-up room) |
| `M` | show the floor map |
| `1` | player report (UP/DOWN pages through players, **M** shows what their identified magic items do) |
| `2` | party report (gold, rations, steps, quest items) |
| `U` | use a magic item |
| `T` | trade or drop a magic item |
| `O` | change formation (choose who leads) |
| `L` | listen at a room door from the hallway |
| `D` | drink from a fountain in the hallway |
| `K` | save the game (only in a hallway, not in a room) |
| `Q` | abandon the quest |
| `?` or `H` | command summary |

The map shows every place you have visited. Finding a floor's **map** (hidden in one of its rooms) reveals the whole floor, and in *Quest of the King* you cannot descend until you have found the map of your current floor.

### 2.4 Rooms and treasure

Entering a room triggers whatever is inside:

- **Monsters** attack first (see Combat). Defeat them to claim the room's contents.
- **Gold, items, maps and quest objects** are picked up automatically; you choose who carries an item.
- **Chest** — choose who opens it. It may be trapped.
- **Vault** — choose who opens it and guess the three-digit combination. Each digit runs from 1 to a maximum that rises on deeper floors. After each guess you are told how many digits are in the right place and whether the real combination is **higher** or **lower**. Each wrong guess may burn the opener. ESC gives up (the combination changes next time).
- **Fountain** — each player may drink once per visit, with random good or bad effects. Fountains also turn up in the hallways of generated floors, as in the original game: you see them standing in the corridor ahead, the game tells you when you reach one, and **D** lets the party drink. They show on the map as blue dots.

![A fountain in the hallway](screens/7_hallway_fountain.png)
- **Living statue** — offer gold (10–90) to have a magic item identified. Offer too little and it may be destroyed.
- **Store** — found on the floors the module chooses.

### 2.5 Combat

![Combat view](screens/5_combat_view.png)

Players act in order; the current player's name is highlighted in the side panel. Each player may **take one step and then attack**, or just attack.

| Key | Action |
|---|---|
| Arrow | step, or attack a monster in that direction |
| `F` | fire a ranged weapon — aim with the arrow keys, **SPACE** fires; the shot flies across the arena to its target |
| `W` | switch between your two weapons (uses an action) |
| `N` | negotiate — the monsters name a price; **Y** pays, **N** haggles (halves the price but risks them attacking), **R** refuses |
| `U` | use a magic item |
| `1` `2` `3` | player, party and monster reports |
| `ENTER` / `SPACE` | end this player's turn |

The side panel shows each player's **HP** (maximum hit points) and **WD** (wounds taken). A player whose wounds reach their hit points is disabled. Under each player, the indicator `++`, `+`, `0`, `-`, `--` shows how that player's fighting chances compare with the monster's — `++` is very favourable, `--` very poor.

Monsters with **speed** 2 move twice per turn. Some monsters use ranged attacks. Defeated monsters give experience; players gain a level (and extra hit points) as experience grows.

### 2.6 Staying alive

- **Rations**: every 10 steps the party eats one ration and each wounded player heals one wound. With no rations you do not heal.
- **Healing** (bought in the store): heals one wound per step until used up.
- **Magic items** are unidentified until used, bought or identified by a statue. Some are harmful: cursed potions, poison ale.
- **Time limits**: some quest objects are destroyed if not found in time. The countdown drops by one turn every 10 steps; if it reaches zero the quest fails. The party report (**2**) shows the turns left for each object (in red at 10 or fewer) and how many steps remain until the next turn. Countdowns are kept in saved games.

To **win**, find every quest object and climb the up-stairs on floor 1. Climbing out before then simply returns you to the surface store.

### 2.7 Saving and continuing

Press **K** in a **hallway** to save to `TODSAVE.DAT`. Saving is not allowed inside a room: a room's monsters stand where they were placed when you entered, and that is not recorded in the save, so a game saved in a guarded room would reload with the monsters moved and healed. Step out into the hallway first. There is one save slot; saving again overwrites it. Choose **C** on the title screen to continue. The save holds the whole dungeon (every room, what you have seen, maps found), the party with all equipment, gold, rations, steps, quest progress and time limits, and which magic items you have identified. The save records which module it belongs to, so keep that `.ADV` file on the card.

---

## 3. Writing adventure modules

A module is a plain text file with the extension `.ADV`. Put it next to `TOD.BAS` and it appears in the New Quest list (up to 9 modules are listed). `QUEST.ADV` is heavily commented and is the best starting point to copy.

### 3.0 The adventure editor

`ADVED.BAS` creates and edits modules on the PicoCalc itself. It presents each part of an adventure as a form, so you fill in labelled fields rather than typing comma-separated lines, and it writes a correct `.ADV` file when you save.

| Main menu key | Action |
|---|---|
| `1` | story text: title, introduction, win and fail messages, and the four class names |
| `2` | settings: floors, grid, rooms, gold, wandering monsters, maps, stores, seed |
| `3`–`6` | lists of items, starting kits, monsters and quest objects |
| `7` | floor maps |
| `8` | check the adventure for problems |
| `9` | generate a complete random adventure |
| `N` / `L` | start a new adventure / load an `.ADV` file |
| `S` / `A` | save / save as a new file (checks first, and asks before replacing a file) |
| `Q` | quit (warns about unsaved changes) |

**Forms.** UP/DOWN chooses a field and ENTER edits it; fields with a fixed set of values (item kind, ranged or not, speed) are chosen with LEFT/RIGHT instead. **R** fills the form with random content. Each field shows a hint, and numbers are cleaned and kept in range as you type, so a module can't be saved with, say, 12 floors or a group of 9 monsters.

**Lists.** ENTER edits the highlighted entry, **A** adds one, **R** adds a random one, **C** copies, **D** deletes, **<** and **>** move it up or down, ESC goes back.

**Maps.** Choose a floor, then draw on its grid: arrows move the cursor; `+` hallway, `R` room, `U`/`D` stairs, `S` store, `C` `V` `F` `T` chest, vault, fountain, statue; **L** then an arrow adds or removes a link; **J** joins a cell to all its neighbours; **P** lays hallway as you move; **G** makes a random floor; **X** clears it; **?** shows help. Floors you don't draw are generated fresh by the game each time.

**Random generation.** From the main menu, *Generate a random adventure* builds a whole playable module: settings, a standard shop plus random magic, starting kits, monsters for every floor, quest objects, story text, themed class names (such as Knight, Mage, Thief, Paladin), and, if you like, a drawn map for every floor.

**Checking.** *Check adventure* (also run before every save) reports errors and warnings: items without a kind or name, magic effects out of range, bows with no matching ammunition, kits naming items that don't exist, monster groups outside 1–7 or floors reversed, monsters that can never appear, floors with no monsters, quest objects on floors that don't exist, stores past the last floor, and drawn maps without exactly one up-stair, missing a down-stair, or with cells that can't be reached.

**One limitation:** because the file is rebuilt from the forms when you save, your own `#` comments are not kept. Lines the editor doesn't recognise are kept, and the check reports them.

### 3.1 File rules

- One entry per line: `KEYWORD,field,field,...`
- Lines starting with `#` (and blank lines) are ignored.
- Keywords are not case-sensitive. Spaces around fields are trimmed.
- Fields are separated by commas, so **text fields cannot contain commas**.
- Keep lines under 255 characters.
- Anything missing uses a default, and over-long values are cut to fit, so a mistake will not crash the game.

### 3.2 Story text

| Line | Meaning |
|---|---|
| `TITLE,text` | adventure name |
| `INTRO,text` | introduction paragraph, word-wrapped; up to 5 lines of 160 characters |
| `WIN,text` | victory message |
| `FAIL,text` | message when the party dies or a quest object is destroyed |

### 3.3 Dungeon settings

| Line | Meaning | Default |
|---|---|---|
| `CLASSES,a,b,c,d` | names for the four class slots (fighter, wizard, rogue, hero), 8 letters max | Fighter, Wizard, Rogue, Hero |
| `FLOORS,n` | number of floors, 1–10 | 3 |
| `GRID,w,h` | cells per floor, up to 14×10 | 12,9 |
| `ROOMS,n` | rooms per randomly generated floor, 3–40 | 14 |
| `GOLD,e,m,h` | starting gold per player at difficulty 1, 2, 3 | 150,120,100 |
| `WANDER,n` | % chance per hallway step of a wandering monster | 5 |
| `NEEDMAP,0/1` | 1 = must find a floor's map before going down | 1 |
| `STORE,a,b` | floor numbers that contain a store (0 = none) | 4,8 |
| `SEED,n` | 0 = a new dungeon each game; any other number = the same dungeon every time | 0 |

### 3.4 Items

```
ITEM,kind,name,v1,v2,cost,classes,unknown-name
```

- **name**: up to 20 characters. **cost** 0 means it is not sold in stores (it can still be found).
- **classes**: letters `F` `W` `R` `H` for who may use it, meaning the four class *slots* in order, whatever the module's `CLASSES` line calls them (in Moria, `F` is the Ranger and `H` the Elf). Blank means everyone.
- **unknown-name**: what an unidentified magic item is called (e.g. `Potion`).

| Kind | Item | v1 | v2 |
|---|---|---|---|
| `W` | hand weapon | damage | — |
| `R` | ranged weapon | damage | ammo group number, or 0 for a weapon needing no ammunition (a sling) |
| `X` | ammunition | count per purchase | ammo group (must match its weapon) |
| `A` | armor | protection | — |
| `S` | shield | protection | — |
| `P` | rations | count | — |
| `H` | healing | wounds healed | — |
| `M` | magic | effect (below) | power |

Magic effects: `1` heal wounds (power = amount) · `2` cursed, harms the user · `3` fireball, damages every monster · `4` bolt, damages one chosen monster · `5` reveal this floor's map · `6` raise maximum HP · `7` raise bonus.

Up to 48 items. The store sells every item that has a cost (up to 40), twelve to a page.

### 3.5 Starting kit

```
KIT,classes,item name
```

Gives every player of the listed classes a free item at the start. `KIT,FR,Leather Armor` gives it to Fighters and Rogues. Repeat a line to give two (e.g. two packs of arrows). Up to 24 lines.

### 3.6 Monsters

```
MON,name,glyph,colour,hp,attack,defense,damage,speed,xp,minfloor,maxfloor,maxcount,ranged,negotiate%,sound
```

| Field | Meaning |
|---|---|
| name | up to 16 characters |
| glyph | one character drawn on the monster's tile |
| colour | tile colour as `&HRRGGBB` |
| hp | hit points of each monster |
| attack / defense | skill values; higher means more likely to hit / harder to hit |
| damage | maximum damage per hit |
| speed | moves per turn (1 or 2 is typical) |
| xp | experience for each one killed |
| minfloor / maxfloor | floors where it appears |
| maxcount | largest group, **1–7** (hard difficulty may add one, still capped at 7) |
| ranged | 1 = can attack from a distance |
| negotiate% | chance per round that they will bargain (0 = never) |
| sound | what you hear when listening at their door, e.g. `rattling bones` |

Up to 24 monsters. A module with no `MON` lines has no fighting at all (see `PENNIES.ADV`).

### 3.7 Quest objects

```
QUEST,name,floor,countdown
```

Each object is hidden in a room on the given floor, usually guarded by a slightly tougher monster. **countdown** is the time limit in ticks (one tick every 10 steps, counted from the start of the game); 0 means no limit. Up to 8 objects. The quest is won when all are found and the party climbs out on floor 1.

### 3.8 Hand-drawn floors

Any floor can be drawn by hand; the rest are generated. Start with `FLOOR,n`, then give each map row as a `MAP,` line:

```
FLOOR,1
MAP,U-+-+-+-R   R-+-+-C
MAP,  |     |   |     |
MAP,  +     +-+-+     +
```

- Text starts straight after `MAP,` — leading spaces count.
- Cells sit at **even character positions of even rows** (counting from 0).
- Between cells, `-` joins left and right neighbours. On the odd rows, `|` under a cell joins it to the cell below.

| Symbol | Cell |
|---|---|
| `+` | hallway |
| `R` | ordinary room (gets random monsters/treasure) |
| `U` | stairs up — **every floor needs one** |
| `D` | stairs down — needed on every floor except the last |
| `S` | store |
| `C` | chest room |
| `V` | vault room |
| `F` | fountain room |
| `T` | living statue room |

Hand-drawn floors keep exactly the features you draw (the game adds no hallway fountains to them). Monsters, gold, items, the floor map and quest objects are still placed at random in their rooms. Make sure every cell can be reached from the up-stairs.

### 3.9 Limits at a glance

10 floors · 14×10 grid · 48 items · 24 monsters · 7 monsters per group · 8 quest objects · 24 kit lines · 5 intro lines · 9 modules listed on the menu.

---

### 3.10 Editor roadmap

Possible future features for `ADVED.BAS`, roughly in order of usefulness:

1. **Keep comments** — carry each `#` comment through a load and save, attached to the line after it.
2. **Balance report** — per floor: monsters available, average monster strength, gold and items on offer.
3. **Play-test button** — save and run `TOD.BAS` on the module directly.
4. **Colour preview** — show a monster's colour and glyph as you choose them.
5. **Search and bulk edit** — find a name across the module, or scale all monster hit points by a percentage.
6. **Undo** for the last change, and automatic backup (`.BAK`) on save.

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
| Party creation | `PartyMenu` (use the saved party or make one), `PcCreate`, `PcMake`, `PcRoll`, `PcShow`, `PcName$`, `PcSave`; class names come from `cln$()`, set by the module's `CLASSES` line |
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

Each class has its own 16x20 bitmap: a fighter with helm, shield and sword, a wizard with pointed hat, beard and staff, a hooded rogue with a dagger, and a hero with a winged helm and cape. They are stored at the end of the program as `DATA` lines, one list per class, holding the bitmap cut into filled rectangles. Each rectangle is packed into one number as `((((x*32+y)*32+w)*32+h)*8+colour)`, where colour 1 means "this player's own colour" and 2-6 are white, yellow, red, brown and cyan. `FigInit` reads them at start-up into `fig()`; `DrawCls x,y,class,colour` draws one (32-43 boxes), and `DrawPl x,y,player` is the wrapper the game uses. The title screen shows all four classes with `DrawCls`, and so do the party screens.

This deliberately avoids the PicoMite `SPRITE` commands, which need a VGA or HDMI display or a framebuffer and are not available on the PicoCalc's SPI LCD. To redraw the artwork, edit the generator rather than the numbers.

### 4.7 Sound

All sound uses PicoMite's `PLAY TONE left,right,ms`, with the same frequency on both channels. Each program has two routines:

- `SndT freq,ms` starts a tone and then `PAUSE`s for its length, because a new `PLAY TONE` replaces one that is still playing. A frequency of 0 is a rest.
- `SndSeq notes$` plays a list such as `"523/100,0/50,880/40"` (frequency in Hz `/` duration in ms).

In `TOD.BAS`, game code only calls `Sfx "name"` (e.g. `Sfx "gold"`); all the effects' notes are in the one `SELECT CASE` inside `Sfx`, so sounds can be retuned in one place. The title screen plays the opening of the Swan theme from Tchaikovsky's *Swan Lake* (public domain) from `TitleTune`, which checks the keyboard while each note sounds; pressing **N**, **C** or **Q** stops it at once (`PLAY STOP`) and acts as that choice. Change its tempo with `CONST TBEAT` (milliseconds per quarter note). Sound is always on. `PLAY STOP` is called at the end-of-game screen. Effects play while the game waits, so keep new ones short.

### 4.8 File formats

**PARTY.DAT** (written by the party creator in `TOD.BAS`):
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

### 4.9 Extending the game

- **New room feature**: add a constant, give it a letter in `ParseMap`'s `"RUDSFVCT"` / `"07683214"` strings, a chance in `Populate`, a drawing in `DrawArena`, and a `CASE` in `Treasure`.
- **New magic effect**: add a `CASE` in `UseMagic` and document the number for module writers.
- **New module keyword**: add a `CASE` in `LoadModule`, set a default at the top of that routine, and clamp the value.
- **Wider or taller grids**: `cell()` and the `GRID` limit are 14×10; the map screen scales automatically, but `SaveGame` row lines must stay under 255 characters (each cell can take up to 14 characters).

### 4.10 MMBasic pitfalls met during development

- `k` and `k$` are **the same name** in MMBasic. Two `LOCAL`s like `k$, k` in one routine clash, and a variable cannot share a name with a SUB or FUNCTION (e.g. a local `cs` clashes with `CS`).
- Single-line `IF … THEN … ELSE IF …` is not allowed; use a block `IF … ELSEIF … ENDIF`.
- Program lines and strings are limited to 255 characters; declare `LENGTH` on string arrays to save memory.
- Passing a user function straight into `DIR$` (e.g. `DIR$(FS$(a$,2),FILE)`) crashed MMB4L; assign to a variable first.
- A line that starts with a SUB call followed by a colon (`Clr: TopBar ...`) is read as a **label**, not a call. Put the call on its own line.
- Names that firmware treats as keywords (`FM`, `KEY`, `OFF`, ...) fail with "Invalid in a program"; a space appearing inside the name when the line is listed is the giveaway.
- `NOT` is a logical operator in MMBasic (`NOT 16` is 0). To clear one bit use `INV`: `v AND (INV 16)`. Using `NOT` there wiped whole map cells in the adventure creator.
- Never start a SUB call's first argument with a bracket: `TxL (i-1)*80,232,...` is parsed as a bracketed call and silently draws nothing. Write `TxL 80*(i-1),232,...` instead.
- A wrong number of arguments to a SUB is only reported when that line runs, so rarely used screens can hide such bugs. Check argument counts when editing.

### 4.11 Testing

Development used MMB4L built as a headless interpreter, with Python scripts that strip the main loop, swap the graphics wrappers for stubs and drive `GetK` with scripted or random keys. The checks covered:

- 1,500 generated dungeons checked for stairs, exits that stay on the grid, two-way doors, and reachability of every cell.
- Tens of thousands of random keypresses, checking the game state after every key (position, room/hallway agreement, gold, rations, wounds, ammunition).
- Save → scramble → load round-trips that must reproduce the state exactly.
- Scripted runs through title → new game → party menu → store → save → continue, and through party creation.
- Screenshots produced by logging the wrapper calls and redrawing them at 320×320.

None of this can test the real LCD, timing, keyboard or memory limits of a PicoCalc, so please report anything that looks wrong on hardware.
