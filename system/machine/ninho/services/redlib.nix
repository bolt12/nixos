# Redlib: privacy-respecting Reddit frontend. JS-free, no tracking.
# Anonymous-only (no Reddit login); subscriptions persist via cookie or URL.
# Bound on 0.0.0.0 so it's reachable from LAN and the WireGuard VPN.
#
# The redlib package is pinned to upstream HEAD via the overlay in
# `system/machine/ninho/package-overrides.nix` (see comment there for the
# bump procedure).
{
  pkgs,
  lib,
  constants,
  ...
}:
let
  inherit (constants) network ports;
  redlibBase = "http://${network.ninho.vpnIp}:${toString ports.redlib}";

  # Subscriptions pre-populated into every fresh visitor's cookie. Sorted
  # case-insensitively for findability: add/remove freely. Reddit subreddit
  # names are case-insensitive in URLs but redlib preserves casing in the
  # cookie, so keep the user's preferred capitalization.
  subreddits = [
    "agda"
    "Aiabock"
    "alloyanalyzer"
    "Android"
    "anime"
    "anime_titties"
    "archlinux"
    "AskCulinary"
    "AskFoodHistorians"
    "AskReddit"
    "askscience"
    "braga"
    "Breadit"
    "Canning"
    "Charcuterie"
    "cheesemaking"
    "chemistry"
    "ClaudeCode"
    "coding"
    "ComentariosMelhores"
    "compsci"
    "CookbookLovers"
    "Coq"
    "dailyprogrammer"
    "DataHoarder"
    "dependent_types"
    "devpt"
    "DotA2"
    "EarthPorn"
    "emacs"
    "explainlikeimfive"
    "fermentation"
    "fuckcars"
    "functionalprogramming"
    "GameDeals"
    "gaming"
    "GifRecipes"
    "haskell"
    "hiphopheads"
    "homeassistant"
    "homelab"
    "HomeServer"
    "HotPeppers"
    "HunterXHunter"
    "Idris"
    "investing"
    "JapaneseFood"
    "jutaku"
    "KendrickLamar"
    "Koji"
    "leanprover"
    "LifeProTips"
    "LiminalSpace"
    "linux"
    "lisboa"
    "literaciafinanceira"
    "LocalLLM"
    "MachineLearning"
    "math"
    "menoscarros"
    "NaBoaChavaloRetardado"
    "neapolitanpizza"
    "news"
    "NixOS"
    "OutOfTheLoop"
    "portugal"
    "PORTUGALCARALHO"
    "privacy"
    "programming"
    "ProgrammingLanguages"
    "ramen"
    "rust"
    "Sake"
    "science"
    "selfhosted"
    "Sourdough"
    "sousvide"
    "Sprinting"
    "SteamDeck"
    "Supernote"
    "sysadmin"
    "todayilearned"
    "trackandfield"
    "trees"
    "TudoCasa"
    "typetheory"
    "unixporn"
    "urbandesign"
    "urbanplanning"
    "vim"
    "woahdude"
    "WTF"
    "yakitori_ya"
    "yogurtmaking"
    "Zettelkasten"
    "zfs"
  ];

  # One-shot migration: rewrite Miniflux feed/site URLs from any reddit.com
  # host to redlib. Idempotent: re-running matches no rows. Run as:
  #   sudo migrate-miniflux-to-redlib
  migrateScript = pkgs.writeShellApplication {
    name = "migrate-miniflux-to-redlib";
    runtimeInputs = [ pkgs.postgresql ];
    text = ''
      REDLIB_BASE="${redlibBase}"
      echo "Rewriting reddit.com URLs in miniflux DB → $REDLIB_BASE"
      sudo -u miniflux psql -d miniflux -v ON_ERROR_STOP=1 <<SQL
        \echo === Feeds matching reddit.com (before) ===
        SELECT id, title, feed_url FROM feeds
        WHERE feed_url ~ '^https?://([a-z]+\.)?reddit\.com';

        UPDATE feeds
        SET feed_url = regexp_replace(feed_url,
              '^https?://([a-z]+\.)?reddit\.com', '$REDLIB_BASE'),
            site_url = regexp_replace(site_url,
              '^https?://([a-z]+\.)?reddit\.com', '$REDLIB_BASE')
        WHERE feed_url ~ '^https?://([a-z]+\.)?reddit\.com';

        \echo === Feeds after rewrite ===
        SELECT id, title, feed_url FROM feeds
        WHERE feed_url LIKE '$REDLIB_BASE%';
      SQL
      echo "Done. Trigger a refresh in Miniflux UI to verify."
    '';
  };
in
{
  environment.systemPackages = [ migrateScript ];

  services.redlib = {
    enable = true;
    address = "0.0.0.0";
    port = ports.redlib;
    openFirewall = true;

    # Settings become REDLIB_* environment variables on the systemd unit;
    # bools render as on/off via the upstream module.
    settings = {
      REDLIB_DEFAULT_THEME = "gruvbox";
      REDLIB_DEFAULT_FRONT_PAGE = "popular";
      REDLIB_DEFAULT_LAYOUT = "card";
      REDLIB_DEFAULT_POST_SORT = "hot";
      REDLIB_DEFAULT_COMMENT_SORT = "confidence";
      REDLIB_DEFAULT_BLUR_NSFW = true;
      REDLIB_DEFAULT_BLUR_SPOILER = true;
      REDLIB_DEFAULT_USE_HLS = true;
      REDLIB_DEFAULT_HIDE_HLS_NOTIFICATION = true;
      REDLIB_DEFAULT_AUTOPLAY_VIDEOS = false;
      REDLIB_DEFAULT_FIXED_NAVBAR = true;
      REDLIB_DEFAULT_DISABLE_VISIT_REDDIT_CONFIRMATION = true;
      # Absolute URLs in RSS feeds and og:url so reader entries link back to
      # redlib instead of reddit.com.
      REDLIB_FULL_URL = redlibBase;
      REDLIB_ROBOTS_DISABLE_INDEXING = true;
      # RSS is opt-in in newer redlib; we want it for Miniflux integration.
      REDLIB_ENABLE_RSS = true;
      # Pre-populate the subscriptions cookie on first visit. Server-side
      # default; users can still edit via the UI (changes go to their cookie).
      REDLIB_DEFAULT_SUBSCRIPTIONS = lib.concatStringsSep "+" subreddits;
    };
  };
}
