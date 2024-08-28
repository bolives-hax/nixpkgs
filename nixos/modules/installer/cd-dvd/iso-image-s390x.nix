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
    system.build.isoImage = (pkgs.callPackage ../../../lib/make-iso9660-image.nix ({
	isoName = "nixos-s390x.iso";
	volumeID = "nixos";
	compressImage = false;

	bootable = true;
	# usbBootable = true; ?!
	bootImage = pkgs.stdenvNoCC.mkDerivation {
      		pname = "bigimg-boot";
      		# TODO this is just a single file
      		dontUnpack = true;
      		version = "0.1.0";
      		nativeBuildInputs = with pkgs; [
      		  #xorriso
      		  mk-s390-cdboot
      		];
      		buildPhase = let
      			paramFile = pkgs.writeText "params.txt" ''
      			  init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} copytoram
      			'';
		in ''
			${pkgs.mk-s390-cdboot}/bin/mk-s390-cdboot  -i ${config.system.boot.loader.kernelFile} \
      		    -r ${config.system.boot.loader.initrdFile}  -p ${paramFile} -o kernel_bundle.img
		'';
		installPhase = "mv kernel_bundle.img $out";
	};

	contents = [
		# kernel 
		{ 
		  source = config.boot.kernelPackages.kernel + "/" + config.system.boot.loader.kernelFile;
        	  target = "/boot/" + config.system.boot.loader.kernelFile;
        	}
		# initrd
        	{
		  source = config.system.build.initialRamdisk + "/" + config.system.boot.loader.initrdFile;
        	  target = "/boot/" + config.system.boot.loader.initrdFile;
        	}
		# version
        	{
		  source = pkgs.writeText "version" config.system.nixos.label;
        	  target = "/version.txt";
        	}
	];
	#storeContents = [ config.system.build.toplevel ];
    })).overrideAttrs (final: prev: {
		nativeBuildInputs = with pkgs; [
			xorriso
			#syslinux
			zstd
			libossp_uuid 
		];
	});

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
