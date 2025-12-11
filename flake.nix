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

            environment.systemPackages = [
              claude-code.packages.${system}.default
              pkgs.ghc
              pkgs.cabal-install
              pkgs.git
            ];

            users.users.dev = {
              isNormalUser = true;
              extraGroups = [ "wheel" ];
              initialPassword = "dev";
            };

            services.getty.autologinUser = "dev";

            virtualisation.vmVariant.virtualisation = {
              memorySize = 8192;
              cores = 16;
              graphics = false;
              diskSize = 32768; # 32 GB disk size in MB
              sharedDirectories.workspace = {
                source = "$HOME/Tmp/claude-code-nixos-vm/workspace";
                target = "/workspace";
              };
            };

            nix.settings.experimental-features = [
              "nix-command"
              "flakes"
            ];
          }
        ];
      };

      packages.${system}.default = self.nixosConfigurations.vm.config.system.build.vm;

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
