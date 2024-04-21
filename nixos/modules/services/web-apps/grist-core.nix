{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    literalExpression
    types
    mkOption
    mkPackageOption
    mkEnableOption
    mkIf
    ;

  cfg = config.services.grist-core;
in
{
  meta.maintainers = with lib.maintainers; [ scandiravian ];

  options.services.grist-core = {
    enable = mkEnableOption "Grist core";

    package = mkPackageOption pkgs "grist-core" { };

    user = mkOption {
      type = types.str;
      default = "grist-core";
      description = "User account under which grist-core runs.";
    };

    group = mkOption {
      type = types.str;
      default = "grist-core";
      description = "Group under which grist-core runs.";
    };

    pythonEnv = mkOption {
      internal = true;
      type = types.package;
      default = pkgs.grist-core.pythonEnv;
      example = literalExpression ''
        pkgs.python3.withPackages (ps: with ps; [
          astroid
          asttokens
          chardet
          et-xmlfile
          executing
          friendly-traceback
          iso8601
          lazy-object-proxy
          openpyxl
          phonenumbers
          pure-eval
          python-dateutil
          roman
          six
          sortedcontainers
          stack-data
          typing-extensions
          unittest-xml-reporting
          wrapt
        ]);
      '';
    };

    settings = mkOption {
      type =
        with types;
        submodule {
          freeformType = attrsOf str;

          options = {
            GRIST_DATA_DIR = mkOption {
              type = str;
              default = "/var/lib/grist-core/docs";
            };

            GRIST_INST_DIR = mkOption {
              type = str;
              default = "/var/lib/grist-core";
            };

            GRIST_USER_ROOT = mkOption {
              type = str;
              default = "/var/lib/grist-core";
            };

            GRIST_SANDBOX_FLAVOR = mkOption {
              type = str;
              default = "gvisor";
            };

            GVISOR_FLAGS = mkOption {
              type = str;
              default = "--rootless";
            };

            GVISOR_AVAILABLE = mkOption {
              type = str;
              default = "1";
              readOnly = true;
            };

            TYPEORM_DATABASE = mkOption {
              type = str;
              default = "/var/lib/grist-core/db.sqlite";
            };

            TYPEORM_TYPE = mkOption {
              type = enum [
                "sqlite"
                "postgres"
              ];
              default = "sqlite";
            };
          };
        };
      default = { };
      example = {
        GRIST_DEFAULT_EMAIL = "example@example.com";
      };
      description = ''
        Environment variables used for Grist.
        See [](https://github.com/gristlabs/grist-core/tree/v1.3.2?tab=readme-ov-file#environment-variables)
        for available environment variables.
      '';
    };

    environmentFiles = mkOption {
      type = with types; listOf path;
      default = [ ];
      description = ''
        Environment files for secrets.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.settings.GRIST_SANDBOX_FLAVOR == "gvisor";
        message = "Only gvisor is currently supported for grist, but 'GRIST_SANDBOX_FLAVOR' is set to '${cfg.settings.GRIST_SANDBOX_FLAVOR}'";
      }
    ];

    systemd.services.grist-core = {
      description = "Grist Core";

      after = [
        "network.target"
      ] ++ lib.optional (cfg.settings.TYPEORM_TYPE == "postgres") "postgresql.service";

      wants = [ "network.target" ];

      path = [
        pkgs.gvisor
        cfg.pythonEnv
      ];

      environment = cfg.settings;

      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        Restart = "always";
        DynamicUser = true;

        RuntimeDirectory = "grist-core";
        StateDirectory = "grist-core";

        ProtectHome = true;
        ProtectSystem = "strict";
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        NoNewPrivileges = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        PrivateMounts = true;

        EnvironmentFile = cfg.environmentFiles;
      };

      wantedBy = [ "multi-user.target" ];
    };
  };
}
