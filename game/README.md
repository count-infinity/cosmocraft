# The Claim (Milestone 0)

The first playable slice of the [game vision](../design/game_vision.md): one sector of dark regions, a ship, and the siege. Nothing else yet.

**Run it:** open `game/main.tscn` in the editor and press F6, or double-click `run_claim.bat`.

## How to play

You start in your home region, the one patch of light in the sector. Regions that border your light pulse with a gold diamond.

1. Fly into a bordering region and press **E** to kindle a spark.
2. Stay inside the region while the progress bar fills. Bigger regions take longer.
3. The Gloom pours in from the dark edges. Kills drop sparks; collecting them speeds up the claim.
4. Snuffers ignore you and crawl toward your spark. If one reaches it, you lose 15%. An elite one arrives at 90%.
5. Leave the region and progress pauses, then drains after 3 seconds. Shields only recharge in your own light, so retreating is always possible, but it costs you.
6. At 100% the region ignites: it's yours, and the regions beyond it open up.

## Controls

| Input | Action |
|---|---|
| WASD | Move |
| Mouse | Aim |
| Hold left click | Fire |
| Space / Shift | Dash (brief invulnerability) |
| E | Kindle a spark |
| Tab / M | Sector map (pauses) |
| Esc | Pause |
| H | Hide the controls hint |
| F1 / F2 / F3 | Debug overlay / claim speed 1x-3x-10x / god mode |
| F4 / F5 | New random sector / mute |
| F11 | Fullscreen |

## What to judge while playing

The milestone asks one question: **is holding a polygon under pressure fun on its own?** Things worth noticing:

- Do small and large regions feel different, or just longer?
- Does the pressure ramp feel right? Is the first third too calm, the last tenth too chaotic?
- Is going back into your light to recharge a real decision?
- Does ignition feel like a payoff?
- Does the ship feel good to fly? (Drift, dash, fire rate.)

## Tuning

Every number lives in `space/space_tuning.gd`: claim time per screen of area, grace period, drain rate, spark value, wave budget and ramp, ship speed, dash, fire rate, shields. Change the defaults there, or give the `SpaceGame` node in `main.tscn` a tuning resource and edit it in the inspector.
