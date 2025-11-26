# NVIDIA RTX 5090 GPU Configuration for Ninho Server

## Hardware Specifications

- **GPU**: NVIDIA GeForce RTX 5090 (Blackwell architecture)
- **VRAM**: 32GB GDDR7
- **System RAM**: 128GB DDR5
- **CPU**: AMD Ryzen 9 9950X3D
- **Configuration**: Headless server (no display manager)

## NixOS Configuration

The ninho server is configured with comprehensive NVIDIA GPU support for the RTX 5090 in a **headless** configuration (no X11/Wayland display server).

### Key Configuration Elements

#### 1. Kernel Module Loading (Critical for Headless)

```nix
# Force load NVIDIA modules in initrd (required for headless servers)
boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

# Kernel parameters
boot.kernelParams = [
  "nvidia-drm.modeset=1"
  "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
];
```

**Why**: On headless servers without a display manager, NVIDIA modules don't auto-load via X11. Loading them in `initrd.kernelModules` ensures they're available at boot time, before any services need GPU access.

#### 2. X Server Configuration (Required Even for Headless)

```nix
services.xserver = {
  enable = true;  # Required for videoDrivers to work
  videoDrivers = [ "nvidia" ];

  # Headless configuration - no actual X server running
  displayManager.startx.enable = false;
  desktopManager.gnome.enable = false;
};
```

**Why**: NixOS requires `services.xserver.enable = true` for `videoDrivers` to load the NVIDIA kernel modules, even on headless systems. No actual X server will run.

#### 3. NVIDIA Driver (Latest)

```nix
hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.latest;
```

**Why**: RTX 5090 (Blackwell) requires driver version 565 or later for full support. The `latest` package ensures you get the most recent production driver with Blackwell optimizations.

#### 4. Open-Source Kernel Module

```nix
hardware.nvidia.open = true;
```

**Why**: NVIDIA's open-source kernel module (GSP firmware) provides:
- Better performance for RTX 40/50 series cards
- Improved stability
- Better integration with the Linux kernel
- Required for some advanced features on Blackwell architecture

#### 5. Power Management

```nix
hardware.nvidia.powerManagement = {
  enable = true;
  # finegrained = true;  # Experimental, uncomment for better Blackwell power control
};
```

**Why**:
- Enables dynamic power management for better efficiency
- Fine-grained power management is experimental but provides better control over Blackwell's power states
- Important for a headless server to reduce idle power consumption
- RTX 5090 TDP: 575W - proper power management is crucial

#### 4. Persistence Daemon

```nix
hardware.nvidia.nvidiaPersistenced = true;
```

**Why**:
- Keeps GPU initialized even when no display is attached
- Required for headless servers
- Prevents driver reload on suspend/resume
- Improves resume times

#### 5. Kernel Modules

```nix
boot.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
```

**Modules explained**:
- `nvidia`: Core driver module
- `nvidia_modeset`: Kernel mode setting (required for DRM)
- `nvidia_uvm`: Unified Virtual Memory (required for CUDA)
- `nvidia_drm`: Direct Rendering Manager integration

#### 6. Kernel Parameters

```nix
boot.kernelParams = [
  "nvidia-drm.modeset=1"
  "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
];
```

**Parameters explained**:
- `nvidia-drm.modeset=1`: Enables DRM kernel mode setting (better stability)
- `NVreg_PreserveVideoMemoryAllocations=1`: Preserves video memory on suspend/resume

## Installed Tools

### nvtop

GPU monitoring tool (like htop for GPU):

```bash
nvtop
```

Shows:
- GPU utilization
- Memory usage (out of 32GB)
- Temperature
- Power consumption (out of 575W)
- Running processes

### CUDA Toolkit

Full CUDA development environment included:

```bash
nvcc --version  # Check CUDA compiler version
nvidia-smi      # GPU status and process list
```

## Memory Considerations

With 128GB system RAM and 32GB GPU VRAM:

### ZFS ARC Cache

Default ZFS ARC uses 50% of RAM = 64GB. This is fine for most workloads, but if you're running memory-intensive GPU workloads:

