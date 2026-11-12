# TEMPORARY: delete this file, and its import in configuration.nix, once ninho
# runs a 7.0+ kernel, which ships this driver in-tree. The move is blocked for
# now by OpenZFS not supporting 7.3 yet (see the kernel pin in boot.nix). The
# assertion at the bottom fails the build as soon as the pin reaches 7.0, so
# this cannot outlive its purpose by accident.
#
# Driver for the Valve USB Wi-Fi adapter (28de:2432, an RTL8832CU). The pinned
# 6.18 kernel has no rtw89_8852cu: the module arrived in 6.19 and the Valve ID
# in 7.0. This builds the rtw89 directory of the Linux 7.0 release against the
# running kernel. rtw89 from 7.1 onwards needs mac80211 APIs that 6.18 lacks.
#
# The modules install under updates/, which depmod searches before the
# kernel's own modules, so every rtw89 module comes from this one source. That
# includes chip modules ninho has no hardware for: they link against
# rtw89_core and would not load next to a replaced one.
#
# Missing compared with 7.3: the adapter's serial_number and uuid sysfs files
# (7.2), and its 2.4 GHz-off quirk and status LED (7.3). Those commits do not
# apply to 7.0 without porting.
#
# modprobe reads the booted system's module tree, so this takes effect after a
# reboot, not on `nixos-rebuild switch`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.boot) kernelPackages;
  inherit (kernelPackages) kernel;

  # Every rtw89 module the 6.18 kernel builds in-tree, plus 8852CU.
  modules = [
    "CORE"
    "PCI"
    "USB"
    "8851B"
    "8851BE"
    "8851BU"
    "8852A"
    "8852AE"
    "8852B_COMMON"
    "8852B"
    "8852BE"
    "8852BU"
    "8852BT"
    "8852BTE"
    "8852C"
    "8852CE"
    "8852CU"
    "8922A"
    "8922AE"
  ];

  rtw89 = pkgs.stdenv.mkDerivation {
    pname = "rtw89-linux-7.0";
    inherit (kernel) version;

    src = pkgs.fetchurl {
      url = "mirror://kernel/linux/kernel/v7.x/linux-7.0.tar.xz";
      hash = "sha256-u39tgLOHx1e30Uu5MCj8uQ95PFwNNnc27oFaEAs4kfA=";
    };

    # Only the driver directory, not the whole kernel tree.
    unpackPhase = ''
      runHook preUnpack
      tar -xf $src linux-7.0/drivers/net/wireless/realtek/rtw89
      runHook postUnpack
    '';
    sourceRoot = "linux-7.0/drivers/net/wireless/realtek/rtw89";

    nativeBuildInputs = kernel.moduleBuildDependencies;
    hardeningDisable = [
      "pic"
      "format"
    ];

    makeFlags =
      kernelPackages.kernelModuleMakeFlags
      ++ [
        "-C"
        "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        "M=$(PWD)"
      ]
      ++ map (m: "CONFIG_RTW89_${m}=m") modules;
    buildFlags = [ "modules" ];

    installPhase = ''
      runHook preInstall
      install -Dm444 -t $out/lib/modules/${kernel.modDirVersion}/updates/rtw89 *.ko
      runHook postInstall
    '';
  };
in
{
  assertions = [
    {
      assertion = lib.versionOlder kernel.version "7.0";
      message = "rtw89-backport.nix: kernel ${kernel.version} ships rtw89_8852cu in-tree. Delete system/machine/ninho/rtw89-backport.nix and its import in configuration.nix.";
    }
  ];

  boot.extraModulePackages = [ rtw89 ];
}
