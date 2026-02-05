{
  description = "zccinfo - fast Zig CLI status line for Claude Code";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        zig = pkgs.zig_0_15;
      in
      {
        packages = rec {
          zccinfo = pkgs.stdenv.mkDerivation {
            pname = "zccinfo";
            version = self.shortRev or self.dirtyShortRev or "dev";

            src = ./.;

            nativeBuildInputs = [ zig.hook ];

            zigBuildFlags = [ "-Doptimize=ReleaseSafe" ];

            dontUseZigCheck = true;

            meta = with pkgs.lib; {
              description = "Fast Zig CLI status line for Claude Code";
              homepage = "https://github.com/tuananh131001/zccinfo";
              license = licenses.mit;
              platforms = platforms.unix;
              mainProgram = "zccinfo";
            };
          };

          default = zccinfo;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ zig ];
        };
      }
    ) // {
      overlays.default = final: prev: {
        zccinfo = self.packages.${prev.system}.zccinfo;
      };
    };
}
