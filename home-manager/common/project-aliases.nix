# Shared project / work directory aliases for bolt.
# The desktop prefix differs across hosts:
#   laptop (bolt-with-de) — ~/Desktop/...
#   ninho (bolt)          — ~/x1-g8-laptop/Desktop/... (Syncthing-replicated)
{ desktopPrefix, homeDirectory }:
let
  desktop = "${homeDirectory}/${desktopPrefix}";
in
{
  # Project directories
  uminho  = "cd ${desktop}/Bolt/UMinho/";
  tese    = "cd ${desktop}/Bolt/UMinho/5ºAno/Tese";
  haskell = "cd ${desktop}/Bolt/Playground/Haskell/";
  talks   = "cd ${desktop}/Bolt/Playground/Talks/";
  agdacd  = "cd ${desktop}/Bolt/Playground/Agda/";
  playg   = "cd ${desktop}/Bolt/Playground/";

  # Work directories
  welltyped = "cd ${desktop}/Bolt/UMinho/Profissional/Well-Typed/";
  iohk      = "cd ${desktop}/Bolt/UMinho/Profissional/Well-Typed/Projects/IOHK";
  hsbindgen = "cd ${desktop}/Bolt/UMinho/Profissional/Well-Typed/Projects/hs-bindgen";

  # Tool shortcuts
  doom = "${homeDirectory}/.emacs.d/bin/doom";
}
