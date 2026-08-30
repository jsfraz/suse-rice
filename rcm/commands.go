package main

import (
	"fmt"
	"reflect"
	"strconv"
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

// getFieldByJSONTag finds a struct field in the Config struct by matching its JSON tag name.
//
// Behavior:
//   - Uses reflection to iterate through all fields in the Config struct
//   - Compares each field's JSON tag (without options like omitempty) with the provided tag
//   - Returns the field value, field metadata, and true if found
//   - Returns empty values and false if no matching field is found
//
// Parameters:
//   - config: The Config struct to search through
//   - jsonTag: The JSON tag name to search for (e.g., "mode", "background")
//
// Returns:
//   - reflect.Value: The value of the found field (or zero value if not found)
//   - reflect.StructField: Metadata about the found field (or zero value if not found)
//   - bool: true if field was found, false otherwise
func getFieldByJSONTag(config Config, jsonTag string) (reflect.Value, reflect.StructField, bool) {
	v := reflect.ValueOf(config)
	t := reflect.TypeOf(config)

	for i := 0; i < t.NumField(); i++ {
		field := t.Field(i)
		tag := field.Tag.Get("json")
		// Remove omitempty and other options
		tagName := strings.Split(tag, ",")[0]
		if tagName == jsonTag {
			return v.Field(i), field, true
		}
	}
	return reflect.Value{}, reflect.StructField{}, false
}

// Execute runs the get command to retrieve and display a configuration field value.
//
// Behavior:
//   - Validates that at least one argument (field name) is provided
//   - Loads the current configuration from ~/.rcm/config.json
//   - Searches for the field by its JSON tag name using reflection
//   - Prints the field value to stdout if found
//   - Returns an error if the field doesn't exist or config loading fails
//
// Parameters:
//   - args: Command-line arguments where args[0] should be the field name
//
// Returns:
//   - error: Error if arguments are missing, field not found, or config loading fails
func (c GetCommand) Execute(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("missing field name\nUsage: rcm get <field>")
	}

	fieldName := args[0]
	config, err := GetConfig()
	if err != nil {
		return err
	}

	fieldValue, _, found := getFieldByJSONTag(config, fieldName)
	if !found {
		return fmt.Errorf("unknown field: %s", fieldName)
	}

	fmt.Println(fieldValue.Interface())
	return nil
}

// Help returns detailed usage information and examples for the get command.
//
// Behavior:
//   - Returns a formatted string with command syntax
//   - Lists all available configuration fields that can be retrieved
//   - Includes brief descriptions of each field
//   - Provides usage examples
//
// Returns:
//   - string: Formatted help text for the get command
func (c GetCommand) Help() string {
	return `Usage: rcm get <field>

Get a configuration value.

Available fields:
  background         - Path to background image
  mode               - Color mode (light, dark, auto)
  force_mode         - Force mode regardless of time
  color              - Accent color (auto, blue, green, orange, pink, purple, red, teal, yellow)
  force_color        - Force color regardless of wallpaper
  enable_night_light - Enable night light feature
  autoclick_enabled  - Enable autoclick feature
  autoclick_interval - Autoclick interval in milliseconds
  keyboard           - Keyboard layout (cz, us)
  screensaver        - Screensaver type (none, random, matrix, pipes, aquarium, lavalamp, hollywood, train, weather)

Example:
  rcm get mode
  rcm get background`
}

// Execute runs the set command to update a configuration field value.
//
// Behavior:
//   - Validates that field name and new value arguments are provided
//   - Loads the current configuration from ~/.rcm/config.json
//   - Uses reflection to find the field by its JSON tag name
//   - Converts and sets the new value based on field type (string, bool, int)
//   - Validates the new value against the field's validation rules
//   - Saves the updated configuration back to the file
//   - Prints a success message if the operation completes successfully
//   - Returns an error if validation fails or any step encounters an error
//
// Parameters:
//   - args: Command-line arguments where args[0] is field name, args[1] is new value
//
// Returns:
//   - error: Error if arguments are invalid, field not found, validation fails,
//     type conversion fails, or config saving fails
func (c SetCommand) Execute(args []string) error {
	if len(args) < 2 {
		return fmt.Errorf("missing field name or value\nUsage: rcm set <field> <value>")
	}

	fieldName := args[0]
	newValue := args[1]

	config, err := GetConfig()
	if err != nil {
		return err
	}

	// Use reflection to set the field
	configValue := reflect.ValueOf(&config).Elem()
	configType := reflect.TypeOf(config)

	var fieldIndex int = -1
	var fieldType reflect.StructField

	// Find field by JSON tag
	for i := 0; i < configType.NumField(); i++ {
		field := configType.Field(i)
		tag := field.Tag.Get("json")
		tagName := strings.Split(tag, ",")[0]
		if tagName == fieldName {
			fieldIndex = i
			fieldType = field
			break
		}
	}

	if fieldIndex == -1 {
		return fmt.Errorf("unknown field: %s", fieldName)
	}

	fieldValue := configValue.Field(fieldIndex)

	// Set the value based on the field type
	switch fieldValue.Kind() {
	case reflect.String:
		fieldValue.SetString(newValue)
	case reflect.Bool:
		boolVal, err := strconv.ParseBool(newValue)
		if err != nil {
			return fmt.Errorf("invalid boolean value for %s: %s (use true or false)", fieldName, newValue)
		}
		fieldValue.SetBool(boolVal)
	case reflect.Int, reflect.Int64:
		intVal, err := strconv.ParseInt(newValue, 10, 64)
		if err != nil {
			return fmt.Errorf("invalid integer value for %s: %s", fieldName, newValue)
		}
		fieldValue.SetInt(intVal)
	default:
		return fmt.Errorf("unsupported field type for %s", fieldName)
	}

	// Validate the modified field
	if err := validate.Var(fieldValue.Interface(), fieldType.Tag.Get("validate")); err != nil {
		// Extract validation error details
		return fmt.Errorf("validation failed for %s: %s", fieldName, formatValidationError(fieldType, err))
	}

	// Save the updated config
	if err := config.Save(); err != nil {
		return err
	}

	fmt.Printf("Successfully set %s to: %v\n", fieldName, newValue)
	return nil
}

