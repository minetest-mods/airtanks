local S = minetest.get_translator(minetest.get_current_modname())

local print_settingtypes = false
local CONFIG_FILE_PREFIX = "airtanks_"
local config = {}

local function setting(stype, name, default, description)
	local value
	if stype == "bool" then
		value = minetest.settings:get_bool(CONFIG_FILE_PREFIX..name)
	elseif stype == "string" then
		value = minetest.settings:get(CONFIG_FILE_PREFIX..name)
	elseif stype == "int" or stype == "float" then
		value = tonumber(minetest.settings:get(CONFIG_FILE_PREFIX..name))
	end
	if value == nil then
		value = default
	end
	config[name] = value
	
	if print_settingtypes then
		minetest.debug(CONFIG_FILE_PREFIX..name.." ("..description..") "..stype.." "..tostring(default))
	end	
end

-- Single tanks
setting("int", "steel_uses", 20, "Number of uses for a steel air tank")
setting("int", "copper_uses", 10, "Number of uses for a copper air tank")
setting("int", "bronze_uses", config.steel_uses + config.copper_uses, "Number of uses for a bronze air tank")

-- Double tanks
setting("bool", "enable_double", true, "Enable double tanks")
setting("int", "steel_2_uses", config.steel_uses * 2, "Number of uses for a pair of steel air tanks")
setting("int", "copper_2_uses", config.copper_uses * 2, "Number of uses for a pair of copper air tanks")
setting("int", "bronze_2_uses", config.bronze_uses * 2, "Number of uses for a pair of bronze air tanks")

-- Triple tanks
setting("bool", "enable_triple", true, "Enable triple tanks")
setting("int", "steel_3_uses", config.steel_uses * 3, "Number of uses for three steel air tanks")
setting("int", "copper_3_uses", config.copper_uses * 3, "Number of uses for threee copper air tanks")
setting("int", "bronze_3_uses", config.bronze_uses * 3, "Number of uses for three bronze air tanks")

setting("bool", "wear_in_creative", true, "Air tanks wear out in creative mode")

setting("bool", "compressor_needs_fuel", true, "Compressor needs fuel")

-- these may come from default or from mineclone mods
local steel_ingot
local copper_ingot
local bronze_ingot
local mese_crystal_fragment
local get_itemslot_bg = function(x, y, w, h) return "" end
local get_hotbar_bg = function(x, y) return "" end
local sounds

if minetest.get_modpath("default") then
	steel_ingot = "default:steel_ingot"
	copper_ingot = "default:copper_ingot"
	bronze_ingot = "default:bronze_ingot"
	mese_crystal_fragment = "default:mese_crystal_fragment"
	get_hotbar_bg = default.get_hotbar_bg
	sounds = default.node_sound_metal_defaults()
elseif minetest.get_modpath("mcl_core") then
	steel_ingot = "mcl_core:iron_ingot"
	mese_crystal_fragment = "mesecons:wire_00000000_off"
else
	assert(false, "This mod requires either Mineclone or the default Minetest Game to be installed.")
end

if minetest.get_modpath("mcl_formspec") then
	get_itemslot_bg = mcl_formspec.get_itemslot_bg
end
if minetest.get_modpath("mcl_sounds") then
	sounds = mcl_sounds.node_sound_metal_defaults()
end
if minetest.get_modpath("mcl_copper") then
	copper_ingot = "mcl_copper:copper_ingot"
end

local compressor_desc = S("A machine for filling air tanks with compressed air.")
local compressor_help
if config.compressor_needs_fuel then
	compressor_help = S("This machine requires fuel to operate. Place something that can burn in the fuel slot, and then place empty tanks in the inventory to the right. The compressor will start filling the largest capacity tanks first.")
else
	compressor_help = S("Place place empty tanks in the inventory to the right. The compressor will start filling the largest capacity tanks first.")
end

local tube_desc = S("A breathing tube to allow automatic hands-free use of air tanks.")
local tube_help = S("If this item is present in your quick-use inventory then whenever your breath bar goes below 5 it will automatically make use of any air tanks that are present in your quick-use inventory to replenish your breath supply. Note that it will not use air tanks that are present elsewhere in your inventory, only ones in your quick-use bar.")

local cardinal_dirs = {{x=1,y=0,z=0},{x=-1,y=0,z=0},{x=0,y=1,z=0},{x=0,y=-1,z=0},{x=0,y=0,z=1},{x=0,y=0,z=-1},}

