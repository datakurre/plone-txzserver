# Plone expects Zope2 to load ``./etc/site.zcml`` from ``instancehome``.

{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
  name = "instancehome";
  builder = builtins.toFile "builder.sh" ''
    source $stdenv/setup
    mkdir -p $out/etc
    cat > $out/etc/site.zcml << EOF
    <configure
        xmlns="http://namespaces.zope.org/zope"
        xmlns:meta="http://namespaces.zope.org/meta"
        xmlns:plone="http://namespaces.plone.org/plone"
        xmlns:five="http://namespaces.zope.org/five">

      <include package="Products.Five" />
      <meta:redefinePermission from="zope2.Public" to="zope.Public" />
      <meta:provides feature="disable-autoinclude" />

      <five:loadProducts file="meta.zcml"/>
      <five:loadProducts />
      <five:loadProductsOverrides />

      <include package="plonetheme.barceloneta" />
      <include package="collective.taskqueue" />
      <include package="collective.wsevents" />

      <securityPolicy
          component="AccessControl.security.SecurityPolicy" />

    </configure>
    EOF
  '';
}
