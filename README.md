# Gamekit

Gamekit is the code games share: the game standard they implement, the host
that runs them under supervision, and the tool that packs a game into its own
portable `.zx` app. Games import it through `ziran.toml`; nothing in it depends
on a particular collection or player.

```toml
[dependencies.gamekit]
git = "https://github.com/kryonlabs/gamekit.git"
ref = "master"
```

## Modules

- `gamekit/contract` is the game standard, `standards/game-v1.json`: contract,
  module and host API versions, the required and optional host calls, record
  and resource limits, `GameDescriptorRead`/`GameDescriptorAccepted` for a
  game's `catalog.json`, `GameLocaleLookup` for its locale files and the shared
  `GameProfile`. Portable; games import it too.
- `gamekit/host` runs one game bundle for a native host: `GameOpen(game,
  data_directory, locale)`, `GameFrame(frame)` and `GameClose()`. It checks the
  bundle against the standard, answers the standard's host calls, keeps records
  under `DATA/games/<id>/records` and extracts assets under `.../resources`.
  `GameSetProfile(profile)` sets the profile `AppProfileHost` gives every game:
  a collection shares its one profile with each downloaded game, and a
  standalone game keeps its own local one.

A game asks for the profile with
`AppProfileHost :: () -> GameProfile #foreign host_api;` and treats an empty
`identity` as signed out.

## Packing a game

From the game's own project:

```sh
ziran tool gamekit pack catalog.json build/apps/wurm.zx
ziran tool gamekit pack editor/catalog.json build/apps/wurm-editor.zx
```

`MANIFEST` is the app's `catalog.json`, relative to the project root. `pack`
then:

1. stages `assets` as `build/gamekit/<name>/assets/<name>/`, adds the copies
   in a `shared_assets.json` beside the manifest and writes `catalog.json`
   without `build_defines` and `prepare_assets`;
2. removes what a `bundle.json` beside the manifest leaves out (`leave_out`
   wildcard patterns, plus `release_leave_out` with `--release`) and keeps
   `art.json` to the remaining files;
3. writes the `[<locale_prefix>…]` blocks of each `locales/*.txt` to
   `locales/` and the matching `GameLocaleText(language, key)` to
   `build/gamekit/<name>-generated/translations.zi`;
4. runs the game's `prepare_assets` program, a Ziran program built from the
   game's project (or the game's own Python script), as
   `PROGRAM RESOURCES GENERATED`;
5. for an app whose `apps.json` entry `requires` another app of the project,
   replaces byte-identical shared copies by links to that app's resources and
   writes `requirements.json` with the links and the required bundle's
   SHA-256. An add-on that reuses the game's code imports the game's modules;
   the linker builds that code into the add-on's own bundle;
6. bundles `source` and `entry` with `ziran bundle --project`, using the
   game's own lock (`--locked` without a `ziran.local.toml`), its
   `build_defines` and `KRYON_HOSTED_UI`.

Pack an app before the apps that require it; they are looked up as
`<name>.zx` in the output's folder.

The bundle step passes `build/gamekit/<name>-generated` as
`--module-path`, so the game imports `translations` and the modules its
preparation program writes like its own modules; its locked packages never
see them. This needs a game lock pinning Ziran 0c95f849 or later.

## Tests

```sh
make test
```

It checks the modules, compares the contract with `standards/game-v1.json`,
tests the profile record, locale generation, exclusions and add-on links, and
packs `tests/fixture-game` and its add-on with `ziran tool gamekit pack`,
then opens both bundles with Ziran's bundle loader. The fixture test locks a
copy of the fixture against this checkout and the packages `ziran.lock`
already pins, so it fetches nothing.