-- For compressor code use later on
local max_uses = math.max(config.steel_uses, config.copper_uses, config.bronze_uses)
if config.enable_triple then
	max_uses = max_uses * 3
elseif config.enable_double then
	max_uses = max_uses * 2
end

local function use_airtank(itemstack, user)
	local breath = user:get_breath()
	if breath > 9 then return itemstack end
	breath = math.min(10, breath+5)
	user:set_breath(breath)
	minetest.sound_play("airtanks_hiss", {pos = user:get_pos(), gain = 0.5})

	if (not minetest.settings:get_bool("creative_mode")) or config.wear_in_creative then
		local wdef = itemstack:get_definition()
		itemstack:add_wear(65535/(wdef._airtanks_uses-1))
		if itemstack:get_count() == 0 then
			if wdef.sound and wdef.sound.breaks then
				minetest.sound_play(wdef.sound.breaks,
					{pos = user:get_pos(), gain = 0.5})
			end
			local inv = user:get_inventory()
			itemstack = inv:add_item("main", wdef._airtanks_empty)
		end
	end
	return itemstack
end

-- This will only work for single use tanks... we need to add separate functions for the others
local function register_air_tank(name, desc, color, uses, material)
	if not material then return end
	minetest.register_craftitem("airtanks:empty_"..name.."_tank", {
		description = S("Empty @1", desc),
		groups = {airtank = 1},
		_doc_items_longdesc = S("A compressed air tank, currently empty."),
		_doc_items_usagehelp = S("This tank can be recharged with compressed air by using it on a compressor block. When fully charged this tank has @1 uses before it becomes empty.", uses),
		_airtanks_uses = uses,
		_airtanks_full = "airtanks:"..name.."_tank",
		inventory_image = "airtanks_airtank.png^[colorize:"..color.."^[mask:airtanks_airtank.png^airtanks_empty.png",
		wield_image = "airtanks_airtank.png^[colorize:"..color.."^[mask:airtanks_airtank.png^airtanks_empty.png",
	})

	minetest.register_tool("airtanks:"..name.."_tank", {
		description = desc,
		_doc_items_longdesc = S("A tank containing compressed air."),
		_doc_items_usagehelp = S("If you're underwater and you're running out of breath, wield this item and use it to replenish 5 bubbles on your breath bar. When fully charged this tank has @1 uses before it becomes empty.", uses),
		_airtanks_uses = uses,
		_airtanks_empty = "airtanks:empty_"..name.."_tank",
		groups = {not_repaired_by_anvil = 1, airtank = 2},
		inventory_image = "airtanks_airtank.png^[colorize:"..color.."^[mask:airtanks_airtank.png",
		wield_image = "airtanks_airtank.png^[colorize:"..color.."^[mask:airtanks_airtank.png",
		stack_max = 1,
	
		on_place = function(itemstack, user, pointed_thing)
			return use_airtank(itemstack, user)
		end,

		on_use = function(itemstack, user, pointed_thing)
			return use_airtank(itemstack, user)
		end,
	})
	
	minetest.register_craft({
		recipe = {
			{"", material, ""},
			{material, "airtanks:compressor", material},
			{"", material, ""},
		},
		output = "airtanks:empty_"..name.."_tank",
		replacements = {{"airtanks:compressor", "airtanks:compressor"}},
	})
	
end

