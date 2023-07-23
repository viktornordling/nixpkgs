{ systemd
, makeWrapper
, stdenv
, binutils-unwrapped
, sbsigntool
, makeRustPlatform
, rustPlatform
, rustc
, cargo
, fetchFromGitHub
, lanzaboote-stub
, lib
, mkStdenvNoLibs
, pkgsBuildTarget
, buildPackages
, overrideCC
, writeShellScriptBin
}:
let
  uefiPlatform = lib.systems.elaborate "${stdenv.hostPlatform.qemuArch}-windows" // {
    rustc.config = "${stdenv.hostPlatform.qemuArch}-unknown-uefi";
    useLLVM = true;
  };
  uefiLinker = writeShellScriptBin "lld-link" ''
    exec ${buildPackages.llvmPackages_15.lld}/bin/lld-link "$@"
    '';

  uefiBintools = buildPackages.llvmPackages_15.clang.bintools.override {
    extraBuildCommands = ''
      wrap lld-link ${../../../build-support/bintools-wrapper/ld-wrapper.sh} ${uefiLinker}/bin/lld-link
    '';
  };

  uefiCC = buildPackages.llvmPackages_15.clang; #.override {
 #   bintools = uefiBintools;
 # };

  hostUefiStdenv = overrideCC (stdenv.override (old: {
    targetPlatform = uefiPlatform;
  })) uefiCC;
  uefiStdenv = overrideCC (stdenv.override (old: {
    hostPlatform = uefiPlatform;
    targetPlatform = uefiPlatform;
  })) uefiCC;

  hostUefiRustc = rustc.override {
    stdenv = hostUefiStdenv;
    pkgsBuildTarget = pkgsBuildTarget // { targetPackages.stdenv = hostUefiStdenv; };
  };
  uefiRustPlatform = makeRustPlatform {
    stdenv = uefiStdenv;
    rustc = hostUefiRustc;
    inherit cargo;
  };
in
rustPlatform.buildRustPackage rec {
  pname = "lanzaboote_tool";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "nix-community";
    repo = "lanzaboote";
    rev = "v${version}";
    hash = "sha256-Fb5TeRTdvUlo/5Yi2d+FC8a6KoRLk2h1VE0/peMhWPs=";
  };

  sourceRoot = "source/rust/tool";
  cargoHash = "sha256-ebaLnq2takCEvbHVqkI73FVTwjn1u80nnuy+GzVnROA=";

  env.TEST_SYSTEMD = systemd;

  nativeBuildInputs = [
    makeWrapper
  ];

  postInstall = ''
    # Clean PATH to only contain what we need to do objcopy. Also
    # tell lanzatool where to find our UEFI binaries.
    mv $out/bin/lzbt $out/bin/lzbt-unwrapped
    makeWrapper $out/bin/lzbt-unwrapped $out/bin/lzbt \
      --set PATH ${lib.makeBinPath [ binutils-unwrapped sbsigntool ]} \
      --set LANZABOOTE_STUB ${passthru.stub}/bin/lanzaboote_stub.efi
  '';

  nativeCheckInputs = [
    binutils-unwrapped
    sbsigntool
  ];

  passthru.stub = (lanzaboote-stub.override {
    rustPlatform = uefiRustPlatform;
    uefiLinker = uefiLinker;
  });

  meta = with lib; {
    description = "Lanzaboote UEFI tooling for SecureBoot enablement on NixOS systems";
    homepage = "https://github.com/nix-community/lanzaboote";
    license = licenses.gpl3Only;
    mainProgram = "lzbt";
    maintainers = with maintainers; [ raitobezarius nikstur ];
  };
}
