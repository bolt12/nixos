# Panel constructors and grid layout for the Grafana dashboards.
#
# A dashboard is a list of rows, a row is a list of panels, and a panel comes
# from one of the constructors below. `dashboard` flows each row across
# Grafana's 24-column grid and numbers the panels, so a dashboard file states
# what to show and never where.
#
# House rules the constructors enforce:
#   - one unit per panel, so never two y-axes;
#   - status colours mean state and nothing else, and always sit next to a
#     word or a number that says the same thing;
#   - a number is neutral ink until it crosses a threshold;
#   - series colours come from a fixed palette in a fixed order.
{ lib }:
let
  datasource = {
    type = "prometheus";
    uid = "prometheus";
  };

  # Categorical palette for the dark theme. The order is what keeps
  # neighbouring series apart for colour-blind readers; do not reshuffle.
  palette = [
    "#3987e5" # blue
    "#d95926" # orange
    "#199e70" # aqua
    "#c98500" # yellow
    "#d55181" # magenta
    "#008300" # green
    "#9085e9" # violet
    "#e66767" # red
  ];

  status = {
    good = "#0ca30c";
    warning = "#fab219";
    serious = "#ec835a";
    critical = "#d03b3b";
    # Grafana's own ink colour: follows the theme.
    neutral = "text";
  };

  refIds = lib.stringToCharacters "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

  # A query and the legend its series get.
  q = expr: legend: {
    inherit expr;
    legendFormat = legend;
  };

  mkTargets =
    extra: targets:
    lib.imap0 (
      i: target:
      {
        inherit datasource;
        refId = lib.elemAt refIds i;
        editorMode = "code";
        range = true;
      }
      // extra
      // target
    ) targets;

  instant = {
    instant = true;
    range = false;
  };

  # [ [ null "text" ] [ 80 warning ] [ 90 critical ] ]
  steps = pairs: {
    mode = "absolute";
    steps = map (pair: {
      value = lib.elemAt pair 0;
      color = lib.elemAt pair 1;
    }) pairs;
  };

  thresholds = {
    # Fine until it climbs past `warn`, then `crit`.
    above =
      warn: crit:
      steps [
        [
          null
          status.neutral
        ]
        [
          warn
          status.warning
        ]
        [
          crit
          status.critical
        ]
      ];
    # Fine until it drops under `warn`, then `crit`.
    below =
      warn: crit:
      steps [
        [
          null
          status.critical
        ]
        [
          crit
          status.warning
        ]
        [
          warn
          status.neutral
        ]
      ];
    # Anything above zero is a problem.
    zero = steps [
      [
        null
        status.neutral
      ]
      [
        1
        status.critical
      ]
    ];
  };

  # { "1" = [ "UP" good ]; "0" = [ "DOWN" critical ]; }
  mapValues = table: [
    {
      type = "value";
      options = lib.mapAttrs (_: pair: {
        text = lib.elemAt pair 0;
        color = lib.elemAt pair 1;
      }) table;
    }
  ];

  mappings = {
    upDown = mapValues {
      "1" = [
        "UP"
        status.good
      ];
      "0" = [
        "DOWN"
        status.critical
      ];
    };
    okFailed = mapValues {
      "1" = [
        "OK"
        status.good
      ];
      "0" = [
        "FAILED"
        status.critical
      ];
    };
    # Codes as published by zfs_exporter.
    poolHealth = mapValues {
      "0" = [
        "ONLINE"
        status.good
      ];
      "1" = [
        "DEGRADED"
        status.warning
      ];
      "2" = [
        "FAULTED"
        status.critical
      ];
      "3" = [
        "OFFLINE"
        status.critical
      ];
      "4" = [
        "UNAVAIL"
        status.critical
      ];
      "5" = [
        "REMOVED"
        status.critical
      ];
      "6" = [
        "SUSPENDED"
        status.critical
      ];
    };
    yesNoBad = mapValues {
      "1" = [
        "YES"
        status.warning
      ];
      "0" = [
        "no"
        status.neutral
      ];
    };
  };

  fixedColor = color: {
    mode = "fixed";
    fixedColor = color;
  };

  colorOverride = matcher: color: {
    inherit matcher;
    properties = [
      {
        id = "color";
        value = fixedColor color;
      }
    ];
  };

  base =
    type:
    {
      title,
      desc ? null,
      w,
      h,
      ...
    }:
    {
      inherit
        type
        title
        w
        h
        datasource
        ;
    }
    // lib.optionalAttrs (desc != null) { description = desc; };

  reduceOptions = {
    calcs = [ "lastNotNull" ];
    fields = "";
    values = false;
  };

  # A headline number. `spark` adds its recent history behind it.
  stat =
    args@{
      expr ? null,
      targets ? [ (q expr "") ],
      unit ? "none",
      decimals ? null,
      w ? 4,
      h ? 4,
      limits ? null,
      states ? null,
      spark ? false,
      noValue ? null,
      # One tile per series, each showing its name.
      named ? false,
      # Show the series name as the content: for info metrics whose value is 1.
      nameOnly ? false,
      ...
    }:
    base "stat" (args // { inherit w h; })
    // {
      targets = mkTargets (lib.optionalAttrs (!spark) instant) targets;
      options = {
        inherit reduceOptions;
        colorMode = if limits != null || states != null then "value" else "none";
        graphMode = if spark then "area" else "none";
        textMode =
          if nameOnly then
            "name"
          else if named then
            "value_and_name"
          else
            "auto";
        justifyMode = "auto";
        orientation = "auto";
        wideLayout = true;
      };
      fieldConfig = {
        defaults = {
          inherit unit;
          color.mode = "thresholds";
          thresholds =
            if limits != null then
              limits
            else
              steps [
                [
                  null
                  status.neutral
                ]
              ];
        }
        // lib.optionalAttrs (decimals != null) { inherit decimals; }
        // lib.optionalAttrs (states != null) { mappings = states; }
        // lib.optionalAttrs (noValue != null) { inherit noValue; };
        overrides = [ ];
      };
    };

  # Change over time. A panel has one unit, so one y-axis.
  #
  # Colour: with `many`, series are whatever the query returns (services,
  # drives) and each is coloured by its name, so it keeps its colour when
  # others come and go. Otherwise every target is one known series and takes
  # the next palette slot. `names` pins palette slots to legend names when one
  # target returns a small known set.
  timeseries =
    args@{
      targets,
      unit ? "short",
      decimals ? null,
      w ? 12,
      h ? 8,
      min ? null,
      max ? null,
      stack ? false,
      many ? false,
      names ? [ ],
      limits ? null,
      interval ? null,
      # Bars, for totals per bucket (energy per day), where a line would
      # suggest values in between.
      bucketed ? false,
      ...
    }:
    let
      single = lib.length targets == 1 && !many && names == [ ];
    in
    base "timeseries" (args // { inherit w h; })
    // {
      targets = mkTargets { } targets;
      options = {
        legend = {
          showLegend = !single;
          displayMode = if many then "table" else "list";
          placement = if many then "right" else "bottom";
          calcs = lib.optionals many [
            "lastNotNull"
            "max"
          ];
        }
        // lib.optionalAttrs many {
          sortBy = "Last *";
          sortDesc = true;
        };
        tooltip = {
          mode = "multi";
          sort = "desc";
        };
      };
      fieldConfig = {
        defaults = {
          inherit unit;
          color = if many then { mode = "palette-classic-by-name"; } else fixedColor (lib.head palette);
          custom = {
            drawStyle = if bucketed then "bars" else "line";
            lineInterpolation = "linear";
            lineWidth = if many then 1 else 2;
            fillOpacity =
              if bucketed then
                70
              else if stack then
                35
              else if single then
                12
              else
                0;
            gradientMode = "none";
            showPoints = "never";
            spanNulls = false;
            axisPlacement = "auto";
            axisBorderShow = false;
            stacking = {
              mode = if stack then "normal" else "none";
              group = "A";
            };
            thresholdsStyle.mode = if limits != null then "line" else "off";
          };
        }
        // lib.optionalAttrs (decimals != null) { inherit decimals; }
        // lib.optionalAttrs (min != null) { inherit min; }
        // lib.optionalAttrs (max != null) { inherit max; }
        // lib.optionalAttrs (limits != null) { thresholds = limits; };
        overrides =
          if many then
            [ ]
          else if names != [ ] then
            lib.imap0 (
              i: name:
              colorOverride {
                id = "byName";
                options = name;
              } (lib.elemAt palette i)
            ) names
          else
            lib.imap0 (
              i: _:
              colorOverride {
                id = "byFrameRefID";
                options = lib.elemAt refIds i;
              } (lib.elemAt palette i)
            ) targets;
      };
    }
    // lib.optionalAttrs (interval != null) { inherit interval; };

  # Magnitude across a handful of things, or a ratio against its limit.
  bars =
    args@{
      targets,
      unit ? "short",
      decimals ? null,
      w ? 12,
      h ? 6,
      min ? 0,
      max ? null,
      limits ? null,
      ...
    }:
    base "bargauge" (args // { inherit w h; })
    // {
      targets = mkTargets instant targets;
      options = {
        inherit reduceOptions;
        displayMode = "basic";
        orientation = "horizontal";
        showUnfilled = true;
        valueMode = "text";
        namePlacement = "left";
        sizing = "auto";
        minVizHeight = 14;
        minVizWidth = 8;
      };
      fieldConfig = {
        defaults = {
          inherit unit min;
          color = if limits != null then { mode = "thresholds"; } else fixedColor (lib.head palette);
        }
        // lib.optionalAttrs (decimals != null) { inherit decimals; }
        // lib.optionalAttrs (max != null) { inherit max; }
        // lib.optionalAttrs (limits != null) {
          # A bar is a mark, not text: its fine state is the series colour.
          thresholds = limits // {
            steps = lib.imap0 (
              i: step:
              if i == 0 && step.color == status.neutral then step // { color = lib.head palette; } else step
            ) limits.steps;
          };
        };
        overrides = [ ];
      };
    };

  # One row per thing, one column per query. Every column query must be
  # aggregated `by (<key>)` so the rows line up.
  #
  # column: { name, expr, unit ? "none", decimals ?, limits ?, states ?,
  #           meter ? null }   meter = { min, max } draws the cell as a bar.
  table =
    args@{
      key,
      keyTitle ? key,
      columns,
      w ? 24,
      h ? 8,
      sortBy ? null,
      sortDesc ? true,
      ...
    }:
    let
      valueField = i: "Value #${lib.elemAt refIds i}";
      column = c: {
        matcher = {
          id = "byName";
          options = c.name;
        };
        properties = [
          {
            id = "unit";
            value = c.unit or "none";
          }
        ]
        ++ lib.optional (c ? decimals) {
          id = "decimals";
          value = c.decimals;
        }
        ++ lib.optionals (c ? limits) [
          {
            id = "thresholds";
            value = c.limits;
          }
          {
            id = "custom.cellOptions";
            value.type = "color-text";
          }
        ]
        ++ lib.optionals (c ? states) [
          {
            id = "mappings";
            value = c.states;
          }
          {
            id = "custom.cellOptions";
            value.type = "color-text";
          }
        ]
        ++ lib.optionals (c ? meter) [
          {
            id = "min";
            value = c.meter.min;
          }
          {
            id = "max";
            value = c.meter.max;
          }
          {
            id = "custom.cellOptions";
            value = {
              type = "gauge";
              mode = "basic";
              valueDisplayMode = "text";
            };
          }
          {
            id = "color";
            value = if c ? limits then { mode = "thresholds"; } else fixedColor (lib.head palette);
          }
        ];
      };
    in
    base "table" (args // { inherit w h; })
    // {
      targets = mkTargets (instant // { format = "table"; }) (map (c: q c.expr "") columns);
      transformations = [
        { id = "merge"; }
        {
          id = "organize";
          options = {
            excludeByName.Time = true;
            renameByName = {
              ${key} = keyTitle;
            }
            // lib.listToAttrs (lib.imap0 (i: c: lib.nameValuePair (valueField i) c.name) columns)
            # A table fed by one query names its column plain "Value".
            // lib.optionalAttrs (lib.length columns == 1) { Value = (lib.head columns).name; };
            indexByName = {
              ${key} = 0;
            }
            // lib.listToAttrs (lib.imap0 (i: _: lib.nameValuePair (valueField i) (i + 1)) columns);
          };
        }
      ];
      options = {
        showHeader = true;
        cellHeight = "sm";
        footer.show = false;
      }
      // lib.optionalAttrs (sortBy != null) {
        sortBy = [
          {
            displayName = sortBy;
            desc = sortDesc;
          }
        ];
      };
      fieldConfig = {
        defaults = {
          color.mode = "thresholds";
          thresholds = steps [
            [
              null
              status.neutral
            ]
          ];
          custom = {
            align = "auto";
            cellOptions.type = "auto";
            filterable = false;
          };
        };
        overrides = map column columns;
      };
    };

  # One row per series, with the listed labels as columns. For lists of
  # things that are described by their labels: health issues, failed units.
  labelTable =
    args@{
      expr,
      labels,
      # Column title for the sample value; null hides it.
      value ? null,
      unit ? "none",
      # { label = pixels; } for columns that should stay narrow.
      widths ? { },
      w ? 24,
      h ? 8,
      ...
    }:
    base "table" (args // { inherit w h; })
    // {
      targets = mkTargets (instant // { format = "table"; }) [ (q expr "") ];
      transformations = [
        {
          id = "filterFieldsByName";
          options.include.names = labels ++ lib.optional (value != null) "Value";
        }
        {
          id = "organize";
          options = {
            indexByName = lib.listToAttrs (lib.imap0 (i: label: lib.nameValuePair label i) labels);
            renameByName = lib.optionalAttrs (value != null) { Value = value; };
          };
        }
      ];
      options = {
        showHeader = true;
        cellHeight = "sm";
        footer.show = false;
      };
      fieldConfig = {
        defaults = {
          inherit unit;
          color.mode = "thresholds";
          thresholds = steps [
            [
              null
              status.neutral
            ]
          ];
          custom = {
            align = "auto";
            cellOptions = {
              type = "auto";
              wrapText = true;
            };
            filterable = false;
          };
        };
        overrides = lib.mapAttrsToList (label: width: {
          matcher = {
            id = "byName";
            options = label;
          };
          properties = [
            {
              id = "custom.width";
              value = width;
            }
          ];
        }) widths;
      };
    };

  # State over time, one lane per series. `states` names and colours them.
  timeline =
    args@{
      targets,
      states,
      w ? 24,
      h ? 10,
      ...
    }:
    base "state-timeline" (args // { inherit w h; })
    // {
      targets = mkTargets { } targets;
      # A lane per series is wide enough at one sample a minute.
      interval = "1m";
      options = {
        # Grafana 13.0 drops the state colours when it merges equal
        # neighbours, and unmerged cells look the same with no border.
        mergeValues = false;
        showValue = "never";
        alignValue = "left";
        rowHeight = 0.8;
        legend = {
          showLegend = true;
          displayMode = "list";
          placement = "bottom";
        };
        tooltip.mode = "single";
      };
      fieldConfig = {
        defaults = {
          color.mode = "thresholds";
          thresholds = steps [
            [
              null
              status.neutral
            ]
          ];
          mappings = states;
          custom = {
            lineWidth = 0;
            fillOpacity = 50;
          };
        };
        overrides = [ ];
      };
    };

  # Grafana's own list of alerts that are firing or about to.
  alerts =
    args@{
      w ? 24,
      h ? 8,
      ...
    }:
    removeAttrs (base "alertlist" (args // { inherit w h; })) [ "datasource" ]
    // {
      options = {
        viewMode = "list";
        groupMode = "default";
        maxItems = 30;
        sortOrder = 3;
        dashboardAlerts = false;
        alertName = "";
        alertInstanceLabelFilter = "";
        stateFilter = {
          firing = true;
          pending = true;
          error = true;
          noData = false;
          normal = false;
        };
      };
    };

  note =
    args@{
      content,
      w ? 24,
      h ? 3,
      ...
    }:
    removeAttrs (base "text" (
      args
      // {
        inherit w h;
        title = args.title or "";
      }
    )) [ "datasource" ]
    // {
      options = {
        mode = "markdown";
        inherit content;
      };
    };

  # Restricts a per-`by` graph to its n largest series over the whole visible
  # range. A bare topk() re-picks its members at every step, which draws
  # scattered dots where there should be lines.
  topOver =
    n: by: expr: overRange:
    "${expr} and on (${by}) topk(${toString n}, ${overRange})";

  # PromQL that more than one dashboard needs, written once.
  promql = rec {
    hoursSince = metric: "(time() - ${metric}) / 3600";
    daysSince = metric: "(time() - ${metric}) / 86400";

    cpuWatts = "sum(rate(node_rapl_package_joules_total[$__rate_interval]))";
    gpuWatts = "sum(nvidia_smi_power_draw_watts)";
    watts = "${cpuWatts} + ${gpuWatts}";

    cpuBusy = ''100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[$__rate_interval])))'';
    memoryUsed = "100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)";

    # hwmon names chips by bus address; the join picks one by driver name.
    sensor =
      driver: selector:
      "node_hwmon_temp_celsius${selector} * on (chip) group_left () node_hwmon_chip_names{chip_name=\"${driver}\"}";
    cpuTemperature = "max(${sensor "k10temp" ''{sensor="temp1"}''})";
    hddTemperature = ''smartctl_device_temperature{temperature_type="current",device!~"nvme.*"}'';

    # CPU cores and memory per systemd service or container, from cAdvisor.
    serviceCpuAt =
      window: at:
      ''sum by (service) (rate(container_cpu_usage_seconds_total{service!=""}[${window}]${at}))'';
    serviceCpu = window: serviceCpuAt window "";
    serviceMemory = ''sum by (service) (container_memory_working_set_bytes{service!=""})'';
    topServiceCpu =
      n: topOver n "service" (serviceCpu "$__rate_interval") (serviceCpuAt "$__range" " @ end()");
    topServiceMemory =
      n:
      topOver n "service" serviceMemory
        ''sum by (service) (avg_over_time(container_memory_working_set_bytes{service!=""}[$__range] @ end()))'';
  };

  row = title: panels: { inherit title panels; };

  # Flow each row left to right, wrapping at 24 columns.
  place =
    rows:
    let
      put =
        state: panel:
        let
          wrap = state.x + panel.w > 24;
          x = if wrap then 0 else state.x;
          y = if wrap then state.y + state.lineHeight else state.y;
        in
        state
        // {
          x = x + panel.w;
          inherit y;
          lineHeight = if wrap then panel.h else lib.max state.lineHeight panel.h;
          out = state.out ++ [
            (
              removeAttrs panel [
                "w"
                "h"
              ]
              // {
                gridPos = {
                  inherit x y;
                  inherit (panel) w h;
                };
              }
            )
          ];
        };
      section =
        state: r:
        let
          header = {
            type = "row";
            inherit (r) title;
            collapsed = false;
            panels = [ ];
            gridPos = {
              h = 1;
              w = 24;
              x = 0;
              inherit (state) y;
            };
          };
          start =
            if r.title == null then
              state
            else
              state
              // {
                y = state.y + 1;
                out = state.out ++ [ header ];
              };
          end = lib.foldl' put start r.panels;
        in
        end
        // {
          x = 0;
          y = end.y + end.lineHeight;
          lineHeight = 0;
        };
      placed =
        (lib.foldl' section {
          x = 0;
          y = 0;
          lineHeight = 0;
          out = [ ];
        } rows).out;
    in
    lib.imap1 (id: panel: panel // { inherit id; }) placed;

  # A dropdown filled from a label's values. Variables render in one row above
  # the panels, which is the only place a filter belongs.
  labelVar =
    {
      name,
      label ? name,
      metric,
      labelName,
      multi ? true,
      # Offer "All". Off where plotting every value at once is unreadable.
      all ? multi,
    }:
    {
      type = "query";
      inherit
        name
        label
        datasource
        multi
        ;
      query = {
        query = "label_values(${metric}, ${labelName})";
        refId = "StandardVariableQuery";
      };
      definition = "label_values(${metric}, ${labelName})";
      includeAll = all;
      allValue = ".*";
      current = { };
      refresh = 2;
      sort = 1;
    };

  textVar =
    {
      name,
      label ? name,
      default,
    }:
    {
      type = "textbox";
      inherit name label;
      query = default;
      current = {
        text = default;
        value = default;
      };
      options = [
        {
          selected = true;
          text = default;
          value = default;
        }
      ];
    };

  annotation = name: color: expr: text: {
    inherit name datasource expr;
    enable = true;
    iconColor = color;
    titleFormat = text;
    step = "1m";
  };

  dashboard =
    {
      uid,
      title,
      description ? "",
      rows,
      variables ? [ ],
      from ? "now-6h",
      refresh ? "1m",
    }:
    {
      inherit uid title description;
      tags = [ "ninho" ];
      schemaVersion = 39;
      version = 1;
      editable = false;
      # Hovering one panel draws the crosshair on all of them.
      graphTooltip = 1;
      timezone = "browser";
      inherit refresh;
      time = {
        inherit from;
        to = "now";
      };
      panels = place rows;
      templating.list = variables;
      annotations.list = [
        (annotation "Reboots" status.serious "changes(node_boot_time_seconds[2m]) > 0" "ninho rebooted")
        (annotation "NixOS switches" (lib.elemAt palette 6) "changes(nixos_generation[6m]) > 0"
          "Switched NixOS generation"
        )
      ];
      # Every dashboard in the suite, as a bar across the top.
      links = [
        {
          type = "dashboards";
          title = "ninho";
          tags = [ "ninho" ];
          asDropdown = false;
          includeVars = false;
          keepTime = true;
          targetBlank = false;
          icon = "external link";
        }
      ];
    };
in
{
  inherit
    alerts
    bars
    dashboard
    labelTable
    labelVar
    mappings
    mapValues
    note
    palette
    promql
    q
    row
    stat
    status
    steps
    table
    textVar
    thresholds
    timeline
    timeseries
    topOver
    ;
}
