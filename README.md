### Technical Documentation: NixOS Multitool for Orange Pi Zero 2W

This documentation outlines the systems engineering and hardware abstraction layers required to deploy a declarative NixOS environment on the Orange Pi Zero 2W. The project serves as a comprehensive, portable development suite optimized for resource-constrained ARM64 environments.

**Developer:** Asher Leroy

**License:** BSD 3-Clause

**Target Architecture:** Allwinner H618 (ARM Cortex-A53)

---

### Hardware Abstraction Layer (HAL)

Deploying NixOS on Allwinner-based Single Board Computers (SBCs) necessitates a manual definition of the bootloader and firmware stack, as these boards lack the UEFI/BIOS standard found in x86 architecture.

#### 1. Boot Sequence and Firmware Injection

The boot process for the H618 SoC follows a non-linear path that requires specific binary blobs to be present during the build phase of the bootloader.

* **ARM Trusted Firmware (ATF):** The system utilizes the `bl31.bin` monitor code. In this configuration, the Nix Flake injects the `armTrustedFirmwareAllwinner` package into the U-Boot environment, providing the necessary secure-world services.
* **U-Boot SPL:** The bootloader is compiled with the `orangepi_zero2w_defconfig`. This is a critical abstraction, as it initializes the **LPDDR4** memory controller. Using a standard Orange Pi Zero 2 (DDR3) configuration would result in a DRAM initialization failure.
* **Device Tree Blob (DTB):** Hardware peripherals are mapped via `sun50i-h618-orangepi-zero2w.dtb`. This file serves as the hardware description for the Linux kernel, defining memory addresses for UART, HDMI, and the USB OTG controller.

#### 2. Kernel and Filesystem Strategy

The system is pinned to **Linux Kernel 6.12**. This specific version provides mainline support for the H618 while maintaining compatibility with out-of-tree modules. ZFS support is explicitly disabled to prevent build-time regressions and reduce the memory footprint of the kernel image.

---

### System Architecture and Optimization

#### Resource Management

To maintain system stability on a board with limited physical RAM, the configuration implements two primary memory management strategies:

* **ZRAM Integration:** Utilizes the `zstd` compression algorithm to create a swap device within the RAM. This provides a virtual increase in memory capacity, which is essential for executing large-language model (LLM) inference.
* **Socket Activation:** Services such as **Docker** and **Ollama** are configured with systemd socket activation. The daemons remain idle and consume zero memory until a specific API call or command is executed.

#### Connectivity: USB Gadget Mode

The configuration enables the `g_ether` kernel module and applies a Device Tree overlay to force the USB-C port into peripheral mode. This allows the board to function as a virtual Ethernet adapter when connected to a host computer.

* **Static IP Assignment:** `10.0.0.1`
* **Discovery:** Avahi/mDNS is enabled, allowing network access via `opi-multitool.local`.

---

### Software Toolkit

The environment provides a curated suite of development tools without introducing system bloat:

* **Window Management:** A custom-patched build of **DWM** (Dynamic Window Manager). The source is modified at build-time via a Nix overlay to remap the `MODKEY` to `Mod4Mask` (Super/Windows key).
* **Integrated Editors:** Includes **Neovim**, **Emacs-nox**, and **VSCodium** (the community-driven, telemetry-free binary of VS Code).
* **AI Orchestration:** Integrated support for **Alpaca** and **Ollama**, allowing for local LLM experimentation within the ARM64 instruction set.

---

### Build and Deployment Instructions

#### Infrastructure as Code

To generate the bootable SD image, execute the following command from an x86_64 host with AArch64 emulation enabled:

```bash
nix build .#nixosConfigurations.opi-zero2w.config.system.build.sdImage

```

#### Media Preparation

The resulting image must be written to the physical media using a raw block copy. The Flake's `postBuildCommands` automatically handles the `dd` seek offset for the U-Boot SPL (8KB offset).

```bash
# Ensure /dev/sdX is the correct target device
sudo dd if=result/sd-image/nixos-image-*.img of=/dev/sdX bs=4M status=progress conv=fsync

```

---

### BSD 3-Clause License

Copyright (c) 2026, Asher Leroy. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
