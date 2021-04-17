{ lib
, stdenv
, fetchFromGitHub
, fetchftpdir
, autoreconfHook
, gettext
, perl
, pkg-config
, readline
, texinfo
}:

stdenv.mkDerivation rec {
  pname = "remake";
  remakeVersion = "4.3";
  dbgVersion = "1.5";
  version = "${remakeVersion}+dbg-${dbgVersion}";

  src = fetchFromGitHub {
    owner = "rocky";
    repo = "remake";
    rev = "release_${remakeVersion}%2Bdbg-${dbgVersion}";
    sha256 = "0fidz2jpy2c9pn16xv485jv575kikhs0dlcdh1qfl5l8xv1px79a";
  };
  po_files = fetchftpdir {
    url = "http://translationproject.org/latest/make";
    sha256 = "0y8sw9isjmbb8466lh14sk70zl49nyql2nf6494ln6083jzsgcil";
  };

  patches = [
    ./glibc-2.27-glob.patch
    # remake tries to rsync the translations
    # file from http://translationproject.org/latest/make
    # to the po/ directory
    # but the below postPatch does already that
    ./no-rsync.patch
  ];

  postPatch = ''
    cp ${po_files}/translationproject.org/latest/make/*.po po/
  '';

  nativeBuildInputs = [
    autoreconfHook
    gettext
    perl
    pkg-config
    texinfo
  ];
  buildInputs = [ readline ];

  postConfigure = ''
    make po-update
    pushd doc
    make stamp-1 stamp-vti
    popd
  '';

  # make check fails, see https://github.com/rocky/remake/issues/117

  meta = {
    homepage = "http://bashdb.sourceforge.net/remake/";
    license = lib.licenses.gpl3Plus;
    description = "GNU Make with comprehensible tracing and a debugger";
    platforms = with lib.platforms; linux ++ darwin;
    maintainers = with lib.maintainers; [ bjornfor shamilton ];
  };
}
