# Changelog

## [Unreleased]

- Pack add-ons for Ziran's one-format ZX: an add-on imports its game's modules and its bundle carries that code. The `shared_code` and `library_entries` fields of `apps.json` are removed.
- Game standard, supervised game host with a shared player profile, and `ziran tool gamekit pack` to pack a game into its own portable app.
- Packed games can import the generated `translations` module and modules their asset preparation writes.