local function register_air_tank_2(name, desc, color, uses, material)
	if not material then return end

	minetest.register_craftitem("airtanks:empty_"..name.."_tank_2", {
		description = S("Empty @1", desc),
		groups = {airtank = 1},
		_doc_items_longdesc = S("A pair of compressed air tanks, currently empty."),
		_doc_items_usagehelp = S("This tank can be recharged with compressed air by using it on a compressor block. When fully charged these tanks have @1 uses before it becomes empty.", uses),
		_airtanks_uses = uses,
		_airtanks_full = "airtanks:"..name.."_tank_2",
		inventory_image = "airtanks_airtank_two.png^[colorize:"..color.."^[mask:airtanks_airtank_two.png^airtanks_empty.png",
		wield_image = "airtanks_airtank_two.png^[colorize:"..color.."^[mask:airtanks_airtank_two.png^airtanks_empty.png",
	})

	minetest.register_tool("airtanks:"..name.."_tank_2", {
		description = desc,
		_doc_items_longdesc = S("A pair of tanks containing compressed air."),
		_doc_items_usagehelp = S("If you're underwater and you're running out of breath, wield this item and use it to replenish 5 bubbles on your breath bar. When fully charged these tanks have @1 uses before it becomes empty.", uses),
		_airtanks_uses = uses,
		_airtanks_empty = "airtanks:empty_"..name.."_tank_2",
		groups = {not_repaired_by_anvil = 1, airtank = 2},
		inventory_image = "airtanks_airtank_two.png^[colorize:"..color.."^[mask:airtanks_airtank_two.png",
		wield_image = "airtanks_airtank_two.png^[colorize:"..color.."^[mask:airtanks_airtank_two.png",
		stack_max = 1,
	
		on_place = function(itemstack, user, pointed_thing)
			return use_airtank(itemstack, user)
		end,

		on_use = function(itemstack, user, pointed_thing)
			return use_airtank(itemstack, user)
		end,
	})
	
	-- Allow empty tanks
	minetest.register_craft({
		recipe = {
			-- Use 2 singles to make a double
			{"airtanks:empty_"..name.."_tank", "airtanks:empty_"..name.."_tank"},
		},
		output = "airtanks:empty_"..name.."_tank_2",
	})
	-- Allow full tanks too
	minetest.register_craft({
		recipe = {
			-- Use 2 singles to make a double
			{"airtanks:"..name.."_tank", "airtanks:"..name.."_tank"},
		},
		output = "airtanks:"..name.."_tank_2",
	})
	
end

local function register_air_tank_3(name, desc, color, uses, material)
	if not material then return end

	minetest.register_craftitem("airtanks:empty_"..name.."_tank_3", {
		description = S("Empty @1", desc),
		groups = {airtank = 1},
		_doc_items_longdesc = S("A set of three compressed air tanks, currently empty."),
		_doc_items_usagehelp = S("These tanks can be recharged with compressed air by using it on a compressor block. When fully charged these tanks have @1 uses before it becomes empty.", uses),
		_airtanks_uses = uses,
		_airtanks_full = "airtanks:"..name.."_tank_3",
		inventory_image = "airtanks_airtank_three.png^[colorize:"..color.."^[mask:airtanks_airtank_three.png^airtanks_empty.png",
		wield_image = "airtanks_airtank_three.png^[colorize:"..color.."^[mask:airtanks_airtank_three.png^airtanks_empty.png",
	})

	minetest.register_tool("airtanks:"..name.."_tank_3", {
		description = desc,
		_doc_items_longdesc = S("A set of three tanks containing compressed air."),
		_doc_items_usagehelp = S("If you're underwater and you're running out of breath, wield this item and use it to replenish 5 bubbles on your breath bar. When fully charged these tanks have @1 uses before it becomes empty.", uses),
		_airtanks_uses = uses,
		_airtanks_empty = "airtanks:empty_"..name.."_tank_3",
		groups = {not_repaired_by_anvil = 1, airtank = 2},
		inventory_image = "airtanks_airtank_three.png^[colorize:"..color.."^[mask:airtanks_airtank_three.png",
		wield_image = "airtanks_airtank_three.png^[colorize:"..color.."^[mask:airtanks_airtank_three.png",
		stack_max = 1,
	
		on_place = function(itemstack, user, pointed_thing)
			return use_airtank(itemstack, user)
		end,

		on_use = function(itemstack, user, pointed_thing)
			return use_airtank(itemstack, user)
		end,
	})

	-- Allow empty tanks
	minetest.register_craft({
		recipe = {
			-- Use 3 singles to make a triple
			{"airtanks:empty_"..name.."_tank", "airtanks:empty_"..name.."_tank", "airtanks:empty_"..name.."_tank"},
		},
		output = "airtanks:empty_"..name.."_tank_3",
	})
	minetest.register_craft({
		recipe = {
			-- Use 1 single and 1 double to make a triple
			{"airtanks:empty_"..name.."_tank", "airtanks:empty_"..name.."_tank_2", ""},
		},
		output = "airtanks:empty_"..name.."_tank_3",
	})
	-- Allow full tanks too
	minetest.register_craft({
		recipe = {
			-- Use 3 singles to make a triple
			{"airtanks:"..name.."_tank", "airtanks:"..name.."_tank", "airtanks:"..name.."_tank"},
		},
		output = "airtanks:"..name.."_tank_3",
	})
	minetest.register_craft({
		recipe = {
			-- Use 1 single and 1 double to make a triple
			{"airtanks:"..name.."_tank", "airtanks:"..name.."_tank_2", ""},
		},
		output = "airtanks:"..name.."_tank_3",
	})
	
