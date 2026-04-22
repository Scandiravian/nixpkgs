{ lib, config, ... }:
let
  facterLib = import ./lib.nix lib;

  cfg = config.hardware.facter;
in
{
  options.hardware.facter.detected.cpu.amd = {
    enable = lib.mkEnableOption "Enable the Facter AMD CPU module" // {
      default =
        if lib.hasAttrByPath [ "hardware" "cpu" ] cfg.report then facterLib.hasAmdCpu cfg.report else false;
      defaultText = "Enabled if the CPU vendor is `AuthenticAMD`.";
    };

    cppc = lib.mkEnableOption "Collaborative Processor Performance Control" // {
      default = lib.any (cpu: lib.elem "cppc" cpu.features) (
        lib.attrByPath [ "hardware" "cpu" ] [ ] cfg.report
      );
      defaultText = "Enabled if the cpu supports Collaborative Processor Performance Control (`cppc`).";
    };
  };

  config.hardware.cpu.amd = lib.mkIf cfg.detected.cpu.amd.enable {
    pstate.enable = lib.mkDefault cfg.detected.cpu.amd.cppc;
  };
}
