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
            echo "Container Factory Dev Environment" >&2
            echo "Tools available: make, trivy, docker-buildx" >&2
            echo "Security tools: hadolint, shellcheck, dive, cosign, pre-commit, crane" >&2
          '';
        };
      }
    );
}
