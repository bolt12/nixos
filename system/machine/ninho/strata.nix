# Strata (github.com/Niko1221/Strata): an inference engine written for Qwen3.8-Flash-Next. The
# most-used experts live in VRAM, every expert in RAM, and the CPU computes cache misses while the
# GPU works; its own MTP layer drafts tokens. Upstream's Linux install is a setup script that
# compiles in place, so this is that same build, laid out for the Nix store: the CUDA engine, the
# Python HTTP server (OpenAI and Anthropic APIs), and the prep tools that turn a GGUF into a pack.
#
# CUDA must be 13.0 exactly: 12.8 builds crash on long prompts on sm_120 (Strata #220), and nvcc
# 13.2 miscompiles the IQ1_S/IQ2_S/IQ3_S kernels on sm_120 (Strata #892), which UD-IQ4_XS uses
# for its gate/up experts. The caller passes cudaPackages_13_0.
{
  lib,
  fetchFromGitHub,
  cudaPackages,
  cmake,
  ninja,
  python3,
  makeWrapper,
  autoAddDriverRunpath,
  runtimeShell,
}:
let
  version = "0.1.39";

  # The llama.cpp commit Strata pins (third_party/ggml/VERSION.txt). Its ggml builds the CPU expert
  # kernels and its gguf-py serves the prep tools. Passing it as STRATA_GGML_DIR skips the CMake
  # FetchContent download, which the sandbox would refuse anyway.
  llamaSrc = fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = "3cf03257f219afbe7334045ff7c6a06ac68c627d";
    hash = "sha256-SRGoXa+4ACBCB3eaG9XFYhMN1i0FyPEy9Rrer+dFGYI=";
  };

  # requirements.txt minus cmake and ninja, which only setup.py's own build used.
  python = python3.withPackages (
    ps: with ps; [
      numpy
      jinja2
      regex
      pyyaml
      tqdm
      requests
      pillow
      psutil
    ]
  );
in
cudaPackages.backendStdenv.mkDerivation {
  pname = "strata";
  inherit version;

  src = fetchFromGitHub {
    owner = "Niko1221";
    repo = "Strata";
    rev = "6f32ec070f23ced9f50e704d854d775da52591ab";
    hash = "sha256-9jqmV+AbGKiOqW1DvKjqBLVXmJCI9o6WI85QoHj5vBI=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    cudaPackages.cuda_nvcc
    makeWrapper
    autoAddDriverRunpath
  ];

  buildInputs = with cudaPackages; [
    cuda_cudart
    cuda_cccl
    libcublas
  ];

  cmakeFlags = [
    "-DSTRATA_ENABLE_CUDA=ON"
    "-DSTRATA_BUILD_TESTS=OFF"
    # The RTX 5090 alone, as in the Docker build that was benchmarked.
    "-DCMAKE_CUDA_ARCHITECTURES=120"
    "-DSTRATA_GGML_DIR=${llamaSrc}"
  ];

  # Strata builds ggml with GGML_NATIVE for its AVX-512 CPU expert kernels. Like llama-cpp-cuda,
  # this package is built on and for ninho only.
  preConfigure = ''
    export NIX_ENFORCE_NO_NATIVE=0
  '';

  # Only the engine: the other CMake targets are developer tools.
  buildPhase = ''
    runHook preBuild
    cmake --build . --target strata -j $NIX_BUILD_CORES
    runHook postBuild
  '';

  # Upstream has no install rules. The server reads the engine's version from a BUILD.json beside
  # it (serve/server.py), and finds serve/, tools/ and data/ relative to its own file.
  installPhase = ''
    runHook preInstall

    install -Dm755 strata $out/libexec/strata/strata
    echo '{"source": "nix", "version": "${version}"}' > $out/libexec/strata/BUILD.json

    mkdir -p $out/share/strata
    cp -r $src/serve $src/tools $src/data $out/share/strata/

    # The server's NVML telemetry loads libnvidia-ml through ctypes, which RUNPATH cannot reach.
    makeWrapper ${python}/bin/python $out/bin/strata-serve \
      --add-flags $out/share/strata/serve/server.py \
      --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib

    # strata-tool NAME ARGS: one of the prep tools (iq_pack, mtp_fetch, mtp_pack, mtp_rt, ...).
    cat > $out/bin/strata-tool <<EOF
    #!${runtimeShell}
    tool=\$1
    shift
    export STRATA_GGUF_PY=${llamaSrc}/gguf-py
    exec ${python}/bin/python $out/share/strata/tools/\$tool.py "\$@"
    EOF
    chmod +x $out/bin/strata-tool

    runHook postInstall
  '';

  passthru = { inherit llamaSrc python; };

  meta = {
    description = "Qwen3.8-Flash-Next inference engine with GPU expert caching and CPU offload";
    homepage = "https://github.com/Niko1221/Strata";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "strata-serve";
  };
}
