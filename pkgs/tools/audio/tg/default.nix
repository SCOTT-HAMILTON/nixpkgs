{ lib
, stdenv
, fetchFromGitHub
, fetchFromGitLab
, alsa-lib
, libX11
, libXrender
, at-spi2-atk
, at-spi2-core
, atk
, autoreconfHook
, bzip2
, cairo
, cmake
, dbus
, dconf
, epoxy
, expat
, fftwFloat
, freetype
, gdk-pixbuf
, gettext
, glib
, gobject-introspection
, gsettings-desktop-schemas
, gtk3
, harfbuzz
, json-glib
, libGL
, libXau
, libXcomposite
, libXcursor
, libXdmcp
, libXfixes
, libXi
, libXinerama
, libXrandr
, libdatrie
, libglvnd-meson
, libpng
, libselinux
, libuuid
, libxcb
, libxkbcommon
, makeWrapper
, meson
, musl-fts
, ninja
, pango
, pkg-config
, portaudio
, python3
, sassc
, shared-mime-info
, substituteAll
, wayland
, wrapGAppsHook
, zlib
}:
let
  libXcursorFixed = libXcursor.overrideAttrs (old: {
    # NIX_LDFLAGS = "-static -k";
    configureFlags = [ "LDFLAGS=-static" ];
    buildInputs = (old.buildInputs or []) ++ [
      libXrandr
    ];
  });
  fftwFloatFixed = fftwFloat.overrideAttrs (old: {
    outputs = [ "out" "dev" "man" ];
    configureFlags = [
      # "--enable-shared"
      "--enable-threads"
      "--enable-single"
      "--disable-doc"
      "--disable-openmp"
    ];
  });
  alsa-lib-fixed = alsa-lib.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ./alsa-lib-fix-static-build.patch ];
  });
  portaudioFixed = (portaudio.override { alsa-lib = alsa-lib-fixed; })
  .overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
      cmake
    ];
    cmakeFlags = [
      "-DPA_BUILD_SHARED=OFF"
      "-DPA_BUILD_STATIC=ON"
    ];
  });
  waylandFixed = wayland.overrideAttrs (old: {
    buildInputs = (old.buildInputs or []) ++ [ zlib ];
    NIX_LDFLAGS = "-lz";
    patches = (old.patches or []) ++ [ ./wayland-disable-tests.patch ];
  });
  libxkbcommonFixed = (libxkbcommon.override { wayland = waylandFixed; })
    .overrideAttrs (old: {
    buildInputs = (old.buildInputs or []) ++ [ zlib libXau libXdmcp ];
    NIX_LDFLAGS = "-lz -lXau -lXdmcp";
  });
  # libglvndFixed = libglvnd.overrideAttrs (old: {
  #   configureFlags = (old.configureFlags or []) ++ [
  #     "--disable-shared"
  #     "--enable-static"
  #   ];
  # });
  libGLFixed = libGL.override { libglvnd = libglvnd-meson; };
  epoxyFixed = epoxy.override { libGL = libGLFixed; };
  libselinuxFixed = (libselinux.override { fts = musl-fts; })
  .overrideAttrs (old: {
    NIX_LDFLAGS = "-lfts -lpcre";
  });
  glibFixed = (glib.override { libselinux = libselinuxFixed; })
  .overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ./glib-link-selinux-statically.patch ];
    buildInputs = (old.buildInputs or []) ++ [
      libuuid
    ];
    NIX_LDFLAGS = "-lblkid";
  });
  cairoFixed = (cairo.override {
    libGL = libGLFixed;
    glib = glibFixed;
  }).overrideAttrs (old: rec {
    version = "1.17.4";
    src = fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "cairo";
      repo = "cairo";
      rev = version;
      sha256 = "1fzk50bs6y117yczaihkchl3rkz66mmfjpb5r7zhx47srip0lf6c";
    };
    patches = [ ./cairo-fix-meson.patch ];
    outputs = [ "out" "dev" ];
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ meson ninja python3 ];
    buildInputs = (old.buildInputs or []) ++ [
      libglvnd-meson libXau libXdmcp bzip2 expat
    ];
    mesonFlags = [
      "-Dtee=enabled"
      "-Dxcb=enabled"
      "-Dgl-backend=gl"
      "-Dzlib=enabled"
      "-Dxlib=enabled"
      "-Dtests=disabled"
      "-Dspectre=disabled"
    ];
    NIX_LDFLAGS = "-lGLdispatch -lxcb -lXau -lXdmcp -lbz2 -lexpat";
    preConfigure = ''
      # Work around broken `Requires.private' that prevents Freetype
      # `-I' flags to be propagated.
      sed -i "src/cairo.pc.in" \
          -es'|^Cflags:\(.*\)$|Cflags: \1 -I${freetype.dev}/include/freetype2 -I${freetype.dev}/include|g'
      patchShebangs version.py
    '';
  });
  harfbuzzFixed = (harfbuzz.override { glib = glibFixed; })
  .overrideAttrs (old: {
    buildInputs = (old.buildInputs or []) ++ [
      libpng
      zlib
      bzip2
    ];
    NIX_LDFLAGS = "-lpng -lz -lbz2";
  });
  gobject-introspectionFixed = let 
    cpuFamily = platform: with platform;
      /**/ if isAarch32 then "arm"
      else if isAarch64 then "aarch64"
      else if isx86_32  then "x86"
      else if isx86_64  then "x86_64"
      else platform.parsed.cpu.family + builtins.toString platform.parsed.cpu.bits;
    crossFile = builtins.toFile "cross-file.conf" ''
      [properties]
      needs_exe_wrapper = false

      [host_machine]
      system = '${stdenv.targetPlatform.parsed.kernel.name}'
      cpu_family = '${cpuFamily stdenv.targetPlatform}'
      cpu = '${stdenv.targetPlatform.parsed.cpu.name}'
      endian = ${if stdenv.targetPlatform.isLittleEndian then "'little'" else "'big'"}
    '';
  in (gobject-introspection.override {
    cairo = cairoFixed;
    glib = glibFixed;
  }).overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./gobject-introspection-no-tests-static-build.patch
      ./gobject-introspection-gir-static-link.patch
    ];
    mesonFlags = (old.mesonFlags or []) ++ [
      "--cross-file=${crossFile}"
      # "--datadir=${placeholder "lib"}/share"
      "-Dgi_cross_use_prebuilt_gi=true"
      # "-Dbuild_introspection_data=false"
      "-Dgtk_doc=false"
    ];
    outputs = [ "out" "dev" "man" ];
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ gobject-introspection ];
    buildInputs = (old.buildInputs or []) ++ [ libuuid ];
    # NIX_LDFLAGS = "-luuid";
    # outputs = [ "out" "dev" "lib" "man" ];
    # outputBin = "dev";
    # postInstall = ''
    #   mkdir -p "$out"
    #   mkdir -p "$lib/share"
    #   cp -r "$lib/lib/pkgconfig" "$lib/share"
    # '';
  });
  pangoFixed = (pango.override {
    cairo = cairoFixed;
    glib = glibFixed;
    harfbuzz = harfbuzzFixed;
    gobject-introspection = gobject-introspectionFixed;
  }).overrideAttrs (old: {
    src = fetchFromGitLab {
      domain = "gitlab.gnome.org";
      owner = "GNOME";
      repo = "pango";
      rev = "1.48.5";
      sha256 = "1wysyf9ahn2c8l72n5zdaigsr3i81f77bhv06mgpmims031m84wk";
    };
    outputs = [ "bin" "out" "dev" ];
    nativeBuildInputs = [
      meson ninja
      glibFixed # for glib-mkenum
      pkg-config
      libselinux
    ];
    mesonFlags = (old.mesonFlags or []) ++ [ "-Dgtk_doc=false" ];
    postInstall = "";
    buildInputs = (old.buildInputs or []) ++ [
      bzip2 libxcb libXau libXdmcp expat libdatrie
    ];
    NIX_LDFLAGS = "-lbz2 -lxcb -lXau -lXdmcp -lexpat -ldatrie";
    patches = (old.patches or []) ++ [ ./pango-link-gio-statically.patch ];
  });
  gsettings-desktop-schemasFixed = (gsettings-desktop-schemas.override {
    # gobject-introspection = (lib.traceValFn (x: "out: ${x.out}, dev: ${x.dev}") gobject-introspectionFixed);
    gobject-introspection = null;
    glib = glibFixed;
  }).overrideAttrs (old: {
    src = fetchFromGitLab {
      domain = "gitlab.gnome.org";
      owner = "GNOME";
      repo = "gsettings-desktop-schemas";
      rev = "40.0";
      sha256 = "0lyf805nhjm04xvc5sk33y347qmvk8gpxi7gdnxqkbb2ybna2vrz";
    };
    patches = [ ./gsettings-desktop-schemas-no-post-install.patch ];
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ gettext libselinux ];
    depsBuildBuild = (old.depsBuildBuild or []) ++ [ pkg-config ];
    buildInputs = [
      glibFixed
    ];
    mesonFlags = (old.mesonFlags or []) ++ [ "-Dintrospection=false" ];
  });
  dbusFixed = dbus.overrideAttrs (old: {
    configureFlags = (old.configureFlags or []) ++ [
      "--disable-shared"
      "--enable-static"
      "--without-x"
    ];
    NIX_CFLAGS_COMPILE = "";
  });
  dconfFixed = (dconf.override { glib = glibFixed; dbus = dbusFixed; })
  .overrideAttrs (old: {
    src = fetchFromGitLab {
      domain = "gitlab.gnome.org";
      owner = "GNOME";
      repo = "dconf";
      rev = "0.40.0";
      sha256 = "01101ixgrhv20wssb5lhv1lwj3i4slx6i7p3g36m9aql6rm2hn5d";
    };
    patches = (old.patches or []) ++ [ ./dconf-link-statically.patch ];
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ glib libselinux ];
  });
  at-spi2-coreFixed = (at-spi2-core.override {
    gsettings-desktop-schemas = gsettings-desktop-schemasFixed;
    glib = glibFixed;
    dconf = dconfFixed;
    dbus = dbusFixed;
  }).overrideAttrs (old: {
    mesonFlags = (old.mesonFlags or []) ++ [ "-Dintrospection=no" ];
    patches = (old.patches or []) ++ [ ./at-spi2-core-link-statically.patch ];
  });
  shared-mime-infoFixed = (shared-mime-info.override { glib = glibFixed; })
  .overrideAttrs (old: {
    buildInputs = (old.buildInputs or []) ++ [ zlib ];
    NIX_LDFLAGS = "-lz";
    patches = (old.patches or []) ++ [
      ./shared-mime-info-link-gio-statically.patch
    ];
  });
  json-glibFixed = (json-glib.override { glib = glibFixed; })
  .overrideAttrs (old: {
    src = fetchFromGitLab {
      domain = "gitlab.gnome.org";
      owner = "GNOME";
      repo = "json-glib";
      rev = "1.6.2";
      sha256 = "0k2z8imazzn8awpk04qbzdajqcy61rn2k14x113lns3m54kdxyyc";
    };
    patches = (old.patches or []) ++ [ ./json-glib-link-gio-statically.patch ];
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ libselinux ];
  });
  atkFixed = (atk.override { glib = glibFixed; })
  .overrideAttrs (old: rec {
    pname = "atk";
    version = "2.36.0";
    src = fetchFromGitLab {
      domain = "gitlab.gnome.org";
      owner = "GNOME";
      repo = "atk";
      rev = "ATK_2_36_0";
      sha256 = "02c0wcmw3kf1541l00gw81kq1wf649r5nlb726i0jm52dryq1ms3";
    };
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ libselinux ];
    postPatch = ''
      substituteInPlace meson.build \
        --replace "subdir('tests')" ""
    '';
  });
  at-spi2-atkFixed = (at-spi2-atk.override {
    at-spi2-core = at-spi2-coreFixed;
    atk = atkFixed;
    glib = glibFixed;
    dbus = dbusFixed;
  }).overrideAttrs (old: {
    buildInputs = (old.buildInputs or []) ++ [ libxcb libXau libXdmcp zlib ];
    NIX_CFLAGS_COMPILE = "-DG_LOG_DOMAIN=\"\"\"\"";
    NIX_LDFLAGS = "-lxcb -lXau -lXdmcp -lz";
    # patches = (old.patches or []) ++ [ ./at-spi2-atk-glogdomain.patch ];
  });
  gdk-pixbufFixed = (gdk-pixbuf.override { glib = glibFixed; })
  .overrideAttrs (old: {
    src = fetchFromGitLab {
      domain = "gitlab.gnome.org";
      owner = "GNOME";
      repo = "gdk-pixbuf";
      rev = "2.42.6";
      sha256 = "0ml0nlz5rhcyp4iaqpmvkb3wq3s6iazkrhh4gh8zm472d5gcvhfg";
    };
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ libselinux ];
    patches = (old.patches or []) ++ [ ./gdk-pixbuf-link-gio-statically.patch ];
  });
  gtk3Fixed = let
    gtkCleanImmodulesCache = substituteAll {
      src = ../../../development/libraries/gtk/hooks/clean-immodules-cache.sh;
      gtk_module_path = "gtk-3.0";
      gtk_binary_version = "3.0.0";
    };
  in (gtk3.override {
    cupsSupport = false;
    wayland = waylandFixed;
    libxkbcommon = libxkbcommonFixed;
    libGL = libGLFixed;
    epoxy = epoxyFixed;
    cairo = cairoFixed;
    pango = pangoFixed;
    gsettings-desktop-schemas = gsettings-desktop-schemasFixed;
    gobject-introspection = gobject-introspectionFixed;
    at-spi2-atk = at-spi2-atkFixed;
    glib = glibFixed;
    shared-mime-info = shared-mime-infoFixed;
    json-glib = json-glibFixed;
    atk = atkFixed;
    gdk-pixbuf = gdk-pixbufFixed;
    trackerSupport = false;
    withGtkDoc = false;
    waylandSupport = false;
  }).overrideAttrs (old: rec {
    mesonFlags = (old.mesonFlags or []) ++ [
      "-Dintrospection=false"
      "-Dwayland_backend=false"
    ];
    NIX_CFLAGS_COMPILE = "-DG_LOG_DOMAIN=\"\"\"\"";
    patches = (old.patches or []) ++ [ ./gtk3-link-statically.patch ];
    setupHooks = [
      ../../../development/libraries/gtk/hooks/drop-icon-theme-cache.sh
      gtkCleanImmodulesCache
    ];
    nativeBuildInputs = [
      gettext
      makeWrapper
      meson
      ninja
      pkg-config
      python3
      sassc
      wayland
      glib
      gdk-pixbuf
    ] ++ setupHooks;
    NIX_LDFLAGS = "-static -lXcomposite -lXi -lXinerama -lXrandr -lepoxy -lXfixes -lXcursor -latk-bridge-2.0";
    buildInputs = (old.buildInputs or []) ++ [
      libXcomposite
      libXi
      libXinerama
      libXrandr
      epoxyFixed
      libXfixes
      libXcursor
      at-spi2-atkFixed
    ];
  });
