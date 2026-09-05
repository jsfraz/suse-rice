package main

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"testing"
)

func TestParseValue(t *testing.T) {
	tests := []struct {
		in   string
		want any
	}{
		{"true", true},
		{"TRUE", true},
		{"False", false},
		{"0", int64(0)},
		{"1500", int64(1500)},
		{"-12", int64(-12)},
		{"1.5", float64(1.5)},
		{"1e2", float64(100)},
		{"dark", "dark"},
		{"/home/user/wallpaper.jpg", "/home/user/wallpaper.jpg"},
		{"true-ish", "true-ish"},
	}

	for _, tt := range tests {
		got := parseValue(tt.in)
		if got != tt.want {
			t.Errorf("parseValue(%q) = %#v (%T), want %#v (%T)", tt.in, got, got, tt.want, tt.want)
		}
	}
}

func TestFormatValue(t *testing.T) {
	tests := []struct {
		in   any
		want string
	}{
		{true, "true"},
		{false, "false"},
		{int64(1500), "1500"},
		{float64(1.5), "1.5"},
		{"dark", "dark"},
		{nil, ""},
	}

	for _, tt := range tests {
		got := formatValue(tt.in)
		if got != tt.want {
			t.Errorf("formatValue(%#v) = %q, want %q", tt.in, got, tt.want)
		}
	}
}

func TestConfigResolve(t *testing.T) {
	cfg := Config{
		Value:    map[string]any{"mode": "dark"},
		Fallback: map[string]any{},
	}

	got, wrote, err := cfg.Resolve("mode", "auto", true)
	if err != nil || got != "dark" || !wrote {
		t.Errorf("Resolve existing value = %#v wrote=%v err=%v, want dark/true/nil", got, wrote, err)
	}
	if cfg.Fallback["mode"] != "auto" {
		t.Errorf("Resolve did not seed fallback, fallback=%v", cfg.Fallback)
	}
	if cfg.Value["mode"] != "dark" {
		t.Errorf("Resolve wrote fallback into value, value=%v", cfg.Value)
	}

	got, wrote, err = cfg.Resolve("mode", "light", true)
	if err != nil || got != "dark" || wrote {
		t.Errorf("Resolve existing fallback = %#v wrote=%v err=%v, want dark/false/nil", got, wrote, err)
	}
	if cfg.Fallback["mode"] != "auto" {
		t.Errorf("Resolve overwrote fallback, fallback=%v", cfg.Fallback)
	}

	got, wrote, err = cfg.Resolve("color", "blue", true)
	if err != nil || got != "blue" || !wrote {
		t.Errorf("Resolve missing = %#v wrote=%v err=%v, want blue/true/nil", got, wrote, err)
	}
	if cfg.Fallback["color"] != "blue" {
		t.Errorf("Resolve did not store fallback, fallback=%v", cfg.Fallback)
	}
	if _, ok := cfg.Value["color"]; ok {
		t.Errorf("Resolve stored fallback in value, value=%v", cfg.Value)
	}

	got, wrote, err = cfg.Resolve("color", "red", false)
	if err != nil || got != "blue" || wrote {
		t.Errorf("Resolve stored fallback = %#v wrote=%v err=%v, want blue/false/nil", got, wrote, err)
	}

	_, _, err = cfg.Resolve("missing", nil, false)
	if err == nil {
		t.Error("expected error when value and fallback are missing")
	}
}

func TestConfigSetSeparatesStores(t *testing.T) {
	cfg := emptyConfig()
	cfg.Set("mode", "dark")
	cfg.SetFallback("mode", "auto")

	if cfg.Value["mode"] != "dark" {
		t.Errorf("Set wrote value=%#v, want dark", cfg.Value["mode"])
	}
	if cfg.Fallback["mode"] != "auto" {
		t.Errorf("SetFallback wrote fallback=%#v, want auto", cfg.Fallback["mode"])
	}

	got, wrote, err := cfg.Resolve("mode", "light", true)
	if err != nil || got != "dark" || wrote {
		t.Errorf("user value should win: %#v wrote=%v err=%v", got, wrote, err)
	}
}

func TestParseGetArgs(t *testing.T) {
	field, fallback, fallbackSet, err := parseGetArgs([]string{"mode", "-f", "auto"})
	if err != nil {
		t.Fatalf("parseGetArgs: %v", err)
	}
	if field != "mode" || fallback != "auto" || !fallbackSet {
		t.Errorf("got field=%q fallback=%#v set=%v, want mode/auto/true", field, fallback, fallbackSet)
	}

	field, fallback, fallbackSet, err = parseGetArgs([]string{"-f", "1000", "interval"})
	if err != nil {
		t.Fatalf("parseGetArgs flag first: %v", err)
	}
	if field != "interval" || fallback != int64(1000) || !fallbackSet {
		t.Errorf("got field=%q fallback=%#v set=%v, want interval/1000/true", field, fallback, fallbackSet)
	}

	field, fallback, fallbackSet, err = parseGetArgs([]string{"force_mode", "--fallback", "false"})
	if err != nil {
		t.Fatalf("parseGetArgs --fallback: %v", err)
	}
	if field != "force_mode" || fallback != false || !fallbackSet {
		t.Errorf("got field=%q fallback=%#v set=%v, want force_mode/false/true", field, fallback, fallbackSet)
	}

	field, fallback, fallbackSet, err = parseGetArgs([]string{"color", "-f=blue"})
	if err != nil {
		t.Fatalf("parseGetArgs -f=: %v", err)
	}
	if field != "color" || fallback != "blue" || !fallbackSet {
		t.Errorf("got field=%q fallback=%#v set=%v, want color/blue/true", field, fallback, fallbackSet)
	}

	field, fallback, fallbackSet, err = parseGetArgs([]string{"mode"})
	if err != nil {
		t.Fatalf("parseGetArgs without -f: %v", err)
	}
	if field != "mode" || fallbackSet {
		t.Errorf("got field=%q set=%v, want mode/false", field, fallbackSet)
	}

	if _, _, _, err := parseGetArgs([]string{"-f", "auto"}); err == nil {
		t.Error("expected error when field is missing")
	}
	if _, _, _, err := parseGetArgs([]string{"mode", "-b", "auto"}); err == nil {
		t.Error("expected error for removed -b flag")
	}
}

