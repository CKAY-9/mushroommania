# Mushroom Mania

Mushroom Mania is a Garry's Mod addon for the DarkRP gamemode where players are able to cultivate different species of Mushrooms.

## Grow loop

1. Buy a **MonoTub**, **Filters**, **Substrate**, **Cleaning Agent**, a **Liquid Culture** and a **Spray Bottle** (F4 > Mushroom Mania).
2. Drop the **Substrate** onto the MonoTub.
3. Drop up to **2 Filters** onto the MonoTub (filters can be added or replaced at any time).
   - 2 filters: no degradation
   - 1 filter: degrades over time (150s of health by default)
   - 0 filters: the tub is contaminated after 30s of growing
4. Tilt the **Cleaning Agent** over the MonoTub (physgun-rotate it, or tip it over on top) to pour it in.
5. Drop a **Liquid Culture** onto the MonoTub to start growing.
6. Keep humidity in the ideal range with the **Spray Bottle** and replace filters as they wear out.
7. After the grow time, press **E** on the MonoTub to harvest. The substrate is used up and the tub loses a use (5 total).
8. Optionally, drop raw mushrooms onto a **Food Drier** (holds 50g), press **E** to start it, wait 120s, then press **E** to collect them dried (they're worth more). It's loud while running, so nearby players can hear it.
9. Put the mushrooms near a **Mushroom Enthusiast** and press **E** on the Enthusiast to sell everything nearby.

Selling contaminated mushrooms pays 10% and every Mushroom Enthusiast refuses you for 10 minutes.

## Strains

Cheapest to most valuable. Prices are per gram at 100% quality.

| Strain          | Culture | Raw  | Dried | Grow time | Notes |
|-----------------|---------|------|-------|-----------|-------|
| Lion's Mane     | $250    | $30  | $55   | 5 min     | Beginner: no filters or cleaning agent needed, forgiving humidity (20-100%) |
| Golden Teachers | $500    | $60  | $110  | 6 min     | Standard grow loop |
| Penis Envy      | $800    | $85  | $155  | 7 min     | Standard grow loop |
| Tidal Wave      | $1,100  | $110 | $200  | 8 min     | Standard grow loop |
| Enigmas         | $1,500  | $150 | $275  | 10 min    | Expert: humidity must stay at 80-90% for Perfect (5s grace), and it's contaminated the moment it has no filter (a filter must be fitted before the culture goes in). Its culture, tub, bags and drier glow faintly purple |

## Quality

A grow starts with 100 score and loses points every second the humidity is outside the ideal range.

| Quality      | Value | Score |
|--------------|-------|-------|
| Perfect      | 110%  | 90+   |
| Good         | 100%  | 70+   |
| Okay         | 80%   | 45+   |
| Poor         | 50%   | 0+    |
| Contaminated | 10%   | -     |

## Configuration

Everything lives in [`lua/mushroommania/sh_config.lua`](lua/mushroommania/sh_config.lua): F4 prices and limits, timers, filter degradation, humidity, quality tiers, models, sounds and label colours.

- **New species:** copy a block in `C.Species`. A `mm_culture_<key>` entity and its F4 entry are created automatically. Optional per-species rules (`NeedsFilters`, `NeedsCleaning`, `UnfilteredContaminateTime`, `PerfectHumidity`, and any `C.Grow` value) are documented above the table.
- **F4 menu:** set `C.Shop.Register = false` to register the items yourself in `darkrpmodification`.
- **Models:** the current models are HL2 placeholders. Change `Model` in each entity's config block.

### In-game settings

**Q menu > Utilities > Mushroom Mania > Settings** lets permitted staff change these live, for everyone:

- whether the items are sold in the F4 menu (added or removed live)
- raw and dried sell prices for each species
- the value % for each quality, including Contaminated

Press **Save** to apply and broadcast. **Discard changes** reloads the current values, and **Reset to config defaults** (click twice) goes back to `sh_config.lua`. Overrides are saved to `data/mushroommania/settings.json` and survive restarts.

Access uses the CAMI permission **"Mushroom Mania Settings"**, so ULX, SAM and similar admin mods list it. It defaults to admins and above; change `C.Settings.MinAccess` to adjust that.

## Mushroom Enthusiasts

Spawn them from the Q menu (Entities > Mushroom Mania, admin only), then run `mm_save_enthusiasts` as superadmin to keep them on the current map.

## Entities

| Class                 | Description                                         |
|-----------------------|-----------------------------------------------------|
| `mm_monotub`          | Grow container                                      |
| `mm_filter`           | Filter                                              |
| `mm_substrate`        | Substrate                                           |
| `mm_cleaning_agent`   | Cleaning agent (tilt to pour)                       |
| `mm_culture_<species>`| Liquid culture, one per species                     |
| `mm_mushrooms`        | Harvested batch (raw or dried)                      |
| `mm_food_drier`       | Food Drier                                          |
| `mm_enthusiast`       | Buyer NPC                                           |
| `mm_spray_bottle`     | Spray Bottle SWEP                                   |
