{ pkgs ? import ./nix {}
, plone ? "plone521"
, python ? "python37"
}:

(import ./setup.nix {
  inherit pkgs plone python;
  buildInputs = with pkgs; [
    niv
  ];
}).buildout
