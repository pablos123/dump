# Tests

Run all:

```
bats tests/
```

Run one file:

```
bats tests/test-db.bats
```

Tests use ephemeral SQLite files via mktemp and stub `pokeapi_get` against
JSON fixtures under `tests/fixtures/`. Each test cleans up after itself.

`pokidle rebuild-biomes` is excluded from automated tests because it makes
~1000 live API calls (~10 min wall clock at the 0.5 s rate limit). Run
manually after Plan B is wired up.
