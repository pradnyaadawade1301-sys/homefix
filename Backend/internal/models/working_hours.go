package models

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

// DayHours is one weekday's open window in a technician's weekly schedule.
// Open/Close are "HH:MM" 24-hour wall-clock strings in the app's local
// timezone (IST). Zero-padded, so plain string comparison orders them.
type DayHours struct {
	Open  string `json:"open"`
	Close string `json:"close"`
}

// WorkingHours is a technician's self-set weekly schedule, keyed by lowercase
// 3-letter weekday ("mon".."sun"). A nil value (or an absent key) means the
// technician does not work that day.
//
// This is display-only — it never gates matching or booking. It implements
// sql.Scanner / driver.Valuer so it round-trips straight through pgx as JSONB.
type WorkingHours map[string]*DayHours

// weekdayKeys is the canonical ordered list of keys WorkingHours accepts.
var weekdayKeys = []string{"mon", "tue", "wed", "thu", "fri", "sat", "sun"}

// goWeekdayKey maps time.Weekday (Sunday=0) to our key.
var goWeekdayKey = map[time.Weekday]string{
	time.Monday:    "mon",
	time.Tuesday:   "tue",
	time.Wednesday: "wed",
	time.Thursday:  "thu",
	time.Friday:    "fri",
	time.Saturday:  "sat",
	time.Sunday:    "sun",
}

func isWeekdayKey(k string) bool {
	for _, w := range weekdayKeys {
		if w == k {
			return true
		}
	}
	return false
}

// validHHMM reports whether s is a "HH:MM" 24-hour time string.
func validHHMM(s string) bool {
	if len(s) != 5 || s[2] != ':' {
		return false
	}
	h := int(s[0]-'0')*10 + int(s[1]-'0')
	m := int(s[3]-'0')*10 + int(s[4]-'0')
	if s[0] < '0' || s[0] > '9' || s[1] < '0' || s[1] > '9' ||
		s[3] < '0' || s[3] > '9' || s[4] < '0' || s[4] > '9' {
		return false
	}
	return h >= 0 && h <= 23 && m >= 0 && m <= 59
}

// Validate rejects unknown day keys and malformed / inverted time windows so a
// bad payload can't get persisted.
func (w WorkingHours) Validate() error {
	if w == nil {
		return errors.New("working_hours is required")
	}
	for k, v := range w {
		if !isWeekdayKey(k) {
			return fmt.Errorf("invalid day key %q (expected mon..sun)", k)
		}
		if v == nil {
			continue
		}
		if !validHHMM(v.Open) || !validHHMM(v.Close) {
			return fmt.Errorf("%s: open/close must be HH:MM 24-hour", k)
		}
		if v.Open >= v.Close {
			return fmt.Errorf("%s: open (%s) must be before close (%s)", k, v.Open, v.Close)
		}
	}
	return nil
}

// Scan implements sql.Scanner for reading a JSONB column.
func (w *WorkingHours) Scan(src any) error {
	if src == nil {
		*w = nil
		return nil
	}
	var b []byte
	switch v := src.(type) {
	case []byte:
		b = v
	case string:
		b = []byte(v)
	default:
		return fmt.Errorf("WorkingHours.Scan: unsupported type %T", src)
	}
	if len(b) == 0 || string(b) == "null" {
		*w = nil
		return nil
	}
	return json.Unmarshal(b, w)
}

// Value implements driver.Valuer for writing to a JSONB column.
func (w WorkingHours) Value() (driver.Value, error) {
	if w == nil {
		return nil, nil
	}
	b, err := json.Marshal(map[string]*DayHours(w))
	if err != nil {
		return nil, err
	}
	// Return a string (not []byte) so pgx sends it as text — Postgres then
	// coerces it into the jsonb column, whereas []byte would go as bytea.
	return string(b), nil
}
