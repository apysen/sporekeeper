# Long-term TODO

Work that is deliberately not being done yet, and why. Each entry is parked rather than
forgotten: it names what exists today, what would have to be decided before it can be
built, and where it would be built.

A changelog's "Still to do" is for the next day or two. This is for the things that
need a design decision rather than an afternoon.

## Meta-progression: unlocks across runs

**Today.** `src/core/entities/meta/meta_record.gd` accumulates finished runs, victories,
and the best wave and Biomass reached in each mode. Two screens read it - the title
screen shows the record, and the run result panel says whether the run that just ended
beat the mode's best. `SaveStore` keeps it in `user://save.dat`, separately from the run
in progress, so clearing one leaves the other alone.

**Nothing in a run consults it.** It unlocks nothing and grants nothing.

**What has to be decided first.** What a run earns that outlives it, what that buys,
and what it does to the next run. That is a design question about how the game should
feel over ten runs rather than one, and answering it by building whatever is easy to
store would set the answer by accident:

- What is the currency - waves survived, runs finished, Biomass earned, a specific
  achievement?
- What does it unlock - new Adaptations in the draft pool, starting relics, difficulty
  tiers, cosmetic discoveries, arena variants?
- Does an unlock make a run stronger or wider? A stronger one changes balance for every
  run after it; a wider one changes what a run can be.
- Is any of it revocable - a prestige, a reset, a per-mode split?

**Where it goes when it is answered.** The record is already the right shape to grow
into: add fields to `MetaRecord`, read them in whatever rule owns eligibility (the draft
pool lives in `src/core/rules/progression/`), and give `SaveStore.MIGRATIONS` its first
entry so existing saves carry forward. The persistence, the file format and the
migration chain are built and tested; this is a design decision wearing a storage
problem.

## Several save slots

**Today.** There is exactly one. Starting a new run from the title screen asks before
overwriting a saved one, and that confirmation exists precisely because there is nowhere
else for the old run to go.

**Why it is parked.** Several slots is a different feature rather than a bigger number:
it needs a slot-selection screen, a way to name or recognise each one, a rule for what
happens when they are all full, and it changes what the overwrite confirmation is for.
Nobody has asked to run two Sporekeeper games at once.

**Where it goes.** `src/core/persistence/save_store.gd` owns the path and is the only
thing that knows the file exists, so the storage half is a parameter. The menu half is
the feature.
