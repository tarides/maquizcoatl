# Experiment #13 tools

Two command-line tools for experiment #13 (upgrade cost), see
`plans/13-upgrade-cost.md`:

- `upgrade_mining` (library `src/`, `bin/upgrade_mining.ml`): Part C,
  mines the history of the projects for tool bumps and their diffs.
- `upgrade_builds` (library `builds/`, `bin/upgrade_builds.ml`): Part A,
  installs the toolchains, prepares and runs the timed builds, and
  records one CSV row per run. `upgrade_builds --help` lists the commands.

## Dependencies

- OCaml 5.4 or later (the code uses `Result.Syntax`, `In_channel`,
  `Out_channel`) and dune 3.0 or later.
- `unix` (with the compiler).
- `cmdliner` 2.0 or later, for `upgrade_builds` (`Arg.Conv`, `Cmd.eval'`).
- `alcotest`, for the tests.

At run time, `upgrade_builds` needs Linux with GNU coreutils (`timeout`,
`nice`, `sha256sum`) and util-linux (`taskset`), plus `git`, `curl`,
`tar`, `unzip` and `opam` for the installs. Some tests start `sh`,
`sleep` and `true` under `timeout` and `taskset`; they are skipped where
those programs are missing.

## Build and test

    dune build @check
    dune test
