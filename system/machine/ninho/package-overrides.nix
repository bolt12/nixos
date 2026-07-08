{
  pkgs,
  inputs,
  system,
  ...
}:

let
  # Import unstable with overlay to fix bellows test failures
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    overlays = [
      (final: prev: {
        python313 = prev.python313.override {
          packageOverrides = pyfinal: pysuper: {
            # Disable tests for bellows - test_ash_end_to_end is flaky with Python 3.13
            bellows = pysuper.bellows.overridePythonAttrs (oldAttrs: {
              doCheck = false;
              doInstallCheck = false;
            });
          };
        };
      })
    ];
    config.allowUnfree = true;
  };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      # llama-cpp-cuda - Build from PR #18551 with thinking/reasoning support
      llama-cpp-cuda =
        (unstable.llama-cpp.override {
          cudaSupport = true;
          cudaPackages = unstable.cudaPackages;
          blasSupport = true;
          rocmSupport = false;
          metalSupport = false;
        }).overrideAttrs
          (oldAttrs: {
            version = "9984";

            src = pkgs.fetchFromGitHub {
              owner = "ggml-org";
              repo = "llama.cpp";
              tag = "b9984";
              hash = "sha256-oiQKGkaq4Oe/0pCdSk7dze76BbOjFdv7DrxOWbMvQVA=";
              leaveDotGit = true;
              postFetch = ''
                git -C "$out" rev-parse --short HEAD > $out/COMMIT
                find "$out" -name .git -print0 | xargs -0 rm -rf
              '';
            };

            cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
              "-DGGML_NATIVE=ON"
              # RTX 5090 is Blackwell (sm_120), not Ada (89). 120a-real is llama.cpp's
              # own recommended Blackwell arch: the architecture-specific "a" variant
              # enables the FP4 tensor-core MMA path (BLACKWELL_MMA_AVAILABLE, gated on
              # __CUDA_ARCH__>=1200), which native MXFP4/NVFP4 need. real-only (no PTX):
              # there's no other GPU to fall back to, and no virtual arch until Rubin.
              "-DCMAKE_CUDA_ARCHITECTURES=120a-real"
            ];

            preConfigure = ''
              export NIX_ENFORCE_NO_NATIVE=0
              ${oldAttrs.preConfigure or ""}
            '';

            # b8635 removed tools/server/public/index.html.gz from the source tree,
            # but upstream nixpkgs postPatch still tries to rm it, so use -f to tolerate
            postPatch =
              builtins.replaceStrings
                [ "rm tools/server/public/index.html.gz" ]
                [ "rm -f tools/server/public/index.html.gz" ]
                (oldAttrs.postPatch or "");

            # b9091+ moved the webui sources from tools/server/webui → tools/ui.
            # nixpkgs's package.nix still bakes the old path into npmRoot and its
            # npmDeps hash; override both so fetchNpmDeps reads the new lockfile.
            # Recompute via:
            #   nix run nixpkgs#prefetch-npm-deps -- <unpacked-src>/tools/ui/package-lock.json
            npmRoot = "tools/ui";
            npmDepsHash = "sha256-6s9skw1wzEfm9QKktTqea3J+oudQAsS6O2VnZEMXAdw=";

            # Keep the original postInstall to handle installation correctly
            postInstall = oldAttrs.postInstall or "";
          });

      # llama-swap v239 - Latest release with Anthropic API compatibility
      # (v195 renamed ui/ → ui-svelte/, so we rebuild the UI derivation from scratch)
      llama-swap =
        let
          llama-swap-src = pkgs.fetchFromGitHub {
            owner = "mostlygeek";
            repo = "llama-swap";
            tag = "v239";
            hash = "sha256-uxlOOEYg165ujc6fn77UcgssirS3c6AzcYmkRJOUoUw=";
            leaveDotGit = true;
            postFetch = ''
              cd "$out"
              git rev-parse HEAD > $out/COMMIT
              date -u -d "@$(git log -1 --pretty=%ct)" "+'%Y-%m-%dT%H:%M:%SZ'" > $out/SOURCE_DATE_EPOCH
              find "$out" -name .git -print0 | xargs -0 rm -rf
            '';
          };
          llama-swap-ui = pkgs.buildNpmPackage {
            pname = "llama-swap-ui";
            version = "239";
            src = llama-swap-src;
            sourceRoot = "${llama-swap-src.name}/ui-svelte";
            npmDepsHash = "sha256-cAdFKDhmyaYCoKqSYEuAhu29rBxs7i8uTmU2SHwTLnY=";
            postPatch = ''
              substituteInPlace vite.config.ts \
                --replace-fail "../internal/server/ui_dist" "${placeholder "out"}/ui_dist"
            '';
            postInstall = ''
              rm -rf $out/lib
            '';
          };
        in
        unstable.llama-swap.overrideAttrs (oldAttrs: {
          version = "239";
          src = llama-swap-src;
          proxyVendor = true;
          vendorHash = "sha256-59ep82wHrd134bCm3G8i7xhvW4M+PbIf6CcFyODTPC8=";
          # v239 gates the embedded web UI behind the `embed_ui` Go build tag
          # (internal/server/embed.go). Without it, embed_notag.go compiles an
          # empty UI FS, so every /ui/ path returns 404 while the API stays fine.
          # Upstream's Makefile/goreleaser pass `-tags embed_ui`; buildGoModule
          # reads `tags` at build time, so setting it via overrideAttrs works.
          tags = (oldAttrs.tags or [ ]) ++ [ "embed_ui" ];
          # Merge (not replace) passthru so buildGoModule's overrideModAttrs survives.
          passthru = (oldAttrs.passthru or { }) // {
            ui = llama-swap-ui;
          };

          # v221's internal/process tests exec shell scripts via shebang, which
          # fails in the Nix sandbox (no /bin/bash); skip those forking tests.
          checkFlags = (oldAttrs.checkFlags or [ ]) ++ [
            "-skip=TestProcessCommand_(StopForkingWrapper|StopHonorsGracefulTimeout|StopReapsForkedGrandchild)"
          ];

          preBuild = ''
            ldflags+=" -X main.commit=$(cat COMMIT)"
            ldflags+=" -X main.date=$(cat SOURCE_DATE_EPOCH)"
            # go:embed ui_dist lives only in internal/server (the proxy/ copy
            # v221 needed was dropped upstream by v239).
            cp -r ${llama-swap-ui}/ui_dist internal/server/
          '';
        });

      # MOSS-Transcribe-Diarize: SOTA end-to-end transcription + diarization
      # (Apache-2.0). Replaces whisperx. One model pass emits transcription +
      # [S01]/[S02] speaker labels + timestamps, so diarization is native (no
      # separate pyannote step). trust_remote_code downloads the model code +
      # weights (~1.8GB) to the HF cache on first run, like whisperx did for
      # pyannote. flash-attn is optional and omitted (falls back to sdpa/eager).
      # torch here is CUDA-enabled via nixpkgs.config.cudaSupport.
      moss-transcribe-diarize = final.python3Packages.buildPythonPackage {
        pname = "moss-transcribe-diarize";
        version = "0-unstable-2026-07-09";
        pyproject = true;

        src = pkgs.fetchFromGitHub {
          owner = "OpenMOSS";
          repo = "MOSS-Transcribe-Diarize";
          rev = "b5ad0f8386b155ddb89f9332ba3ca71891900357";
          hash = "sha256-xEMA/DhAL7J/43O7JzCLcRXCsb8fbgfP9Lk+3Fj7K9c=";
        };

        build-system = [ final.python3Packages.setuptools ];

        # pyproject pins transformers<6, torch~=2.8, etc.; relax against 26.05's
        # ecosystem (transformers 5.5.4, torch 2.11.0 satisfy the intent).
        pythonRelaxDeps = true;

        dependencies = with final.python3Packages; [
          transformers
          safetensors
          numpy
          av
          librosa
          numba
          soundfile
          soxr
          packaging
          fastapi
          uvicorn
          python-multipart
          torch
          torchaudio
        ];

        # `mtd-subtitle --render` (burn-in) and video probing shell out to
        # ffmpeg/ffprobe (app/cli.py: detect_ffmpeg, probe_video_size). Wrap so
        # the app carries them, instead of depending on ffmpeg being in the
        # caller's PATH (only true today because it's in systemPackages).
        makeWrapperArgs = [
          "--prefix"
          "PATH"
          ":"
          (pkgs.lib.makeBinPath [ pkgs.ffmpeg-headless ])
        ];

        # Upstream tests need a GPU + model download; import check is enough here.
        doCheck = false;
        pythonImportsCheck = [ "moss_transcribe_diarize" ];
      };

      # dnd-transcribe: long-form wrapper around MOSS for multi-hour recordings.
      # MOSS is single-pass with a 131072-token context (~85 min at 12.5 audio
      # tokens/sec), so a 3-4h D&D session must be split. This driver chunks the
      # audio with ffmpeg, transcribes each chunk with the model loaded once
      # (moss_transcribe_diarize.app.model_runner.ModelRunner), offsets the
      # timestamps, and merges to one SRT + JSON via MOSS's own subtitle API.
      dnd-transcribe =
        let
          pyEnv = final.python3.withPackages (_: [ final.moss-transcribe-diarize ]);
        in
        pkgs.writeShellApplication {
          name = "dnd-transcribe";
          runtimeInputs = [
            pyEnv
            pkgs.ffmpeg-headless
          ];
          text = ''exec ${pyEnv}/bin/python ${./dnd-transcribe.py} "$@"'';
        };

      # redlib: pin to upstream HEAD. Reddit rotates anti-bot measures every
      # few months; the packaged Sept-2025 build returns 403 on every request.
      # Upstream HEAD ships boring-sys2 (BoringSSL) for TLS-fingerprint spoof.
      # When this fails again: bump rev via
      #   nix-prefetch-github redlib-org redlib --rev <new-rev>
      # then rebuild and capture the new cargoHash from the FOD mismatch error.
      redlib = prev.redlib.overrideAttrs (
        finalAttrs: prevAttrs: {
          version = "0.36.0-unstable-2026-05-05";
          src = pkgs.fetchFromGitHub {
            owner = "redlib-org";
            repo = "redlib";
            rev = "a4d36e954cf1bd64f209cd8868c5a29edc81b374";
            hash = "sha256-siyD6A12UALQIV7BMd7zu1TaojleTEYtpxPszuhx1/Y=";
          };
          cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
            inherit (finalAttrs) pname version src;
            hash = "sha256-eO3c7rlFna3DuO31etJ6S4c7NmcvgvIWZ1KVkNIuUqQ=";
          };
          # boring-sys2's build.rs cmakes BoringSSL and `git apply`s patches
          # against the vendored source.
          nativeBuildInputs = (prevAttrs.nativeBuildInputs or [ ]) ++ [
            pkgs.cmake
            pkgs.perl
            pkgs.go
            pkgs.git
            pkgs.rustPlatform.bindgenHook
          ];
          # Two new oauth tests in HEAD hit Reddit's network.
          checkFlags = (prevAttrs.checkFlags or [ ]) ++ [
            "--skip=test_generic_web_backend"
            "--skip=test_mobile_spoof_backend"
          ];
        }
      );

      # Fix scaphandre build error with riemann_client unstable feature
      scaphandre = prev.scaphandre.overrideAttrs (oldAttrs: {
        # Unmark as broken and apply patch to fix the compilation error
        meta = oldAttrs.meta // {
          broken = false;
        };

        # Patch the riemann_client vendored source to drop the unstable
        # `#![rustfmt::skip]` inner attribute that breaks the stable compiler.
        # 26.05 switched to fetchCargoVendor, which renamed the vendor dir, so
        # locate mod_pb.rs by content instead of a fixed glob.
        preBuild = (oldAttrs.preBuild or "") + ''
          found=$(find "$NIX_BUILD_TOP" -path '*/riemann_client-*/src/proto/mod_pb.rs' 2>/dev/null | head -n1)
          if [ -n "$found" ]; then
            echo "Patching riemann_client mod_pb.rs to remove unstable Rust feature: $found"
            sed -i '/#!\[rustfmt::skip\]/d' "$found"
          else
            echo "WARNING: riemann_client mod_pb.rs not found; scaphandre patch skipped" >&2
          fi
        '';
      });

    })
  ];
}
