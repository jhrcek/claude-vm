{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    claude-code.url = "github:sadjow/claude-code-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      claude-code,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          {
            system.stateVersion = "25.11";

            networking.hostName = "vm";

            time.timeZone = "Europe/Prague";

            environment.systemPackages = [
              claude-code.packages.${system}.default
              pkgs.haskell.compiler.ghc912
              pkgs.cabal-install
              pkgs.elmPackages.elm
              pkgs.elmPackages.elm-test
              pkgs.git
              pkgs.gnumake
              pkgs.jq
              pkgs.jless
              pkgs.pkg-config
              pkgs.vim
              pkgs.zlib
            ];

            users.users.dev = {
              isNormalUser = true;
              extraGroups = [ "wheel" ];
              initialPassword = "dev";
            };

            # Make C libraries discoverable by cabal/GHC
            environment.variables = {
              LIBRARY_PATH = "${pkgs.zlib}/lib";
              C_INCLUDE_PATH = "${pkgs.zlib.dev}/include";
            };

            # Start in ~/workspace by default on login
            environment.etc."profile.local".text = ''
              cd ~/workspace 2>/dev/null || true
            '';

            services.getty.autologinUser = "dev";

            virtualisation.vmVariant.virtualisation = {
              memorySize = 8192;
              cores = 16;
              graphics = false;
              diskSize = 32768; # 32 GB disk size in MB
              sharedDirectories.workspace = {
                source = ''"$WORKSPACE_DIR"'';
                target = "/home/dev/workspace";
              };
            };

            nix.settings.experimental-features = [
              "nix-command"
              "flakes"
            ];
          }
        ];
      };

      packages.${system}.default =
        let
          vmBuild = self.nixosConfigurations.vm.config.system.build.vm;
        in
        pkgs.writeShellScriptBin "claude-vm" ''
          export WORKSPACE_DIR="$(pwd)"
          exec ${vmBuild}/bin/run-vm-vm
        '';

      formatter.${system} = pkgs.nixfmt;
    };
}
