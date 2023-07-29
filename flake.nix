{
  description = "Nix flake for the odbc_scanner duckdb extension";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    odbc-drivers.url = "github:rupurt/odbc-drivers-nix";
  };

  outputs = {
    flake-utils,
    odbc-drivers,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    outputs = flake-utils.lib.eachSystem systems (system: let
      # use old version of nix packages that builds against glibc 2.35
      pkgs =
        import (builtins.fetchGit {
          name = "nixpkgs-with-glibc-2.35-224";
          url = "https://github.com/nixos/nixpkgs";
          ref = "refs/heads/nixpkgs-unstable";
          rev = "8ad5e8132c5dcf977e308e7bf5517cc6cc0bf7d8";
        }) {
          inherit system;
          overlays = [
            odbc-drivers.overlay
          ];
        };
      stdenv = pkgs.llvmPackages_15.stdenv;

      # Define a helper function to conditionally include the db2-odbc-driver package as not all arch are supported
      isAarch64 = system == "aarch64-linux" || system == "aarch64-darwin";

      getDb2OdbcDriver = if isAarch64 then null else pkgs.db2-odbc-driver;
      getDb2OdbcDriverLibFile = if stdenv.isDarwin then "libdb2.dylib" else "libdb2.so";
      getDb2OdbcDriverPath = if isAarch64 then "" else "DB2_DRIVER_PATH=${getDb2OdbcDriver}/lib/${getDb2OdbcDriverLibFile}";


    in rec {
      # packages exported by the flake
      packages = {
        db2-odbc-driver = if getDb2OdbcDriver != null then getDb2OdbcDriver {} else null;
        postgres-odbc-driver = pkgs.postgres-odbc-driver {};
      };

      # nix run
      apps = {
        generate-dot-clangd = {
          type = "app";
          program = toString (pkgs.writeScript "generate-dot-clangd" ''
            UNIX_ODBC_DIR=${pkgs.unixODBC} \
              envsubst < ./templates/.clangd.template > .clangd
          '');
        };
        generate-dot-clang-format = {
          type = "app";
          program = toString (pkgs.writeScript "generate-dot-clang-format" ''
            cp ./templates/.clang-format.template .clang-format
          '');
        };
        generate-odbc-ini = {
          type = "app";
          program = toString (pkgs.writeScript "generate-odbc-ini" ''
            cp ./templates/.odbc.ini.template .odbc.ini
          '');
        };
        generate-odbcinst-ini = {
          type = "app";
          program = toString (pkgs.writeScript "generate-odbcinst-ini" ''
            ${getDb2OdbcDriverPath} \
            POSTGRES_DRIVER_PATH=${packages.postgres-odbc-driver}/lib/psqlodbca.so \
              envsubst < ./templates/.odbcinst.ini.template > .odbcinst.ini
          '');
        };
        ls-odbc-driver-paths = {
          type = "app";
          program = toString (pkgs.writeScript "ls-odbc-driver-paths" ''
            ${if isAarch64 then "" else "echo \"db2 ${getDb2OdbcDriverPath}"}
            echo "postgres ${packages.postgres-odbc-driver}/lib/psqlodbca.so"
          '');
        };
        load-db2-schema = {
          type = "app";
          program = toString (pkgs.writeScript "load-db2-schema" ''
            echo "TODO: load db2 schema"
          '');
        };
        test = {
          type = "app";
          program = toString (pkgs.writeScript "test" ''
            export PATH="${pkgs.lib.makeBinPath (
              with pkgs; [
                git
                gnumake
                cmake
                ninja
                openssl
                getDb2OdbcDriver
                packages.postgres-odbc-driver
              ]
            )}:$PATH"
            export CC=${stdenv.cc}/bin/clang
            export CXX=${stdenv.cc}/bin/clang++

            make \
              GEN=ninja \
              ODBCSYSINI=$PWD \
              ODBCINSTINI=.odbcinst.ini \
              ODBCINI=$PWD/.odbc.ini \
              test CLIENT_FLAGS="-DODBC_CONFIG=${pkgs.unixODBC}/bin/odbc_config"
          '');
        };
        build = {
          type = "app";
          program = toString (pkgs.writeScript "build" ''
            export PATH="${pkgs.lib.makeBinPath (
              with pkgs; [
                git
                gnumake
                cmake
                ninja
                openssl
                getDb2OdbcDriver
                packages.postgres-odbc-driver
              ]
            )}:$PATH"
            export CC=${stdenv.cc}/bin/clang
            export CXX=${stdenv.cc}/bin/clang++

            make \
              GEN=ninja \
              CLIENT_FLAGS="-DODBC_CONFIG=${pkgs.unixODBC}/bin/odbc_config"
          '');
        };
        default = apps.build;
      };

      # nix fmt
      formatter = pkgs.alejandra;

      # nix develop -c $SHELL
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.git
          pkgs.gnumake
          pkgs.cmake
          # faster cmake builds
          pkgs.ninja
          # clangd lsp
          pkgs.llvmPackages_15.bintools
          pkgs.llvmPackages_15.clang
          pkgs.envsubst
          pkgs.openssl
          pkgs.unixODBC
          # psql cli
          pkgs.postgresql_15
          getDb2OdbcDriver
          packages.postgres-odbc-driver
        ];
      };
    });
  in
    outputs;
}
