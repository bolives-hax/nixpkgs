{
  config,
  options,
  pkgs,
  lib,
  ...
}:

with lib;

let

  cfg = config.services.rtorrent;
  opt = options.services.rtorrent;

in
{
  meta.maintainers = with lib.maintainers; [ thiagokokada ];

  options.services.rtorrent = {
    enable = mkEnableOption "rtorrent";

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/rtorrent";
      description = ''
        The directory where rtorrent stores its data files.
      '';
    };

    dataPermissions = mkOption {
      type = types.str;
      default = "0750";
      example = "0755";
      description = ''
        Unix Permissions in octal on the rtorrent directory.
      '';
    };

    downloadDir = mkOption {
      type = types.str;
      default = "${cfg.dataDir}/download";
      defaultText = literalExpression ''"''${config.${opt.dataDir}}/download"'';
      description = ''
        Where to put downloaded files.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "rtorrent";
      description = ''
        User account under which rtorrent runs.
      '';
    };

    group = mkOption {
      type = types.str;
      default = "rtorrent";
      description = ''
        Group under which rtorrent runs.
      '';
    };

    package = mkPackageOption pkgs "rtorrent" { };

    port = mkOption {
      type = types.port;
      default = 50000;
      description = ''
        The rtorrent port.
      '';
    };

    dht = {
      port = mkOption {
        type = types.port;
          description = ''
            The port on which the service will listen for DHT (Distributed Hash Table)
            peer exchanges. Set this to the UDP port used for discovering and connecting
            to other peers. Ensure the port is open in your firewall if you want
            external peers to connect.
          '';
          default = 6881;
      };
      mode = mkOption {
        ## May be set to `disable` (completely disable DHT), `off` (do not start DHT), `auto` (start and stop DHT as needed), or `on` (start DHT immediately).
        type = lib.types.enum [ "disable" "off" "auto" "on" ];
        description = ''
          Controls the DHT behavior. Options are:
          - `disable`: Completely disables DHT.
          - `off`: Does not start DHT.
          - `auto`: Starts and stops DHT as needed.
          - `on`: Starts DHT immediately.

          For more information, refer to the official rTorrent documentation:
          https://github.com/rakshasa/rtorrent/wiki/Using-DHT
        '';
        default = "off";
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to open the firewall for the port in {option}`services.rtorrent.port`.
      '';
    };

    rpcSocket = mkOption {
      type = types.str;
      readOnly = true;
      default = "/run/rtorrent/rpc.sock";
      description = ''
        RPC socket path.
      '';
    };

    configText = mkOption {
      type = types.lines;
      default = "";
      description = ''
        The content of {file}`rtorrent.rc`. The [modernized configuration template](https://rtorrent-docs.readthedocs.io/en/latest/cookbook.html#modernized-configuration-template) with the values specified in this module will be prepended using mkBefore. You can use mkForce to overwrite the config completely.
      '';
    };
  };

  config = mkIf cfg.enable {

    users.groups = mkIf (cfg.group == "rtorrent") {
      rtorrent = { };
    };

    users.users = mkIf (cfg.user == "rtorrent") {
      rtorrent = {
        group = cfg.group;
        shell = pkgs.bashInteractive;
        home = cfg.dataDir;
        description = "rtorrent Daemon user";
        isSystemUser = true;
      };
    };

    networking.firewall.allowedTCPPorts = mkIf (cfg.openFirewall) [ cfg.port ]
      ++ lib.lists.optional dhtEnabled cfg.dht.port;

    services.rtorrent.configText = let
        dhtEnabled = cfg.dht.mode != "off";
      in mkBefore ''
      # Instance layout (base paths)
      method.insert = cfg.basedir, private|const|string, (cat,"${cfg.dataDir}/")
      method.insert = cfg.watch,   private|const|string, (cat,(cfg.basedir),"watch/")
      method.insert = cfg.logs,    private|const|string, (cat,(cfg.basedir),"log/")
      method.insert = cfg.logfile, private|const|string, (cat,(cfg.logs),(system.time),".log")
      method.insert = cfg.rpcsock, private|const|string, (cat,"${cfg.rpcSocket}")

      # Create instance directories
      execute.throw = sh, -c, (cat, "mkdir -p ", (cfg.basedir), "/session ", (cfg.watch), " ", (cfg.logs))

      # Listening port for incoming peer traffic (fixed; you can also randomize it)
      network.port_range.set = ${toString cfg.port}-${toString cfg.port}
      network.port_random.set = no

      # Tracker-less torrent and UDP tracker support
      # (conservative settings for 'private' trackers, change for 'public')
      # dht.mode.set = disable
      #
      # <see at the end>
      #
      #dht.mode.set = auto
      # protocol.pex.set = no
      protocol.pex.set = yes
      trackers.use_udp.set = yes

      # Peer settings
      throttle.max_uploads.set = 100
      throttle.max_uploads.global.set = 300

      throttle.min_peers.normal.set = 1
      throttle.max_peers.normal.set = 50
      throttle.min_peers.seed.set = 1
      throttle.max_peers.seed.set = 50
      trackers.numwant.set = 100

      protocol.encryption.set = allow_incoming,try_outgoing,enable_retry

      # Limits for file handle resources, this is optimized for
      # an `ulimit` of 1024 (a common default). You MUST leave
      # a ceiling of handles reserved for rTorrent's internal needs!
      network.http.max_open.set = 512
      network.max_open_files.set = 32768

      network.max_open_sockets.set = 16384

      # Memory resource usage (increase if you have a large number of items loaded,
      # and/or the available resources to spend)
      pieces.memory.max.set = 5120M
      network.xmlrpc.size_limit.set = 16M

      # Basic operational settings (no need to change these)
      session.path.set = (cat, (cfg.basedir), "session/")
      directory.default.set = "${cfg.downloadDir}"
      log.execute = (cat, (cfg.logs), "execute.log")
      ##log.xmlrpc = (cat, (cfg.logs), "xmlrpc.log")
      execute.nothrow = sh, -c, (cat, "echo >", (session.path), "rtorrent.pid", " ", (system.pid))

      # Other operational settings (check & adapt)
      encoding.add = utf8
      system.umask.set = 0027
      system.cwd.set = (cfg.basedir)
      network.http.dns_cache_timeout.set = 600
      schedule2 = monitor_diskspace, 15, 60, ((close_low_diskspace, 1000M))
      schedule2 = session_save , 200 , 86400, ((session.save))

      # Watch directories (add more as you like, but use unique schedule names)
      #schedule2 = watch_start, 10, 10, ((load.start, (cat, (cfg.watch), "start/*.torrent")))
      #schedule2 = watch_load, 11, 10, ((load.normal, (cat, (cfg.watch), "load/*.torrent")))

      # Logging:
      #   Levels = critical error warn notice info debug
      #   Groups = connection_* dht_* peer_* rpc_* storage_* thread_* tracker_* torrent_*
      print = (cat, "Logging to ", (cfg.logfile))
      log.open_file = "log", (cfg.logfile)
      log.add_output = "info", "log"
      ##log.add_output = "tracker_debug", "log"

      # XMLRPC
      scgi_local = (cfg.rpcsock)
      schedule = scgi_group,0,0,"execute.nothrow=chown,\"torrentdata\",(cfg.rpcsock)"
      schedule = scgi_permission,0,0,"execute.nothrow=chmod,\"g+w,o=\",(cfg.rpcsock)"

      ${lib.optionalString dhtEnabled "dht.port.set = ${toSString cfg.dht.port}"}
      dht.mode.set = ${cfg.dht.mode}

      # added: unlimited global rates for 1Gbps connection
      throttle.global_down.max_rate.set_kb = 0
      throttle.global_up.max_rate.set_kb = 0

      # added: bigger TCP buffers for 1Gbps throughput
      network.send_buffer.size.set = 4M
      network.receive_buffer.size.set = 4M

      # added: skip hash check on completion — massive I/O savings on HDD
      pieces.hash.on_completion.set = no

      # added: disable preallocation — ZFS COW makes it wasteful
      system.file.allocate.set = 0
    '';

    systemd = {
      services = {
        rtorrent =
          let
            rtorrentConfigFile = pkgs.writeText "rtorrent.rc" cfg.configText;
          in
          {
            description = "rTorrent system service";
            after = [ "network.target" ];
            path = [
              cfg.package
              pkgs.bash
            ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              User = cfg.user;
              Group = cfg.group;
              Type = "simple";
              Restart = "on-failure";
              WorkingDirectory = cfg.dataDir;
              ExecStartPre = ''${pkgs.bash}/bin/bash -c "if test -e ${cfg.dataDir}/session/rtorrent.lock && test -z $(${pkgs.procps}/bin/pidof rtorrent); then rm -f ${cfg.dataDir}/session/rtorrent.lock; fi"'';
              ExecStart = "${cfg.package}/bin/rtorrent -n -o system.daemon.set=true -o import=${rtorrentConfigFile}";
              RuntimeDirectory = "rtorrent";
              RuntimeDirectoryMode = 750;

              CapabilityBoundingSet = [ "" ];
              LockPersonality = true;
              NoNewPrivileges = true;
              PrivateDevices = true;
              PrivateTmp = true;
              ProtectClock = true;
              ProtectControlGroups = true;
              # If the default user is changed, there is a good chance that they
              # want to store data in e.g.: $HOME directory
              # Relax hardening in this case
              ProtectHome = lib.mkIf (cfg.user == "rtorrent") true;
              ProtectHostname = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              ProtectProc = "invisible";
              ProtectSystem = "full";
              RestrictAddressFamilies = [
                "AF_UNIX"
                "AF_INET"
                "AF_INET6"
              ];
              RestrictNamespaces = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              SystemCallArchitectures = "native";
              SystemCallFilter = [
                "@system-service"
                "~@privileged"
              ];
            };
          };
      };

      tmpfiles.rules = [ "d '${cfg.dataDir}' ${cfg.dataPermissions} ${cfg.user} ${cfg.group} -" ];
    };
  };
}
