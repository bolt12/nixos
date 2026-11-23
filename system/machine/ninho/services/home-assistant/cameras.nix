# Home Assistant, generic camera entities backed by Frigate's go2rtc restream.
# No MQTT or Frigate HA integration required: the generic platform pulls RTSP
# for live view and Frigate's HTTP API for still snapshots. The Frigate
# container must be running for these entities to come online.
{ constants, ... }:
let
  inherit (constants) ports;
  frigateUrl = "http://127.0.0.1:${toString ports.frigate}";

  cameras = [
    {
      name = "eufy_office";
      friendly = "Office Camera";
    }
    {
      name = "family_room";
      friendly = "Family Room Camera";
    }
    {
      name = "living_room";
      friendly = "Living Room Camera";
    }
    {
      name = "bedroom";
      friendly = "Bedroom Camera";
    }
  ];
in
{
  services.home-assistant.config = {
    camera = map (c: {
      platform = "generic";
      name = c.friendly;
      still_image_url = "${frigateUrl}/api/${c.name}/latest.jpg";
      stream_source = "rtsp://127.0.0.1:8554/${c.name}";
    }) cameras;
  };
}
