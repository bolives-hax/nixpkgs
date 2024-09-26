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
 boot.kernelPackages = pkgs.linuxPackagesFor ( pkgs.linuxManualConfig rec {
    version = "6.6.21";
    src = fetchTarball {
      url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.52.tar.xz";
      sha256 = "sha256:0h92b741c602ff7i6hyndpjn8n1k06qa2pqprncd2ax9zn0k2d86";
    };
    configfile = "${(pkgs.fetchurl {
	url = "https://git.alpinelinux.org/aports/plain/main/linux-lts/lts.s390x.config";
	hash = "sha256:1hx3i93r67jxcd367cab6i8511zfcjfs1bh9nn92dr48nm6cg1j2";
    })}";
    stdenv = pkgs.gcc10Stdenv;  # doesn't seem to set the GCC used for compilation
  });
system.requiredKernelConfig = lib.mkForce [];
/*
    boot.kernelPackages = pkgs.linuxPackagesFor ( pkgs.linuxPackages_latest.kernel.override {
	structuredExtraConfig = with lib.kernel; {
		EARLY_PRINTK = yes;
		CRASH_DUMP = lib.mkForce yes;
                DEBUG_INFO = yes;
                EXPERT = yes;
                DEBUG_KERNEL = yes;
		TASK_DELAY_ACCT = yes;
		IKHEADERS = yes; # bcc needs this for memleak testing 

		# test if that fixes kernel
		#SCLP_TTY = module;
		#SCLP_CONSOLE = module;
		#SCLP_VT220_TTY = module;
		#SCLP_VT220_CONSOLE = module;
		#SCLP_OFB = yes;
	};
    });
*/

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
      [ 
	"root=LABEL=nixos"
        "boot.shell_on_fail"
	# TODO the emergency shell seems
	# to be useless in qemu as
	# it doesn't select the right serialdev/tty
	# and thus the shell won't show up after
	# the (press X to choice ...) dialogue
      ];
    system.build.isoImage = let 
	bigimg = pkgs.stdenvNoCC.mkDerivation {
      		pname = "bigimg-boot";
      		# TODO this is just a single file
      		dontUnpack = true;
      		version = "0.1.4";
      		dontFixup = true;
      		nativeBuildInputs = with pkgs; [
      		  # TODO make sure getopt is a dep of s390 tools
		  # and that share/netboot scripts are either another pkg or
		  # added to /bin
      		  getopt
      		  s390-tools
      		];
		# TODO i don't think the copytoram gets interpreted here ...
		# does it? And is it a wise default selection? I figured
		# it would make things better when using emulation > kvm
      		buildPhase = let
      			/*paramFile = pkgs.writeText "params.txt" ''
      			  init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} copytoram
      			'';*/
      			paramFile = pkgs.writeText "params.txt" ''
      			  init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}
      			'';
		in ''${pkgs.s390-tools}/usr/share/s390-tools/netboot/mk-s390image \
			${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile} \
      		    	-r ${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile} \
			-p ${paramFile} kernel_bundle.img'';
		installPhase = "mv kernel_bundle.img $out";
	};
	in (pkgs.callPackage ../../../lib/make-iso9660-image.nix ({
	isoName = "nixos-s390x.iso";
	# V TODO set this like its being done in the non s390x cdimage thingy
	volumeID = "nixos";
	compressImage = false;
	squashfsCompression = "zstd -Xcompression-level 6";

	bootable = true;
	# usbBootable = true; ?! # why does this cause issues
	# do we want to hardcode this and is this a smart name?
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
			#syslinux # we don't have syslinux here
			# but should fix this in a lasting sense instead of just
			# overriding here
			zstd
			libossp_uuid 
		];
	});

  };
}
