---
name: lapis-logging-telemetry
description: >-
  Implement and manage game logging, custom log filters, BBCode console output, and telemetry using Godot.log and the lapis log CLI.
  Use when adding logging to nodes, creating custom log levels/filters, formatting logs, or streaming and inspecting logs via CLI.
---

# Lapis Diagnostic Logging & Telemetry Runbook

Lapis provides a high-performance diagnostic logging apparatus designed specifically for Godot game development. It combines compile-time elision with rich tag-based filtering, BBCode console coloring, and CLI log inspection.

---

## 1. Quick Code Example

```crystal
require "libgodot"

# 1. Define custom domain-specific log filters across your codebase
define_log_filters do
  filter :combat, tag: "{combat}", name_tag: "COMBAT", color: "#ff5555"
  filter :ai,     tag: "{ai}",     name_tag: "AI",     color: "#50fa7b"
  filter :network,tag: "{net}",    name_tag: "NET",    color: "#8be9fd"
end

# 2. Log messages anywhere in your game using Godot.log
node Enemy < CharacterBody2D do
  def take_damage(amount : Int32) : Void
    # Dynamic log with custom tag and level
    Godot.log :combat, "Enemy took #{amount} damage (HP remaining: #{hp})"
  end

  def think_patrol : Void
    # Low-overhead debug log (stripped in release or when log level is lower)
    Godot.log :ai, "Patrolling to waypoint #{current_waypoint}"
  end
end
```

---

## 2. Standard Severity Levels

Lapis defines a monotonic severity hierarchy:
1. `Godot::LogLevel::Off` (0)
2. `Godot::LogLevel::Error` (1) - Always logged, red `#ff5555`
3. `Godot::LogLevel::Warn` (2) - Warning events, gold `#ffb86c`
4. `Godot::LogLevel::Info` (3) - General milestones, cyan `#8be9fd`
5. `Godot::LogLevel::Debug` (4) - Development details, green `#50fa7b`
6. `Godot::LogLevel::Trace` (5) - High-frequency flow, purple `#bd93f9`
7. `Godot::LogLevel::Internal` (6) - Low-level engine & GC internals

### Built-in Shorthand Methods:
```crystal
Godot.error("Failed to load level", "LevelLoader")
Godot.warn("High frame time detected: #{delta * 1000} ms")
Godot.info("Player spawned at #{position}")
Godot.debug("Velocity: #{velocity}")
Godot.trace("Evaluating physics sub-step")
```

---

## 3. Custom Log Filters (`define_log_filters` / `log_filter`)

You can define custom log filters in two ways:

### Block Syntax (Recommended for systems and subsystems):
```crystal
define_log_filters do
  filter :quest,      tag: "{quest}",      name_tag: "QUEST",      color: "#f1fa8c"
  filter :inventory,  tag: "{inventory}",  name_tag: "INVENTORY",  color: "#ff79c6"
end
```

### Single-Statement Syntax (Ideal for individual file headers):
```crystal
log_filter :audio, tag: "{audio}", name_tag: "AUDIO", color: "#8be9fd"
```

Each filter generates a type-safe enum entry in `Godot::LogLevel` and custom tag dispatching.

---

## 4. Compile-Time Log Elision

To eliminate log formatting overhead and string allocations in production releases:
- When compiled with `--release` or with specific log level thresholds (e.g. `-Dlog_level=error` or `--log=1`), log statements above the threshold are completely stripped at compile time.
- Macro expressions inside `Godot.log` blocks are not evaluated if the log level is disabled, ensuring **zero runtime cost**.

---

## 5. Streaming and Inspecting Logs via CLI (`lapis log`)

Lapis includes a dedicated CLI command to tail, filter, and inspect game logs:

```bash
# Stream and follow live game logs in real-time
lapis log --tail

# Filter logs by severity level
lapis log --level=WARN

# Filter logs by custom tag or subsystem
lapis log --filter=combat

# Output logs formatted with terminal ANSI colors
lapis log --ansi

# Inspect the most recent N log records
lapis log --lines=100
```
