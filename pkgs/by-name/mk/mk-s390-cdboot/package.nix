{ lib
, stdenv
, fetchurl
}:

stdenv.mkDerivation {
  pname = "mk-s390x-cdboot";
  # TODO this is just a single file
  version = "0.1.0";

  src = fetchurl {
    #url = "https://raw.githubusercontent.com/rhinstaller/anaconda/rhel6-branch/utils/mk-s390-cdboot.c";
	url = "https://raw.githubusercontent.com/ibm-s390-linux/s390-tools/master/netboot/mk-s390image";
    hash = "sha256-SqE4Syto1RPzzNIPcHt32z5EQ5/8qq0vsT78OQ79xPk=";
  };

  dontUnpack = true;

  #buildPhase = "$CC $src -o mk-s390-cdboot";

buildPhase = "cp $src mk-s390-cdboot && patchShebangs . && chmod +x mk-s390-cdboot";
  installPhase = "mkdir -p $out/bin && mv ./mk-s390-cdboot $out/bin";


}
