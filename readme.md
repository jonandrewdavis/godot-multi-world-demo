# Godot Multi-World Demo

Seemlessly swap players between worlds, with perfect sync, and drop-in-drop-out.

Allows clients to mount a completely different scene tree than peers or the server. Mounts only the node needed for the current selected "world".

This would be useful for an MMO-like set up that wants to only mount, render, and synchronize players in a certain zone, or for level-based multiplayer games where some players can move to a new level or world and others can stay behind.

![assets/splash.png](assets/splash.png)

### Details:

- Uses `add_visibilty_filter()` in https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html#class-multiplayersynchronizer-method-add-visibility-filter
- Uses a custom spawner to spawn players in specific worlds and move them betwee
- Uses rpc_id to filter out peers not in the same world

### Caveats

- `MultiplayerSpawner` is not compatible with this method.\*\* _yet_
  - You must manually `add_child()` in the right places instead (worlds, players, etc.).
- When a player does an `rpc_id()` you must call it only on peers in the same world. Like so:

```
for id in get_tree().get_first_node_in_group('Main').get_players_in_world():
    sync_set_state.rpc_id(id, state_name)
```

<sub><sup>\*\* Footnote on Spawner: I thought that I could use `set_spawn_function` which I like to use, but MultiplayerSpawner ends up calling `.spawn()` on ALL PEERS unconditionally, so you can't prevent errors. So while `MultiplayerSpawner` _actually (techincally)_ "works" in its basic form, it does not accomplish my goal of a completely clean console. This is because there's no visibility filter. I could probably extend & figure it out with more time or publish a spawner class that abstracts it if this gets traction or it's an excercise for the reader.</sup></sub>

---

Credits:

- Third person controller is the excellent: https://github.com/Jeh3no/Godot-State-Machine-Third-Person-Controller converted to multiplayer
- Textures are from https://ambientcg.com/
