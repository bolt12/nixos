# Specialized tools profile - Domain-specific applications and tools
# This profile contains tools for specific use cases and specialized workflows

{ pkgs, ... }:
  let
    luaWithPackages = pkgs.lua.withPackages (ps:
      with ps; [
        cjson
        luasocket
      ]);
  in {
  home.packages = with pkgs; [
    # Formal methods and verification
    alloy                        # Model checker for formal verification

    # Electronics and hardware
    arduino                      # Arduino development toolkit

    # Education and learning
    anki                         # Spaced repetition flashcards

    # Note-taking and knowledge management
    zk                           # Zettelkasten note-taking system

    # Media creation and editing
    ffmpeg_6-full                # Complete multimedia framework

    # Academic and research tools
    libcamera                    # Camera stack for research/development

    # Java development environment
    jdk                          # Java Development Kit
    jre                          # Java Runtime Environment

    # Torrenting (kept as requested)
    deluge                       # BitTorrent client

    # Lua scripting
    luaWithPackages              # Lua with additional packages
  ];
}
