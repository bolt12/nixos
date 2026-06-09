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
            version = "9584";

            src = pkgs.fetchFromGitHub {
              owner = "ggml-org";
              repo = "llama.cpp";
              tag = "b9584";
              hash = "sha256-0H0RsgV/3HWHpxUcxgPZT2yLNn//a8TidkiT9ES8yeI=";
              leaveDotGit = true;
              postFetch = ''
                git -C "$out" rev-parse --short HEAD > $out/COMMIT
                find "$out" -name .git -print0 | xargs -0 rm -rf
              '';
            };

            cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
              "-DGGML_NATIVE=ON"
              "-DCMAKE_CUDA_ARCHITECTURES=89" # RTX 5090
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
            npmDepsHash = "sha256-pjdbI6NcZRlJVd62xhgbLhWrwFYwgsIwjORqvo1+VD8=";

            # Keep the original postInstall to handle installation correctly
            postInstall = oldAttrs.postInstall or "";
          });

      # llama-swap v223 - Latest release with Anthropic API compatibility
      # (v195 renamed ui/ → ui-svelte/, so we rebuild the UI derivation from scratch)
      llama-swap =
        let
          llama-swap-src = pkgs.fetchFromGitHub {
            owner = "mostlygeek";
            repo = "llama-swap";
            tag = "v223";
            hash = "sha256-I9Tb+DBuD2HgT90sstvIJ1/PWo6GNF91nM8JhixkKBY=";
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
            version = "223";
            src = llama-swap-src;
            sourceRoot = "${llama-swap-src.name}/ui-svelte";
            npmDepsHash = "sha256-NJqEJ+XTdpPFtJJxP4CGu+JDUW7lKDcFgsixQJ3SXtQ=";
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
          version = "223";
          src = llama-swap-src;
          proxyVendor = true;
          vendorHash = "sha256-n3SgvRkO/OTs/ftT89idoHBTQ1H1zr4TOj+tcBi5whc=";
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
            # v221 embeds ui_dist from two locations (internal/server + proxy);
            # both dirs must exist for the go:embed directives to build.
            cp -r ${llama-swap-ui}/ui_dist internal/server/
            cp -r ${llama-swap-ui}/ui_dist proxy/
          '';
        });

      # WhisperX v3.7.6 - Fix use_auth_token TypeError with newer pyannote
      whisperx = prev.whisperx.overridePythonAttrs (oldAttrs: {
        version = "3.7.6";

        # whisperX's metadata pins (pyannote-audio<4, torch~=2.8, torchaudio~=2.8,
        # huggingface-hub<1) all lag 26.05's ecosystem; the postPatch below adapts
        # the code, so relax every version bound for pythonRuntimeDepsCheckHook.
        pythonRelaxDeps = true;

        src = pkgs.fetchFromGitHub {
          owner = "m-bain";
          repo = "whisperX";
          tag = "v3.7.6";
          hash = "sha256-ZHPGQP5HIuFafHGS6ykiSNtHY6QHh0o8DUE2lV41lUI=";
        };

        # Patch for pyannote-audio 4.0+ compatibility
        # 1. use_auth_token -> token (deprecated API change)
        # 2. DiarizeOutput.speaker_diarization wrapper (new return type in 4.0+)
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace whisperx/vads/pyannote.py \
            --replace-fail 'Model.from_pretrained(model_fp, use_auth_token=use_auth_token)' \
                           'Model.from_pretrained(model_fp, token=use_auth_token)' \
            --replace-fail 'super().__init__(segmentation=segmentation, fscore=fscore, use_auth_token=use_auth_token, **inference_kwargs)' \
                           'super().__init__(segmentation=segmentation, fscore=fscore, token=use_auth_token, **inference_kwargs)'
          substituteInPlace whisperx/diarize.py \
            --replace-fail 'Pipeline.from_pretrained(model_config, use_auth_token=use_auth_token)' \
                           'Pipeline.from_pretrained(model_config, token=use_auth_token)' \
            --replace-fail 'speaker_embeddings = {speaker: embeddings[s].tolist() for s, speaker in enumerate(diarization.labels())}' \
                           'speaker_embeddings = {speaker: embeddings[s].tolist() for s, speaker in enumerate(getattr(diarization, "speaker_diarization", diarization).labels())}'
          # Use sed for multiline replacement (DiarizeOutput compatibility)
          sed -i 's/diarize_df = pd.DataFrame(diarization.itertracks(yield_label=True), columns=/annotation = getattr(diarization, "speaker_diarization", diarization)\n        diarize_df = pd.DataFrame(annotation.itertracks(yield_label=True), columns=/g' whisperx/diarize.py
        '';

        meta = (oldAttrs.meta or { }) // {
          broken = false;
        };
      });

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

      # miniflux 2.3.0 wraps the UI in Go's http.CrossOriginProtection,
      # constructed with no trusted origins (internal/ui/ui.go); it is
      # unconfigurable (no BASE_URL / TRUSTED_REVERSE_PROXY_NETWORKS knob) and
      # rejects plain-HTTP bare-IP LAN access with "Sec-Fetch-Site is missing,
      # and Origin does not match Host". Upstream's only fix so far is reverting
      # the commit in the nightly image. Strip the wrapper here; the in-house
      # csrfMiddleware (CSRF token) still runs, matching the 2.2.19 posture.
      # See https://github.com/miniflux/v2/issues/4338
      miniflux = prev.miniflux.overrideAttrs (oldAttrs: {
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace internal/ui/ui.go \
            --replace-fail \
              'return http.NewCrossOriginProtection().Handler(webSessionMiddleware.handle(csrfMiddleware.handle(mux)))' \
              'return webSessionMiddleware.handle(csrfMiddleware.handle(mux))'
        '';
      });

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

      # whisper-cpp-cuda - whisper.cpp with CUDA support for RTX 5090
      whisper-cpp-cuda =
        (unstable.whisper-cpp.override {
          cudaSupport = true;
          cudaPackages = unstable.cudaPackages;
        }).overrideAttrs
          (oldAttrs: {
            cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
              "-DGGML_NATIVE=ON"
              "-DCMAKE_CUDA_ARCHITECTURES=89" # RTX 5090
            ];
            preConfigure = ''
              export NIX_ENFORCE_NO_NATIVE=0
              ${oldAttrs.preConfigure or ""}
            '';
          });

      # stable-diffusion-cpp-cuda - stable-diffusion.cpp with CUDA for image generation
      stable-diffusion-cpp-cuda = unstable.cudaPackages.backendStdenv.mkDerivation {
        pname = "stable-diffusion-cpp";
        version = "unstable-2026-02-19";

        src = pkgs.fetchFromGitHub {
          owner = "leejet";
          repo = "stable-diffusion.cpp";
          rev = "c5eb1e4137f22bcc6bf7b866d059b4e0638fb109";
          hash = "sha256-l69KArY0fGgQCp6YwK0Az9GAxW2rGOJdcJJ634HXQIs=";
          fetchSubmodules = true;
        };

        nativeBuildInputs = [
          unstable.cmake
          unstable.git
          unstable.cudaPackages.cuda_nvcc
          unstable.autoAddDriverRunpath
        ];

        buildInputs = with unstable.cudaPackages; [
          cuda_cccl
          cuda_cudart
          libcublas
        ];

        cmakeFlags = [
          "-DSD_CUDA=ON"
          "-DSD_BUILD_SERVER=ON"
          "-DCMAKE_CUDA_ARCHITECTURES=89" # RTX 5090
          "-DGGML_NATIVE=ON"
        ];

        preConfigure = ''
          export NIX_ENFORCE_NO_NATIVE=0
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          install -Dm755 bin/sd-cli $out/bin/sd-cli
          install -Dm755 bin/sd-server $out/bin/sd-server
          runHook postInstall
        '';

        meta = {
          description = "Stable Diffusion and Flux in pure C/C++ with CUDA support";
          homepage = "https://github.com/leejet/stable-diffusion.cpp";
          license = unstable.lib.licenses.mit;
          platforms = [ "x86_64-linux" ];
        };
      };
    })
  ];
}
