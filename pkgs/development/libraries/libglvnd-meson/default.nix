{ stdenv, lib, fetchFromGitLab
, meson, ninja, pkg-config, python3, addOpenGLRunpath, libxcb
, libX11, libXext, xorgproto, libXau, libXdmcp
}:

stdenv.mkDerivation rec {
  pname = "libglvnd-meson";
  version = "1.3.3";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "glvnd";
    repo = "libglvnd";
    rev = "v${version}";
    sha256 = "0gjk6m3gkdm12bmih2jflp0v5s1ibkixk7mrzrk0cj884m3hy1z6";
  };

  patches = [ ./nm-path-option.patch ./build-statically.patch ];

  nativeBuildInputs = [ meson ninja pkg-config python3 addOpenGLRunpath ];
  buildInputs = [ libX11 libXext xorgproto libxcb libXau libXdmcp ];

  postPatch = '' 
    substituteInPlace meson.build \
      --replace "subdir('tests')" ""
  '' + lib.optionalString stdenv.isDarwin ''
    substituteInPlace src/GLX/Makefile.am \
    --replace "-Wl,-Bsymbolic " ""
    substituteInPlace src/EGL/Makefile.am \
    --replace "-Wl,-Bsymbolic " ""
    substituteInPlace src/GLdispatch/Makefile.am \
    --replace "-Xlinker --version-script=$(VERSION_SCRIPT)" "-Xlinker"
  '';

  NIX_CFLAGS_COMPILE = toString ([
    "-UDEFAULT_EGL_VENDOR_CONFIG_DIRS"
    # FHS paths are added so that non-NixOS applications can find vendor files.
    "-DDEFAULT_EGL_VENDOR_CONFIG_DIRS=\"${addOpenGLRunpath.driverLink}/share/glvnd/egl_vendor.d:/etc/glvnd/egl_vendor.d:/usr/share/glvnd/egl_vendor.d\""

    "-Wno-error=array-bounds"
  ] ++ lib.optional stdenv.cc.isClang "-Wno-error");

  NIX_LDFLAGS = "-lxcb -lXau -lXdmcp";

  mesonFlags  = [ "-Dnm-path=${stdenv.cc.targetPrefix}nm" ]
  # Indirectly: https://bugs.freedesktop.org/show_bug.cgi?id=35268
  ++ lib.optional stdenv.hostPlatform.isMusl "-Dtls=disabled"
  # Remove when aarch64-darwin asm support is upstream: https://gitlab.freedesktop.org/glvnd/libglvnd/-/issues/216
  ++ lib.optional (stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64) "-Dasm=disabled";

  outputs = [ "out" "dev" ];

  # Set RUNPATH so that libGLX can find driver libraries in /run/opengl-driver(-32)/lib.
  # Note that libEGL does not need it because it uses driver config files which should
  # contain absolute paths to libraries.
  postFixup = ''
    addOpenGLRunpath $out/lib/libGLX.so
  '';

  passthru = { inherit (addOpenGLRunpath) driverLink; };

}

