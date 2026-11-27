# Launch Yourself for Goobers!

Cannon your own ragdoll across the map. Whatever crate you land on cracks open into a Goober, an original meme critter that earns cash on your plot. Spend cash on Launch Power, fly farther, land in rarer zones, catch rarer Goobers.

This is the **week one build**: the core loop, playable end to end. Stealing, rebirth, index, game passes and zones 4 to 6 are week two.

## Play it in Studio (on 9100)

1. Install the toolchain once: [Rokit](https://github.com/rojo-rbx/rokit), then in this folder:
   ```sh
   rokit install
   wally install
   ```
2. In Studio, install the **Rojo** plugin (Plugins tab, or from the Creator Store).
3. Start syncing:
   ```sh
   rojo serve
   ```
4. Open a new **Baseplate** place, delete the Baseplate part, click **Connect** in the Rojo plugin, then press **Play**.

Or skip the live sync and build a place file: `rojo build -o goober-launch.rbxl`, then open it.

The map, plots, cannons and Goobers are all built from code, so there's nothing to place by hand.

**One-time game settings** (Home > Game Settings, after publishing):
- **Avatar > Avatar type: R15.** The ragdoll is tuned for R15, and R15-only experiences earn the higher DevEx rate on purchases from verified U.S. 18+ players.
- **Places > Max players: 6.** There are 6 plots.
- **Security > Enable Studio Access to API Services** if you want saves to persist in Studio. Without it, ProfileStore uses an in-memory mock and nothing saves (fine for playtests).

## How to play

1. Walk up to the cannon in front of your plot and press **E** (or tap the prompt).
2. **Hold** mouse, tap, or Space to charge. The meter swings back and forth. **Release in the yellow** for a perfect launch (+12% speed).
3. Fly. Flail. Land. A crate pops where you stop and drops a Goober, which goes on your plot and earns cash every second (offline too, up to 2 hours).
4. Buy **Launch Power** (bottom right) to reach the Suburbs (180+ studs) and the Mall (450+ studs), where rarer Goobers drop.
5. Plot full? A new catch auto-replaces your weakest Goober and sells it. Hold **Sell** on any Goober to sell it yourself.

## What's in the box

```
src/
  server/
    init.server.luau        boots everything in order
    Services/
      MapBuilder            field, zone stripes, signs, walls, spawn
      PlotService           6 plots x 8 pedestals, cannons, placing and selling
      LaunchService         charge -> launch -> flight -> landing -> crate
      Ragdoll               R15 Motor6D <-> BallSocketConstraint swap
      EconomyService        cash/sec, offline earnings, Launch Power purchases
      DataService           ProfileStore saves
  client/
    init.client.luau
    Controllers/
      HUD                   cash, income, upgrade button, meter, result card, toasts
      CannonController      hold-to-charge input, cannon camera, live distance
      RainbowController     color cycling for Rainbow Goobers
  shared/
    Config                  every tunable number
    GooberDefs              the 12 Goobers
    Rolls                   zone, rarity and mutation rolls (pure)
    Formulas                launch speed, costs, income, offline math (pure)
    GooberVisual            builds a Goober model from primitives
    Remotes, Format
tests/run.luau              unit tests for the pure math (Lune)
```

### Anti-exploit stance

The client sends exactly two things: a 0..1 charge value (clamped) and "buy the next Launch Power level". During flight the server takes network ownership of the character, so it runs the physics and measures the distance itself, then caps it at a ballistic maximum anyway. Rolls, cash and income never leave the server.

### Content

- **3 zones**: Backyard (0+), Suburbs (180+), Mall (450+). Each has its own rarity table (`Config.Zones`).
- **12 Goobers across 5 rarities**: Common, Uncommon, Rare, Epic, Legendary (`GooberDefs`). Original characters, no borrowed IP.
- **4 mutations**: Gold x2, Huge x3, Rainbow x5, Crispy x10 (`Config.Mutations`).

## Tuning the feel

Feel is the whole game, so tune before building more. Everything is in `src/shared/Config.luau`:

| Want | Change |
|---|---|
| Flights feel floaty or too short | `Cannon.BaseSpeed`, `Cannon.SpeedPerLevel`, `Cannon.PitchDegrees` |
| Sweet spot too easy or hard | `Cannon.SweetSpotMin/Max`, `Cannon.MeterCycleSeconds` |
| Zones reached too fast or slow | `Zones[i].StartDistance`, `Upgrades.BaseCost/CostGrowth` |
| Rarer drops | `Zones[i].RarityWeights`, `Mutations[i].Chance` |
| More or less flailing | `Cannon.SpinStrength`, joint limits in `Ragdoll.luau` |

Rough range at a full charge is `speed^2 x sin(2 x pitch) / 196.2` studs, plus the launch height and a short tumble after landing (`Flight.GroundSpeedKeptPerStep`). Measured in Studio, a perfect launch goes about 82 studs at level 0 and about 250 at level 6.

## Dev commands

```sh
stylua src tests      # format
selene src            # lint
lune run tests/run    # unit tests
rojo build -o goober-launch.rbxl
```

CI runs all four on every PR.
