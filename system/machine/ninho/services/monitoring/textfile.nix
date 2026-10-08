# Node exporter textfile collectors: facts that no exporter publishes.
#
# Each collector is a program that prints metrics; a small loop service runs it
# and swaps the result into place. A loop, not a timer, so the journal does not
# get two lines per run.
{
  config,
  constants,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  dir = "/var/lib/node-exporter-textfile";

  collectors = {
    # Which generation is running, how many are kept, and whether the booted
    # kernel is still the one the current system wants.
    nixos = {
      interval = 300;
      runtimeInputs = [ pkgs.findutils ];
      text = ''
        profiles=/nix/var/nix/profiles
        link=$(readlink "$profiles/system")
        generation=''${link#system-}
        generation=''${generation%-link}

        reboot=0
        for part in kernel initrd kernel-modules; do
          if [ "$(readlink -f "/run/booted-system/$part")" != "$(readlink -f "/run/current-system/$part")" ]; then
            reboot=1
          fi
        done

        cat <<EOF
        # HELP nixos_generation Number of the active system generation.
        # TYPE nixos_generation gauge
        nixos_generation $generation
        # HELP nixos_generation_created_timestamp_seconds When the active generation was built.
        # TYPE nixos_generation_created_timestamp_seconds gauge
        nixos_generation_created_timestamp_seconds $(stat -c %Y "$profiles/$link")
        # HELP nixos_generations Number of system generations kept on disk.
        # TYPE nixos_generations gauge
        nixos_generations $(find "$profiles" -maxdepth 1 -name 'system-*-link' | wc -l)
        # HELP nixos_reboot_required 1 when the booted kernel, initrd or modules differ from the current system.
        # TYPE nixos_reboot_required gauge
        nixos_reboot_required $reboot
        EOF
      '';
    };

    # Snapshot count, age and space per dataset. Comparing the newest
    # snapshot under storage/backup with its source is the replication check.
    zfs-snapshots = {
      interval = 300;
      runtimeInputs = [
        config.boot.zfs.package
        pkgs.gawk
      ];
      text = ''
        zfs list -H -p -t snapshot -o name,creation | awk -F'\t' '
          {
            split($1, part, "@"); d = part[1]; t = $2 + 0
            count[d]++
            if (!(d in newest) || t > newest[d]) newest[d] = t
            if (!(d in oldest) || t < oldest[d]) oldest[d] = t
          }
          END {
            print "# HELP zfs_snapshot_count Snapshots held per dataset."
            print "# TYPE zfs_snapshot_count gauge"
            for (d in count) printf "zfs_snapshot_count{dataset=\"%s\"} %d\n", d, count[d]
            print "# HELP zfs_snapshot_newest_timestamp_seconds Creation time of the newest snapshot."
            print "# TYPE zfs_snapshot_newest_timestamp_seconds gauge"
            for (d in newest) printf "zfs_snapshot_newest_timestamp_seconds{dataset=\"%s\"} %d\n", d, newest[d]
            print "# HELP zfs_snapshot_oldest_timestamp_seconds Creation time of the oldest snapshot."
            print "# TYPE zfs_snapshot_oldest_timestamp_seconds gauge"
            for (d in oldest) printf "zfs_snapshot_oldest_timestamp_seconds{dataset=\"%s\"} %d\n", d, oldest[d]
          }'

        echo "# HELP zfs_dataset_used_by_snapshots_bytes Space that would be freed by destroying every snapshot of the dataset."
        echo "# TYPE zfs_dataset_used_by_snapshots_bytes gauge"
        zfs list -H -p -t filesystem -o name,usedbysnapshots \
          | awk -F'\t' '{ printf "zfs_dataset_used_by_snapshots_bytes{dataset=\"%s\"} %d\n", $1, $2 }'
      '';
    };

    # The nightly pg_dumpall moves its file into place only on success, so the
    # newest file's mtime is the time of the last good backup.
    postgres-backup = {
      interval = 300;
      runtimeInputs = [
        pkgs.findutils
        pkgs.gawk
      ];
      text = ''
        find ${constants.storage.data}/postgres-backups -maxdepth 1 -name '*.sql.zst' -printf '%T@ %s\n' \
          | sort -rn \
          | awk '
              NR == 1 { newest = $1; size = $2 }
              END {
                print "# HELP postgres_backup_count Logical dumps kept on disk."
                print "# TYPE postgres_backup_count gauge"
                printf "postgres_backup_count %d\n", NR
                if (NR > 0) {
                  print "# HELP postgres_backup_newest_timestamp_seconds Completion time of the newest dump."
                  print "# TYPE postgres_backup_newest_timestamp_seconds gauge"
                  printf "postgres_backup_newest_timestamp_seconds %d\n", newest
                  print "# HELP postgres_backup_newest_size_bytes Compressed size of the newest dump."
                  print "# TYPE postgres_backup_newest_size_bytes gauge"
                  printf "postgres_backup_newest_size_bytes %d\n", size
                }
              }'
      '';
    };

    # GPU memory by tenant. nvidia-smi reports it per pid; the pid's cgroup
    # says which unit or container owns it, which is a label that does not
    # change every time the process restarts.
    gpu-tenants = {
      interval = 15;
      runtimeInputs = [
        config.hardware.nvidia.package.bin
        config.virtualisation.docker.package
      ];
      text = ''
        declare -A used
        while read -r _gpu pid _type mem _rest; do
          [[ $pid =~ ^[0-9]+$ && $mem =~ ^[0-9]+$ ]] || continue
          cgroup=$(head -n1 "/proc/$pid/cgroup" 2>/dev/null) || continue
          unit=''${cgroup##*/}
          case $unit in
            docker-*.scope)
              id=''${unit#docker-}
              tenant=$(docker inspect --format '{{.Name}}' "''${id%.scope}" 2>/dev/null) || tenant=$unit
              tenant=''${tenant#/}
              ;;
            session-*.scope)
              # A login session holds many unrelated programs; name the program.
              tenant=$(cat "/proc/$pid/comm" 2>/dev/null) || tenant=session
              ;;
            *)
              tenant=''${unit%.service}
              tenant=''${tenant%.scope}
              ;;
          esac
          tenant=''${tenant//[^A-Za-z0-9_.:@-]/_}
          used[$tenant]=$((''${used[$tenant]:-0} + mem))
        done < <(nvidia-smi pmon -c 1 -s m)

        echo "# HELP nvidia_tenant_memory_used_bytes GPU memory held, by owning unit, container or program."
        echo "# TYPE nvidia_tenant_memory_used_bytes gauge"
        for tenant in "''${!used[@]}"; do
          printf 'nvidia_tenant_memory_used_bytes{tenant="%s"} %d\n' "$tenant" $((''${used[$tenant]} * 1048576))
        done
      '';
    };
  };

  program =
    name: collector:
    pkgs.writeShellApplication {
      name = "textfile-${name}";
      runtimeInputs = [ pkgs.coreutils ] ++ collector.runtimeInputs;
      inherit (collector) text;
    };

  # A failed run keeps the previous file, so the exporter's own
  # node_textfile_mtime_seconds shows the collector going stale.
  service = name: collector: {
    description = "Textfile collector: ${name}";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 30;
    };
    script = ''
      while true; do
        tmp=$(mktemp ${dir}/${name}.prom.XXXXXX)
        if ${lib.getExe (program name collector)} > "$tmp"; then
          chmod 0644 "$tmp"
          mv "$tmp" ${dir}/${name}.prom
        else
          rm -f "$tmp"
        fi
        sleep ${toString collector.interval}
      done
    '';
  };

  # Known at build time, so no collector: these describe the system closure
  # this file is part of. `self` is left out so that a commit which changes no
  # derivation still produces the same system.
  static = pkgs.writeText "nixos-static.prom" ''
    # HELP nixos_system_info Version of the running system.
    # TYPE nixos_system_info gauge
    nixos_system_info{version="${config.system.nixos.version}",kernel="${config.boot.kernelPackages.kernel.version}"} 1
    # HELP nixos_flake_input_last_modified_seconds Commit time of each flake input the running system was built from.
    # TYPE nixos_flake_input_last_modified_seconds gauge
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: input:
        ''nixos_flake_input_last_modified_seconds{input="${name}"} ${toString input.lastModified}''
      ) (lib.filterAttrs (_: input: input ? lastModified) (removeAttrs inputs [ "self" ]))
    )}
  '';
in
{
  services.prometheus.exporters.node.extraFlags = [ "--collector.textfile.directory=${dir}" ];

  systemd.tmpfiles.rules = [
    "d ${dir} 0755 root root -"
    "L+ ${dir}/nixos-static.prom - - - - ${static}"
  ];

  systemd.services = lib.mapAttrs' (
    name: collector: lib.nameValuePair "textfile-${name}" (service name collector)
  ) collectors;
}
