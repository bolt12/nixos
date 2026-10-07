# mcp-nixos: an MCP server for NixOS and Home Manager option and package
# search, with read access to the pinned flake inputs in the local store.
#
# Taken from unstable for the 3.x line; the stable channel still carries 2.4.3.
# Only the binary is provided here. Registering it with an MCP client is a
# per-user, per-project choice, for example from a checkout of this repo:
#   claude mcp add --scope local nixos -- mcp-nixos
{ pkgs, ... }:
{
  home.packages = [ pkgs.unstable.mcp-nixos ];
}
