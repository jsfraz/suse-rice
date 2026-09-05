package main

import (
	"fmt"
	"strings"
)

// Command represents a CLI command interface
type Command interface {
	Execute(args []string) error
	Help() string
}

// GetCommand handles reading config values
type GetCommand struct{}

// SetCommand handles writing user config values
type SetCommand struct{}

// SetFallbackCommand handles writing fallback config values
type SetFallbackCommand struct{}

// HelpCommand displays usage information
type HelpCommand struct{}

const getUsage = "Usage: rcm get <field> [-f <fallback>]"
const setUsage = "Usage: rcm set <field> <value>"
const setFallbackUsage = "Usage: rcm set-fallback <field> <value> [<field> <value> ...]"

func parseGetArgs(args []string) (field string, fallback any, fallbackSet bool, err error) {
	var fieldName string
	var fallbackRaw string

	for i := 0; i < len(args); i++ {
		arg := args[i]
		name, value, hasValue := splitFlag(arg)

		switch {
		case name == "f" || name == "fallback":
			if !hasValue {
				if i+1 >= len(args) {
					return "", nil, false, fmt.Errorf("flag -%s needs an argument\n%s", name, getUsage)
				}
				i++
				value = args[i]
			}
			fallbackRaw = value
			fallbackSet = true
		case strings.HasPrefix(arg, "-"):
			return "", nil, false, fmt.Errorf("unknown flag: %s\n%s", arg, getUsage)
		default:
			if fieldName != "" {
				return "", nil, false, fmt.Errorf("unexpected argument: %s\n%s", arg, getUsage)
			}
			fieldName = arg
		}
	}

	if fieldName == "" {
		return "", nil, false, fmt.Errorf("missing field name\n%s", getUsage)
	}

	if fallbackSet {
		return fieldName, parseValue(fallbackRaw), true, nil
	}
	return fieldName, nil, false, nil
}

func parseFieldValue(args []string, usage string) (field string, value any, err error) {
	if len(args) < 2 {
		return "", nil, fmt.Errorf("missing field name or value\n%s", usage)
	}
	return args[0], parseValue(strings.Join(args[1:], " ")), nil
}

func parseFieldValuePairs(args []string, usage string) ([]struct {
	field string
	value any
}, error) {
	if len(args) < 2 || len(args)%2 != 0 {
		return nil, fmt.Errorf("missing field name or value\n%s", usage)
	}
	pairs := make([]struct {
		field string
		value any
	}, 0, len(args)/2)
	for i := 0; i < len(args); i += 2 {
		pairs = append(pairs, struct {
			field string
			value any
		}{args[i], parseValue(args[i+1])})
	}
	return pairs, nil
}

func splitFlag(arg string) (name, value string, hasValue bool) {
	switch {
	case strings.HasPrefix(arg, "--"):
		name = strings.TrimPrefix(arg, "--")
	case strings.HasPrefix(arg, "-") && arg != "-":
		name = strings.TrimPrefix(arg, "-")
	default:
		return "", "", false
	}

	if n, v, ok := strings.Cut(name, "="); ok {
		return n, v, true
	}
	return name, "", false
}

// Execute prints a property value. User value wins over stored fallback.
// Optional -f seeds fallback when it is not already stored.
func (c GetCommand) Execute(args []string) error {
	fieldName, fallback, fallbackSet, err := parseGetArgs(args)
	if err != nil {
		return err
	}

	var value any
	_, err = withConfig(func(config *Config) (bool, error) {
		var wrote bool
		var resolveErr error
		value, wrote, resolveErr = config.Resolve(fieldName, fallback, fallbackSet)
		return wrote, resolveErr
	})
	if err != nil {
		return err
	}

	fmt.Println(formatValue(value))
	return nil
}

func (c GetCommand) Help() string {
	return `Usage: rcm get <field> [-f <fallback>]

Get a configuration value by name. Returns the user value from 'rcm set'
when present, otherwise the stored fallback. If neither exists, -f /
--fallback is stored under fallback and printed. -f does not overwrite an
existing fallback. Type is inferred the same way as for 'rcm set'.

Examples:
  rcm get mode
  rcm get mode -f auto
  rcm get autoclick_interval -f 1000
  rcm get force_mode -f false
  rcm get background -f /home/user/wallpaper.jpg`
}

// Execute stores a user property, inferring bool, integer, float, or string.
func (c SetCommand) Execute(args []string) error {
	fieldName, value, err := parseFieldValue(args, setUsage)
	if err != nil {
		return err
	}

	if _, err := withConfig(func(config *Config) (bool, error) {
		config.Set(fieldName, value)
		return true, nil
	}); err != nil {
		return err
	}

	fmt.Printf("Successfully set %s to: %s\n", fieldName, formatValue(value))
	return nil
}

func (c SetCommand) Help() string {
	return `Usage: rcm set <field> <value>

Set a user configuration value by name. Stored under value and preferred
by 'rcm get' over fallback. The data type is inferred from the value:

  true / false  - boolean
  1500          - integer
  1.5           - float
  anything else - string

Property names are not predefined; any name can be stored.

Examples:
  rcm set mode dark
  rcm set keyboard cz
  rcm set autoclick_interval 1500
  rcm set force_mode true
  rcm set background /home/user/wallpaper.jpg`
}

// Execute stores fallback properties used when the user value is unset.
func (c SetFallbackCommand) Execute(args []string) error {
	pairs, err := parseFieldValuePairs(args, setFallbackUsage)
	if err != nil {
		return err
	}

	if _, err := withConfig(func(config *Config) (bool, error) {
		for _, pair := range pairs {
			config.SetFallback(pair.field, pair.value)
		}
		return true, nil
	}); err != nil {
		return err
	}

	for _, pair := range pairs {
		fmt.Printf("Successfully set fallback %s to: %s\n", pair.field, formatValue(pair.value))
	}
	return nil
}

func (c SetFallbackCommand) Help() string {
	return `Usage: rcm set-fallback <field> <value> [<field> <value> ...]

Set one or more fallbacks used by 'rcm get' when the user value is unset.
Stored under fallback and does not change a value written by 'rcm set'.
Type inference matches 'rcm set'. Alias: setFallback.

Examples:
  rcm set-fallback mode auto
  rcm set-fallback keyboard cz
  rcm set-fallback color blue wallpaper /usr/share/hypr/wall0.png
  rcm set-fallback autoclick_interval 1000
  rcm set-fallback force_mode false
  rcm set-fallback background /home/user/wallpaper.jpg`
}

func (c HelpCommand) Execute(args []string) error {
	if len(args) > 0 {
		switch args[0] {
		case "get":
			fmt.Println(GetCommand{}.Help())
		case "set":
			fmt.Println(SetCommand{}.Help())
		case "set-fallback", "setFallback":
			fmt.Println(SetFallbackCommand{}.Help())
		default:
			return fmt.Errorf("unknown command: %s", args[0])
		}
		return nil
	}

	fmt.Println(`rice config handler

Usage:
  rcm <command> [arguments]

Available commands:
  get <field> [-f <fallback>]     Get a configuration value
  set <field> <value>             Set a user configuration value
  set-fallback <field> <value> ...  Set fallbacks for get
  help [command]                  Show help information

Run 'rcm help <command>' for more information about a command.

Config file location: ~/.config/rcm/config.json`)

	return nil
}

func (c HelpCommand) Help() string {
	return `Usage: rcm help [command]

Display help information about rcm commands.`
}
