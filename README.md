# Eternal Bloom

A top-down action game built with **Godot 4.x** featuring fast-paced combat, character skins, and dynamic enemy AI.

## Features

- **Fast-Paced Combat**: Hold-to-attack mechanics with cooldown-based shooting
- **Smart Enemy AI**: Enemies track player movement, adapt their facing direction, and perform coordinated attacks
- **Multiple Character Skins**: Play as different character variations including male, female, and cat kigurumi outfits
- **Seasonal Environments**: Explore tilemaps and items themed for spring, summer, autumn, and winter
- **Particle Effects**: Impact bursts, slash effects, and dash visual feedback
- **Smooth Animations**: Directional walk cycles and attack animations with proper sprite mirroring
- **Polished UI**: Game Over screen with centered modal layout and restart functionality

## Gameplay Mechanics

### Player Combat
- **Hold-to-Attack**: Hold the attack button to continuously fire projectiles on a 0.24s cooldown
- **Single Shot**: Each attack fires 1 projectile (configurable)
- **Knockback Response**: Softer, more fluid knockback on enemy hits (320 force, 1400 decay rate)

### Enemy Behavior
- **Aggressive AI**: Enemies attack on 0.3s cooldown with 3-shot burst attacks
- **Smart Positioning**: Enemies move smoothly toward the player with intelligent arrival slowdown
- **Dynamic Facing**: Enemies face the player accurately in all angles within 240 units (no moonwalking!)
- **Hit Reaction Polish**: Knockback doesn't lock facing direction, maintaining fluid movement during stuns

### Skins & Customization
- **Male Portrait**: Classic character appearance
- **Female Portrait**: Alternative character sprite
- **Cat Kigurumi**: Special outfit with cat hood, available in multiple animations
- **Portrait Variants**: Unique portrait art for each skin variant

### Environment
- **Seasonal Tilesets**: Spring, summer, autumn, and winter tilemap variations
- **Interactive Items**: Seasonal furniture, objects, and collectable items
- **Animated Tiles**: Decorative animated elements for visual polish
- **Bridges & Inside Areas**: Varied terrain for exploration

## Controls

| Input | Action |
|-------|--------|
| **WASD** / **Arrow Keys** | Move |
| **Mouse Click** / **Space** | Attack (hold to fire) |

## Project Structure

```
Eternal-Bloom/
├── scenes/              # Godot scene files (.tscn)
│   ├── Main.tscn       # Main game scene
│   ├── player.tscn     # Player character scene
│   ├── Enemy.tscn      # Enemy character scene
│   ├── Projectile.tscn # Projectile scene
│   └── ...
├── scripts/            # GDScript files
│   ├── Player.gd       # Player controller & combat
│   ├── Enemy.gd        # Enemy AI & behavior
│   ├── Main.gd         # Game manager
│   ├── GameManager.gd  # Game state management
│   └── modules/        # Reusable modules
│       ├── PlayerAttack.gd      # Combat system
│       ├── PlayerInput.gd       # Input handling
│       ├── PlayerCombat.gd      # Combat logic
│       ├── PlayerSkin.gd        # Character skins
│       ├── CameraShake.gd       # Screen shake effects
│       ├── GameOverUI.gd        # Game Over UI
│       └── ...
├── assets/             # Game assets (sprites, tilesets, items)
│   └── Tiny Wonder Forest 1.0/
│       ├── characters/          # Character sprites & animations
│       ├── items&objects/       # Collectible items & furniture
│       └── tilemaps/            # Seasonal tilesets
└── project.godot       # Godot project configuration
```

## Recent Updates

### Combat Balance
- **Player Attack Cadence**: Increased from rapid-fire to 0.24s cooldown for balanced gameplay
- **Hold-to-Attack**: Changed from click-spam to hold-button mechanic for smoother input
- **Enemy Aggression**: Buffed enemy fire rate to 0.3s cooldown with 3-shot burst attacks
- **Knockback Softening**: Reduced knockback force (320 from higher values) and stun time (0.08s) for fluid combat feel

### Enemy AI Polish
- **Directional Facing**: Fixed enemy facing to use player position-based logic (no more opposite-facing bugs)
- **Smooth Movement**: Added movement smoothing (8.0 factor) with intelligent arrival slowdown (115 units)
- **Nearby Sync Range**: Extended facing sync distance to 240 units for early player awareness
- **Animation Fluidity**: Removed knockback-based facing locks to maintain smooth movement during hit reactions

### UI & Polish
- **Game Over Screen**: Rebuilt with centered modal card layout
- **Improved Typography**: 72pt title, 20pt subtitle, 30pt action button
- **Button Styling**: Centered scaling with hover (1.04x) and press (0.96x) feedback
- **Smooth Animations**: 0.35s intro overlay, 0.28s fade, 0.45s elastic scale-in

### Repository Cleanup
- **Git Hygiene**: Removed Godot cache files (.godot/, *.import) from tracking
- **Clean Working Tree**: Repository now focuses on source code only

## Getting Started

### Prerequisites
- **Godot 4.x** ([Download](https://godotengine.org/download))

### Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/Astrollll/Eternal-Bloom.git
   cd Eternal-Bloom
   ```

2. Open in Godot:
   - Launch Godot 4.x
   - Open the `project.godot` file
   - Wait for project import to complete

3. Run the Game:
   - Press **F5** to run the main scene
   - Or click the **Play** button in the top-right corner

## Configuration

All combat parameters are exported and customizable in the Godot Inspector:

### Player Settings (`scripts/Player.gd`)
- `attack_fire_interval`: Time between shots (default: 0.24s)
- `projectile_shots_per_attack`: Projectiles per attack (default: 1)
- `knockback_force`: Hit knockback magnitude (default: 320)

### Enemy Settings (`scripts/Enemy.gd`)
- `attack_cooldown`: Time between attacks (default: 0.3s)
- `ranged_burst_shots`: Projectiles per burst (default: 3)
- `ranged_burst_interval`: Spacing between burst shots (default: 0.05s)
- `nearby_facing_sync_distance`: Range for player-facing sync (default: 240)
- `movement_smoothing`: Movement acceleration factor (default: 8.0)

## Performance

- Optimized sprite rendering with proper mirroring
- Efficient animation frame management
- Spatial partitioning for enemy pathfinding
- Shader caching for smooth 60 FPS gameplay

## Development Notes

### Key Modules
- **PlayerAttack.gd**: Centralized burst shooting system with configurable intervals
- **GameOverUI.gd**: Modular game over screen with reusable modal card design
- **PlayerSkin.gd**: Skin switching system supporting multiple character variations

### Animation System
- Directional animations with automatic sprite mirroring
- Conditional vertical animation flips for walk_up vs walk_down
- Frame-perfect attack and slash impact timing

### Enemy AI Architecture
- Position-based facing logic (no state mirroring bugs)
- Nearby sync distance check for performance optimization
- Movement smoothing with arrival slowdown for natural deceleration

## Future Enhancements

- [ ] Additional character skins & cosmetics
- [ ] New enemy types with unique AI patterns
- [ ] Power-up system & special abilities
- [ ] Multi-level progression
- [ ] Sound effects & music system
- [ ] Leaderboard / High score tracking

## License

This project is open source. Feel free to fork, modify, and extend!

## Credits

- **Game Engine**: [Godot Engine](https://godotengine.org/)
- **Art Assets**: Tiny Wonder Forest 1.0 asset pack
- **Developed By**: The Eternal Bloom Team

---

**Latest Update**: Game balance polish and GitHub repository cleanup (May 2026)
