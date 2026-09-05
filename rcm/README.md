# Rice config manager

Tool for managing rice environment configuration as dynamically named
properties. Types are inferred when setting a value. User values (`rcm set`)
and fallbacks (`rcm set-fallback` or `get -f`) are stored separately. `get`
returns the user value when set, otherwise the fallback.

```
rice config handler

Usage:
  rcm <command> [arguments]

Available commands:
  get <field> [-f <fallback>]     Get a configuration value
  set <field> <value>             Set a user configuration value
  set-fallback <field> <value> ...  Set fallbacks for get
  help [command]                  Show help information

Run 'rcm help <command>' for more information about a command.

Config file location: ~/.config/rcm/config.json
```

## Config file

`~/.config/rcm/config.json` has two objects. `set` writes `value`;
`set-fallback` (one or more field/value pairs) and a first-time `get -f`
write `fallback`. `get` never copies a fallback into `value`. Concurrent
`rcm` processes lock the file and replace it atomically.

```json
{
  "value": {
    "mode": "dark"
  },
  "fallback": {
    "mode": "auto",
    "keyboard": "cz"
  }
}
```

A legacy flat object (`{"color": "blue"}`) is migrated into `value` on load.

## Type autodetection

`rcm set` and `rcm set-fallback` store the value as a JSON-native type:

| Input           | Stored type |
|-----------------|-------------|
| `true` / `false`| boolean     |
| `1500`          | integer     |
| `1.5`           | float       |
| anything else   | string      |

```
rcm set-fallback mode auto
rcm set-fallback autoclick_interval 1000
rcm set-fallback force_mode false

rcm set mode dark
rcm set autoclick_interval 1500
rcm set force_mode true

rcm get mode
rcm get mode -f auto
rcm get autoclick_interval -f 1000
rcm get force_mode -f false
```
