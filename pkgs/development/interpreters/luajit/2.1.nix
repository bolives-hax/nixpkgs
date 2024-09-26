{ self, callPackage, fetchFromGitHub, passthruFun }:

callPackage ./default.nix {
  # The patch version is the timestamp of the git commit,
  # obtain via `cat $(nix-build -A luajit_2_1.src)/.relver`
  version = "2.1.1713773202";

  src = fetchFromGitHub {
    owner = "linux-on-ibm-z";
    repo = "LuaJIT";
    rev = "9eaff286df941f645b31360093e181b967993695";
    hash = "sha256-4irOZ2m3k6Nz5rvvqN4DfAIQWCvIySSSC1MmzvA6GS8=";
  };

  inherit self passthruFun;
}
