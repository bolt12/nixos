# Shared Syncthing `.stignore` patterns for bolt's machines.
# Build artifacts + VCS noise that shouldn't cross the sync boundary.
# The `(?d)` prefix lets Syncthing clean up ignored files whose parent
# directory gets removed remotely — without it, build-artifact-only
# directories linger forever and trigger a red tray icon.
#
# Pollard's ignore set is intentionally distinct and lives inline.
{ pkgs }:

pkgs.writeText "documents-stignore" ''
  // --- Version control ---
  // Sync working trees only; use git push/pull for repo state
  (?d).git

  // --- General ---
  (?d).DS_Store
  (?d)Thumbs.db
  (?d)*~
  (?d)*.lock
  (?d).claude

  // --- C / C++ / CMake ---
  (?d)CMakeFiles
  (?d)CMakeCache.txt
  (?d)cmake_install.cmake
  (?d)Makefile
  (?d)*.a
  (?d)*.so
  (?d)*.dylib

  // --- Haskell (Cabal / Stack) ---
  (?d)dist-newstyle
  (?d).stack-work
  (?d)cabal.sandbox.config
  (?d).cabal-sandbox
  (?d)*.o
  (?d)*.hi
  (?d)*.chi
  (?d)*.chs.h
  (?d)*.dyn_o
  (?d)*.dyn_hi

  // --- Agda ---
  (?d)*.agdai
  (?d)MAlonzo

  // --- Lean ---
  (?d).lake
  (?d)lake-packages
  (?d)build/bin
  (?d)build/ir
  (?d)build/lib

  // --- Java ---
  (?d)*.class
  (?d).gradle
  (?d).settings
  (?d).classpath
  (?d).project
  (?d)target

  // --- JS / Node ---
  (?d)node_modules
  (?d).next
  (?d).nuxt
  (?d).parcel-cache
  (?d).turbo
  (?d).angular
  (?d)bower_components

  // --- Nix ---
  (?d)result
  (?d)result-*
  (?d).direnv

  // --- Chrome extensions ---
  (?d).chrome-profile

  // --- IDE / editor ---
  (?d).idea
  (?d).vscode
  (?d)*.swp
  (?d)*.swo

  // --- Generated output ---
  (?d)Bolt/Playground/Haskell/generative-art/showcases
''
