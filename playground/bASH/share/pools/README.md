# pokidle shipped encounter pools

One JSON per biome. Used to seed `$POKIDLE_CACHE_DIR/pools/` during
`pokidle setup` so the first run skips the ~2 hour cold rebuild against
PokeAPI.

| Field | Meaning |
|-------|---------|
| `biome`    | biome id (matches `config/biomes.json`) |
| `built_at` | UTC ISO timestamp of the rebuild |
| `schema`   | pool format version — must match the value used by `lib/encounter.bash` (currently `3`) |
| `tiers`    | `{common, uncommon, rare, very_rare}` arrays of `{species, min, max}` |
| `berries`  | array of held-berry candidates |

## How setup uses these files

`pokidle setup` copies (not symlinks) `share/pools/*.json` into
`$POKIDLE_CACHE_DIR/pools/`. Existing cache files are kept; pass
`--force` to overwrite. Files whose `schema` does not match the
current code version are skipped with a warning.

## Refreshing the shipped pools

Maintainer-only workflow — end users should run `pokidle rebuild-pool`
to refresh their own cache instead.

```sh
scripts/build-shipped-pools.sh
git add share/pools/*.json
git commit -m "share/pools: refresh against live PokeAPI"
```

`scripts/build-shipped-pools.sh` wipes `$POKIDLE_CACHE_DIR/pools/`,
rebuilds every biome via the live API (respects
`$POKEAPI_RATE_LIMIT_SLEEP`), then copies the freshly-built JSON into
this directory.

## When the shipped pools go stale

- The pool schema in `lib/encounter.bash` is bumped → regenerate.
- A biome is added, removed, or renamed in `config/biomes.json` →
  regenerate (otherwise that biome will rebuild on demand the first
  time it rotates in).
- PokeAPI updates species data and you want the new values →
  regenerate (no urgency; old data still rolls correctly).