// formatValidationError formats validator errors into user-friendly messages.
//
// Behavior:
//   - Extracts validation rules from the field's validate tag
//   - For "oneof" validations, lists all allowed values
//   - For "required" validations, returns a simple required message
//   - For "filepath" validations, returns a path validation message
//   - Falls back to the raw error message for unknown validation types
//
// Parameters:
//   - field: The struct field that failed validation (contains validation tags)
//   - err: The validation error from the validator
//
// Returns:
//   - string: A user-friendly error message explaining the validation failure
func formatValidationError(field reflect.StructField, err error) string {
	tag := field.Tag.Get("validate")

	if strings.Contains(tag, "oneof=") {
		// Extract allowed values from oneof tag
		parts := strings.Split(tag, "oneof=")
		if len(parts) > 1 {
			allowed := strings.Fields(parts[1])
			return fmt.Sprintf("must be one of: %s", strings.Join(allowed, ", "))
		}
	}

	if strings.Contains(tag, "required") {
		return "field is required"
	}

	if strings.Contains(tag, "filepath") {
		return "must be a valid file path"
	}

	return err.Error()
}

// Help returns detailed usage information and examples for the set command.
//
// Behavior:
//   - Returns a formatted string with command syntax
//   - Lists all available configuration fields that can be modified
//   - Shows valid values for each field type
//   - Provides multiple usage examples covering different field types
//
// Returns:
//   - string: Formatted help text for the set command
func (c SetCommand) Help() string {
	return `Usage: rcm set <field> <value>

Set a configuration value.

Available fields and valid values:
  background <path>              - Path to background image
  mode <light|dark|auto>         - Color mode
  force_mode <true|false>        - Force mode regardless of time
  color <auto|blue|green|...>    - Accent color
  force_color <true|false>       - Force color regardless of wallpaper
  enable_night_light <true|false>- Enable night light feature
  autoclick_enabled <true|false> - Enable autoclick feature
  autoclick_interval <number>    - Autoclick interval in milliseconds
  keyboard <cz|us>               - Keyboard layout
  screensaver <none|random|...>  - Screensaver type

Examples:
  rcm set mode dark
  rcm set keyboard cz
  rcm set autoclick_interval 1500
  rcm set background /home/user/wallpaper.jpg`
}

// Execute runs the help command to display usage information.
//
// Behavior:
//   - If a command name is provided in args, displays help for that specific command
//   - Supports showing help for "get" and "set" commands
//   - If no arguments provided, displays general help with command overview
//   - Returns an error if an unknown command name is requested
//
// Parameters:
//   - args: Optional command name ("get" or "set") to show specific help for
//
// Returns:
//   - error: Error if an unknown command name is provided, nil otherwise
func (c HelpCommand) Execute(args []string) error {
	if len(args) > 0 {
		// Show help for specific command
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

	// Show general help
	fmt.Println(`jsfraz's rice config handler

Usage:
  rcm <command> [arguments]

Available commands:
  get <field>        Get a configuration value
  set <field> <value> Set a configuration value
  help [command]     Show help information

Run 'rcm help <command>' for more information about a command.

Config file location: ~/.rcm/config.json`)

	return nil
}

// Help returns usage information for the help command itself.
//
// Behavior:
//   - Returns a brief formatted string explaining how to use the help command
//   - Shows the syntax for getting help on specific commands
//
// Returns:
//   - string: Formatted help text for the help command
func (c HelpCommand) Help() string {
	return `Usage: rcm help [command]

Display help information about rcm commands.`
}
