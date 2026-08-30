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

// SetCommand handles writing config values
type SetCommand struct{}

// HelpCommand displays usage information
type HelpCommand struct{}

const getUsage = "Usage: rcm get <field> -b <fallback>"

func parseGetArgs(args []string) (field string, backup any, err error) {
	var fieldName string
	var backupRaw string
	var backupSet bool

	for i := 0; i < len(args); i++ {
		arg := args[i]
		name, value, hasValue := splitFlag(arg)

		switch {
		case name == "b" || name == "backup":
			if !hasValue {
				if i+1 >= len(args) {
					return "", nil, fmt.Errorf("flag -%s needs an argument\n%s", name, getUsage)
				}
				i++
				value = args[i]
			}
			backupRaw = value
			backupSet = true
		case strings.HasPrefix(arg, "-"):
			return "", nil, fmt.Errorf("unknown flag: %s\n%s", arg, getUsage)
		default:
			if fieldName != "" {
				return "", nil, fmt.Errorf("unexpected argument: %s\n%s", arg, getUsage)
			}
			fieldName = arg
		}
	}

	if fieldName == "" {
		return "", nil, fmt.Errorf("missing field name\n%s", getUsage)
	}
	if !backupSet {
		return "", nil, fmt.Errorf("missing backup flag\n%s", getUsage)
	}

	return fieldName, parseValue(backupRaw), nil
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

// Execute prints a property value, or the provided fallback when the key is missing.
func (c GetCommand) Execute(args []string) error {
	fieldName, fallback, err := parseGetArgs(args)
	if err != nil {
		return err
	}

	config, err := GetConfig()
	if err != nil {
		return err
	}

	value, wrote := config.GetOrSet(fieldName, fallback)
	if wrote {
		if err := config.Save(); err != nil {
			return err
		}
	}

	fmt.Println(formatValue(value))
	return nil
}

func (c GetCommand) Help() string {
	return `Usage: rcm get <field> -b <fallback>

Get a configuration value by name. If the property is not set, the fallback
from -b / --backup is stored in the config file and printed. Fallback type
is inferred the same way as for 'rcm set'.

Examples:
  rcm get mode -b auto
  rcm get autoclick_interval -b 1000
  rcm get force_mode -b false
  rcm get background -b /home/user/wallpaper.jpg`
}

// Execute stores a property, inferring bool, integer, float, or string from the value.
func (c SetCommand) Execute(args []string) error {
	if len(args) < 2 {
		return fmt.Errorf("missing field name or value\nUsage: rcm set <field> <value>")
	}

	fieldName := args[0]
	value := parseValue(strings.Join(args[1:], " "))

	config, err := GetConfig()
	if err != nil {
		return err
	}

	config.Set(fieldName, value)

	if err := config.Save(); err != nil {
		return err
	}

	fmt.Printf("Successfully set %s to: %s\n", fieldName, formatValue(value))
	return nil
}

func (c SetCommand) Help() string {
	return `Usage: rcm set <field> <value>

Set a configuration value by name. The data type is inferred from the value:

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

func (c HelpCommand) Execute(args []string) error {
	if len(args) > 0 {
		switch args[0] {
		case "get":
			fmt.Println(GetCommand{}.Help())
		case "set":
			fmt.Println(SetCommand{}.Help())
		default:
			return fmt.Errorf("unknown command: %s", args[0])
		}
		return nil
	}

	fmt.Println(`rice config handler

Usage:
  rcm <command> [arguments]

Available commands:
  get <field> -b <fallback>  Get a configuration value (fallback if unset)
  set <field> <value>     Set a configuration value (type autodetected)
  help [command]          Show help information

Run 'rcm help <command>' for more information about a command.

Config file location: ~/.config/rcm/config.json`)

	return nil
}

func (c HelpCommand) Help() string {
	return `Usage: rcm help [command]

Display help information about rcm commands.`
}
