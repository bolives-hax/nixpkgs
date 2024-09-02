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

    #fileSystems = config.lib.isoFileSystems;
    boot.initrd.availableKernelModules = [ "squashfs" "iso9660" "uas" "overlay" 
"virtio-pci" "virtio_blk" "virtio_scsi" "sr_mod" ];
    boot.initrd.kernelModules = [ "loop" "overlay" ];
    boot.kernel.features = { debug = true; };
    boot.kernelPackages = pkgs.linuxPackagesFor ( pkgs.linuxPackages_latest.kernel.override {
	structuredExtraConfig = with lib.kernel; {
		EARLY_PRINTK = yes;
		CRASH_DUMP = lib.mkForce yes;
                DEBUG_INFO = yes;
                EXPERT = yes;
                DEBUG_KERNEL = yes;
	};
    });

    fileSystems = {
    "/iso" = 
      { device = "/dev/root";
        neededForBoot = true;
        noCheck = true;
      };

    # In stage 1, mount a tmpfs on top of /nix/store (the squashfs
    # image) to make this a live CD.
    "/nix/.ro-store" = 
      { fsType = "squashfs";
        device = "/iso/nix-store.squashfs";
        options = [ "loop" ];
        neededForBoot = true;
      };

    "/nix/.rw-store" = 
      { fsType = "tmpfs";
        options = [ "mode=0755" ];
        neededForBoot = true;
      };

    "/" = {
	fsType = "tmpfs";
    };
    "/nix/store" = 
      { fsType = "overlay";
        device = "overlay";
        options = [
          "lowerdir=/nix/.ro-store"
          "upperdir=/nix/.rw-store/store"
          "workdir=/nix/.rw-store/work"
        ];
        depends = [
          "/nix/.ro-store"
          "/nix/.rw-store/store"
          "/nix/.rw-store/work"
        ];
      };
    };

    boot.kernelParams =
      [ "root=LABEL=nixos"
        "boot.shell_on_fail"
      ];
    system.build.isoImage = let 
	bigimg = pkgs.stdenvNoCC.mkDerivation {
      		pname = "bigimg-boot";
      		# TODO this is just a single file
      		dontUnpack = true;
      		version = "0.1.3";
      		dontFixup = true;
      		nativeBuildInputs = with pkgs; [
      		  #xorriso
      		  mk-s390-cdboot getopt
      		];
      		buildPhase = let
      			paramFile = pkgs.writeText "params.txt" ''
      			  init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} copytoram
      			'';
		in ''
			mk-s390-cdboot   ${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile} \
      		    -r ${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}  -p ${paramFile} kernel_bundle.img
		'';
		installPhase = "mv kernel_bundle.img $out";
	};
	in (pkgs.callPackage ../../../lib/make-iso9660-image.nix ({
	isoName = "nixos-s390x.iso";
	volumeID = "nixos";
	compressImage = false;
	squashfsCompression = "zstd -Xcompression-level 6";

	bootable = true;
	# usbBootable = true; ?!
	bootImage = "/bigimg";
	contents = [
        	{
		  source = bigimg;
        	  target = "/bigimg";
        	}
		# version
        	{
		  source = pkgs.writeText "version" config.system.nixos.label;
        	  target = "/version.txt";
        	}
	];
	squashfsContents = [ config.system.build.toplevel ];
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
