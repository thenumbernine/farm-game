[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>

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

- voxel system
	- have the .mtl file point to files in the sprites folder / same keys as texpack
	- then upon loading .objs, merge all material groups and remap texcoords to the texture atlas.
	- then do some kind of system for swapping each texture of the voxel ... hmmm ... how to do that ... some way to map from src tex index to dst tex index.
- overlays -> voxels
	- make a dirt voxel type
	- make a 'tilled ground' voxel type
	- make a 'watered ground' voxel type
	- then keep 9-patch staps as possible .tex indexes ... normalize this somehow.
- town
	- fishing store
		- buy rods, lines, bait, tackle, flies, bobbers, etc ... boats? waiters? model if your clothes get wet / temp / hypothermia?
	- livestock store
	- seed store
	- food store
	- blacksmith
	- ... tanner ?
	- ... brewer ?
	- ... all those other DF jobs?
- fishing.
	- casting line animation
	- test for water where the line lands, tangle the line in bushes otherwise
	- prepare / gut fish before cooking
	- cook fish (over fireplace / stove + with pan)
	- fish tanks
	- live fish should run out of air on dry land
	- fish ponds for collecting fish
- cooking
- animals
	- packs wander through
	- pokeballs
	- when you buy an animal from the market, you should get a tether to walk it back to the farm.
	- if animals aren't constrained ...
		- some animals trample your garden
		- some animals trample grass <-> dirt
		- some animals graze <-> have food points <-> can starve and die (same as you)
	- wild animals like coyotes, wolves, etc eat your chickens and cats if you don't keep them safe.
	- dingos eat your babies
	- butcher to gt ....
		- meat -> (cook over fireplace / stove + with pan)
		- skinning
			- tanning
- building
	- fences
	- gates
	- doors
- birds to peck at your crops
	- scarecrows to protect your crops
	- nets over bushes & trees to protect from birds
- hunting weapons
	- guns
		- bullets
	- bow
		- arrows
	- sling
	- crossbow
		- bolts
	- traps
		- mortal
		- live trapping animals
		- domesticate
			- train for fighting
- traceline
	- for placement of items / tiles (preview where they'll go)
	- for determining where weapon/tool swings will land
	- for determining NPC interaction / talking
	- mix traceline with push() and walking
	- make walking step over half-tiles
	- make the default block placement / excavation be half-tile at a time
- digging:
	- if you dig ground, (or remove stone or wood or any tile), it should remove sprites on top of the ground (hoed, watered, seeded)
	- or if you try to dig ground that has a bush/tree on it, it should fail to dig.
	- if you dig, it should first replace with half-step voxel, or of slope? 1:1 or 1:2 slope?
- biomes
	- make plants randomly seed neighboring ground... only if they naturally grow in this biome ofc.
	- also overcrowding of plants
		- ... don't seed / lower lifespan if it is too dense.
		- density is based only on local region (proportional to plant size) of plants with like size. i.e. small plants won't contribute to large plant densiy, so they can grow between.
- stats system.  level system.  weapon-skill-level system.  skill tree ofc because.
	- lots of equipment slots.  materia.
	- good battle system .
		- action-adventure style? TRPG maybe? realtime TRPG?
		- street fighter 2.  or secret of mana.  or both.
- monsters
	- any kind of movement in those goombas
- inventory
	- allow rearranging stuff in inventory.
	- equipment from inventory ...
		- equipment levels? skill levels? weapon levels? job levels?
- animation
	- player animations for sword, pickaxe, axe, shovel, hoe, watering ...
		- sword swing etc should search only objs on the neighboring tiles, not all objs
			- region iterator? instead of manually flagging
- super duper customizable character sprite
- probably better align billboard sprites with where in 3D they are.
- rendering
	- make sure hoed / watered / seeded always render in correct order (z-sort by altitude? or store and render as attribut list per-tile?)
		- maybe overhaul rendering, esp the more modifiers to tiles that I add?
		- maybe make hoed/watered as bitflags, and have the map chunk system handle them?
	- lighting
		- surface lighting
			- plopping down tiles needs to update the surface sun min/max angles
			- and requires updating all surface sun angles along the sun movement axis ....
		- underground lighting
			- any kind of falloff lighting
			- any kind of better daylight shadow lighting.
		- bump-mapping on sprites?  parallax mapping?
			- cheap method, greyscale sprite <-> bumpmap height.
			- also add/mul a distance-from-closest-transparent-pixel to make sure sprites look round.
		- sprites cast shadows on the ground?
	- use GPU to build geometry ... atomics + write ... need a compute/geometry shader?
	- use GPU to do physics updates ...
- physics
	- heat / temperature modeling.
		- you can use the same trick as light modelling, just a dif variable.  
			- have an outdoor ambient temp, then have it converge to underground temp (50 F? after going down a few tiles ... then go down too many and you get to the molten core of the earth)
		- rll, everything is a poisson solver.
		- should i use 3d texs of chunks, or of the map as a whole?
	- CFD/SPH fluids, water, magma, oil, acid, quicksand, poisonous gas
		- drainage / aquifers / accumulate standing water / erosion modeling w/ landscape generation
	- model collapsing of structures.  no more building a giant horizontal platform attached at a single point to the wall.
		- from bottom to top ... 
			- base layer of tiles has full support.  so does outermost layer.
			- next layer up has full support if the layer beneath it also does
				- if the tile from the layer under it doesn't, then we get its support % minus a penalty
				- otherwise for all tiles in the horizontal plane, flood-fill and dissipate % outwards from supports (poisson solver)
				- then if the % goes below a minimum threshold, collapse at that point
		- hmm this algo won't handle vertical U bends in supports ... should I ?
	- GPU-driven physics.
		- GPU-driven detection
		- less `CPU<->GPU` copies of the sprite data
	- allow the player to refine seeds from fruit & veg
- weather
	- rain
		- accumulates in puddles (drainage ...)
		- floods
	- snow
		- also accumulates
			- snow melt. drainage once again.
	- hail.
		- golfball/tennisball sized hail which destroys crops
- plants
	- sword swings shouldn't damage tubers/vegetables ... maybe just bushes?
	- bushes shouldn't give you wood, only trees.
	- redo all the tree / bush / plant pics procedurally or something, esp to have one per 792 plants listed at the store right now.
	- unique seed sprites, to go with the unique veg and plant and fruit sprites.
	- only grow plants if their ground is watered
		- rain also waters
		- so does sprinklers
		- so does near a body of water (lake, river, etc)
			- irrigation also waters
	- if a plant isn't watered, if it's native to the biome then it still grows
	- maybe something about plant root system vs soil moisture vs Ph balance etc ...
- economy
	- limit the seed shop to a subset of all seeds.  maybe multiple seed shops?
		- higher price for more exotic seeds?
	- selling produce option?
		- trash bucket like SDV?  or is that too nonsense, that you can teleport stuff at any time for money.
		- shipping box like SDV, but becuse you're not there to man the booth you always get ripped off.
		- on-farm trade-depot, but only when the Mountainhome Caravan comes once a ... week.  or when customers come.  infrequently.
		- farmers market, once a saturady or something.  or any day.  you get lots of customers and sell at higher price.
			- later you can hire someone to man the booth for you and sell even more round-the-clock.
			- plants in-biome should cost less than plants out of biome
- gems.  metals.  pickaxe quality levels.
- crafting
	- just putting stuff together
		- lamps:
			- wick:
				cotton wick
			- fuel: 
				veg oil (olive, sunflower, walnut, almond, sesame, flax)
				or butter / animal fat
				or kerosene
			- lamp:
				glass / clay / stone / metal
		- candle
			- wick ... same
			- wax
				- or butter / animal fat ... adds to the fuel
		- so to make that you need ...
			- clay ... need to chisel
			- oil ... press from plants ... 
	- your own forge for making stuff.
		- I guess you'll have to talk to Robin to build a forge.  j/k.  but it won't just be an anvil like Minecraft. You'll have to build more.
		- or go to the guy in the town who is named Clint.
		- or go to the Dwarf.
- caves
	- better dungeon/cave area.  not just mindless simplex noise or caves.  more like floodfill dungeons on a coarser resolution (like 8x8x8).
		- more monsters in caves than on surface.
	- underground biome
		- plantable mushrooms, plump helmets, etc
- disasters
- rodents, crop fungus, hurricaines... goblin raiding party.
- give logs plant-type. color them too just like seeds.  and add all those trees to the plant list.
- generalize tile placement
	- tile orientation is added, but make it do something.  won't matter until i get more than just half-blocks ...
	- add material property to tiles ... either color, or some other way to change it based on the material ... and to store the material as well.
- coding
	- better linking/unlinking system than the current Lua-table-based
		- maybe instead something like a per-tile linked-list (tho i need multiple lists per obj), or a ptr-per-tile that points to a list of objs
	- map and sprite display buffers set to crash upon overflow.  mabye just top out, or even better, resize.
	- some kind of game update to run while sleeping, not as intense as a full game update
- player health
	- proper glycemic index and blood sugar level ... [here](https://en.wikipedia.org/wiki/Glycemic_index) [here](https://en.wikipedia.org/wiki/Blood_sugar_level)
		- also make sure this updates while sleeping.  in fact, fix the sleep cycle so it doesn't just set the time but calls :update() , but a limited form so it's not running monsters movements / physics...
	- food points, blood sugar level, etc
- add a grappling hook.
- app packaging
	- fix the distinfo project overall to auto package windows + linux (+osx?) all in one package.  i'm hacking it r.n. with a script.
- water
	- refilling the watering can
	- irrigation & sprinklers
	- fish farms
	- air supply while swimming / drowning
	- scuba diving
		- seafloor farming
		- buried treasure and sunken ships
- food
	- fruit / veg should spoil if you don't pick it in time
		fruit should fall off trees
		trees / bushes should eventually die too
	- have all food / veg / fruit / meat go bad after a fixed time
		- meat spoils unless you salt it
			- dry salt lasts much longer than normie salt
		- pickling / canning will increase storage
		- drying fruits
		- sugaring
		- fermenting / wine / beer
		- jugging / stewing meat
	- refridgeration
		- electric freon fridge
		- old icebox freezer?
		- cellar / basement for storing cool/dry food
- lighting
	- the dirty flag version was fastest
	- if a player is holding a torch in hand, light follows him around

## TODO: make a video:

what to demonstrate?
- go to the town
- buy some seeds and animals
- bring the seeds back, hoe, water, and plant them (watch them grow over the next few days)
- bring the animals back, build a farm, with fence and gate, and put them there.
- dig a cellar and store foods there.  place some torches.
- eat food throughout the day
- sleep a few nights and watch crops grow / fruit
- collect eggs from chickens, milk from cows
- sell some crops and animal produce.

## Music

- https://www.chosic.com/download-audio/28063/
- https://www.chosic.com/download-audio/28027/
- https://www.chosic.com/download-audio/39322/
