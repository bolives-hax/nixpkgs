{musl, gcc14Stdenv, fetchFromGitHub, systemd, cryptsetup, net-snmp, fuse3, openssl
, patchelf, glibc, bash, pkg-config, json_c, lib, wrapCCWith, wrapBintoolsWith, overrideCC, gcc14, binutils-unwrapped}:
let
  stdenv = gcc14Stdenv;
  pname = "s390-tools";
  version = "2.33.1";
  march = with lib; if lib.attrsets.hasAttrByPath
  [ "gcc" "arch" ]
  stdenv.targetPlatform then
  stdenv.targetPlatform.gcc.arch
  else lib.warn "no march specified: selecting z900 (gcc's default)" "z900";

  makeFlags = with lib.strings; (optionalString stdenv.hostPlatform.isS390x "HOST_ARCH=s390x ")
  + (optionalString (stdenv.buildPlatform != stdenv.hostPlatform )  #cross
  "BUILD_ARCH=${stdenv.buildPlatform.system} CROSS_COMPILE=s390x-unknown-linux-gnu-");
  in
  lib.warnIf (lib.lists.any
    (m: m == march)
    [ "z900"  "z990"  "arch6" "z9-109" "z9-ec" "arch7" ]
    ) "gcc.arch = \"${march}\" is broken for zipl"
    stdenv.mkDerivation  {
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
    pkg-config
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
    #glibc.static
  ];
  buildInputs = [
    systemd.dev
    cryptsetup.dev
    net-snmp.dev
    #glibc.static.out
    glibc.dev
    #ncurses.dev
    fuse3
    #pkgs.cargo
    openssl
    #curl.dev
    json_c.dev
    #libxml2.dev
  ];
  hardeningDisable = [ "all" ];
  patchPhase = ''
    patchShebangs --build .
    substituteInPlace \
    common.mak --replace-fail "override SHELL := /bin/bash" "override SHELL := bash"

    substituteInPlace Makefile \
    --replace-fail "LIB_DIRS = libvtoc libzds libdasd libccw libvmcp libekmfweb \\" "LIB_DIRS = #\\" \
    --replace-fail "TOOL_DIRS = zipl zdump fdasd dasdfmt dasdview tunedasd \\" "TOOL_DIRS = zipl dasdfmt zfcpdump netboot zdev#\\"

  '';
  buildPhase = let
a = let
	gcc_static = 
wrapCCWith  {
		cc = gcc14.cc;
		bintools = wrapBintoolsWith {
			bintools = binutils-unwrapped;
			libc = musl;
		};	
	};
in (overrideCC stdenv gcc_static).mkDerivation {
#in stdenv.mkDerivation {
  hardeningDisable = [ "all" ];
  patchPhase = ''
    patchShebangs --build .
    substituteInPlace \
    common.mak --replace-fail "override SHELL := /bin/bash" "override SHELL := bash"

    substituteInPlace Makefile \
    --replace-fail "LIB_DIRS = libvtoc libzds libdasd libccw libvmcp libekmfweb \\" "LIB_DIRS = #\\" \
    --replace-fail "TOOL_DIRS = zipl zdump fdasd dasdfmt dasdview tunedasd \\" "TOOL_DIRS = zipl dasdfmt zfcpdump netboot zdev#\\"
  '';
name = "zfcpdump";
version = "0.0.1";
  src = fetchFromGitHub {
    owner = "ibm-s390-linux";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-flH2v1z7wpDqGV2R/uS4aBKxdtGtEgO03UjbSA+sBWQ=";
  };
buildInputs = [
musl.dev
];
nativeBuildInputs = [
patchelf
];
#dontStrip = true;
buildPhase = "
#	ls -la
#cd zfcpdump
make V=1 -C zfcpdump cpioinit 
patchelf --set-interpreter ${musl}/lib/ld-musl-s390x.so.1 ./zfcpdump/cpioinit
make V=1 -C zfcpdump zfcpdump_part
make V=1 -C zfcpdump  all
";
installPhase = "
#make V=1 -C zfcpdump cpioinit \ 
#      INSTALLDIR=$out 
#cp -r zfcpdump $out
mkdir -p $out/bin
#cp zfcpdump/cpioinit $out/bin
cp zfcpdump/* $out/bin
";
};
	in ''
echo a = ${a}
cp ${a}/bin/* zfcpdump
    substituteInPlace zfcpdump/Makefile \
    --replace-fail "all: check_dep \$(ZFCPDUMP_INITRD) scripts" "all: $(ZFCPDUMP_INITRD) scripts"
echo "int main(int argc, char ** argv) {return 0; }" > 1.c
  echo $CC -L${glibc} -static 1.c 
    echo ${json_c.dev}
    make V=1 -j $(nproc) ${makeFlags} LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${json_c.dev}/
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
    make install V=1 -j $(nproc) ${makeFlags} \
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
    platforms = [ "s390x-linux" /*"s390-linux"*/ ];
  };
}
