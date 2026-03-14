{ pkgs, inputs, system, ... }:

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
      llama-cpp-cuda = (unstable.llama-cpp.override {
        cudaSupport = true;
        cudaPackages = unstable.cudaPackages;
        blasSupport = true;
        rocmSupport = false;
        metalSupport = false;
      }).overrideAttrs (oldAttrs: {
        version = "8334";

        src = pkgs.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = "b8334";
          hash = "sha256-1WBivYmZQgujl73IS4J5/jUiwOh/d2ZfKRA93P9ADiM=";
          leaveDotGit = true;
          postFetch = ''
            git -C "$out" rev-parse --short HEAD > $out/COMMIT
            find "$out" -name .git -print0 | xargs -0 rm -rf
          '';
        };

        cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
          "-DGGML_NATIVE=ON"
          "-DCMAKE_CUDA_ARCHITECTURES=89"  # RTX 5090
        ];

        preConfigure = ''
          export NIX_ENFORCE_NO_NATIVE=0
          ${oldAttrs.preConfigure or ""}
        '';

        # Webui npm deps hash changed with this source version
        npmDepsHash = "sha256-5ZswgZFLeI32/xQZqCTTFbCzleDqr5AotjFg/5rNn1M=";

        # Keep the original postInstall to handle installation correctly
        postInstall = oldAttrs.postInstall or "";
      });

      # llama-swap v195 - Latest release with Anthropic API compatibility
      # v195 renamed ui/ → ui-svelte/, so we rebuild the UI derivation from scratch
      llama-swap = let
        llama-swap-src = pkgs.fetchFromGitHub {
          owner = "mostlygeek";
          repo = "llama-swap";
          tag = "v198";
          hash = "sha256-7fZUKDCtj8RGca53CkLwVpvNWX6ryTbS02Uz/+uZpTs=";
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
          version = "198";
          src = llama-swap-src;
          sourceRoot = "${llama-swap-src.name}/ui-svelte";
          npmDepsHash = "sha256-gTDsuWPLCWsPltioziygFmSQFdLqjkZpmmVWIWoZwoc=";
          postPatch = ''
            substituteInPlace vite.config.ts \
              --replace-fail "../proxy/ui_dist" "${placeholder "out"}/ui_dist"
          '';
          postInstall = ''
            rm -rf $out/lib
          '';
        };
      in prev.llama-swap.overrideAttrs (oldAttrs: {
        version = "198";
        src = llama-swap-src;
        proxyVendor = true;
        vendorHash = "sha256-TPOKqgyf8vltRLbtNWXcK3jsWsVFaSrZAc+/AMkG/8A=";
        passthru.ui = llama-swap-ui;

        preBuild = ''
          ldflags+=" -X main.commit=$(cat COMMIT)"
          ldflags+=" -X main.date=$(cat SOURCE_DATE_EPOCH)"
          cp -r ${llama-swap-ui}/ui_dist proxy/
        '';
      });

      # WhisperX v3.7.6 - Fix use_auth_token TypeError with newer pyannote
      whisperx = prev.whisperx.overridePythonAttrs (oldAttrs: {
        version = "3.7.6";

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

        meta = (oldAttrs.meta or {}) // { broken = false; };
      });

      # Fix scaphandre build error with riemann_client unstable feature
      scaphandre = prev.scaphandre.overrideAttrs (oldAttrs: {
        # Unmark as broken and apply patch to fix the compilation error
        meta = oldAttrs.meta // {
          broken = false;
        };

        # Patch the riemann_client vendored source to fix unstable Rust feature
        # This needs to run before cargo build starts
        preBuild = (oldAttrs.preBuild or "") + ''
          # The vendored dependencies are extracted to ../scaphandre-VERSION-vendor/
          # Find and patch the riemann_client mod_pb.rs file
          if [ -f ../scaphandre-*-vendor/riemann_client-*/src/proto/mod_pb.rs ]; then
            echo "Patching riemann_client mod_pb.rs to remove unstable Rust feature..."
            sed -i '/#!\[rustfmt::skip\]/d' ../scaphandre-*-vendor/riemann_client-*/src/proto/mod_pb.rs
          fi
        '';
      });

      # whisper-cpp-cuda - whisper.cpp with CUDA support for RTX 5090
      whisper-cpp-cuda = (unstable.whisper-cpp.override {
        cudaSupport = true;
        cudaPackages = unstable.cudaPackages;
      }).overrideAttrs (oldAttrs: {
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
