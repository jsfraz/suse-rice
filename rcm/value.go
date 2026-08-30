package main

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
)

// parseValue infers a native type from a CLI string:
// bool (true/false), int64, float64, otherwise string.
func parseValue(s string) any {
	switch strings.ToLower(s) {
	case "true":
		return true
	case "false":
		return false
	}

	if i, err := strconv.ParseInt(s, 10, 64); err == nil {
		return i
	}

	if f, err := strconv.ParseFloat(s, 64); err == nil {
		return f
	}

	return s
}

// formatValue prints a stored or fallback value for CLI output.
func formatValue(v any) string {
	switch n := v.(type) {
	case nil:
		return ""
	case bool:
		return strconv.FormatBool(n)
	case int:
		return strconv.Itoa(n)
	case int64:
		return strconv.FormatInt(n, 10)
	case float64:
		return strconv.FormatFloat(n, 'g', -1, 64)
	case json.Number:
		return n.String()
	case string:
		return n
	default:
		encoded, err := json.Marshal(v)
		if err != nil {
			return fmt.Sprint(v)
		}
		return string(encoded)
	}
}

// normalizeValue converts json.Number values to int64 or float64 after decode.
func normalizeValue(v any) any {
	switch n := v.(type) {
	case json.Number:
		if i, err := n.Int64(); err == nil {
			return i
		}
		if f, err := n.Float64(); err == nil {
			return f
		}
		return n.String()
	case map[string]any:
		for key, val := range n {
			n[key] = normalizeValue(val)
		}
		return n
	case []any:
		for i, val := range n {
			n[i] = normalizeValue(val)
		}
		return n
	default:
		return v
	}
}