end

register_air_tank("steel", S("Steel Air Tank"), "#d6d6d6", config.steel_uses, steel_ingot)
register_air_tank("copper", S("Copper Air Tank"), "#cd8e54", config.copper_uses, copper_ingot)
register_air_tank("bronze", S("Bronze Air Tank"), "#c87010", config.bronze_uses, bronze_ingot)

if config.enable_double then
	register_air_tank_2("steel", S("Double Steel Air Tanks"), "#d6d6d6", config.steel_2_uses, steel_ingot)
	register_air_tank_2("copper", S("Double Copper Air Tanks"), "#cd8e54", config.copper_2_uses, copper_ingot)
	register_air_tank_2("bronze", S("Double Bronze Air Tanks"), "#c87010", config.bronze_2_uses, bronze_ingot)
end

if config.enable_triple then
	register_air_tank_3("steel", S("Triple Steel Air Tanks"), "#d6d6d6", config.steel_3_uses, steel_ingot)
	register_air_tank_3("copper", S("Triple Copper Air Tanks"), "#cd8e54", config.copper_3_uses, copper_ingot)
	register_air_tank_3("bronze", S("Triple Bronze Air Tanks"), "#c87010", config.bronze_3_uses, bronze_ingot)
end

---------------------------------------------------------------------------------------------------------
-- Compressor

local tank_inv_size = 4*4

local get_compressor_formspec
if config.compressor_needs_fuel then
	get_compressor_formspec = function(remaining_time)
		local formspec =
			"size[8,9]" ..
			"label[1,1.5;" .. S("Fuel") .. "]" ..
			get_itemslot_bg(1,2,1,1) ..
			"list[context;fuel;1,2;1,1;]" ..
			"label[4.5,0;" .. S("Tanks") .. "]" ..
			"label[2,2;" .. S("Pressure:\n@1", remaining_time) .. "]" ..
			get_itemslot_bg(3,0.5,4,4) ..
			"list[context;tanks;3,0.5;4,4;]" ..
			get_itemslot_bg(0,4.85,8,1) ..
			"list[current_player;main;0,4.85;8,1;]" ..
			get_itemslot_bg(0,6.08,8,3) ..
			"list[current_player;main;0,6.08;8,3;8]" ..
			"listring[context;tanks]" ..
			"listring[current_player;main]" ..
			get_hotbar_bg(0,4.85)
		return formspec
	end
else
	get_compressor_formspec = function()
		local formspec =
			"size[8,9]" ..
			"label[3.5,0;" .. S("Tanks") .. "]" ..
			get_itemslot_bg(2,0.5,4,4) ..
			"list[context;tanks;2,0.5;4,4;]" ..
			get_itemslot_bg(0,4.85,8,1) ..
			"list[current_player;main;0,4.85;8,1;]" ..
			get_itemslot_bg(0,6.08,8,3) ..
			"list[current_player;main;0,6.08;8,3;8]" ..
			"listring[context;tanks]" ..
			"listring[current_player;main]" ..
			get_hotbar_bg(0,4.85)
		return formspec	
	end
end

-- ensures only valid items can be placed into compressor inventories
local test_can_put = function(pos, listname, index, itemstack)
	if listname == "tanks" then
		if minetest.get_item_group(itemstack:get_name(), "airtank") > 0 then
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			if inv:get_stack(listname, index):get_count() == 0 then
				return 1
			end
		end
		return  0
	end
	if listname == "fuel" then
		local fuel, afterfuel = minetest.get_craft_result({method="fuel",width=1,items={itemstack:get_name()}})
		if fuel.time ~= 0 then
			return itemstack:get_count()
		end
		return 0
	end
	return itemstack:get_count()
end

-- whenever an inventory action is performed, makes sure there's a timer running
local ensure_timer = function(pos)
	local timer = minetest.get_node_timer(pos)
	if not timer:is_started() then
		timer:start(1)
	end
end

