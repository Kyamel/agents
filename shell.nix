{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = [
    pkgs.swi-prolog
    pkgs.sqlite
    pkgs.pkg-config
    pkgs.gcc

    (pkgs.python313.withPackages (ps: with ps; [
      mypy
      pandas
      matplotlib
      seaborn
      ipykernel
      jupyterlab
      notebook
    ]))
  ];

  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
    pkgs.sqlite
  ];

  shellHook = ''
    swipl --version
  '';
}
