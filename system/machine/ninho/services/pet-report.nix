# pet-report: a VLM-driven daily journal of the pets, layered over Frigate. It
# reads Frigate's events and snapshots, asks the local vision model what each one
# shows, stores structured per-pet observations, and writes the day up. Frigate
# spots that something happened; this works out what it meant.
#
# Every dependency already runs on this host, which is why the upstream defaults
# line up: Frigate (ports.frigate), llama-swap serving the vision alias
# (ports.llamaswap), and ntfy for the twice-daily push (ports.ntfy).
#
# The roster (who each pet is, how to tell them apart), report preferences, and
# household context are app state set in the in-app setup wizard, not here. What
# is configured below is only the infrastructure wiring. A saved profile also
# overrides the URLs, model name, timezone and camera list at runtime with no
# restart, so treat these as the boot-time defaults rather than the last word.
{
  inputs,
  constants,
  ...
}:
let
  inherit (constants) ports network;
in
{
  imports = [ inputs.pet-report.nixosModules.pet-report ];

  # The module expects pkgs.pet-report-backend and pkgs.pet-report-frontend.
  # Applied here rather than in system/common/overlays.nix because ninho is the
  # only host that runs it, and that file is documented as global overlays.
  nixpkgs.overlays = [ inputs.pet-report.overlays.default ];

  services.pet-report = {
    enable = true;
    port = ports.pet-report;
    backendPort = ports.pet-report-backend;

    # All three are loopback: every one of them is a service on this same host,
    # and the backend itself only listens on loopback behind nginx.
    frigateUrl = "http://127.0.0.1:${toString ports.frigate}";
    llamaUrl = "http://127.0.0.1:${toString ports.llamaswap}";
    ntfyUrl = "http://127.0.0.1:${toString ports.ntfy}/pet-report";

    # llama-swap alias, defined in services/llama-cpp/models.nix. The non-MTP
    # GGUF with the mmproj loaded: MTP speculative decoding is incompatible with
    # a vision projector, which is why this is a separate entry from
    # qwen3.6-35B-A3B-full rather than the same model with a flag.
    visionModel = "qwen3.6-35B-A3B-vision";

    # Mirrors cameraDefs in services/frigate.nix, which asks for exactly this.
    # Add a camera there and it belongs here too (or enable it in-app, which
    # supersedes this list without a rebuild).
    cameras = [
      "eufy_office"
      "family_room"
      "living_room"
      "bedroom"
    ];

    # Kept in step with the audio.listen list in services/frigate.nix, as that
    # file asks. Spelled out rather than left to the built-in default because
    # Frigate's list carries "slam", which the default omits: a label Frigate
    # raises but pet-report ignored would be a silently dropped sound event.
    audioLabels = [
      "bark"
      "bow-wow"
      "howl"
      "growling"
      "whimper_dog"
      "meow"
      "speech"
      "yell"
      "doorbell"
      "ding-dong"
      "knock"
      "slam"
      "fire_alarm"
      "smoke_detector"
      "siren"
      "car_alarm"
      "glass"
      "shatter"
      "breaking"
      "thump"
      "bang"
    ];

    # Matches the TZ passed to the Frigate container, so day boundaries and the
    # morning/evening split agree with the timestamps on the events being read.
    timeZone = "Europe/Lisbon";

    # Deliberately not the 08:00/20:00 upstream default. morning-brief.nix runs
    # at 08:00 and holds llama-swap with qwen3.6-27B-full; overlapping would
    # force a swap to the vision model mid-brief and make both slow. An hour is
    # ample for the brief, which is a single text call.
    batchHours = [
      9
      21
    ];

    # Tap-through target for the ntfy push. Addresses ninho by its VPN IP, the
    # same convention homepage.nix uses, so the link works from the phone over
    # WireGuard rather than only on the LAN.
    publicUrl = "http://${network.ninho.vpnIp}:${toString ports.pet-report}";

    # Frigate is an oci-container here, so its unit is docker-frigate.service.
    # Ordering after it means a reboot does not start ingest against a dead API.
    frigateService = "docker-frigate.service";
  };
}
