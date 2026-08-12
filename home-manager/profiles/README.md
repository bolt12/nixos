# Home Manager Profiles

Package profiles imported per user. Each file groups related packages so a user config picks the sets it needs instead of one flat list.

## Profile Structure

### Core Profiles

- **`desktop.nix`** - GUI applications and desktop environment tools
  - Web browsers, communication apps, media players
  - Office productivity, file managers, theming tools
  - Best for: Desktop/laptop systems with GUI

- **`development.nix`** - Programming and development tools
  - Version control, code editors, documentation tools
  - Language runtimes, build tools, container tools
  - Best for: Software development workflows

- **`system-tools.nix`** - Core utilities and system administration  
  - Shell utilities, monitoring tools, network utilities
  - Essential command-line tools and system libraries
  - Best for: All systems (essential tools)

- **`specialized.nix`** - Domain-specific and specialized tools
  - Formal verification, electronics, education tools
  - Research tools, specialized media utilities
  - Best for: Specific use cases and professional workflows

- **`wayland.nix`** - Wayland compositor and related packages
  - Wayland-specific tools, display management, desktop portals
  - Audio/video tools with Wayland support
  - Best for: Wayland-based desktop environments

## Usage Examples

### Full Desktop System
```nix
imports = [
  ./profiles/desktop.nix
  ./profiles/development.nix  
  ./profiles/system-tools.nix
  ./profiles/specialized.nix
  ./profiles/wayland.nix
];
```

### Minimal Development Machine
```nix
imports = [
  ./profiles/development.nix
  ./profiles/system-tools.nix
];
```

### Server/Headless System
```nix
imports = [
  ./profiles/system-tools.nix
  # Optional: ./profiles/development.nix for server development
];
```

### Specialized Workstation
```nix
imports = [
  ./profiles/system-tools.nix
  ./profiles/development.nix
  ./profiles/specialized.nix  # For research/academic work
];
```

## Adding New Packages

When adding new packages, consider which profile they belong to:

- **GUI applications** → `desktop.nix`
- **Development tools** → `development.nix` 
- **Command-line utilities** → `system-tools.nix`
- **Specialized/domain tools** → `specialized.nix`
- **Wayland-specific tools** → `wayland.nix`

## Profile Dependencies

- `system-tools.nix` - Foundational, needed by most systems
- `wayland.nix` - Depends on Wayland compositor (Sway)
- `desktop.nix` - Usually paired with `wayland.nix` for GUI systems
- `development.nix` - Independent, can be used with any combination
- `specialized.nix` - Independent, use based on specific needs