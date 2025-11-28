{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
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
