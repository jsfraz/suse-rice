package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// Config is a dynamically keyed property store. Values are native JSON types
// (string, bool, int64, float64) inferred when a property is set.
type Config map[string]any

func getConfigPath() (string, error) {
	configHome, err := os.UserConfigDir()
	if err != nil {
		return "", fmt.Errorf("failed to get config directory: %w", err)
	}

	configDir := filepath.Join(configHome, "rcm")
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create config directory: %w", err)
	}

	return filepath.Join(configDir, "config.json"), nil
}

func writeConfig(config Config, configFile string) error {
	if config == nil {
		config = Config{}
	}

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

// GetConfig loads the property store from ~/.config/rcm/config.json.
// A missing or empty file is treated as an empty store and created on disk.
func GetConfig() (Config, error) {
	configFile, err := getConfigPath()
	if err != nil {
		return nil, err
	}

	data, err := os.ReadFile(configFile)
	if err != nil {
		if os.IsNotExist(err) {
			empty := Config{}
			if err := writeConfig(empty, configFile); err != nil {
				return nil, err
			}
			return empty, nil
		}
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	if len(bytes.TrimSpace(data)) == 0 {
		return Config{}, nil
	}

	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.UseNumber()

	var raw any
	if err := decoder.Decode(&raw); err != nil {
		return nil, fmt.Errorf("failed to parse config file: %w", err)
	}

	obj, ok := raw.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("config file must be a JSON object")
	}

	return Config(normalizeValue(obj).(map[string]any)), nil
}

// Get returns the stored value for key, or fallback when the key is absent.
func (c Config) Get(key string, fallback any) any {
	if c == nil {
		return fallback
	}
	value, ok := c[key]
	if !ok {
		return fallback
	}
	return value
}

// GetOrSet returns the stored value for key. When the key is missing, fallback
// is written into the map and wrote is true so the caller can persist it.
func (c Config) GetOrSet(key string, fallback any) (value any, wrote bool) {
	if c == nil {
		return fallback, false
	}
	value, ok := c[key]
	if ok {
		return value, false
	}
	c[key] = fallback
	return fallback, true
}

// Set stores value under key, creating the property if it does not exist.
func (c Config) Set(key string, value any) {
	c[key] = value
}

// Save persists the property store to ~/.config/rcm/config.json.
func (c Config) Save() error {
	configFile, err := getConfigPath()
	if err != nil {
		return err
	}
	return writeConfig(c, configFile)
}
