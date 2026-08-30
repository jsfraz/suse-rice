package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/go-playground/validator/v10"
)

type Config struct {
	Background        string `json:"background"`
	Mode              string `json:"mode" validate:"required,oneof=light dark auto"`
	ForceMode         bool   `json:"force_mode"`
	Color             string `json:"color" validate:"required,oneof=auto blue green orange pink purple red teal yellow"`
	ForceColor        bool   `json:"force_color"`
	EnableNightLight  bool   `json:"enable_night_light"`
	AutoclickEnabled  bool   `json:"autoclick_enabled"`
	AutoclickInterval int    `json:"autoclick_interval" validate:"required"`
	Keyboard          string `json:"keyboard" validate:"required,oneof=cz us"`
	Screensaver       string `json:"screensaver" validate:"required,oneof=none random matrix pipes aquarium lavalamp hollywood train weather"`
}

var (
	defaultConfig = Config{
		Background:        "",
		Mode:              "auto",
		ForceMode:         false,
		Color:             "auto",
		ForceColor:        false,
		EnableNightLight:  true,
		AutoclickEnabled:  false,
		AutoclickInterval: 1000,
		Keyboard:          "cz",
		Screensaver:       "matrix",
	}

	validate = validator.New()
)

// getConfigPath returns the absolute path to the configuration file and ensures
// the parent directory exists.
//
// Behavior:
//   - Gets the user's home directory
//   - Creates the ~/.rcm directory if it doesn't exist (with 0755 permissions)
//   - Returns the full path to ~/.rcm/config.json
//
// Returns:
//   - string: The absolute path to the config file
//   - error: Any error from getting home directory or creating the directory
func getConfigPath() (string, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("failed to get home directory: %w", err)
	}

	configDir := filepath.Join(homeDir, ".rcm")
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create config directory: %w", err)
	}

	return filepath.Join(configDir, "config.json"), nil
}

// writeConfig writes the given configuration to the specified file as formatted JSON.
//
// Behavior:
//   - Creates or overwrites the config file at the given path
//   - Encodes the Config struct as JSON with 2-space indentation
//   - Automatically closes the file when done (via defer)
//
// Parameters:
//   - config: The Config struct to write
//   - configFile: The absolute path where the config should be written
//
// Returns:
//   - error: Any error from creating the file or encoding JSON
func writeConfig(config Config, configFile string) error {
	file, err := os.Create(configFile)
	if err != nil {
		return fmt.Errorf("failed to create config file: %w", err)
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(config); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	return nil
}

// GetConfig loads and validates the application configuration from ~/.rcm/config.json.
//
// Behavior:
//   - If the config file doesn't exist, creates it with default values and returns
//     the default configuration
//   - If the config file exists, reads and parses it as JSON
//   - Validates the loaded configuration using struct validation tags (mode, color,
//     keyboard, screensaver values, etc.)
//   - If validation fails, overwrites the corrupted config with default values
//     and returns the default configuration
//   - Returns the successfully loaded and validated configuration
//
// Returns:
//   - Config: The loaded configuration, or default values if file doesn't exist
//     or validation fails
//   - error: Any error from file operations, JSON decoding, or path resolution
func GetConfig() (Config, error) {
	configFile, err := getConfigPath()
	if err != nil {
		return Config{}, err
	}

	// Check if config file exists
	if _, err := os.Stat(configFile); os.IsNotExist(err) {
		if err := writeConfig(defaultConfig, configFile); err != nil {
			return Config{}, err
		}
		return defaultConfig, nil
	}

	// Read existing config
	file, err := os.Open(configFile)
	if err != nil {
		return Config{}, fmt.Errorf("failed to open config file: %w", err)
	}
	defer file.Close()

	var config Config
	if err := json.NewDecoder(file).Decode(&config); err != nil {
		return Config{}, fmt.Errorf("failed to parse config file: %w", err)
	}

	// Validate config
	if err := validate.Struct(config); err != nil {
		// Create file with default config if validation fails
		if err := writeConfig(defaultConfig, configFile); err != nil {
			return Config{}, err
		}
		return defaultConfig, nil
	}

	return config, nil
}

// Save persists the current Config instance to ~/.rcm/config.json.
//
// Behavior:
//   - Gets the config file path (ensures ~/.rcm directory exists)
//   - Overwrites the existing config file with the current Config values
//   - Writes the configuration as formatted JSON with 2-space indentation
//
// Returns:
//   - error: Any error from path resolution, file creation, or JSON encoding
func (c Config) Save() error {
	configFile, err := getConfigPath()
	if err != nil {
		return err
	}
	return writeConfig(c, configFile)
}