```nix
# In configuration.nix, currently commented out
boot.kernelParams = [
  "zfs.zfs_arc_max=34359738368"  # Limit to 32GB (leaves 96GB for GPU workloads)
];
```

**Recommendation**: Keep default 64GB ARC unless you notice memory pressure during GPU compute jobs.

## Usage Examples

### Check GPU Status

```bash
nvidia-smi
```

Sample output:
```
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 565.xx.xx              Driver Version: 565.xx.xx    CUDA Version: 12.7     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id        Disp.A   | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |         Memory-Usage   | GPU-Util  Compute M. |
|=========================================+========================+======================|
|   0  NVIDIA GeForce RTX 5090      On   | 00000000:01:00.0  Off  |                  N/A |
| 30%   45C    P8              35W / 575W |      0MiB / 32768MiB   |      0%      Default |
+-----------------------------------------+------------------------+----------------------+
```

### Monitor GPU in Real-Time

```bash
watch -n 1 nvidia-smi
# OR
nvtop  # Interactive interface
```

### CUDA Test (Python)

```python
import torch
print(torch.cuda.is_available())  # Should print: True
print(torch.cuda.get_device_name(0))  # Should print: NVIDIA GeForce RTX 5090
print(torch.cuda.get_device_properties(0).total_memory / 1024**3)  # ~32GB
```

### Run CUDA Code

```bash
# Example: Compile CUDA program
nvcc my_cuda_program.cu -o my_program
./my_program
```

## Troubleshooting

### GPU Not Detected

```bash
# Check if kernel modules are loaded
lsmod | grep nvidia

# Expected output should show:
# nvidia_drm, nvidia_modeset, nvidia_uvm, nvidia
```

### Driver Issues

```bash
# Check driver version
nvidia-smi

# Check kernel logs
dmesg | grep -i nvidia

# Rebuild system if needed
sudo nixos-rebuild switch --flake .#ninho-nixos
```

### Performance Issues

1. **Check power state**:
   ```bash
   nvidia-smi -q -d PERFORMANCE
   ```

2. **Check temperature**:
   ```bash
   nvidia-smi -q -d TEMPERATURE
   ```

3. **Verify persistence daemon**:
   ```bash
   systemctl status nvidia-persistenced
   ```

### Memory Pressure

If GPU jobs fail with OOM:

1. **Check available system RAM**:
   ```bash
   free -h
   ```

2. **Consider limiting ZFS ARC** (see Memory Considerations above)

3. **Monitor with**:
   ```bash
   nvtop  # Shows both GPU and system memory
   ```

## Headless Configuration

Since this is a headless server:
- ✅ No X server needed (driver works without display)
- ✅ Persistence daemon keeps GPU initialized
- ✅ SSH access for monitoring (nvidia-smi works over SSH)
- ✅ CUDA workloads work without display attached

## Future Enhancements

### For Machine Learning

Add to home-manager configuration:

```nix
home.packages = with pkgs; [
  # ML frameworks with CUDA support
  python311Packages.torch-bin  # PyTorch with CUDA
  python311Packages.tensorflow-bin  # TensorFlow with CUDA

  # Additional tools
  cudaPackages.cudnn  # cuDNN for deep learning
  cudaPackages.nccl   # NCCL for multi-GPU (future expansion)
];
```

### For Container Workloads

Enable NVIDIA Container Toolkit:

```nix
# In configuration.nix
virtualisation.docker.enableNvidia = true;

# Or for Podman
hardware.nvidia-container-toolkit.enable = true;
```

Then run containers with GPU access:
```bash
docker run --gpus all nvidia/cuda:12.7-base nvidia-smi
```

## References

- [NixOS NVIDIA Documentation](https://nixos.wiki/wiki/Nvidia)
- [NVIDIA RTX 5090 Specifications](https://www.nvidia.com/en-us/geforce/graphics-cards/50-series/rtx-5090/)
- [NVIDIA Linux Driver Archive](https://www.nvidia.com/en-us/drivers/unix/)
- [CUDA Documentation](https://docs.nvidia.com/cuda/)

---

**Configuration File**: `/home/bolt/GitHub/nixos/system/machine/ninho/configuration.nix:201-240`

**Last Updated**: 2025-11-25
