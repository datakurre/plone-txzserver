{ pkgs ? import ./nix { config = { allowBroken = true; }; }
, plone ? "plone521"
, python ? "python37"
, pythonPackages ? builtins.getAttr (python + "Packages") pkgs
, requirements ?  ./. + "/requirements-${plone}-${python}.nix"
, buildInputs ? []
}:

with builtins;
with pkgs;
with pkgs.lib;

let

  # Requirements for generating requirements.nix
  requirementsBuildInputs = [ cacert nix nix-prefetch-git niv libyaml
                              cyrus_sasl libffi libxml2 libxslt openldap ];
  buildoutPythonPackages = [ "cython" "pillow" "setuptools" ];

  # Load generated requirements
  requirementsFunc = import requirements {
    inherit pkgs;
    inherit (builtins) fetchurl;
    inherit (pkgs) fetchgit fetchhg;
  };

  # List package names in requirements
  requirementsNames = attrNames (requirementsFunc {} {});

  # Return base name from python drv name or name when not python drv
  pythonNameOrName = drv:
    if hasAttr "overridePythonAttrs" drv then drv.pname else drv.name;

  # Merge named input list from nixpkgs drv with input list from requirements drv
  mergedInputs = old: new: inputsName: self: super:
    (attrByPath [ inputsName ] [] new) ++ map
    (x: attrByPath [ (pythonNameOrName x) ] x self)
    (filter (x: !isNull x) (attrByPath [ inputsName ] [] old));

  # Merge package drv from nixpkgs drv with requirements drv
  mergedPackage = old: new: self: super:
    if isString new.src
       && !isNull (match ".*\.whl" new.src)  # do not merge build inputs for wheels
       && new.pname != "wheel"               # ...
    then new.overridePythonAttrs(old: rec {
      propagatedBuildInputs =
        mergedInputs old new "propagatedBuildInputs" self super;
    })
    else old.overridePythonAttrs(old: rec {
      inherit (new) pname version src;
      name = "${pname}-${version}";
      checkInputs =
        mergedInputs old new "checkInputs" self super;
      buildInputs =
        mergedInputs old new "buildInputs" self super;
      nativeBuildInputs =
        mergedInputs old new "nativeBuildInputs" self super;
      propagatedBuildInputs =
        mergedInputs old new "propagatedBuildInputs" self super;
      doCheck = false;
    });

  # Build python with manual aliases for naming differences between world and nix
  buildPython = (pythonPackages.python.override {
    packageOverrides = self: super:
      listToAttrs (map (name: {
        name = name; value = getAttr (getAttr name aliases) super;
      }) (filter (x: hasAttr (getAttr x aliases) super) (attrNames aliases)));
  });

  # Build target python with all generated & customized requirements
  targetPython = (buildPython.override {
    packageOverrides = self: super:
      # 1) Merge packages already in pythonPackages
      let super_ = (requirementsFunc self buildPython.pkgs);  # from requirements
          results = (listToAttrs (map (name: let new = getAttr name super_; in {
        inherit name;
        value = mergedPackage (getAttr name buildPython.pkgs) new self super_;
      })
      (filter (name: hasAttr "overridePythonAttrs"
                     (if (tryEval (attrByPath [ name ] {} buildPython.pkgs)).success
                      then (attrByPath [ name ] {} buildPython.pkgs) else {}))
       requirementsNames)))
      // # 2) with packages only in requirements or disabled in nixpkgs
      (listToAttrs (map (name: { inherit name; value = (getAttr name super_); })
      (filter (name: (! ((hasAttr name buildPython.pkgs) &&
                         (tryEval (getAttr name buildPython.pkgs)).success)))
       requirementsNames)));
      in # 3) finally, apply overrides (with aliased drvs mapped back)
      (let final = (super // (results //
        (listToAttrs (map (name: {
          name = getAttr name aliases; value = getAttr name results;
        }) (filter (x: hasAttr x results) (attrNames aliases))))
      )); in (final // (overrides self final)));
    self = buildPython;
  });

  # Alias packages with different names in requirements and in nixpkgs
  aliases = {
    "Pillow" = "pillow";
    "Pygments" = "pygments";
    "python-ldap" = "ldap";
  };

  # Final overrides to fix issues all the magic above cannot fix automatically
  overrides = self: super:

    # Short circuit circulare dependency issues in Plone by ignoring all dependencies
    super // (listToAttrs (map (name: {
      name = name;
      value = (getAttr name super).overridePythonAttrs(old: {
        pipInstallFlags = [ "--no-dependencies" ];
        propagatedBuildInputs = [];
        doCheck = false;
      });
    }) (filter (name: (! hasAttr name buildPython.pkgs)) requirementsNames)))

    # Restore dependencies for packages that build just fine (have no circular deps)
    // (listToAttrs (map (name: {
      name = name;
      value = (getAttr name super).overridePythonAttrs(old: {});
    }) (filter (name: elem name [
      "Automat"
      "SecretStorage"
      "Twisted"
      "docutils"
      "keyring"
      "persistent"
      "readme-renderer"
      "twine"
      "zope.component"
      "zope.container"
      "zope.deferredimport"
      "zope.deprecation"
      "zope.event"
      "zope.i18n"
      "zope.i18nmessageid"
      "zope.proxy"
      "zope.publisher"
      "zope.schema"
      "zope.security"
      "zope.traversing"
    ]) requirementsNames)))

    # Custom overrides for packages with various build issues
    // {
      # fix issue where nixpkgs drv is missing a dependency
      "sphinx" = super."sphinx".overridePythonAttrs(old: {
        propagatedBuildInputs = old.propagatedBuildInputs ++ [ self."packaging" ];
      });
      "pyflakes" = super."pyflakes".overridePythonAttrs(old: {
        doCheck = false;
      });
    };

in rec {

  # shell with 'buildout' for resolving requirements.txt with buildout
  buildout = mkShell {
    buildInputs = requirementsBuildInputs ++ buildInputs ++ [
      (pythonPackages.python.withPackages(ps: with ps; [
        (zc_buildout_nix.overridePythonAttrs(old: { postInstall = ""; }))
      ] ++ map (name: getAttr name ps) buildoutPythonPackages))
    ];
  };

  # shell with 'pip2nix' for resolving requirements.txt into requirements.nix
  pip2nix = mkShell {
    buildInputs = requirementsBuildInputs ++ [
      (getAttr
          ("python" + replaceStrings ["."] [""] pythonPackages.python.pythonVersion)
          pkgs.pip2nix)
      (pythonPackages.python.withPackages(ps: with ps; [
        (zc_buildout_nix.overridePythonAttrs(old: { postInstall = ""; }))
      ] ++ map (name: getAttr name ps) buildoutPythonPackages))
    ];
  };

  # shell with 'buildout' and all packages in requirements.txt
  shell = mkShell {
    buildInputs = requirementsBuildInputs ++ [
      (targetPython.withPackages(ps: with ps; [
        (zc_buildout_nix.overridePythonAttrs(old: { postInstall = ""; }))
      ] ++ map (name: getAttr name ps)
               (filter (x: x != "zc.buildout") requirementsNames)))
    ];
  };

  inherit buildPython targetPython toZConfig;

  plonePython = targetPython.withPackages(ps: map (name: getAttr name ps) requirementsNames);
}
