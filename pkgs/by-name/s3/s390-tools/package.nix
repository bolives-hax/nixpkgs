{ gcc14Stdenv, fetchFromGitHub, systemd, cryptsetup, net-snmp, fuse3, openssl
, bash }:
let
  pname = "s390-tools";
  version = "2.33.1";
in gcc14Stdenv.mkDerivation {
  inherit pname version;
  src = fetchFromGitHub {
    owner = "ibm-s390-linux/s390-tools";
    repo = pname;
    rev = "${version}";
    hash = "sha256-GhZPvo8wlXInHwg8rSmpwMMkZVw5SMpnZyKqFUYLbrE=";
  };
  nativeBuildInputs = [
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
    common.mak --replace-fail "override SHELL := /bin/bash" "override SHELL := ${bash}/bin/bash"

    substituteInPlace Makefile \
    --replace-fail "LIB_DIRS = libvtoc libzds libdasd libccw libvmcp libekmfweb \\" "LIB_DIRS = #\\" \
    --replace-fail "TOOL_DIRS = zipl zdump fdasd dasdfmt dasdview tunedasd \\" "TOOL_DIRS = zipl #\\"
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
  dontFixup = true;
  meta = {
    # TODO etc
    # at the moment except very few utilities s390-tools can
    # only be build for s390 / s390x
    platforms = [ "s390x-linux" "s390-linux" ];
  };
}
