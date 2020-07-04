{ stdenv
, lib
, fetchFromGitHub
, meson
, ninja
, pkg-config
, libxkbcommon
, pango
, which
, git
, cairo
, libxcb
, xcbutil
, xcbutilwm
, xcbutilxrm
, xcb-util-cursor
, libstartup_notification
, bison
, flex
, librsvg
, check
, makeWrapper
}:

stdenv.mkDerivation rec {
  pname = "rofi-unwrapped";
  version = "1.7.2";

  src = fetchFromGitHub {
    owner = "davatorium";
    repo = "rofi";
    rev = version;
    fetchSubmodules = true;
    sha256 = "vre8kFou01P7S6KBBtfzvfFP554mhV+d6rjvY+GfWXk=";
  };

  preConfigure = ''
    patchShebangs "script"
    # root not present in build /etc/passwd
    sed -i 's/~root/~nobody/g' test/helper-expand.c
  '';

  nativeBuildInputs = [ meson ninja pkg-config makeWrapper ];
  buildInputs = [
    libxkbcommon
    pango
    cairo
    git
    bison
    flex
    librsvg
    check
    libstartup_notification
    libxcb
    xcbutil
    xcbutilwm
    xcbutilxrm
    xcb-util-cursor
    which
  ];

  postInstall = ''
    wrapProgram $out/bin/rofi \
      --run 'export XDG_DATA_DIRS="$(sed "s| |/share:|g" < <(echo $NIX_PROFILES))/share:$XDG_DATA_DIRS"'
  '';

  doCheck = false;

  meta = with lib; {
    description = "Window switcher, run dialog and dmenu replacement";
    homepage = "https://github.com/davatorium/rofi";
    license = licenses.mit;
    maintainers = with maintainers; [ bew shamilton ];
    platforms = with platforms; linux;
  };
}
