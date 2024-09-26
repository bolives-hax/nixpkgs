{ self, callPackage, fetchFromGitHub, passthruFun }:

callPackage ./default.nix {
  # The patch version is the timestamp of the git commit,
  # obtain via `cat $(nix-build -A luajit_2_1.src)/.relver`
  version = "2.1.1713773202";

  src = fetchFromGitHub {
    owner = "linux-on-ibm-z";
    repo = "LuaJIT";
    rev = "5790d253972c9d78a0c2aece527eda5b134bbbf7";
    hash = "ha256-4irOZ2m3k6Nz5rvvqN4DfAIQWCvIySSSC1MmzvA6GS8=";
  };

  inherit self passthruFun;
}