-- Locates the target tank to fill
local find_most_fillable = function(inv)
	local most_fillable_index = 0
	local most_fillable_capacity = 0
	local most_fillable_needs = max_uses + 1
	local most_fillable_stack
	local most_fillable_def
	for i = 1, tank_inv_size do
		local tank = inv:get_stack("tanks", i)
		local count = tank:get_count() -- for sanity-checking purposes
		if count > 1 then
			minetest.log("error", "[airtanks] Compressor at " .. minetest.pos_to_string(pos)
				.. " had a tank stack with more than one tank in it. Currently not something that's"
				.. " handled gracefully.")
			return false
		elseif count == 1 then
			local tank_def = tank:get_definition()
			local tank_capacity = tank_def._airtanks_uses
			local tank_needs
			if tank_def._airtanks_full then
				tank_needs = tank_capacity -- this is an empty tank
			else
				tank_needs = tank_capacity * (tank:get_wear() / 65535)
			end			
			if tank_needs > 0 then -- ignore tanks that are already full
				if tank_capacity > most_fillable_capacity then -- fill biggest tanks first
					most_fillable_needs = max_uses + 1
					most_fillable_capacity = tank_capacity
				end
				if tank_needs < most_fillable_needs then-- fill tanks closest to being full first
					most_fillable_needs = tank_needs
				end
				if most_fillable_capacity == tank_capacity and most_fillable_needs == tank_needs then
					most_fillable_index = i
					most_fillable_stack = tank
					most_fillable_def = tank_def
				end
			end
		end		
	end
	
	return most_fillable_index, most_fillable_stack, most_fillable_def
end

local compressor_timestep_with_fuel = function(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local fuel_time = meta:get_float("fuel_time")
	
	if (fuel_time < 1 and inv:is_empty("fuel")) or inv:is_empty("tanks") then
		return false
	end
	
	local most_fillable_index, most_fillable_stack, most_fillable_def = find_most_fillable(inv)
	
	if most_fillable_index == 0 then
		return false
	end
	
	-- we now have a tank to fill. Do we have enough fuel?
	if fuel_time < 1 then
		local fuel_item = inv:get_stack("fuel", 1) -- there should be something here or we would have exited early above
		fuel_item:set_count(1)
		local fuel_item = inv:remove_item("fuel", fuel_item)
		local burn = minetest.get_craft_result({method="fuel",width=1,items={fuel_item:get_name()}})
		fuel_time = fuel_time + burn.time
	end
	
	if fuel_time < 1 then
		-- this fuel source is producing less than 1 second of burn time. Weird, but maybe so.
		-- don't refill yet, just update the fuel burned and try again.
		-- this is an edge case so I'm not too worried about efficiency here
		meta:set_float("fuel_time", fuel_time)
		return true
	end
	
	fuel_time = fuel_time - 1
	local wear_per_use = 65535/most_fillable_def._airtanks_uses
	if most_fillable_def._airtanks_full then
		-- we're starting with a completely empty tank, turn it into a full tank and add wear.
		most_fillable_stack = ItemStack(most_fillable_def._airtanks_full)
		most_fillable_stack:set_wear(65535 - wear_per_use)
	else
		most_fillable_stack:set_wear(math.max(most_fillable_stack:get_wear() - wear_per_use, 0))
	end

	inv:set_stack("tanks", most_fillable_index, most_fillable_stack)
	meta:set_float("fuel_time", fuel_time)
	return true
end

local compressor_timestep_without_fuel = function(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	
	if inv:is_empty("tanks") then
		return false
	end
	
	local most_fillable_index, most_fillable_stack, most_fillable_def = find_most_fillable(inv)
	
	if most_fillable_index == 0 then
		return false
	end
	
	local wear_per_use = 65535/most_fillable_def._airtanks_uses
	if most_fillable_def._airtanks_full then
		-- we're starting with a completely empty tank, turn it into a full tank and add wear.
		most_fillable_stack = ItemStack(most_fillable_def._airtanks_full)
		most_fillable_stack:set_wear(65535 - wear_per_use)
	else
		most_fillable_stack:set_wear(math.max(most_fillable_stack:get_wear() - wear_per_use, 0))
	end

	inv:set_stack("tanks", most_fillable_index, most_fillable_stack)
	return true
end

local compressor_timestep
if config.compressor_needs_fuel then
	compressor_timestep = compressor_timestep_with_fuel
else
	compressor_timestep = compressor_timestep_without_fuel
end

local compressor_construct = function(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	inv:set_size("fuel", 1)
	inv:set_size("tanks", tank_inv_size)
	meta:set_float("fuel_time", 0)
	meta:set_string("formspec", get_compressor_formspec(0))
end

minetest.register_node("airtanks:compressor", {
	description = S("Air Compressor"),
	_doc_items_longdesc = compressor_desc,
	_doc_items_usagehelp = compressor_help,
	groups = {oddly_breakable_by_hand = 1, airtanks_compressor = 1, handy = 1},
	sounds = sounds,
	tiles = {
		"airtanks_compressor_bottom.png^[transformR90",
		"airtanks_compressor_bottom.png^[transformR90",
		"airtanks_compressor.png"
	},
	use_texture_alpha = "clip",
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.25, -0.4375, -0.5, 0.25, 0.0625, 0.5},
			{-0.3125, -0.5, -0.375, 0.3125, 0.125, 0.375},
			{-0.125, 0.125, -0.25, 0.125, 0.4375, 0.25},
		}
	},
	
	on_construct = compressor_construct,
	
	can_dig = function(pos,player)
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		return inv:is_empty("fuel") and inv:is_empty("tanks")
	end,

	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		local stack = inv:get_stack(from_list, from_index)
		return test_can_put(pos, to_list, to_index, stack)
	end,
    allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		return test_can_put(pos, listname, index, stack)
	end,
	on_metadata_inventory_move = ensure_timer,
    on_metadata_inventory_put = ensure_timer,
    on_metadata_inventory_take = ensure_timer,
		
	on_timer = function(pos, elapsed)
		local meta = minetest.get_meta(pos)
		local last_return = true
		while elapsed > 0 and last_return == true do
			last_return = compressor_timestep(pos)
			elapsed = elapsed - 1
		end
		if last_return == true then
			minetest.sound_play("airtanks_compressor", {pos = pos, gain = 0.5})
			minetest.get_node_timer(pos):start(1)
			meta:set_string("last_state", "success")
		elseif meta:get("last_state") == "success" then
			minetest.sound_play("airtanks_compressor_fail", {pos = pos, gain = 0.5})
			meta:set_string("last_state", "fail")
		end
		meta:set_string("formspec", get_compressor_formspec(math.floor(meta:get_float("fuel_time"))))
	end
})


