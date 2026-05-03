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
