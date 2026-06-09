{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = [
    pkgs.swi-prolog
    pkgs.sqlite
    pkgs.pkg-config
    pkgs.gcc

    pkgs.python313
    pkgs.python313Packages.pandas
    pkgs.python313Packages.matplotlib
    pkgs.python313Packages.seaborn
    pkgs.python313Packages.ipykernel
    pkgs.python313Packages.jupyterlab
    pkgs.python313Packages.notebook
  ];

  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
    pkgs.sqlite
  ];

  shellHook = ''
    swipl --version
  '';
}
