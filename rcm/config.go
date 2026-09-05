package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"syscall"
)

// Config stores user values and defaults in separate objects.
// Types are native JSON (string, bool, int64, float64).
type Config struct {
	Value    map[string]any `json:"value"`
	Fallback map[string]any `json:"fallback"`
}

func emptyConfig() Config {
	return Config{
		Value:    map[string]any{},
		Fallback: map[string]any{},
	}
}

func (c *Config) ensureMaps() {
	if c.Value == nil {
		c.Value = map[string]any{}
	}
	if c.Fallback == nil {
		c.Fallback = map[string]any{}
	}
}

var configPathOverride string

func getConfigPath() (string, error) {
	if configPathOverride != "" {
		return configPathOverride, nil
	}

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

func writeConfig(config *Config, configFile string) error {
	if config == nil {
		empty := emptyConfig()
		config = &empty
	}
	config.ensureMaps()

	dir := filepath.Dir(configFile)
	tmp, err := os.CreateTemp(dir, ".config.*.json.tmp")
	if err != nil {
		return fmt.Errorf("failed to create config file: %w", err)
	}
	tmpName := tmp.Name()

	encoder := json.NewEncoder(tmp)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(config); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		return fmt.Errorf("failed to write config file: %w", err)
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		return fmt.Errorf("failed to write config file: %w", err)
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpName)
		return fmt.Errorf("failed to write config file: %w", err)
	}

	if err := os.Rename(tmpName, configFile); err != nil {
		os.Remove(tmpName)
		return fmt.Errorf("failed to write config file: %w", err)
	}

	return nil
}

func isNewFormat(obj map[string]any) bool {
	if len(obj) == 0 {
		return true
	}
	for key, val := range obj {
		if key != "value" && key != "fallback" {
			return false
		}
		if val == nil {
			continue
		}
		if _, ok := val.(map[string]any); !ok {
			return false
		}
	}
	return true
}

func configFromObject(obj map[string]any) (Config, bool) {
	obj = normalizeValue(obj).(map[string]any)
	if isNewFormat(obj) {
		cfg := emptyConfig()
		if value, ok := obj["value"].(map[string]any); ok {
			cfg.Value = value
		}
		if fallback, ok := obj["fallback"].(map[string]any); ok {
			cfg.Fallback = fallback
		}
		return cfg, false
	}

	cfg := emptyConfig()
	cfg.Value = obj
	return cfg, true
}

func configFromJSON(data []byte) (Config, bool, error) {
	if len(bytes.TrimSpace(data)) == 0 {
		return emptyConfig(), false, nil
	}

	reader := bytes.NewReader(data)
	decoder := json.NewDecoder(reader)
	decoder.UseNumber()

	var raw any
	if err := decoder.Decode(&raw); err != nil {
		return Config{}, false, fmt.Errorf("failed to parse config file: %w", err)
	}

	var rest bytes.Buffer
	if _, err := io.Copy(&rest, decoder.Buffered()); err != nil {
		return Config{}, false, fmt.Errorf("failed to parse config file: %w", err)
	}
	if _, err := io.Copy(&rest, reader); err != nil {
		return Config{}, false, fmt.Errorf("failed to parse config file: %w", err)
	}
	trailing := len(bytes.TrimSpace(rest.Bytes())) > 0

	obj, ok := raw.(map[string]any)
	if !ok {
		return Config{}, false, fmt.Errorf("config file must be a JSON object")
	}

	cfg, migrated := configFromObject(obj)
	return cfg, migrated || trailing, nil
}

func loadConfigFile(configFile string) (Config, bool, error) {
	data, err := os.ReadFile(configFile)
	if err != nil {
		if os.IsNotExist(err) {
			return emptyConfig(), true, nil
		}
		return Config{}, false, fmt.Errorf("failed to read config file: %w", err)
	}

	cfg, rewrite, err := configFromJSON(data)
	if err != nil {
		return Config{}, false, err
	}
	if len(bytes.TrimSpace(data)) == 0 {
		rewrite = true
	}
	return cfg, rewrite, nil
}

func withConfig(fn func(*Config) (persist bool, err error)) (Config, error) {
	configFile, err := getConfigPath()
	if err != nil {
		return Config{}, err
	}

	if err := os.MkdirAll(filepath.Dir(configFile), 0755); err != nil {
		return Config{}, fmt.Errorf("failed to create config directory: %w", err)
	}

	lock, err := os.OpenFile(configFile+".lock", os.O_CREATE|os.O_RDWR, 0644)
	if err != nil {
		return Config{}, fmt.Errorf("failed to lock config file: %w", err)
	}
	defer lock.Close()

	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return Config{}, fmt.Errorf("failed to lock config file: %w", err)
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)

	cfg, rewrite, err := loadConfigFile(configFile)
	if err != nil {
		return Config{}, err
	}

	persist, err := fn(&cfg)
	if err != nil {
		return Config{}, err
	}
	if persist || rewrite {
		if err := writeConfig(&cfg, configFile); err != nil {
			return Config{}, err
		}
	}

	return cfg, nil
}

// GetConfig loads the property store from ~/.config/rcm/config.json.
// A missing or empty file is treated as an empty store and created on disk.
// A flat legacy object is migrated into value and rewritten.
func GetConfig() (Config, error) {
	return withConfig(func(*Config) (bool, error) { return false, nil })
}

// Resolve returns value for key, then stored fallback, then the optional -f
// fallback. A missing stored fallback is seeded from -f without writing value.
func (c *Config) Resolve(key string, fallback any, fallbackSet bool) (value any, wrote bool, err error) {
	if c == nil {
		if fallbackSet {
			return fallback, false, nil
		}
		return nil, false, fmt.Errorf("no value or fallback for %q", key)
	}
	c.ensureMaps()

	if stored, ok := c.Value[key]; ok {
		if fallbackSet {
			if _, exists := c.Fallback[key]; !exists {
				c.Fallback[key] = fallback
				return stored, true, nil
			}
		}
		return stored, false, nil
	}

	if stored, ok := c.Fallback[key]; ok {
		return stored, false, nil
	}

	if fallbackSet {
		c.Fallback[key] = fallback
		return fallback, true, nil
	}

	return nil, false, fmt.Errorf("no value or fallback for %q\nuse -f or set-fallback", key)
}

// Set stores a user value under key.
func (c *Config) Set(key string, value any) {
	c.ensureMaps()
	c.Value[key] = value
}

// SetFallback stores a fallback used by get when the user value is unset.
func (c *Config) SetFallback(key string, value any) {
	c.ensureMaps()
	c.Fallback[key] = value
}

// Save persists the property store to ~/.config/rcm/config.json.
func (c *Config) Save() error {
	configFile, err := getConfigPath()
	if err != nil {
		return err
	}
	return writeConfig(c, configFile)
}
