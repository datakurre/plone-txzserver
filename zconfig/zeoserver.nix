{ pkgs ? import <nixpkgs> {}
, generators ? import ./generators.nix {}
, var ? "$(PWD)/var"
}:

let configuration = generators.toZConfig {

  zeo = {
    address = "$(PLONE_ZEOSERVER_ADDRESS)";
    read-only = false;
    invalidation-queue-size = 100;
    pid-filename = "/tmp/zeoserver.pid";
  };

  filestorage = {
    "1" = {
      path = "${var}/filestorage/Data.fs";
      blob-dir = "${var}/blostorage";
    };
  };

  eventlog = {
    level = "INFO";
    logfile = {
      stdout = {
        path = "STDOUT";
        format = "%(levelname)s %(asctime)s %(message)s";
      };
    };
  };

}; in

pkgs.stdenv.mkDerivation {
  name = "zeo.conf";
  builder = builtins.toFile "builder.sh" ''
    source $stdenv/setup
    cat > $out << EOF
    $configuration
    EOF
  '';
  inherit configuration;
}
