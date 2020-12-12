{ pkgs ? import <nixpkgs> {}
, generators ? import ./generators.nix {}
, instancehome ? import ./instancehome.nix {}
, var ? "$(PWD)/var"
}:

let configuration = generators.toZConfig {

  effective-user = "$(USER)";
  clienthome = "${var}";
  debug-mode = false;
  default-zpublisher-encoding = "utf-8";
  enable-product-installation = false;
  http-header-max-length = 8192;
  instancehome = "${instancehome}";
  lock-filename = "/tmp/instance.lock";
  pid-filename = "/tmp/instance.pid";
  python-check-interval = 1000;
  security-policy-implementation = "C";
  verbose-security = false;
  zserver-threads = 2;

  environment = {
    CHAMELEON_CACHE = "/tmp";
    PTS_LANGUAGES = [ "en" "fi" ];
    TMP = "/tmp";
    zope_i18n_allowed_languages = [ "en" "fi" ];
  };

  warnfilter = {
    action = "ignore";
    category = "DeprecationWarning";
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

  logger = {
    access = {
      level = "INFO";
      logfile = {
        stdout = {
          path = "STDOUT";
          format = "%(levelname)s %(asctime)s %(message)s";
        };
      };
    };
  };

  http-server = {
    address = "$(PLONE_HTTP_PORT)";
    fast-listen = true;
  };

  zodb_db = {
    main = {
      cache-size = 40000;
      mount-point = "/";
      blobstorage = {
        blob-dir = "${var}/blostorage";
        filestorage = {
          path = "${var}/filestorage/Data.fs";
        };
      };
    };
    temporary = {
      temporarystorage = {
        name = "temporary storage for sessioning";
      };
      mount-point = "/temp_folder";
      container-class = "Products.TemporaryFolder.TemporaryContainer";
    };
  };
}; in

pkgs.stdenv.mkDerivation {
  name = "zope.conf";
  builder = builtins.toFile "builder.sh" ''
    source $stdenv/setup
    cat > $out << EOF
    $configuration
    EOF
  '';
  inherit configuration;
}
