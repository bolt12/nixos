final: prev: {
  ollama = prev.ollama.overrideAttrs (oldAttrs: rec {
    version = "0.13.3";

    src = prev.fetchFromGitHub {
      owner = "ollama";
      repo = "ollama";
      tag = "v${version}";
      hash = "sha256-DsAgosnvkyGFPKSjjnE9dZ37CfqAIlvodpVjHLihX2A=";
    };

    # The vendorHash might need to be updated if Go dependencies changed
    # If the build fails with a hash mismatch, update this value with the expected hash
    # To find the correct hash, set this to null, build, and use the hash from the error
    vendorHash = "sha256-NM0vtue0MFrAJCjmpYJ/rPEDWBxWCzBrWDb0MVOhY+Q=";
  });
}