minetest.register_craft({
	recipe = {
		{"", steel_ingot, ""},
		{steel_ingot, mese_crystal_fragment, steel_ingot},
		{"group:wood", steel_ingot, "group:wood"},
	},
	output = "airtanks:compressor"
})

---------------------------------------------------------------------------------------------------------
-- breathing tube

minetest.register_craftitem("airtanks:breathing_tube", {
	description = S("Breathing Tube"),
	_doc_items_longdesc = tube_desc,
	_doc_items_usagehelp = tube_help,
	inventory_image = "airtanks_breathing_tube.png",
	wield_image = "airtanks_breathing_tube.png",
})

minetest.register_craft({
	recipe = {
		{"", "group:stick", ""},
		{"", "group:stick", ""},
		{"group:wood", "group:stick", ""},
	},
	output = "airtanks:breathing_tube"
})

local function tool_active(player, item)
	local inv = player:get_inventory()
	local hotbar = player:hud_get_hotbar_itemcount()
	for i=1, hotbar do
		if inv:get_stack("main", i):get_name() == item then
			return true
		end
	end
	return false
end

local function use_any_airtank(player)
	local inv = player:get_inventory()
	local hotbar = player:hud_get_hotbar_itemcount()
	for i=1, hotbar do
		local itemstack = inv:get_stack("main", i)
		if minetest.get_item_group(itemstack:get_name(), "airtank") > 1 then
			itemstack = use_airtank(itemstack, player)
			inv:set_stack("main", i, itemstack)
			return true
		end
	end
	return false
end

local function player_event_handler(player, eventname)
	if player:is_player() and eventname == "breath_changed" and player:get_breath() < 5 and tool_active(player, "airtanks:breathing_tube") then
		if not use_any_airtank(player) then
			minetest.sound_play("airtanks_gasp", {pos = player:get_pos(), gain = 0.5})
		end
	end

	return false
end

minetest.register_playerevent(player_event_handler)

-----------------------------------------------------------------------------------------
-- Update old compressors

minetest.register_lbm({
	label = "Upgrade airtanks compressors",
	name = "airtanks:upgrade_compressors",
	nodenames = {"airtanks:compressor"},
	run_at_every_load = false,
	action = function(pos, node)
		compressor_construct(pos)
	end,
})
