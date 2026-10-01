# Lapis Multiplayer & Network Spy Demo

This example demonstrates real-time multiplayer networking in Godot 4 using Crystal and Lapis.

## Features

- **ENetMultiplayerPeer**: Dedicated server and client network topology over UDP.
- **Declarative `@[RPC]` Annotations**: Methods with `:any_peer`, `:authority`, `:call_local`, and transfer modes (`:reliable`, `:unreliable_ordered`).
- **Wireshark Packet Spy (`Lapis::Multiplayer::Spy`)**: In-engine packet auditing, real-time bandwidth meter, and latency simulation.
- **Multi-Peer Input Pumping**: Demonstrates testing techniques using `Lapis::Multiplayer::Harness`.
- **Automated Headless Test**: Run `make test` to execute the full multiplayer networking cycle headlessly in CI.

## Building and Running

```bash
# Build game library and sync dependencies
make

# Launch interactive demo in Godot
make run

# Run automated headless multiplayer test
make test

# Open in Godot Editor
make editor
```
