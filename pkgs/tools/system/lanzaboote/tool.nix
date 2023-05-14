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
}:
let
  uefiPlatform = lib.systems.elaborate "${stdenv.hostPlatform.qemuArch}-windows" // {
    rustc.config = "${stdenv.hostPlatform.qemuArch}-unknown-uefi";
  };
  uefiStdenv = mkStdenvNoLibs (stdenv.override (old: {
    hostPlatform = uefiPlatform;
    targetPlatform = uefiPlatform;

    # cc = buildPackages.llvmPackages.clang;
  }));
  uefiRustc = rustc.override {
    stdenv = uefiStdenv;
  };
  uefiRustPlatform = makeRustPlatform {
    stdenv = uefiStdenv;
    rustc = uefiRustc;
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
  });

  meta = with lib; {
    description = "Lanzaboote UEFI tooling for SecureBoot enablement on NixOS systems";
    homepage = "https://github.com/nix-community/lanzaboote";
    license = licenses.gpl3Only;
    mainProgram = "lzbt";
    maintainers = with maintainers; [ raitobezarius nikstur ];
  };
}
