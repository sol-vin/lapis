---
name: lapis-logging-telemetry
description: >-
  Implement and manage game logging, custom log filters, BBCode console output, and telemetry using Godot.log and the lapis log CLI.
  Use when adding logging to nodes, creating custom log levels/filters, formatting logs, or streaming and inspecting logs via CLI.
---

# Lapis Diagnostic Logging & Telemetry Runbook

This skill outlines how to implement high-performance diagnostic logging, domain-specific log filters, BBCode console formatting, and telemetry metric streaming in Lapis games.

---

## Table of Contents
<table>
  <thead>
    <tr>
      <th align="left">Section</th>
      <th align="left">Description</th>
      <th align="center">Lines</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><a href="#1-quick-code-example"><strong>1. Quick Code Example</strong></a></td>
      <td>require "libgodot"</td>
      <td align="center"><code>L59–L85</code></td>
    </tr>
    <tr>
      <td><a href="#2-standard-severity-hierarchy-visual-formatting"><strong>2. Standard Severity Hierarchy & Visual Formatting</strong></a></td>
      <td>Lapis defines a monotonic severity hierarchy with standardized ANSI terminal colors and Godot BBCode tags:</td>
      <td align="center"><code>L86–L163</code></td>
    </tr>
    <tr>
      <td><a href="#3-custom-log-filters-definelogfilters-logfilter"><strong>3. Custom Log Filters (`define_log_filters` / `log_filter`)</strong></a></td>
      <td>Domain-specific log filters allow subsystems (Combat, AI, Physics, Audio, Inventory) to be toggled independ...</td>
      <td align="center"><code>L164–L184</code></td>
    </tr>
    <tr>
      <td><a href="#4-zero-cost-compile-time-log-elision"><strong>4. Zero-Cost Compile-Time Log Elision</strong></a></td>
      <td>In production releases, string formatting and interpolation for high-frequency logs (Trace, Debug) introduc...</td>
      <td align="center"><code>L185–L198</code></td>
    </tr>
    <tr>
      <td><a href="#5-telemetry-ring-buffers-metric-streaming"><strong>5. Telemetry Ring Buffers & Metric Streaming</strong></a></td>
      <td>Beyond unstructured strings, Lapis includes structured numeric telemetry for monitoring gameplay metrics:</td>
      <td align="center"><code>L199–L213</code></td>
    </tr>
    <tr>
      <td><a href="#6-streaming-inspecting-logs-via-cli-lapis-log"><strong>6. Streaming & Inspecting Logs via CLI (`lapis log`)</strong></a></td>
      <td>Use the lapis log CLI tool to tail, filter, and inspect logs:</td>
      <td align="center"><code>L214–L234</code></td>
    </tr>
  </tbody>
</table>

---

## 1. Quick Code Example

```crystal
require "libgodot"

# 1. Define domain-specific log filters across your codebase
define_log_filters do
  filter :combat,   tag: "{combat}", name_tag: "COMBAT", color: "#ff5555"
  filter :ai,       tag: "{ai}",     name_tag: "AI",     color: "#50fa7b"
  filter :network,  tag: "{net}",    name_tag: "NET",    color: "#8be9fd"
  filter :physics,  tag: "{phys}",   name_tag: "PHYS",   color: "#f1fa8c"
end

# 2. Log messages anywhere in your game using Godot.log
node Enemy < CharacterBody2D do
  def take_damage(amount : Int32) : Void
    Godot.log :combat, "Enemy took #{amount} damage (HP remaining: #{hp})"
  end

  def think_patrol : Void
    Godot.log :ai, "Patrolling toward waypoint #{current_waypoint}"
  end
end
```

---

## 2. Standard Severity Hierarchy & Visual Formatting

Lapis defines a monotonic severity hierarchy with standardized ANSI terminal colors and Godot BBCode tags:

