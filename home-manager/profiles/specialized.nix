# Specialized tools profile - Domain-specific applications and tools
# This profile contains tools for specific use cases and specialized workflows

{ pkgs, ... }:
let
  luaWithPackages = pkgs.lua.withPackages (
    ps: with ps; [
      cjson
      luasocket
    ]
  );
in
{
  home.packages = with pkgs; [
    # Education and learning
    anki # Spaced repetition flashcards

    # Note-taking and knowledge management
    zk # Zettelkasten note-taking system

    # Media creation and editing
    ffmpeg # Multimedia framework

    # Torrenting
    deluge # BitTorrent client

    # Lua scripting
    luaWithPackages # Lua with additional packages
  ];
}
