{ lib
, stdenv
, fetchFromGitHub
, fetchurl
, fetchpatch
, gcc
}:
let
    linux-makefile = fetchurl {
      url = "https://aur.archlinux.org/cgit/aur.git/plain/Makefile.linux?h=calendar";
      sha256 = "0aj6x3v86jw02x5lh9kjy9rrf69b9bm5vg94ab5pdkwf296dk772";
    };
in
stdenv.mkDerivation rec {
  pname = "openbsd-calendar";
  # check https://github.com/openbsd/src/sys/conf/newvers.sh
  # for the corresponding commit
  version = "6.8-current";

  src = fetchFromGitHub {
      owner = "openbsd";
      repo = "src";
      rev = "e5d32326ca316ca97670d484b46db42e9d6da269";
      sparseCheckout = "usr.bin/calendar";
      sha256 = "1l4zg6hl6p03fbcycyjyw7v7vd348kzwf6zqriq8nv9948m9hd56";
  };

  sourceRoot = "source/usr.bin/calendar";

  patches = [
    # Adapted from https://aur.archlinux.org/cgit/aur.git/tree/calendar-linux.patch?h=calendar
    ./calendar-linux-fix.patch
  ];

  postPatch = ''
    echo "Makefile : \`${linux-makefile}\`"
    cp ${linux-makefile} Makefile
    substituteInPlace Makefile \
      --replace "DESTDIR =" "DESTDIR = $out" \
      --replace "/usr" ""
    substituteInPlace pathnames.h \
      --replace "/usr/bin/cpp" "${gcc}/bin/cpp" \
      --replace "-I/usr/share/calendar" "-I$out/share/calendar"
    cat pathnames.h
  '';

  postInstall = ''
    install -Dm 644 calendar.h "$out/share/calendar/calendar.h"
  '';
  
  propagatedBuildInputs = [ gcc ];

  meta = with lib; {
    description = "OpenBSD's Reminder utility";
    license = licenses.bsd;
    homepage = "https://www.openbsd.org/";
    maintainers = with maintainers; [ shamilton ];
    platforms = platforms.linux;
  };
}
