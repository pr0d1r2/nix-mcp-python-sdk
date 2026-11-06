{
  description = "Nix package for the Model Context Protocol Python SDK (mcp 2.x)";

  nixConfig = {
    connect-timeout = 15;
    download-attempts = 5;
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    set-and-setting = {
      url = "github:pr0d1r2/set-and-setting/fa85f87a1be50f44cd75ce6357520f725cf94b4c";
      inputs = {
        nixpkgs-lock.follows = "nixpkgs-lock";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      set-and-setting,
      ...
    }:
    set-and-setting.lib.mkConsumerFlake {
      inherit self nixpkgs set-and-setting;
      fragments = [
        "base"
        "actions"
        "nix"
        "ascii"
        "markdown"
        "yaml"
        "toml"
      ];
      src = ./.;
      extraPackages = pkgs: import ./mcp-python-sdk.nix { inherit pkgs; };
      extraChecks = pkgs: {
        load-server = pkgs.runCommand "mcp-load-server-check" {
          nativeBuildInputs = [
            (pkgs.python313.withPackages (_: [ self.packages.${pkgs.stdenv.hostPlatform.system}.mcp ]))
          ];
        } "python3 ${./tests/load_server.py} && touch $out";
      };
    };
}
