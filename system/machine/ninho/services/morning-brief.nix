# Daily 08:00 brief: LLM-summarized overnight events → ntfy.
# Pulls journal warnings, ZFS state, SMART temps/wear, failed services, etc.
# Feeds them to qwen3.6-27B-full via llama-swap; posts the summary to ntfy.
{
  config,
  lib,
  pkgs,
  constants,
  ...
}:
let
  inherit (constants) ports storage;

  briefTime = "08:00:00";
  model = "qwen3.6-27B-full";
  topic = "morning-brief";

  briefScript = pkgs.writeShellApplication {
    name = "morning-brief";
    runtimeInputs = with pkgs; [
      curl
      jq
      systemd
      zfs
      coreutils
      gnugrep
      gawk
      procps
    ];
    text = ''
            LLAMA_SWAP_URL="http://localhost:${toString ports.llamaswap}"
            NTFY_URL="http://localhost:${toString ports.ntfy}/${topic}"
            PROM_URL="http://localhost:${toString ports.prometheus}"
            MODEL="${model}"

            # ---- Signals ---------------------------------------------------------

            failed_services=$(systemctl --failed --no-legend --plain 2>/dev/null | head -20 || true)
            [ -z "$failed_services" ] && failed_services="(none)"

            # Recent warnings, excluding pure scrape noise from prometheus/exportarr
            journal_warnings=$(journalctl --since "24 hours ago" -p warning --no-pager -o cat 2>/dev/null \
              | grep -vE "(prometheus|exportarr)" \
              | head -50 || true)
            [ -z "$journal_warnings" ] && journal_warnings="(none)"

            noisy_units=$(journalctl --since "24 hours ago" -o json --no-pager 2>/dev/null \
              | jq -r '._SYSTEMD_UNIT // empty' \
              | sort | uniq -c | sort -rn | head -10 || true)

            zpool_status=$(zpool status 2>/dev/null | grep -E "(pool:|state:|errors:|scan:)" || true)

            smart_temps=$(curl -fsS "$PROM_URL/api/v1/query?query=smartctl_device_temperature%7Btemperature_type%3D%22current%22%7D" 2>/dev/null \
              | jq -r '.data.result[]? | "\(.metric.device): \(.value[1])°C"' \
              || echo "(prometheus query failed)")

            nvme_wear=$(curl -fsS "$PROM_URL/api/v1/query?query=smartctl_device_percentage_used" 2>/dev/null \
              | jq -r '.data.result[]? | "\(.metric.device): \(.value[1])%"' \
              || echo "(prometheus query failed)")

            disk_use=$(df -h / /storage 2>/dev/null | awk 'NR>1 {printf "%s: %s used / %s (%s)\n", $6, $3, $2, $5}' || true)

            load=$(cut -d' ' -f1-3 /proc/loadavg)
            mem_used=$(free -h | awk 'NR==2 {print $3 " / " $2}')

            gen_today=$(find /nix/var/nix/profiles -maxdepth 1 -name "system-*-link" -newermt "yesterday 00:00" 2>/dev/null | wc -l || echo 0)

            zfs_capacity=$(zfs list -H -o name,used,avail rpool storage 2>/dev/null \
              | awk '{printf "%-10s used=%s avail=%s\n", $1, $2, $3}' \
              || echo "(zfs list failed)")

            # Last 5 snapshots on the syncoid destination: staleness ≈ replication lag.
            syncoid_recent=$(zfs list -H -t snapshot -o name,creation -s creation -r storage/backup 2>/dev/null \
              | tail -5 \
              || true)
            [ -z "$syncoid_recent" ] && syncoid_recent="(no snapshots on storage/backup yet)"

            # Three most-recent Postgres logical dumps. Mtime drift > 24h = the
            # nightly dump timer is failing or the directory was rotated wrong.
            pg_dump_latest=$(find ${storage.data}/postgres-backups -maxdepth 1 -name '*.sql.zst' \
                -printf '%TY-%Tm-%Td %TH:%TM  %f  (%s bytes)\n' 2>/dev/null \
              | sort -r | head -3 \
              || true)
            [ -z "$pg_dump_latest" ] && pg_dump_latest="(no dumps yet)"

            # ---- Prompt ----------------------------------------------------------

            prompt="You are the morning briefer for ninho, a NixOS home server.
      Summarize overnight events in 8-12 lines max for the operator (bolt).
      Lead with anything needing attention. Be concise; don't restate raw data
      unless it's the interesting bit. End with exactly one line:
      SEVERITY=NORMAL|CONCERN|CRITICAL

      == Failed services ==
      $failed_services

      == Top 10 noisy units (24h) ==
      $noisy_units

      == Recent warnings (24h, exporter scrape noise filtered) ==
      $journal_warnings

      == ZFS ==
      $zpool_status

      == Drive temps ==
      $smart_temps

      == NVMe wear ==
      $nvme_wear

      == Disk usage ==
      $disk_use

      == ZFS capacity ==
      $zfs_capacity

      == Recent storage/backup snapshots (syncoid replication freshness) ==
      $syncoid_recent

      == Recent Postgres dumps ==
      $pg_dump_latest

      == Snapshot ==
      load: $load
      mem: $mem_used
      new generations since yesterday: $gen_today"

            # ---- LLM call --------------------------------------------------------

            # Both the prompt AND the assembled JSON payload go through tempfiles;
            # the previous `curl -d "$(jq …)"` form put the entire payload on the
            # shell command line, hitting ARG_MAX when journal warnings were
            # noisy (jq/curl: "Argument list too long").
            prompt_file=$(mktemp)
            payload_file=$(mktemp)
            response_file=$(mktemp)
            trap 'rm -f "$prompt_file" "$payload_file" "$response_file"' EXIT
            printf '%s' "$prompt" > "$prompt_file"

            jq -nc --arg m "$MODEL" --rawfile p "$prompt_file" \
              '{model: $m, messages: [{role: "user", content: $p}], max_tokens: 6000, temperature: 0.6}' \
              > "$payload_file"

            # Qwen3.6 reasoning lands in .reasoning_content; the user-facing answer
            # is in .content. With preserve_thinking=true it's easy to truncate before
            # any .content tokens are emitted, so we budget generously and fall back
            # to a clear error if .content is empty (jq // does not catch "").
            if curl -fsS -X POST "$LLAMA_SWAP_URL/v1/chat/completions" \
                 -H "Content-Type: application/json" \
                 --max-time 1500 \
                 --data-binary "@$payload_file" \
                 -o "$response_file"; then
              response=$(jq -r '.choices[0].message.content
                                | if (. // "") == "" then "Morning brief: LLM returned empty content (likely truncated by max_tokens)." else . end' \
                         "$response_file" 2>/dev/null \
                         || echo "Morning brief: LLM response parse error.")
            else
              response="Morning brief: LLM call failed; see \`journalctl -u morning-brief\`."
            fi

            # ---- ntfy priority by self-tagged severity ---------------------------

            priority=3
            if echo "$response" | grep -q "SEVERITY=CRITICAL"; then
              priority=5
            elif echo "$response" | grep -q "SEVERITY=CONCERN"; then
              priority=4
            fi

            # Trim to ntfy 4K body limit (margin for headers)
            body=$(printf '%s' "$response" | head -c 3500)

            curl -fsS -X POST "$NTFY_URL" \
              -H "Title: ninho morning brief $(date +%Y-%m-%d)" \
              -H "Priority: $priority" \
              -H "Tags: server,coffee" \
              --data "$body" >/dev/null
    '';
  };
in
{
  systemd.services.morning-brief = {
    description = "Daily LLM-summarized overnight brief";
    after = [
      "network-online.target"
      "llama-swap.service"
      "ntfy-sh.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${briefScript}/bin/morning-brief";
      User = "root"; # journalctl + zpool need root; tighten later if needed
      TimeoutStartSec = "30min"; # 27B cold start + reasoning on a long prompt
    };
  };

  systemd.timers.morning-brief = {
    description = "Fire morning brief at ${briefTime}";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* ${briefTime}";
      Persistent = true; # run on next boot if missed
      AccuracySec = "1m";
    };
  };
}
