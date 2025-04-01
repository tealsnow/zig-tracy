{
  description = "zig-tracy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        # @TODO: Create a deriviation for this lib

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            zig
            zls
            # @TODO: Investigate using the tracy lib from here instead of a submodule
          ];
        };
      }
    );
}
