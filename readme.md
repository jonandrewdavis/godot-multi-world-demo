# Godot Multi-World Demo

Seemlessly swap players between worlds, with perfect sync, and drop-in-drop-out.

Allows clients to mount a completely different scene tree than peers or the server. Mounts only the node needed for the current selected "world".

This would be useful for an MMO-like set up that wants to only mount, render, and synchronize players in a certain zone, or for level-based multiplayer games where some players can move to a new level or world and others can stay behind.

![assets/splash.png](assets/splash.png)

Details:

- Uses `add_visibilty_filter()` in https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html#class-multiplayersynchronizer-method-add-visibility-filter
- Uses a custom spawner to spawn players in specific worlds and move them betwee
- Uses rpc_id to filter out peers not in the same world

Credits:

- Third person controller is the excellent: https://github.com/Jeh3no/Godot-State-Machine-Third-Person-Controller converted to multiplayer
- Textures are from https://ambientcg.com/
