# Lean theorem prover toolchain - heavy, opt-in per machine.
# Pulled in by Ninho only. Excluded from laptop configs.

{ pkgs, ... }:
{
  home.packages = with pkgs; [
    lean4
  ];
}
