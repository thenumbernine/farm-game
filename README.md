[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>
[![Donate via Bitcoin](https://img.shields.io/badge/Donate-Bitcoin-green.svg)](bitcoin:37fsp7qQKU8XoHZGRQvVzQVP8FrEJ73cSJ)<br>

## Harvest Dwarf Stardew Moon Secret of Mana Fortress Valley: Link to the Past

## So Far:

- you can dig dirt, chop down trees and wood tiles, and you can plop them down like any other voxel engine game.
- you can sleep in the bed and time will pass until the next day.
    - oh yes and there's realtime sunlighting on at least the top level of tiles.
- you can buy seeds from the shop guy.
- you can hoe ground, water ground, and plant seeds in ground.
- you can use your one sword to kill enemies.

## Controls:

- arrows move
- z = use item
- x = jump
- c = interact with world
- a = switch previous item
- s = switch next item
- d = open inventory
- q = rotate camera left
- w = rotate camera right
- `0-9, -, =` = select item in inventory bar.

When inventory is open, arrows navigate, and `interact with world` will drop the item.

## TODO:

- digging:
	- if you dig ground, (or remove stone or wood or any tile), it should remove sprites on top of the ground (hoed, watered, seeded)
	- if you try to dig ground that has a bush/tree on it, it should fail to dig.
	- half-step voxels for grass and stone, and maybe some slope tiles, and maybe rotate them in any of the 4 directions, so I don't have to jump everywhere (stupid Minecraft, why did you make that a standard?)
- make sure hoed / watered / seeded always render in correct order (z-sort by altitude? or store and render as attribut list per-tile?)
- make biomes
- make plants randomly seed neighboring ground... only if they naturally grow in this biome ofc.
- sword swing etc should search only objs on the neighboring tiles, not all objs
	- region iterator, index for last region iterator
- player sprite animations for sword, pickaxe, axe, shovel, hoe, watering ...
- super duper customizable character sprite
- probably better align billboard sprites with where in 3D they are.
- better lighting.  underground lighting.  any kind of falloff lighting.  any kind of better daylight shadow lighting.
- any kind of movement in those goombas
- redo all the tree / bush / plant pics procedurally or something, esp to have one per 792 plants listed at the store right now.
- fix the distinfo project overall to auto package windows + linux (+osx?) all in one package.  i'm hacking it r.n. with a script.
- unique sprite icons per each seed.
- unique sprite icons per each tool / weapon / etc.
- unique sprites per plant fruit / growing fruit.
- for berries on bushes, pick them every so often.
- weather.  rain.  snow.  etc.
- sprites cast shadows on the ground?
- bump-mapping on sprites?  parallax mapping?
- limit the seed shop to a subset of all seeds.  maybe multiple seed shops?
	- higher price for more exotic seeds?
- selling produce option?
	- trash bucket like SDV?  or is that too nonsense, that you can teleport stuff at any time for money.
	- shipping box like SDV, but becuse you're not there to man the booth you always get ripped off.
	- on-farm trade-depot, but only when the Mountainhome Caravan comes once a ... week.  or when customers come.  infrequently.
	- farmers market, once a saturady or something.  or any day.  you get lots of customers and sell at higher price.
		- later you can hire someone to man the booth for you and sell even more round-the-clock.
		- plants in-biome should cost less than plants out of biome
- get seeds from fruit.
- livestock.
- fences and gates to keep livestock from getting away.
- capure livestock in pokeballs and train them to fight.
- pickaxe.  gems.  metals.
- your own forge for making stuff.
	- I guess you'll have to talk to Robin to build a forge.  j/k.  but it won't just be an anvil like Minecraft. You'll have to build more.
    - or go to the guy in the town who is named Clint.
	- or go to the Dwarf.
- good battle system .
	- action-adventure style? TRPG maybe? realtime TRPG?
    - street fighter 2.  or secret of mana.  or both.
- stats system.  level system.  weapon-skill-level system.  skill tree ofc because.
    - lots of equipment slots.  materia.
- better dungeon/cave area.  not just mindless simplex noise or caves.  more like floodfill dungeons on a coarser resolution (like 8x8x8).
	- more monsters in caves than on surface.
- rodents, crop fungus, hurricaines... goblin raiding party.
- give logs plant-type. color them too just like seeds.  and add all those trees to the plant list.
- Better separate game-player from game-obj-player.  move all the UI stuff / clientside-only to game-player, all serverside to game-obj-player.
- allow rearranging stuff in inventory.
- generalize tile placement
	- tile orientation is added, but make it do something.  won't matter until i get more than just half-blocks ...
	- add material property to tiles ... either color, or some other way to change it based on the material ... and to store the material as well.
- better linking/unlinking system than the current Lua-table-based
	- maybe instead something like a per-tile linked-list (tho i need multiple lists per obj), or a ptr-per-tile that points to a list of objs
- proper glycemic index and blood sugar level ... [here](https://en.wikipedia.org/wiki/Glycemic_index) [here](https://en.wikipedia.org/wiki/Blood_sugar_level)
	- also make sure this updates while sleeping.  in fact, fix the sleep cycle so it doesn't just set the time but calls :update() , but a limited form so it's not running monsters movements / physics...
- add a grappling hook.
- map and sprite display buffers set to crash upon overflow.  mabye just top out, or even better, resize.
- food points, blood sugar level, etc
- some kind of game update to run while sleeping, not as intense as a full game update
