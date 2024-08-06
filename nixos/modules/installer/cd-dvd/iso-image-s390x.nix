{ lib
, config
, pkgs
, ...
}: {
  options = with lib; {
    s390xIso = mkOption {
      type = types.package;
      default = pkgs.hello;
    };
  };

  config = {

    s390xIso = let
      paramFile = pkgs.writeText "params.txt" ''
        init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} copytoram
      '';
    in pkgs.stdenvNoCC.mkDerivation {
      pname = "s390x-installer-iso";
      # TODO this is just a single file
      dontUnpack = true;
      version = "0.1.0";
      nativeBuildInputs = with pkgs; [
        xorriso
        mk-s390x-cdboot
      ];
      buildPhase =
      #''
      #  ${pkgs.mk-s390x-cdboot}  -i ${config.system.boot.loader.kernelFile} \
      #    -r ${config.system.boot.loader.initrdFile}  -p ${paramFile} -o kernel_bundle.img
      ''
       mk-s390x-cdboot
        xorrisofs -r -l -no-emul-boot -eltorito-boot kernel_bundle.img -o cdrom.iso
      '';
      installPhase = ''
        mkdir $out
        mv cdrom.iso $out
      '';
    };
  };
}
