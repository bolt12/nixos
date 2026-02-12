# Home Assistant Dashboard Designer Prompt

Generate a complete Home Assistant Lovelace dashboard in **valid Nix syntax** for the `lovelaceConfig.views` attribute. This will be used directly in a NixOS configuration file.

---

## Output Format Requirements

- Output must be valid **Nix attribute set syntax**, not YAML
- The output replaces the `views = [ ... ];` list inside `lovelaceConfig`
- Use `''` (double single-quote) for multiline strings
- Use `''${` to escape Nix interpolation inside Jinja2 templates (e.g., `''${ states('sensor.x') }` renders as `${ states('sensor.x') }` in the YAML output)
- Attribute sets use `{ key = value; }` syntax with semicolons
- Lists use `[ item1 item2 ]` syntax (no commas)
- String values use double quotes: `"value"`
- Booleans are lowercase: `true`, `false`
- Numbers are unquoted: `24`, `0.5`

### Nix Syntax Examples

```nix
# Simple card
{
  type = "custom:mushroom-entity-card";
  entity = "climate.ac_sala";
  name = "Sala";
  icon = "mdi:sofa";
  show_temperature_control = true;
}

# Jinja template in Nix (escape interpolation)
{
  type = "custom:mushroom-chips-card";
  chips = [{
    type = "template";
    icon = "mdi:air-conditioner";
    content = "''${ states('sensor.active_ac_units') } AC";
    icon_color = "{% if states('sensor.active_ac_units')|int > 0 %}blue{% else %}grey{% endif %}";
  }];
}

# Multiline template
{
  type = "markdown";
  content = ''
    ## Status
    Temperature: ''${ state_attr('weather.forecast_home', 'temperature') }°C
  '';
}
```

---

## Custom Lovelace Modules Available

All 9 modules are already installed via `customLovelaceModules`:

| Module | Type Prefix | Best Use Cases |
|---|---|---|
| **bubble-card** | `custom:bubble-card` | Bottom navigation bar, pop-up cards, modern floating UI elements |
| **mini-graph-card** | `custom:mini-graph-card` | Compact temperature/sensor history graphs, sparklines |
| **mushroom** | `custom:mushroom-*-card` | Entity cards, climate cards, media player cards, chips, title cards, template cards |
| **button-card** | `custom:button-card` | Highly customizable action buttons with JavaScript templates `[[[ ]]]` |
| **lg-webos-remote-control** | `custom:lg-webos-remote-control` | LG TV remote control interface |
| **universal-remote-card** | `custom:universal-remote-card` | Generic remote control layout |
| **auto-entities** | `custom:auto-entities` | Dynamic entity filtering, auto-discovering cards |
| **card-mod** | N/A (CSS modifier) | Custom CSS styling on any card via `card_mod.style` |
| **apexcharts-card** | `custom:apexcharts-card` | Advanced charts: line, bar, area, radial, timeline. Best for trends & statistics |

---

## Complete Entity Inventory

### Climate (Gree AC units)
- `climate.ac_sala` — Living room AC
- `climate.ac_escritorio` — Office AC
- `climate.ac_quarto` — Bedroom AC
- `climate.ac_quarto_hospedes` — Guest bedroom AC
- Attributes: `current_temperature`, `temperature` (target), `hvac_mode`, `fan_mode`

### Media Players
- `media_player.lg_webos_tv` — LG WebOS TV (living room)
- `media_player.spotify` — Spotify
- `media_player.jellyfin` — Jellyfin media server

### Weather
- `weather.forecast_home` — Met.no weather forecast
- Attributes: `temperature`, `humidity`, `pressure`, `wind_speed`

### Person & Presence
- `person.armando` — Primary user (home/not_home)
- `sensor.waze_travel_time` — Commute travel time

### Sensors — Template
- `sensor.active_ac_units` — Count of active AC units (0-4)
- `sensor.time_of_day` — Morning/Afternoon/Evening/Night

### Sensors — System Monitor
- `sensor.processor_use` — CPU usage %
- `sensor.memory_use_percent` — RAM usage %
- `sensor.disk_use_percent` — Root disk usage %
- `sensor.disk_use_percent_storage` — Storage disk usage %
- `sensor.load_1m`, `sensor.load_5m`, `sensor.load_15m` — System load averages
- `sensor.uptime` — System uptime

