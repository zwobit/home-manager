{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.programs.mbsync;
  accountCfg = config.accounts.mail.accounts;

  genAccountConfig = name: account: ''
    IMAPAccount ${name}
    Host ${account.imap.host}
    User ${account.userName}
    PassCmd "${toString account.passwordCommand}"
    SSLType IMAPS

    IMAPStore ${name}-remote
    Account ${name}

    MaildirStore ${name}-local
    Path ${account.maildir.path}/
    Inbox ${account.maildir.path}/Inbox
    Flatten .

    Channel ${name}
    Master :${name}-remote:
    Slave :${name}-local:
    Patterns ${toString account.mbsync.patterns}
    Create Both
    Expunge Both
    SyncState *
  '';

  genGroupConfig = name: channels: ''
    Group ${name}
    ${concatStringsSep "\n"
      (mapAttrsToList (n: boxes: "Channel ${n}:${concatStringsSep "," boxes}")
      channels)}
  '';

in

{
  options = {
    programs.mbsync = {
      enable = mkEnableOption "mbsync IMAP4 and Maildir mailbox synchronizer";

      groups = mkOption {
        type = types.attrsOf (types.attrsOf (types.listOf types.str));
        default = {};
        example = {
          inboxes = { account1 = [ "Inbox" ]; account2 = [ "Inbox" ]; };
        };
        description = ''
          Definition of groups.
        '';
      };
    };

    accounts.mail.accounts = mkOption {
      options = [
        {
          mbsync = {
            enable = mkEnableOption "synchronization using mbsync";

            patterns = mkOption {
              type = types.listOf types.str;
              default = [ "*" ];
              description = ''
                Pattern of mailboxes to synchronize.
              '';
            };
          };
        }
      ];
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.isync ];

    home.file.".mbsyncrc".text =
      let
        accounts =
          mapAttrsToList genAccountConfig
          (filterAttrs (name: account: account.mbsync.enable) accountCfg);

        groups = mapAttrsToList genGroupConfig cfg.groups;
      in
        concatStringsSep "\n\n" (accounts ++ groups);
  };
}
