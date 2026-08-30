package main

import (
	"encoding/json"
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

func TestConfigGetFallback(t *testing.T) {
	cfg := Config{"mode": "dark"}

	if got := cfg.Get("mode", "auto"); got != "dark" {
		t.Errorf("Get existing = %#v, want dark", got)
	}
	if got := cfg.Get("missing", parseValue("auto")); got != "auto" {
		t.Errorf("Get missing string = %#v, want auto", got)
	}
	if got := cfg.Get("interval", parseValue("1000")); got != int64(1000) {
		t.Errorf("Get missing int = %#v, want 1000", got)
	}
	if got := Config(nil).Get("mode", "auto"); got != "auto" {
		t.Errorf("Get on nil config = %#v, want auto", got)
	}

	cfg = Config{"mode": "dark"}
	got, wrote := cfg.GetOrSet("mode", "auto")
	if got != "dark" || wrote {
		t.Errorf("GetOrSet existing = %#v wrote=%v, want dark/false", got, wrote)
	}
	got, wrote = cfg.GetOrSet("color", "blue")
	if got != "blue" || !wrote {
		t.Errorf("GetOrSet missing = %#v wrote=%v, want blue/true", got, wrote)
	}
	if cfg["color"] != "blue" {
		t.Errorf("GetOrSet did not store fallback, map=%v", cfg)
	}
}

func TestParseGetArgs(t *testing.T) {
	field, backup, err := parseGetArgs([]string{"mode", "-b", "auto"})
	if err != nil {
		t.Fatalf("parseGetArgs: %v", err)
	}
	if field != "mode" || backup != "auto" {
		t.Errorf("got field=%q backup=%#v, want mode/auto", field, backup)
	}

	field, backup, err = parseGetArgs([]string{"-b", "1000", "interval"})
	if err != nil {
		t.Fatalf("parseGetArgs flag first: %v", err)
	}
	if field != "interval" || backup != int64(1000) {
		t.Errorf("got field=%q backup=%#v, want interval/1000", field, backup)
	}

	field, backup, err = parseGetArgs([]string{"force_mode", "--backup", "false"})
	if err != nil {
		t.Fatalf("parseGetArgs --backup: %v", err)
	}
	if field != "force_mode" || backup != false {
		t.Errorf("got field=%q backup=%#v, want force_mode/false", field, backup)
	}

	field, backup, err = parseGetArgs([]string{"color", "-b=blue"})
	if err != nil {
		t.Fatalf("parseGetArgs -b=: %v", err)
	}
	if field != "color" || backup != "blue" {
		t.Errorf("got field=%q backup=%#v, want color/blue", field, backup)
	}

	if _, _, err := parseGetArgs([]string{"mode"}); err == nil {
		t.Error("expected error when -b is missing")
	}
	if _, _, err := parseGetArgs([]string{"-b", "auto"}); err == nil {
		t.Error("expected error when field is missing")
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