<table>
  <thead>
    <tr>
      <th align="left">Level</th>
      <th align="center">Numeric</th>
      <th align="left">BBCode Tag</th>
      <th align="left">Hex Color</th>
      <th align="left">Typical Use Case</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>Off</code></td>
      <td align="center">0</td>
      <td>None</td>
      <td>N/A</td>
      <td>Disables all logging completely</td>
    </tr>
    <tr>
      <td><code>Error</code></td>
      <td align="center">1</td>
      <td><code>[color=#ff5555][ERROR][/color]</code></td>
      <td><code>#ff5555</code> (Red)</td>
      <td>Critical failures, dead-pointer intercepts, missing assets</td>
    </tr>
    <tr>
      <td><code>Warn</code></td>
      <td align="center">2</td>
      <td><code>[color=#ffb86c][WARN][/color]</code></td>
      <td><code>#ffb86c</code> (Gold)</td>
      <td>Degraded performance, frame-rate dips, retry operations</td>
    </tr>
    <tr>
      <td><code>Info</code></td>
      <td align="center">3</td>
      <td><code>[color=#8be9fd][INFO][/color]</code></td>
      <td><code>#8be9fd</code> (Cyan)</td>
      <td>Level load completed, player joined, save game written</td>
    </tr>
    <tr>
      <td><code>Debug</code></td>
      <td align="center">4</td>
      <td><code>[color=#50fa7b][DEBUG][/color]</code></td>
      <td><code>#50fa7b</code> (Green)</td>
      <td>State transitions, spatial queries, inventory transactions</td>
    </tr>
    <tr>
      <td><code>Trace</code></td>
      <td align="center">5</td>
      <td><code>[color=#bd93f9][TRACE][/color]</code></td>
      <td><code>#bd93f9</code> (Purple)</td>
      <td>High-frequency loops, per-frame calculations, packet payloads</td>
    </tr>
    <tr>
      <td><code>Internal</code></td>
      <td align="center">6</td>
      <td><code>[color=#6272a4][INTERNAL][/color]</code></td>
      <td><code>#6272a4</code> (Muted)</td>
      <td>Low-level GDExtension FFI calls, Boehm GC allocation sweeps</td>
    </tr>
  </tbody>
</table>

### Shorthand Convenience Methods:
```crystal
Godot.error("Failed to load scene", "LevelLoader")
Godot.warn("High frame time detected: #{delta * 1000} ms")
Godot.info("Player spawned at #{position}")
Godot.debug("Velocity: #{velocity}")
Godot.trace("Evaluating physics sub-step #{step_index}")
```

---

## 3. Custom Log Filters (`define_log_filters` / `log_filter`)

Domain-specific log filters allow subsystems (Combat, AI, Physics, Audio, Inventory) to be toggled independently:

### Block Syntax:
```crystal
define_log_filters do
  filter :quest,      tag: "{quest}",      name_tag: "QUEST",      color: "#f1fa8c"
  filter :inventory,  tag: "{inventory}",  name_tag: "INVENTORY",  color: "#ff79c6"
end
```

### Single-Statement Syntax:
```crystal
log_filter :audio, tag: "{audio}", name_tag: "AUDIO", color: "#8be9fd"
```

Each declared filter automatically injects type-safe method overloads on `Godot.log` and registers filter tags with the CLI log streamer.

---

## 4. Zero-Cost Compile-Time Log Elision

In production releases, string formatting and interpolation for high-frequency logs (`Trace`, `Debug`) introduce unnecessary CPU and allocation overhead.

Lapis guarantees **zero runtime cost** when logs are elided:
- When compiled with `--release` or with `-Dlog_level=warn`, any `Godot.log :debug, ...` or `Godot.trace(...)` expressions are completely eliminated from the AST by the Crystal macro engine.
- String interpolations inside elided calls are never evaluated at runtime:
  ```crystal
  # If log_level is :info, this expensive string concatenation produces 0 instructions:
  Godot.debug("Entity positions: #{entities.map(&.position).join(", ")}")
  ```

---

## 5. Telemetry Ring Buffers & Metric Streaming

Beyond unstructured strings, Lapis includes structured numeric telemetry for monitoring gameplay metrics:

```crystal
# Record rolling telemetry metric
Godot::Telemetry.record("fps", Godot.performance.get_monitor(Godot::Performance::TIME_FPS))
Godot::Telemetry.record("static_memory_mb", Godot.performance.get_monitor(Godot::Performance::MEMORY_STATIC) / 1024.0 / 1024.0)

# Sample rolling window average
avg_fps = Godot::Telemetry.average("fps", window_seconds: 5.0)
```

---

## 6. Streaming & Inspecting Logs via CLI (`lapis log`)

Use the `lapis log` CLI tool to tail, filter, and inspect logs:

```bash
# Stream and follow live game logs in real-time
lapis log --tail

# Filter logs by minimum severity level
lapis log --level=WARN

# Filter logs by specific custom tag or subsystem
lapis log --filter=combat

# Output logs formatted with terminal ANSI colors
lapis log --ansi

# Inspect the most recent N log records
lapis log --lines=100
```
