{ gcc14Stdenv, fetchFromGitHub, systemd, cryptsetup, net-snmp, fuse3, openssl
, bash, lib}:
let
  pname = "s390-tools";
  version = "2.33.1";
  march = with lib; if lib.attrsets.hasAttrByPath
  [ "gcc" "arch" ]
  gcc14Stdenv.targetPlatform then
  gcc14Stdenv.targetPlatform.gcc.arch
  else lib.warn "no march specified: selecting z900 (gcc's default)" "z900";
  in
  lib.warnIf (lib.lists.any
    (m: m == march)
    [ "z900"  "z990"  "arch6" "z9-109" "z9-ec" "arch7" ]
    ) "gcc.arch = \"${march}\" is broken for zipl"
    gcc14Stdenv.mkDerivation  {
  inherit pname version;
  src = fetchFromGitHub {
    owner = "ibm-s390-linux";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-flH2v1z7wpDqGV2R/uS4aBKxdtGtEgO03UjbSA+sBWQ=";
  };
  nativeBuildInputs = [
    bash
    #gettext
    #pkg-config
    #perl
    #net-snmp.dev
    #ncurses.dev
    #fuse3
    ##pkgs.cargo
    #curl.dev
    #json_c.dev
    #libxml2.dev
    #pkgs.gcc14.stdenv.cc
    #_pkgs.elfkickers # sstrp (didn't seem to help)
  ];
  buildInputs = [
    systemd.dev
    cryptsetup.dev
    net-snmp.dev
    #glibc.static.out
    #ncurses.dev
    fuse3
    #pkgs.cargo
    openssl
    #curl.dev
    #json_c.dev
    #libxml2.dev
  ];
  hardeningDisable = [ "all" ];
  patchPhase = ''
    patchShebangs --build .
    substituteInPlace \
    common.mak --replace-fail "override SHELL := /bin/bash" "override SHELL := bash"

    substituteInPlace Makefile \
    --replace-fail "LIB_DIRS = libvtoc libzds libdasd libccw libvmcp libekmfweb \\" "LIB_DIRS = #\\" \
    --replace-fail "TOOL_DIRS = zipl zdump fdasd dasdfmt dasdview tunedasd \\" "TOOL_DIRS = zipl dasdfmt#\\"
  '';
  buildPhase = ''
    make V=1 -j $(nproc) HOST_ARCH=s390x BUILD_ARCH=x86_64-linux CROSS_COMPILE=s390x-unknown-linux-gnu- \
      INSTALLDIR=$out \
      HAVE_OPENSSL=0 \
      HAVE_CURL=0 \
    	HAVE_CARGO=0 \
    	HAVE_GLIB=0 \
    	HAVE_GLIB2=0 \
    	HAVE_PFM=0
  '';
  installPhase = ''
    mkdir -p $out
    make install V=1 -j $(nproc) HOST_ARCH=s390x BUILD_ARCH=x86_64-linux CROSS_COMPILE=s390x-unknown-linux-gnu- \
      INSTALLDIR=$out \
      HAVE_OPENSSL=0 \
      HAVE_CURL=0 \
    	HAVE_CARGO=0 \
    	HAVE_GLIB=0 \
    	HAVE_GLIB2=0 \
    	HAVE_PFM=0

  '';
  #dontFixup = true;
  meta = {
    # TODO etc
    # at the moment except very few utilities s390-tools can
    # only be build for s390 / s390x
    platforms = [ "s390x-linux" "s390-linux" ];
  };
}
