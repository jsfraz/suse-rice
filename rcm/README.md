# Rice config manager

Tool for managing rice environment configuration as dynamically named
properties. Types are inferred when setting a value; getting a value requires
a fallback via `-b` used when the property is unset. A missing property is
written to the config file as that fallback.

```
rice config handler

Usage:
  rcm <command> [arguments]

Available commands:
  get <field> -b <fallback>  Get a configuration value (fallback if unset)
  set <field> <value>     Set a configuration value (type autodetected)
  help [command]          Show help information

Run 'rcm help <command>' for more information about a command.

Config file location: ~/.config/rcm/config.json
```

## Type autodetection

`rcm set` stores the value as a JSON-native type:

| Input           | Stored type |
|-----------------|-------------|
| `true` / `false`| boolean     |
| `1500`          | integer     |
| `1.5`           | float       |
| anything else   | string      |

```
rcm set mode dark
rcm set autoclick_interval 1500
rcm set force_mode true

rcm get mode -b auto
rcm get autoclick_interval -b 1000
rcm get force_mode -b false
```