func TestConfigFromJSON(t *testing.T) {
	cfg, migrated, err := configFromJSON([]byte(`{
		"value": {"mode": "dark"},
		"fallback": {"mode": "auto", "interval": 1500}
	}`))
	if err != nil {
		t.Fatalf("configFromJSON new format: %v", err)
	}
	if migrated {
		t.Error("new format should not migrate")
	}
	if cfg.Value["mode"] != "dark" {
		t.Errorf("value.mode = %#v, want dark", cfg.Value["mode"])
	}
	if cfg.Fallback["interval"] != int64(1500) {
		t.Errorf("fallback.interval = %#v (%T), want int64(1500)", cfg.Fallback["interval"], cfg.Fallback["interval"])
	}

	cfg, migrated, err = configFromJSON([]byte(`{"color": "blue", "force_mode": true}`))
	if err != nil {
		t.Fatalf("configFromJSON legacy: %v", err)
	}
	if !migrated {
		t.Error("flat object should migrate into value")
	}
	if cfg.Value["color"] != "blue" || cfg.Value["force_mode"] != true {
		t.Errorf("migrated value = %#v", cfg.Value)
	}
	if len(cfg.Fallback) != 0 {
		t.Errorf("migrated fallback should be empty, got %#v", cfg.Fallback)
	}

	cfg, migrated, err = configFromJSON([]byte(`{"value": "blue"}`))
	if err != nil {
		t.Fatalf("configFromJSON property named value: %v", err)
	}
	if !migrated {
		t.Error("string value key should be treated as legacy")
	}
	if cfg.Value["value"] != "blue" {
		t.Errorf("legacy value key = %#v, want blue", cfg.Value["value"])
	}

	cfg, migrated, err = configFromJSON([]byte(`{
  "value": {},
  "fallback": {}
}
 "brightness_mode": "light"
}
`))
	if err != nil {
		t.Fatalf("configFromJSON torn file: %v", err)
	}
	if !migrated {
		t.Error("trailing garbage should force a rewrite")
	}
	if len(cfg.Value) != 0 || len(cfg.Fallback) != 0 {
		t.Errorf("torn first object = value %#v fallback %#v", cfg.Value, cfg.Fallback)
	}
}

func TestParseFieldValuePairs(t *testing.T) {
	pairs, err := parseFieldValuePairs([]string{"color", "blue", "forcedColor", "false"}, "usage")
	if err != nil {
		t.Fatalf("parseFieldValuePairs: %v", err)
	}
	if len(pairs) != 2 || pairs[0].field != "color" || pairs[0].value != "blue" || pairs[1].value != false {
		t.Errorf("pairs = %#v", pairs)
	}
	if _, err := parseFieldValuePairs([]string{"color"}, "usage"); err == nil {
		t.Error("expected error for incomplete pair")
	}
}

func TestConcurrentSetFallback(t *testing.T) {
	dir := t.TempDir()
	configPathOverride = filepath.Join(dir, "config.json")
	t.Cleanup(func() { configPathOverride = "" })

	const workers = 8
	done := make(chan error, workers)
	for i := 0; i < workers; i++ {
		i := i
		go func() {
			_, err := withConfig(func(cfg *Config) (bool, error) {
				cfg.SetFallback(fmt.Sprintf("k%d", i), int64(i))
				return true, nil
			})
			done <- err
		}()
	}
	for i := 0; i < workers; i++ {
		if err := <-done; err != nil {
			t.Fatalf("worker: %v", err)
		}
	}

	cfg, err := GetConfig()
	if err != nil {
		t.Fatalf("GetConfig: %v", err)
	}
	if _, ok := cfg.Value["k0"]; ok {
		t.Errorf("fallback leaked into value: %#v", cfg.Value)
	}
	for i := 0; i < workers; i++ {
		key := fmt.Sprintf("k%d", i)
		if cfg.Fallback[key] != int64(i) {
			t.Errorf("fallback %s = %#v, want %d; file=%v", key, cfg.Fallback[key], i, cfg.Fallback)
		}
	}
}

func TestNormalizeJSONNumber(t *testing.T) {
	raw := map[string]any{
		"interval": json.Number("1500"),
		"ratio":    json.Number("1.5"),
		"flag":     true,
	}

	got := normalizeValue(raw).(map[string]any)
	if got["interval"] != int64(1500) {
		t.Errorf("interval = %#v (%T), want int64(1500)", got["interval"], got["interval"])
	}
	if got["ratio"] != float64(1.5) {
		t.Errorf("ratio = %#v (%T), want float64(1.5)", got["ratio"], got["ratio"])
	}
	if got["flag"] != true {
		t.Errorf("flag = %#v, want true", got["flag"])
	}
}
