{
  description = "NixOS OPi Zero 2W: Multitool (Final Python/Binman Fix)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: let
    system = "aarch64-linux";
    
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        (final: prev: {
          # 1. Custom U-Boot (Fixed: Python Libs + Binman deps)
          ubootOrangePiZero2W = prev.buildUBoot {
            defconfig = "orangepi_zero2w_defconfig";
            extraMeta.platforms = [ "aarch64-linux" ];
            filesToInstall = [ "u-boot-sunxi-with-spl.bin" ];
            version = "2024.04";
            src = prev.fetchurl {
              url = "https://ftp.denx.de/pub/u-boot/u-boot-2024.04.tar.bz2";
              hash = "sha256-GKhT/jn6160DqQzC1Cda6u1tppc13vrDSSuAUIhD3Uo=";
            };
            
            # --- BUILD FIXES ---
            nativeBuildInputs = [ 
              prev.dtc 
              prev.armTrustedFirmwareTools 
              prev.bison 
              prev.flex 
              prev.which
              prev.swig
              prev.openssl # Required for image signing
              
              # WRAPPED PYTHON: Provides libfdt (fixes your error) and pyelftools (fixes the next error)
              (prev.python3.withPackages (p: [ 
                p.setuptools 
                p.libfdt 
                p.pyelftools 
              ]))
            ];
            
            # Inject BL31 binary for H618
            BL31 = "${prev.armTrustedFirmwareAllwinner}/bl31.bin";
          };
          
          # 2. Custom DWM
          dwm = prev.dwm.overrideAttrs (old: {
            src = prev.fetchgit {
              url = "https://git.suckless.org/dwm";
              rev = "6.4";
              hash = "sha256-uhFal7PdyxC7ppKEATw3Q6DLFTdr0qbboIgFw1c2vQg=";
            };
            postPatch = ''
              sed -i 's/#define MODKEY Mod1Mask/#define MODKEY Mod4Mask/' config.def.h
            '';
          });
        })
      ];
    };

  in {
    nixosConfigurations.opi-zero2w = nixpkgs.lib.nixosSystem {
      inherit system;
      
      modules = [
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        
        ({ config, lib, ... }: {
          
          # --- 0. NIXPKGS CONFIG ---
          nixpkgs.pkgs = pkgs;

          # --- 1. HARDWARE & KERNEL ---
          # Pinned to 6.12 to avoid ZFS breakage
          boot.kernelPackages = pkgs.linuxPackages_6_12;
          boot.supportedFilesystems = lib.mkForce [ "vfat" "ext4" ];

          hardware.deviceTree.name = "allwinner/sun50i-h618-orangepi-zero2w.dtb";
          boot.loader.grub.enable = false;
          boot.loader.generic-extlinux-compatible.enable = true;
          boot.kernelParams = [ "console=ttyS0,115200" ];
          
          zramSwap.enable = true;
          zramSwap.algorithm = "zstd";
          zramSwap.memoryPercent = 100;

          # --- 2. CONNECTIVITY ---
          networking.hostName = "opi-multitool";
          services.avahi = { enable = true; nssmdns4 = true; publish = { enable = true; addresses = true; }; };

          boot.kernelModules = [ "g_ether" ];
          hardware.deviceTree.overlays = [{
            name = "usb0-peripheral";
            dtsText = ''
              /dts-v1/; /plugin/;
              / { fragment@0 { target = <&usbotg>; __overlay__ { dr_mode = "peripheral"; status = "okay"; }; }; };
            '';
          }];
          networking.interfaces.usb0.ipv4.addresses = [{ address = "10.0.0.1"; prefixLength = 24; }];
          networking.defaultGateway = "10.0.0.2"; 
          networking.nameservers = [ "1.1.1.1" ];

          # --- 3. GUI ---
          services.xserver = {
            enable = true;
            videoDrivers = [ "modesetting" ];
            windowManager.dwm.enable = true;
            displayManager.lightdm.enable = true;
            displayManager.sessionCommands = ''
              while true; do
                xsetroot -name "$(free -h | awk '/^Mem/ { print $7 }') avail | $(date +'%H:%M')"
                sleep 10
              done &
            '';
          };
          services.displayManager.autoLogin = { enable = true; user = "root"; };

          # --- 4. TOOLKIT ---
          fonts.packages = with pkgs; [ 
            nerd-fonts.jetbrains-mono
          ];

          environment.systemPackages = with pkgs; [
            alpaca
            vscodium
            ollama
            neovim
            emacs-nox
            # Kate removed
            git
            wget
            btop
            st
            dmenu
            (pkgs.writeShellScriptBin "start-ai" ''
              echo "Starting Ollama Service..."
              systemctl start ollama
              echo "Ready. Launching Alpaca..."
              alpaca
            '')
          ];

          # --- 5. ON-DEMAND SERVICES ---
          virtualisation.docker.enable = true;
          virtualisation.docker.autoPrune.enable = true;
          systemd.services.docker.wantedBy = lib.mkForce []; 
          systemd.sockets.docker.wantedBy = lib.mkForce [ "sockets.target" ];

          services.ollama = {
            enable = true;
            host = "0.0.0.0";
          };
          systemd.services.ollama.wantedBy = lib.mkForce [];

          # --- 6. BUILD CONFIG ---
          sdImage = {
            compressImage = false;
            postBuildCommands = ''
              dd if=${pkgs.ubootOrangePiZero2W}/u-boot-sunxi-with-spl.bin of=$img bs=1024 seek=8 conv=notrunc
            '';
          };

          services.openssh = { enable = true; settings.PermitRootLogin = "yes"; };
          users.users.root.initialPassword = "nixos";
          system.stateVersion = "25.11";
        })
      ];
    };
  };
}
