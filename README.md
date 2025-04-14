# retroarch_cfg_merge

A small utility to merge multiple `retroarch.cfg` files.

RetroArch already lets you overlay multiple config files via CLI, however, sometimes you don't have much control over how RetroArch is invoked (e.g. retro handhelds). This helps alleviate those odd cases.

## Usage
```
Usage: cfg_merge <one.cfg> [two.cfg ... [n].cfg] [--output=output_file]
  Merges multiple RetroArch config files, with later files taking precedence.
  If --output is not specified, the result is printed to stdout.
```
