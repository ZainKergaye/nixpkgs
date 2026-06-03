{
  fetchPnpmDeps,
  lib,
  nodejs,
  pnpm_11,
  pnpmConfigHook,
  stdenv,
  fetchFromGitHub,
  electron,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  buildGoModule,
  wayland,
}:
let
  pnpm = pnpm_11;

  version = "3.0.0";

  src = fetchFromGitHub {
    owner = "0bCdian";
    repo = "Waypaper-Engine";
    tag = "v${version}";
    hash = "sha256-oee44RABW+0BcirsJbc5WnLVQeyAamXfxj4Q1x4B2JA=";
  };
  backend = buildGoModule (finalAttrs: {
    pname = "waypaper-daemon";
    inherit version src;

    sourceRoot = "${finalAttrs.src.name}/daemon";

    buildInputs = [
      wayland
    ];

    proxyVendor = true;
    vendorHash = "sha256-KGyaZhWU5UOPV73MitA5eycy3ugH+rwgNu09r3ALtIo=";

    subPackages = [ "cmd/daemon" ];

    ldflags = [
      "-s"
      "-X main.version=${version}"
    ];

  });
in
stdenv.mkDerivation (finalAttrs: {
  pname = "waypaper-engine";
  inherit version src;

  strictDeps = true;
  __structuredAttrs = true;

  nativeBuildInputs = [
    nodejs # in case scripts are run outside of a pnpm call
    pnpmConfigHook
    pnpm # At least required by pnpmConfigHook, if not other (custom) phases
    makeWrapper
    copyDesktopItems
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 3;
    hash = "sha256-m/TtZ1rUXyzSYfxDMuZGW8d0Rl6T7qU+v4kRHAa6PM0=";
  };

  buildPhase = ''
    runHook preBuild

    pnpm exec vite build

    runHook postBuild
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "waypaper-engine";
      exec = finalAttrs.meta.mainProgram;
      comment = finalAttrs.meta.description;
      type = "Application";
      icon = "waypaper-engine";
      desktopName = "Waypaper-engine";
      categories = [ "Utility" ];
    })
  ];

  installPhase = ''
    runHook preInstall
    mkdir $out
    cp -r ./ $out/
    mkdir $out/bin
    cp ${backend}/bin/daemon $out/bin/

    for size in 16x16 32x32 64x64 128x128 256x256 512x512; do
      mkdir -p "$out/share/icons/hicolor/$size/apps" && cp "build/icons/$size.png" "$out/share/icons/hicolor/$size/apps/waypaper-engine.png"
    done

    runHook postInstall
  '';

  postInstall = ''
    makeWrapper ${electron}/bin/electron $out/bin/${finalAttrs.pname} \
      --add-flags $out/dist-electron/main.js
  '';

  meta = {
    description = "A wallpaper setter GUI with playlist functionality for Wayland and X11";
    longDescription = ''
      Waypaper Engine is a wallpaper manager with playlist support, advanced filters, multiple backend support, and Wallhaven integration.
    '';
    homepage = "https://github.com/0bCdian/Waypaper-Engine";
    license = lib.licenses.gpl3Plus;
    changelog = "https://github.com/0bCdian/Waypaper-Engine/releases/tag/${finalAttrs.src.rev}";
    maintainers = [ lib.maintainers.zainkergaye ];
    platforms = [
      "x86_64-linux"
    ];
    mainProgram = "waypaper-engine";
  };

})
