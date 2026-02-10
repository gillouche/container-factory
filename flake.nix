{
  description = "Container Factory Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            trivy
            gnumake
            docker-buildx
            hadolint
            shellcheck
            dive
            cosign
            pre-commit
            crane
            gh
            python3
          ];

          shellHook = ''
          '';
        };
      }
    );
}
