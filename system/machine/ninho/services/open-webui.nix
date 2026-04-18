{ config, pkgs, lib, constants, ... }:
let
  inherit (constants) ports;
in
{
  services.open-webui = {
    enable = true;
    package = pkgs.unstable.open-webui;
    port = ports.open-webui;
    openFirewall = true;
    host = "0.0.0.0";
    environment = {
      # Use llama-swap as the OpenAI-compatible backend
      OPENAI_API_BASE_URLS = "http://127.0.0.1:${toString ports.llamaswap}/v1";
      OPENAI_API_KEYS = "not-needed";
      # Disable Ollama (we use llama-swap)
      ENABLE_OLLAMA_API = "False";
      # Increase timeout for model loading (llama-swap loads on demand)
      AIOHTTP_CLIENT_TIMEOUT = "1200";
      # Disable task model thrashing (title/tag/followup generation)
      TASK_MODEL = "";
      ENABLE_TAGS_GENERATION = "False";
    };
  };
}
