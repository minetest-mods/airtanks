-- internationalization boilerplate
local MP = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")

local print_settingtypes = false
local CONFIG_FILE_PREFIX = "airtanks_"
local config = {}

local function setting(stype, name, default, description)
	local value
	if stype == "bool" then
		value = minetest.setting_getbool(CONFIG_FILE_PREFIX..name)
	elseif stype == "string" then
		value = minetest.setting_get(CONFIG_FILE_PREFIX..name)
	elseif stype == "int" or stype == "float" then
		value = tonumber(minetest.setting_get(CONFIG_FILE_PREFIX..name))
	end
	if value == nil then
		value = default
	end
	config[name] = value
	
	if print_settingtypes then
		minetest.debug(CONFIG_FILE_PREFIX..name.." ("..description..") "..stype.." "..tostring(default))
	end	
end

setting("int", "steel_uses", 30, "Number of uses for a steel air tank")
setting("int", "copper_uses", 10, "Number of uses for a copper air tank")
setting("int", "bronze_uses", (config.steel_uses + config.copper_uses)/2, "Number of uses for a bronze air tank")

local recharge_airtank = function(itemstack, user, pointed_thing, full_item)
	if pointed_thing.type ~= "node" then return itemstack end
	local node = minetest.get_node(pointed_thing.under)
	if minetest.get_item_group(node.name, "airtanks_compressor") > 0 then
		if itemstack:get_name() == full_item then
			itemstack:set_wear(0)
		else
			local inv = user:get_inventory()
			local leftover = inv:add_item("main", full_item)
			if leftover:get_count() == 0 then
				itemstack:set_count(itemstack:get_count()-1)
			end
		end
		minetest.sound_play("airtanks_compressor", {pos = pointed_thing.under, gain = 0.5})
	end
	return itemstack
end

local use_airtank = function(itemstack, user, pointed_thing, uses, full_item, empty_item)
	itemstack = recharge_airtank(itemstack, user, pointed_thing, full_item) -- first check if we're clicking on a compressor

	local breath = user:get_breath()
	if breath > 9 then return itemstack end
	breath = math.min(10, breath+5)
	user:set_breath(breath)
	minetest.sound_play("airtanks_hiss", {pos = user:getpos(), gain = 0.5})

	if not minetest.setting_getbool("creative_mode") then
		local wdef = itemstack:get_definition()
		itemstack:add_wear(65535/(uses-1))
		if itemstack:get_count() == 0 then
			if wdef.sound and wdef.sound.breaks then
				minetest.sound_play(wdef.sound.breaks,
					{pos = user:getpos(), gain = 0.5})
			end
			local inv = user:get_inventory()
			itemstack = inv:add_item("main", empty_item)
		end
	end
	return itemstack
end

local function register_air_tank(name, desc, color, uses, material)
	minetest.register_craftitem("airtanks:empty_"..name.."_tank", {
		description = S("Empty @1", desc),
		inventory_image = "airtanks_airtank.png^[multiply:"..color.."^airtanks_empty.png",
		wield_image = "airtanks_airtank.png^[multiply:"..color.."^airtanks_empty.png",
		stack_max = 99,
		
		on_place = function(itemstack, user, pointed_thing)
			return recharge_airtank(itemstack, user, pointed_thing, "airtanks:"..name.."_tank")
		end,
		
		on_use = function(itemstack, user, pointed_thing)
			return recharge_airtank(itemstack, user, pointed_thing, "airtanks:"..name.."_tank")
		end,
	})

	minetest.register_tool("airtanks:"..name.."_tank", {
		description = desc,
		groups = {not_repaired_by_anvil = 1},
		inventory_image = "airtanks_airtank.png^[multiply:"..color,
		wield_image = "airtanks_airtank.png^[multiply:"..color,
		stack_max = 1,
	
		on_place = function(itemstack, user, pointed_thing)
			return use_airtank(itemstack, user, pointed_thing, uses, "airtanks:"..name.."_tank", "airtanks:empty_"..name.."_tank")
		end,

		on_use = function(itemstack, user, pointed_thing)
			return use_airtank(itemstack, user, pointed_thing, uses, "airtanks:"..name.."_tank", "airtanks:empty_"..name.."_tank")
		end,
	})
	
	minetest.register_craft({
		recipe = {
			{"", material, ""},
			{material, "", material},
			{"", material, ""},
		},
		output = "airtanks:empty_"..name.."_tank"
	})
	
end

register_air_tank("steel", S("Steel Air Tank"), "#d6d6d6", config.steel_uses, "default:steel_ingot")
register_air_tank("copper", S("Copper Air Tank"), "#cd8e54", config.copper_uses, "default:copper_ingot")
register_air_tank("bronze", S("Bronze Air Tank"), "#c87010", config.bronze_uses, "default:bronze_ingot")

minetest.register_node("airtanks:compressor", {
	description = S("Air Compressor"),
	groups = {oddly_breakable_by_hand = 1, airtanks_compressor = 1},
	sounds = default.node_sound_metal_defaults(),
	tiles = {
		"airtanks_compressor_bottom.png^[transformR90",
		"airtanks_compressor_bottom.png^[transformR90",
		"airtanks_compressor.png"
	},
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
	}
})

minetest.register_craft({
	recipe = {
		{"", "default:steel_ingot", ""},
		{"default:steel_ingot", "default:mese_crystal_fragment", "default:steel_ingot"},
		{"group:wood", "default:steel_ingot", "group:wood"},
	},
	output = "airtanks:compressor"
})