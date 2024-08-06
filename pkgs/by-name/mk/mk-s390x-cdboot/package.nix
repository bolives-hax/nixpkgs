{ lib
, stdenv
, fetchurl
}:

stdenv.mkDerivation {
  pname = "mk-s390x-cdboot";
  # TODO this is just a single file
  version = "0.1.0";

  src = fetchurl {
    url = "https://raw.githubusercontent.com/rhinstaller/anaconda/rhel6-branch/utils/mk-s390-cdboot.c";
    hash = "sha256-0WfJPLaerylQoFQiKMy5Tt3xa3dU1R74C9XHmKBxoK0=";
  };

  dontUnpack = true;

  buildPhase = "$CC $src -o mk-s390-cdboot";
  installPhase = "mv ./mk-s390-cdboot $out";


}
