{ pkgs, inputs, system, ... }:

let
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    overlays = [];
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
        version = "7658";

        src = pkgs.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = "b7658";
          hash = "sha256-Ij8N5zsAx6GX89xOgPVZkMjE1N2tRJ+LerrJ02ckRsE=";
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
        version = "182";

        src = pkgs.fetchFromGitHub {
          owner = "mostlygeek";
          repo = "llama-swap";
          tag = "v182";
          hash = "sha256-w/VQS8uCpgniwLiJsH/8IG/AGasRxjCv7fADTfpvWLw=";
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
        passthru.npmDepsHash = "sha256-RKPcMwJ0qVOgbTxoGryrLn7AW0Bfmv9WasoY+gw4B30=";
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
