# nix-build -A dropbear kobo.nix

let 
  nix = import <nixpkgs>;
  kobo = (nix {}).platforms.armv7l-hf-multiplatform;

  uclibcCross = self: super: {
    uclibcCross = super.uclibcCross.overrideAttrs (oldAttrs: rec {
      configurePhase = let
        from = "KERNEL_HEADERS";
        to = ''
          UCLIBC_SUSV3_LEGACY y
          CONFIG_ARM_EABI y
          ARCH_WANTS_BIG_ENDIAN n
          ARCH_BIG_ENDIAN n
          ARCH_WANTS_LITTLE_ENDIAN y
          ARCH_LITTLE_ENDIAN y
          UCLIBC_HAS_FPU n
        '' + from;
        in builtins.replaceStrings [from] [to] oldAttrs.configurePhase;
      patches = [ ./libgcc_resume.patch ];
    });
  };

  dropbear = let
    overrideStatic = self: super: {
      dropbear = super.dropbear.override {
        enableStatic = true;
        zlib = self.zlibStatic;
      };
    };
    buildStatic = self: super: {
      dropbear = super.dropbear.overrideAttrs (oldAttrs: rec {
        buildInputs = [self.zlibStatic self.zlibStatic.static];
      });
    };
    in [overrideStatic buildStatic];

in nix
{
  crossSystem = {
    config = "arm-linux-gnueabihf";
    bigEndian = true;
    arch = "arm";
    float = "hard";
    libc = "uclibc";
    platform = kobo;
  };

  overlays = [ uclibcCross ] ++ dropbear;
}
