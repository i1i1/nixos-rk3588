{
  description = "A minimal NixOS configuration for the RK3588/RK3588S based SBCs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05-small";

    # GPU drivers
    mesa-panfork = {
      url = "gitlab:panfork/mesa/csf";
      flake = false;
    };

    # https://github.com/armbian/linux-rockchip/tree/rk-5.10-rkr4
    kernel-rockchip = {
      url = "github:armbian/linux-rockchip/rk-5.10-rkr4";
      flake = false;
    };
  };

  outputs = inputs@{self, nixpkgs, ...}: let
    pkgsKernel_orangepi5 = import nixpkgs {
      system = "x86_64-linux";
      crossSystem = {
        config = "aarch64-unknown-linux-gnu";
      };

      overlays = [
        (self: super: {
          linuxPackages_rockchip = super.linuxPackagesFor (super.callPackage ./pkgs/kernel {
            src = inputs.kernel-rockchip;
            stdenv = super.gcc11Stdenv;
            boardName = "orangepi5";
          });
        })
      ];
    };
  in {
    nixosConfigurations = {
      # Orange Pi 5 SBC
      orangepi5 = import "${nixpkgs}/nixos/lib/eval-config.nix" rec {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules =
          [
            {
              networking.hostName = "orangepi5";

              nixpkgs.crossSystem = {
                config = "aarch64-unknown-linux-gnu";
              };
            }

            ./modules/orangepi5.nix
          ];
      };

      # Orange Pi 5 Plus SBC
      # TODO not complete yet
      orangepi5plus = import "${nixpkgs}/nixos/lib/eval-config.nix" rec {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules =
          [
            {
              networking.hostName = "orangepi5plus";

              nixpkgs.crossSystem = {
                config = "aarch64-unknown-linux-gnu";
              };
            }

            ./modules/orangepi5plus.nix
          ];
      };

      # Rock 5 Model A SBC
      # TODO not complete yet
      rock5a = import "${nixpkgs}/nixos/lib/eval-config.nix" rec {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules =
          [
            {
              networking.hostName = "rock5a";

              nixpkgs.crossSystem = {
                config = "aarch64-unknown-linux-gnu";
              };
            }

            ./modules/rock5a.nix
          ];
      };
    };

    packages.x86_64-linux = {
      # sdImage
      sdImage-opi5 = self.nixosConfigurations.orangepi5.config.system.build.sdImage;

      # the custom kernel for debugging
      # use `nix develop` to enter the environment with the custom kernel build environment available.
      # and then use `unpackPhase` to unpack the kernel source code and cd into it.
      # then you can use `make menuconfig` to configure the kernel.
      # 
      # problem
      #   - using `make menuconfig` - Unable to find the ncurses package.
      # Solution
      #   - unpackPhase, and the use `nix develop .#fhsEnv` to enter the fhs test environment.
      #   - Then use `make menuconfig` to configure the kernel.
      kernel = pkgsKernel_orangepi5.linuxPackages_rockchip.kernel.dev;
    };

    # use `nix develop .#fhsEnv` to enter the fhs test environment defined here.
    # for kernel debugging
    devShells.x86_64-linux.fhsEnv = let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
      };
    in
      # the code here is mainly copied from:
      #   https://nixos.wiki/wiki/Linux_kernel#Embedded_Linux_Cross-compile_xconfig_and_menuconfig
      (pkgs.buildFHSUserEnv {
        name = "kernel-build-env";
        targetPkgs = pkgs_: (with pkgs_;
          [
            # we need theses packages to make `make menuconfig` work.
            pkgconfig
            ncurses

            # custom kernel
            pkgsKernel_orangepi5.linuxPackages_rockchip.kernel

            # arm64 cross-compilation toolchain
            pkgsKernel_orangepi5.gcc11Stdenv.cc
            # native gcc
            gcc
          ]
          ++ pkgs.linux.nativeBuildInputs);
        runScript = pkgs.writeScript "init.sh" ''
          # set the cross-compilation environment variables.
          export CROSS_COMPILE=aarch64-unknown-linux-gnu-
          export ARCH=arm64
          export PKG_CONFIG_PATH="${pkgs.ncurses.dev}/lib/pkgconfig:"
          exec bash
        '';
      }).env;
  };
}
