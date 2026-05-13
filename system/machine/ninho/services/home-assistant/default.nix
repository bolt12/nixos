# Home Assistant — split into one file per config domain.
#
# The slim core (services.home-assistant.{enable, package, openFirewall,
# configDir, http, recorder, frontend, mobile_app, …, extraComponents,
# customComponents, customLovelaceModules}) lives in ../home-assistant.nix.
# Each declarative config domain is a sibling here; module merging combines
# them into the final services.home-assistant.config attrset.
{ ... }:
{
  imports = [
    ./helpers.nix
    ./templates.nix
    ./sensors.nix
    ./utility-meters.nix
    ./rest-commands.nix
    ./automations.nix
    ./scripts.nix
    ./lovelace.nix
  ];
}
