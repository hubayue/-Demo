# v7.19.2 Foe Commander Plan

**Goal:** Reproduce the frozen Web Demo's eight weekly foe commanders, their ten-card decks, 30-second telegraphs, and all fifteen current card consequences in the Godot single-player battle.

**Authority:** Frozen `reference/web-v7.19.2/index.html` functions `foeLordFor`, `foeLordTick`, `foeCast`, `foeHitUnit`, `foeSealUnit`, `foeSummon`, plus `FOE_CARDS` and `FOE_LORDS`.

**Architecture:** Add a focused `battle_foe_lord.gd` rules object owned by `BattleRun`. Keep combat consequences in the run's existing shared damage/movement paths, expose render-ready preview/cast events to `main.gd`, and keep weekly selection deterministic from `week` and city `k`.

- [x] Add failing tests for the `(week*31 + k*7) % 8` commander seat, ten-card deck, wave-eight gate, 30-second preview, 100-second draw cadence, and reshuffle.
- [x] Implement all bounded foe cards: rage, shield, heal, curse, single/row seal, fire rain, snipe, wall ram, dispel, three summon patterns, and taunt.
- [x] Make enemy shields, sealed fighters, nonlethal commander damage, curse/rage multipliers, and summoned spawn coordinates affect real battle execution.
- [x] Draw the mirrored foe wall, commander identity, next-card countdown, preview/cast feedback, and clickable ten-card deck panel.
- [x] Run focused and full tests, editor import, rendered QA, independent review, commit, and push.
