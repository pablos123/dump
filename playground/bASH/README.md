# pokidle

A passive Pokemon encounter daemon for the Linux desktop, written in Bash.

It runs as a systemd user service and, on a slow cadence, "encounters" wild
Pokemon, drops items, levels/befriends/evolves your current-week catches, and
rarely spawns a legendary. Each event fires a desktop notification (and
optionally a sound). A CLI inspects, filters, and exports your catches.

The world has 36 type-themed biomes that rotate every few hours and decide
which species, items, and berries appear.

## Dependencies

Required:

- `bash` 4+, `jq`, `curl`, `sqlite3`, `awk`
- `notify-send` (libnotify)
- `systemd` (user instance) — the daemon runs as a user service

Optional (degrade gracefully):

- `paplay` or `aplay` — notification sounds
- `chafa` — inline sprite previews in `list` / `items` (auto-uses
  kitty/sixel for pixel-perfect output where supported)

## Install

```sh
git clone https://github.com/pablos123/pokidle.git && cd pokidle && ./pokidle setup
```

`setup` installs config/assets/unit, seeds the 36 prebuilt encounter pools, and
**enables and starts** `pokidle.service` — installing pokidle activates it.
Pass `--no-enable` to install without starting. Ensure `~/.local/bin` is on
your `PATH`.

Install is symlink-based: the `~/.local/bin/pokidle` launcher, the asset
symlinks, and the service `ExecStart` all point back into this clone. **Keep
the repo where it is** — moving or deleting it breaks the install. To relocate,
`uninstall`, move the clone, then `setup` again.

## Usage

After `setup`, `pokidle` is on your `PATH`:

```sh
pokidle --help
```

## Configuration

All paths, cadences, odds, and toggles are environment variables. See
[docs/configuration.md](docs/configuration.md) for the full reference, and
[docs/notifications.md](docs/notifications.md) for notification/sound options.

## pokeapi CLI

`pokeapi` is a standalone cache-aware PokeAPI probe used in development
(`pokeapi pokemon metagross`, `pokeapi sprite eevee`). Independent of the
daemon; run `pokeapi help`.

## Tests

```sh
bats tests/
```

Ephemeral SQLite + stubbed PokeAPI fixtures. No network required.

## Notes

- Data is rolled against the live [PokeAPI](https://pokeapi.co) (cached on disk)
  and stored in a local SQLite database at `$POKIDLE_DB_PATH`.
- Shipped pools skip the cold rebuild, but the first `tick` of each kind still
  fetches species/nature/move data from PokeAPI (cached after), so the daemon
  needs network on first run.
