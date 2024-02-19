{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, llvmPackages_17
, zlib
, ncurses
, libxml2
}:

rustPlatform.buildRustPackage rec {
  pname = "bpf-linker";
  version = "0.9.5";

  src = fetchFromGitHub {
    owner = "aya-rs";
    repo = pname;
    rev = "2ae2397701272bface78abc36b0b32d99a2a6998";
    sha256 = "0yb5ni0n1hpyrp5mibz4mlm0igasrbxnz94c4aiih33yrhri4f3p";
    #hash = "sha256-LEZ2to1bzJ;
  };

  #cargoSha256 = "";#2ae2397701272bface78abc36b0b32d99a2a6998";
  cargoHash = "";

  buildNoDefaultFeatures = true;
  buildFeatures = [ "system-llvm" ];

  nativeBuildInputs = [ llvmPackages_17.llvm ];
  buildInputs = [ zlib ncurses libxml2 ];

  # fails with: couldn't find crate `core` with expected target triple bpfel-unknown-none
  # rust-src and `-Z build-std=core` are required to properly run the tests
  doCheck = false;

  # Work around https://github.com/NixOS/nixpkgs/issues/166205.
  env = lib.optionalAttrs stdenv.cc.isClang {
    NIX_LDFLAGS = "-l${stdenv.cc.libcxx.cxxabi.libName}";
  };

  meta = with lib; {
    description = "Simple BPF static linker";
    homepage = "https://github.com/aya-rs/bpf-linker";
    license = with licenses; [ asl20 mit ];
    maintainers = with maintainers; [ nickcao ];
    # llvm-sys crate locates llvm by calling llvm-config
    # which is not available when cross compiling
    broken = stdenv.buildPlatform != stdenv.hostPlatform;
  };
}
