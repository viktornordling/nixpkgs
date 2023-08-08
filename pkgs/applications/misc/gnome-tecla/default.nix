{ stdenv
, lib
, fetchurl
, meson
, ninja
, pkg-config
, wrapGAppsHook4
, glib
, gtk4
, libadwaita
, libxkbcommon
, wayland
, gnome
}:

stdenv.mkDerivation rec {
  pname = "tecla";
  version = "45.alpha";

  src = fetchurl {
    url = "mirror://gnome/sources/${pname}/${lib.versions.major version}/${pname}-${version}.tar.xz";
    hash = "sha256-dl96ZD5aHaqd7ywMg988ZRrkveBVM9ZO4VWeuzxOjr0=";
  };

  patches = [
    # ../src/tecla-util.c:29:12: error: 'PATH_MAX' undeclared
    # https://gitlab.gnome.org/GNOME/tecla/-/issues/8
    ./fix-path-max.patch
  ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    wrapGAppsHook4
  ];

  buildInputs = [
    glib
    gtk4
    libadwaita
    libxkbcommon
    wayland
  ];

  passthru = {
    updateScript = gnome.updateScript {
      attrPath = "gnome-tecla";
      packageName = "tecla";
    };
  };

  meta = with lib; {
    description = "Keyboard layout viewer";
    homepage = "https://gitlab.gnome.org/GNOME/tecla";
    license = licenses.gpl2Plus;
    maintainers = teams.gnome.members;
    platforms = platforms.linux;
    mainProgram = "tecla";
  };
}