### Sensors — AC Runtime (history_stats)
- `sensor.ac_sala_runtime_today` — Sala AC runtime hours today
- `sensor.ac_escritorio_runtime_today` — Office AC runtime hours today
- `sensor.ac_quarto_runtime_today` — Bedroom AC runtime hours today
- `sensor.ac_quarto_hospedes_runtime_today` — Guest bedroom AC runtime hours today

### Sensors — Network
- `sensor.speedtest_download` — Download speed Mbps
- `sensor.speedtest_upload` — Upload speed Mbps
- `sensor.speedtest_ping` — Ping latency ms

### Sensors — Media (Servarr)
- `sensor.sonarr_queue` — Sonarr download queue count
- `sensor.radarr_queue` — Radarr download queue count
- `sensor.jellyfin_movies` — Jellyfin movie library count
- `sensor.jellyfin_series` — Jellyfin series library count
- `sensor.jellyfin_music` — Jellyfin music album count

### Sensors — Garmin Connect (custom component)
- `sensor.garmin_body_battery` — Body battery level (0-100)
- `sensor.garmin_resting_heart_rate` — Resting heart rate (bpm)
- `sensor.garmin_sleep_score` — Sleep quality score
- `sensor.garmin_stress` — Stress level
- `sensor.garmin_steps` — Daily step count
- `sensor.garmin_calories` — Total calories burned
- `sensor.garmin_active_calories` — Active calories burned
- `sensor.garmin_intensity_minutes` — Intensity minutes
- `sensor.garmin_last_activity_name` — Last workout name (e.g. "Strength")
- `sensor.garmin_last_activity_type` — Last workout type
- `sensor.garmin_last_activity_duration` — Last workout duration

### Sensors — Computed (template)
- `sensor.recovery_score` — Weighted composite: 40% body battery + 30% sleep + 30% inverse stress (0-100%)
- `sensor.training_readiness` — Categorical: Ready (>=70) / Moderate (50-70) / Rest (<50)

### Sensors — Cooking
- `sensor.meater_probe_cook_state` — Meater probe status (cooking/done)

### Sensors — GPU
- `sensor.gpu_temperature` — NVIDIA GPU temperature

### Calendar
- `calendar.default` — Google Calendar (primary)
- `calendar.*` — Additional Google calendars (auto-discovered)

### Sun & Moon
- `sun.sun` — Sun position (above_horizon/below_horizon)

### Automations (by ID, referenced as `automation.<id>`)
- `workday_start_comfort`, `evening_transition_office_to_sala`, `night_shutdown_all_ac`
- `away_mode_ac_off`, `return_home_smart_preheat`
- `office_temp_reached_eco`, `office_temp_dropped_reheat`
- `seasonal_mode_switch`, `low_temperature_alert`, `weekly_summary`
- `weekend_morning_comfort`, `lunch_break_eco`, `lunch_break_end`
- `night_bedroom_prep`, `cold_weather_boost`
- `tv_on_heat_sala`, `tv_off_late_night_shutdown`
- `cooking_done_notification`, `slow_network_alert`, `new_media_downloaded`
- `garmin_daily_summary`, `post_workout_notification`, `low_recovery_alert`, `resting_hr_elevation_alert`
- `calendar_meeting_preheat`, `commute_delay_alert`, `gpu_temperature_alert`
- `sheets_hourly_temperature_log`, `sheets_daily_ac_runtime`, `sheets_daily_garmin_log`

### Scripts
- `script.all_ac_off` — Turn off all AC units
- `script.guest_room_on` — Turn on guest room heating
- `script.bedroom_quick_heat` — Heat bedroom for 30 minutes

---

## User Lifestyle Profile

- **Location**: Portugal (Europe/Lisbon timezone)
- **Work**: Remote/WFH, weekdays
  - 08:30-12:00 — Office (escritório)
  - 12:00-13:30 — Lunch break
  - 13:30-18:00 — Office
  - 18:00-23:00 — Living room (sala)
  - 23:00+ — Bedroom (quarto)
- **Weekends**: Living room from ~10:00 AM, no office automation
- **Fitness**: Garmin watch user, gym strength training (saved as Strength workout), track & field sprint training (not saved as explicit workout). Recovery tracking via body battery, sleep score, resting HR, stress.
- **Media**: LG TV for evening viewing, Jellyfin for movies/TV, Spotify for music, Navidrome for self-hosted music
- **Cooking**: Meater wireless probe for grilling/smoking
- **Commute**: Occasional, monitored via Waze travel time

---

