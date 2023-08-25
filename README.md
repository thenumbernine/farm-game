## Harvest Dwarf Stardew Moon Secret of Mana Fortress Valley: Link to the Past

## So Far:
- you can dig dirt, chop down trees and wood tiles, and you can plop them down like any other voxel engine game.
- you can hoe ground, water ground, and plant seeds in ground.
- you can sleep in the bed and time will pass until the next day.
    - oh yes and there's realtime sunlighting on at least the top level of tiles.
- you can buy seeds from the shop guy.
- you can use your one sword to kill enemies.

## TODO:

- button for opening inventory
- keyboard/controller input for inventory selecting/cycling
- if you dig ground, it should remove sprites on top of the ground (hoed, watered, seeded)
- if you try to dig ground that has a bush/tree on it, it should fail to dig.
- make sure hoed / watered / seeded always render in correct order (z-sort by altitude? or store and render as attribut list per-tile?)
- make seeds grow into plants.  one of a few templates of kinds of plants.
- make plants randomly seed neighboring ground... if they naturally grow in this biome ofc.
- sword swing etc should search only objs on the neighboring tiles, not all objs
- player sprite animations for sword, pickaxe, axe, shovel, hoe, watering ...
- better sleep animation
- super duper customizable character sprite
- probably better align billboard sprites with where in 3D they are.
- better lighting.  underground lighting.  any kind of falloff lighting.  any kind of better daylight shadow lighting.
- half-step voxels for grass and stone, and maybe some slope tiles, and maybe rotate them in any of the 4 directions, so I don't have to jump everywhere (stupid Minecraft, why did you make that a standard?)
- any kind of movement in those goombas
- redo all the tree / bush / plant pics procedurally or something, esp to have one per 792 plants listed at the store right now.
- move all scripts into a subfolder and fix distinfo to copy that one folder.
- fix the distinfo project overall to auto package windows + linux (+osx?) all in one package.  i'm hacking it r.n. with a script.
- unique sprite icons per each seed.
- unique sprite icons per each tool / weapon / etc.
- unique sprites per plant fruit / growing fruit.
- for berries on bushes, pick them every so often.
- weather.  rain.  snow.  etc.
- sprites cast shadows on the ground?
- bump-mapping on sprites?  parallax mapping?
- limit the seed shop to a subset of all seeds.  maybe multiple seed shops?
- selling produce option?
	- trash bucket like SDV?  or is that too nonsense, that you can teleport stuff at any time for money.
	- shipping box like SDV, but becuse you're not there to man the booth you always get ripped off.
	- on-farm trade-depot, but only when the Mountainhome Caravan comes once a ... week.  or when customers come.  infrequently.
	- farmers market, once a saturady or something.  or any day.  you get lots of customers and sell at higher price.
		- later you can hire someone to man the booth for you and sell even more round-the-clock.
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
- better dungeon/cave area.  not just mindless simplex noise or caves.  more like floodfill dungeons with some organization to them.
	- more monsters in caves than on surface.
- rodents, crop fungus, hurricaines... goblin raiding party.
- tag logs with plant-type. shader for them too.  and add all those trees to the plant list.

## Right Now Plant Sprites Are Courtesy Of:

https://opengameart.org/content/trees-bushes
