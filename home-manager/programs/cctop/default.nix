{ lib, pkgs, ... }:
let
  # cctop: btop-style dashboard for Claude Code sessions (single Rust binary).
  # Not in nixpkgs or nix-ai-tools, and upstream ships no flake, so the release
  # tag is built here. The Claude Code plugin (/cctop, cctop-insights) is
  # installed separately with `claude plugin install cctop` and only looks the
  # binary up on PATH.
  #
  # To bump: change `version`, then take both hashes from the mismatch errors
  # (set each to lib.fakeHash in turn).
  cctop = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
    pname = "cctop";
    version = "0.9.1";

    src = pkgs.fetchFromGitHub {
      owner = "tomstagl";
      repo = "cctop";
      tag = "v${finalAttrs.version}";
      hash = "sha256-eJpq8TYfbqSdD4KBTmRQbXttRBc7JEGF+k7M7pTq1rQ=";
    };

    cargoHash = "sha256-S7zlNPladPrqz1IOCl7hzh4T2Jn3+EyZatJpa3CZ1Bk=";

    # Team discovery ignores a teammate transcript last written before the
    # lead session started (`candidates` in src/team.rs). Store sources carry
    # the epoch mtime, which hides fixture D's teammates from 13 tests.
    preCheck = ''
      find fixtures -type f -exec touch {} +
    '';

    # These three assert on the build environment rather than on cctop: the
    # source tree being a git checkout with a HEAD, and `ps` being on PATH.
    checkFlags = [
      "--skip=files::tests::numstat"
      "--skip=git::tests::this_repo_has_a_branch_and_nowhere_has_none"
      "--skip=procs::tests::live_ps_returns_this_process"
    ];

    meta = {
      description = "btop-style live dashboard for Claude Code internals";
      homepage = "https://github.com/tomstagl/cctop";
      license = lib.licenses.mit;
      mainProgram = "cctop";
    };
  });
in
{
  home.packages = [ cctop ];
}