## Self-Hosted Service URLs (for quick-link cards)

| Service | URL | Icon |
|---|---|---|
| Jellyfin | `http://10.100.0.100:8096` | `mdi:play-box-multiple` |
| Navidrome | `http://10.100.0.100:8105` | `mdi:music` |
| Immich | `http://10.100.0.100:2283` | `mdi:image-multiple` |
| Nextcloud | `http://10.100.0.100:8081` | `mdi:cloud` |
| Syncthing | `http://10.100.0.100:8384` | `mdi:sync` |
| FileBrowser | `http://10.100.0.100:8107` | `mdi:folder` |
| llama-swap | `http://10.100.0.100:8080` | `mdi:brain` |
| ComfyUI | `http://10.100.0.100:8188` | `mdi:image-auto-adjust` |
| Homepage | `http://10.100.0.100:8082` | `mdi:view-dashboard` |
| Grafana | `http://10.100.0.100:3000` | `mdi:chart-areaspline` |
| Uptime Kuma | `http://10.100.0.100:8109` | `mdi:heart-pulse` |
| Ntfy | `http://10.100.0.100:8106` | `mdi:bell` |
| Sonarr | `http://10.100.0.100:8989` | `mdi:television-classic` |
| Radarr | `http://10.100.0.100:7878` | `mdi:movie` |
| Miniflux | `http://10.100.0.100:8110` | `mdi:rss` |

---

## Design Requirements

1. **Mobile-first**: Cards must work well on phone screens (HA Companion app). Use vertical stacks over horizontal when content won't fit.
2. **Dark theme**: Design for dark backgrounds. Use card colors that contrast well against dark UI.
3. **bubble-card bottom navigation**: Use bubble-card for a persistent bottom navigation bar across all views.
4. **apexcharts for trends**: Use apexcharts-card for temperature trends, AC runtime graphs, and network speed history.
5. **mushroom for entities**: Use mushroom cards as the primary entity display. Mushroom chips for quick status indicators.
6. **Conditional content by time of day**: Show contextually relevant info (e.g., office climate during work hours, living room in evening).
7. **"Now Playing" auto-entities**: Dynamic section that shows all currently playing/paused media players.
8. **card-mod for polish**: Use subtle CSS customizations for visual hierarchy (rounded corners, shadows, opacity).
9. **Compact information density**: Prefer chips and grids over full-width single-entity cards.

---

## Required Views

### 1. Home (overview)
- Dynamic greeting based on time of day
- Presence chip, active AC count, weather summary
- Contextual room highlight (office during work hours, sala in evening)
- Quick action chips (all AC off, night mode, away mode)
- Today's calendar events
- Now Playing section

### 2. Climate (detailed)
- All 4 AC units with full thermostat controls
- Quick action chips (all off, cool all, heat all)
- 24h temperature trend (apexcharts with all rooms + outdoor)
- AC runtime today (bar chart per unit)
- Automation status toggles

### 3. Media
- LG TV with remote control
- Spotify player
- Jellyfin player
- Now Playing auto-entities
- Library stats (movies, series, albums)
- Service quick links (Jellyfin, Navidrome, Immich)

### 4. Health & Training
- **Top row**: Recovery Score gauge (0-100%), Training Readiness chip (Ready/Moderate/Rest with color coding)
- **Today's metrics**: Body battery, resting HR, sleep score, stress level, steps, calories (mushroom entity cards in grid)
- **Weekly trends** (apexcharts): Recovery score, resting HR, sleep score overlaid - look for correlation patterns
- **Body battery graph** (apexcharts, 24h): Shows battery drain during workouts and recovery during sleep
- **Recent workouts**: Last activity name, type, duration - auto-updates when Garmin syncs a Strength session
- **Resting HR trend** (apexcharts, 7 days): Key overtraining indicator - upward trend = under-recovery
- **Sleep breakdown** (if available): Score trend over the week

### 5. Services
- Grid of self-hosted service cards (all 15 services)
- Group by category: Media, Cloud, AI, Monitoring, Automation
- Each card: icon, name, subtitle, tap to open URL

### 6. System
- CPU, memory, disk gauges
- 24h system load graph
- Network speed (latest + history)
- GPU temperature
- Automation status grid
- Uptime

### 7. Calendar
- Google Calendar card (auto-entities for all calendars)
- Upcoming events list
- Shopping list

### 8. Settings
- Reload dashboard button
- Restart HA button (with confirmation)
- Automation management links
