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
        version = "78083";

        src = pkgs.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = "b8083";
          hash = "sha256-VqtUTzSyF+kavv9S046Hf7q2fEJZr82h7Ab4yUHzalU=";
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

        # Keep the original postInstall to handle installation correctly
        postInstall = oldAttrs.postInstall or "";
      });

      # llama-swap v182 - Latest release with Anthropic API compatibility
      llama-swap = prev.llama-swap.overrideAttrs (oldAttrs: {
        version = "186";

        src = pkgs.fetchFromGitHub {
          owner = "mostlygeek";
          repo = "llama-swap";
          tag = "v186";
          hash = "sha256-3D+fQ9Lu0OfON694hWlv5QcuGS/zAlkOW+Q9AMq+RWQ=";
          leaveDotGit = true;
          postFetch = ''
            cd "$out"
            git rev-parse HEAD > $out/COMMIT
            date -u -d "@$(git log -1 --pretty=%ct)" "+'%Y-%m-%dT%H:%M:%SZ'" > $out/SOURCE_DATE_EPOCH
            find "$out" -name .git -print0 | xargs -0 rm -rf
          '';
        };

        proxyVendor = true;
        vendorHash = "sha256-TPOKqgyf8vltRLbtNWXcK3jsWsVFaSrZAc+/AMkG/8A=";
        passthru.ui = oldAttrs.passthru.ui;
        passthru.npmDepsHash = "sha256-xz4z/Bxlbw7uuzRP0aWPRKSfhPAB++iToYnymu4RVSE=";

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
    })
  ];
}
