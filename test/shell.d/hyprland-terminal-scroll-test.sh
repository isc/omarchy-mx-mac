#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

require_command lua

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# The scroll_touchpad rules input.lua registers, one per line: class, initial
# title (any title when the rule doesn't match on it), and speed.
rules=$(HOME="$tmpdir" XDG_CONFIG_HOME="$tmpdir/.config" OMARCHY_PATH="$ROOT" lua <<'LUA'
package.path = os.getenv("OMARCHY_PATH") .. "/?.lua;" .. package.path

hl = {
  config = function() end,
  window_rule = function(rule)
    if rule.scroll_touchpad then
      print(("%s\t%s\t%s"):format(rule.match.class, rule.match.initial_title or ".*", rule.scroll_touchpad))
    end
  end,
}

require("default.hypr.helpers")
require("default.hypr.input")
LUA
) || fail "input.lua loads" "$rules"

# Hyprland matches a pattern against the whole value, and the last matching
# rule wins.
scroll_touchpad_for() {
  local class="$1" initial_title="$2"
  local rule_class rule_title speed result=""

  while IFS=$'\t' read -r rule_class rule_title speed; do
    [[ $class =~ ^($rule_class)$ ]] || continue
    [[ $initial_title =~ ^($rule_title)$ ]] || continue
    result=$speed
  done <<<"$rules"

  printf '%s\n' "$result"
}

assert_scroll_touchpad() {
  local description="$1" class="$2" initial_title="$3" expected="$4"
  local actual

  actual=$(scroll_touchpad_for "$class" "$initial_title")
  [[ $actual == "$expected" ]] || fail "$description" "expected '$expected', got '$actual'"
  pass "$description"
}

assert_scroll_touchpad "foot windows scroll at foot's speed" "foot" "foot" "2.0"
assert_scroll_touchpad "foot's other app-id scrolls at foot's speed" "org.codeberg.dnkl.foot" "foot" "2.0"
assert_scroll_touchpad "an agent window in foot scrolls at foot's speed" "org.omarchy.agent" "foot" "2.0"
assert_scroll_touchpad "a TUI in kitty scrolls at kitty's speed" "org.omarchy.btop" "kitty" "1.5"
assert_scroll_touchpad "an installed TUI in Alacritty scrolls at Alacritty's speed" "TUI.float" "Alacritty" "1.5"
assert_scroll_touchpad "an agent window in Ghostty scrolls at Ghostty's speed" "org.omarchy.agent" "Ghostty" "0.2"
assert_scroll_touchpad "Ghostty windows scroll at Ghostty's speed" "com.mitchellh.ghostty" "Ghostty" "0.2"
assert_scroll_touchpad "other apps keep the global touchpad speed" "chromium" "foot" ""
