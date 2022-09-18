A simple mod for extending one's underwater excursion time.

Air tanks are crafted from copper, steel, or bronze ingots and are wielded like tools. A compressor is crafted from steel, mese shard, and wood.

Place a compressor in world and click on it with an empty air tank to fill it. Compressors can also recharge partly-used tanks. Compressors require fuel, unless that configuration option has been disabled.

When running low on breath use a filled air tank to recharge your breath bar. One use will replenish 5 steps of breath (out of 10). By default a steel air tank will hold 30 uses, a bronze one holds 20, and a copper one holds 10 - these settings can be changed in the mod's section under Advanced Settings. Once a tank runs out of uses it turns into an empty tank, which can be recharged again with a compressor.

To automatically draw air from air tanks, craft a breathing tube and put it in your quick-use inventory row. When your breath bar drops below 5 steps it will automatically attempt to use an air tank from your quick-use inventory row to replenish it.

## Dependencies

This mod will work with either the default minetest_game (and most other games derived from it), or it will work with MineClone2 or MineClone5. Bronze ingots aren't available in Mineclone and so bronze tanks are not an option when running in that environment.

Although these games are listed as optional dependencies this mod will throw an assert if one of the two are not installed.