in
stdenv.mkDerivation rec {
  pname = "tg";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "vacaboja";
    repo = "tg";
    rev = "v${version}";
    sha256 = "1ih1hpj9ak15i47mljhkv7rrq49xm0gdl4n71zygq0pymwxlvg09";
  };

  patches = [ ./link-statically.patch ];

#   NIX_CFLAGS = "-static";
  # NIX_LDFLAGS = "-luuid";
  # LDFLAGS = "-static -luuid -lxcb -lbz2 -lXi";
  # configureFlags = [ "LDFLAGS='-luuid -lxcb -lbz2'" ];
  buildInputs = [
    at-spi2-atkFixed
    bzip2
    epoxyFixed
    fftwFloatFixed
    gtk3Fixed
    libXcomposite
    libXcursorFixed
    libXfixes
    libXi
    libXinerama
    libXrandr
    libuuid
    libxcb
    portaudioFixed
    libX11
    libXrender
    dbusFixed
  ];
  postConfigure = ''
    substituteInPlace Makefile \
      --replace '-lgtk-3' '-lgtk-3 -latk-bridge-2.0 -ldbus-1 -latspi'
    substituteInPlace Makefile \
      --replace '-lthai' '-lthai -ldatrie'
    substituteInPlace Makefile \
      --replace '-lfontconfig' '-lfontconfig -lexpat'
    substituteInPlace Makefile \
      --replace '-lfreetype' '-lfreetype -lbz2'
    substituteInPlace Makefile \
      --replace '-lxcb ' '-lxcb -lXau -lXdmcp '
    substituteInPlace Makefile \
      --replace '-lmount' '-lmount -lblkid'
  '';
  
  LDFLAGS = "-static -lXcursor -lXrandr -lXrender -lXcomposite -lXi -lXinerama -lepoxy -lXfixes";
  NIX_LDFLAGS = LDFLAGS;
  nativeBuildInputs = [ pkg-config autoreconfHook wrapGAppsHook ];

  meta = with lib; {
    description = "Argument Parser for Modern C++";
    license = licenses.mit;
    homepage = "https://github.com/p-ranav/argparse";
    maintainers = [ "Scott Hamilton <sgn.hamilton+nixpkgs@protonmail.com>" ];
    platforms = platforms.linux;
  };
}
