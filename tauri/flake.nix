{
  description = "Devshell for this project";

  nixConfig = {
    extra-substituters = [
      "https://fenix.cachix.org"
    ];
    extra-trusted-public-keys = [
      "fenix.cachix.org-1:ecJhr+RdYEdcVgUkjruiYhjbBloIEGov7bos90cZi0Q="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    fenix.url = "github:nix-community/fenix";

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [inputs.fenix.overlays.default];
    };

    lib = pkgs.lib;

    rust-toolchain = pkgs.fenix.fromToolchainFile {
      file = ./rust-toolchain.toml;
      sha256 = "sha256-A1abGIbOtcBSdrUMhDGrER3pRM1hQP4fp9gh3Y4PKc8=";
    };

    pre-commit-check = inputs.git-hooks.lib.${system}.run {
      src = ./.;

      # GIT HOOKS GO HERE
      # See https://devenv.sh/git-hooks/ for how to configure hooks
      # To get the root of the project, use the following command as a workaround: $(git rev-parse --show-toplevel)
      # See https://github.com/NixOS/nix/issues/8034#issuecomment-3366842508 for more info
      hooks = let
        pnpm-check-wrapper = pkgs.writeShellApplication {
          name = "pnpm-check";
          runtimeInputs = [pkgs.pnpm];

          text = ''
            cd "$(git rev-parse --show-toplevel)"/src
            pnpm run check
          '';
        };
      in {
        pnpm-check = {
          enable = false;
          name = "svelte-check";
          entry = "${lib.getExe pnpm-check-wrapper}";
          pass_filenames = false;
          files = "^src/.*\\.(${
            builtins.concatStringsSep "|" [
              "js"
              "ts"
              "svelte"
            ]
          })$";
        };

        clippy = {
          enable = false;
          packageOverrides = {
            cargo = rust-toolchain;
            clippy = rust-toolchain;
          };
          settings = {
            allFeatures = true;
            denyWarnings = true;
            extraArgs = "--manifest-path ./src-tauri/Cargo.toml";
          };
        };

        rustfmt = {
          enable = true;
          settings.manifest-path = "src-tauri/Cargo.toml";
          packageOverrides = {
            cargo = rust-toolchain;
            rustfmt = rust-toolchain;
          };
        };

        biome = {
          enable = true;
          settings = {
            binPath = "./node_modules/.bin/biome";
            configPath = "./biome.json";
          };
        };

        alejandra.enable = true;
        check-toml.enable = true;
        taplo.enable = true;
        markdownlint.enable = true;
      };
    };
  in {
    devShells.${system}.default = pkgs.mkShell rec {
      nativeBuildInputs = with pkgs; [
        # MARKDOWN
        markdownlint-cli # Formatter

        # NIX
        nixd # LSP
        alejandra # Formatter

        # NODE
        nodejs_24
        pnpm

        # RUST
        rust-toolchain
        pkg-config
        wrapGAppsHook4
      ];

      buildInputs = with pkgs; [
        glib
        gtk3
        libsoup_3
        librsvg
        webkitgtk_4_1
        cairo
        pango
        atk
        gdk-pixbuf
        harfbuzz
        dbus
        openssl

        gst_all_1.gstreamer
        gst_all_1.gst-plugins-base
        gst_all_1.gst-plugins-good
        gst_all_1.gst-plugins-bad
      ];

      shellHook = ''
        ${pre-commit-check.shellHook}
        pnpm install
      '';

      env = {
        LD_LIBRARY_PATH = lib.makeLibraryPath buildInputs;
        XDG_DATA_DIRS = "$GSETTINGS_SCHEMAS_PATH"; # Needed on Wayland to report the correct display scale
        GDK_BACKEND = "x11"; # Fixes styling issues on wayland
      };
    };
  };
}
