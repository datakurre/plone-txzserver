{ pkgs ? import ./nix {}
, python ? "python37"
}:

(import ./setup.nix {
  inherit pkgs;
  inherit python;
  buildInputs = with pkgs; [
    niv
  ];
}).buildout
