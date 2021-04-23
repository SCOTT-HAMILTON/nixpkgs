{ lib
, stdenv
, fetchFromGitHub
, autoreconfHook
, git
, pkg-config
, glib
, jsoncpp
, libcap_ng
, libnl
, libuuid
, lz4
, openssl
, protobuf
, python3
, tinyxml

, docutils
, jinja2
}:

stdenv.mkDerivation rec {
  pname = "openvpn3";
  version = "13_beta";

  src = fetchFromGitHub {
    owner = "OpenVPN";
    repo = "openvpn3-linux";
    rev = "v${version}";
    fetchSubmodules = true;
    leaveDotGit = true;
    sha256 = "1k0vs7rghkil2rrnrh1pscsvlvyjs59a6l2bw5iz618db7aapb9f";
  };

  patches = [ ./disable-selinux-build.patch ];

  postPatch = ''
    ./update-version-m4.sh
    patchShebangs ./openvpn3-core/scripts/version
  '';

  nativeBuildInputs = [
    autoreconfHook
    docutils
    git
    jinja2
    pkg-config
  ];
  propagatedBuildInputs = [
    python3
  ];
  buildInputs = [
    glib
    jsoncpp
    libcap_ng
    libnl
    libuuid
    lz4
    openssl
    protobuf
    tinyxml
  ];
  
  configureFlags = [ "--disable-selinux-build" ];

  NIX_LDFLAGS = "-lpthread";

  meta = with lib; {
    description = "OpenVPN 3 Linux client";
    license = licenses.agpl3Plus;
    homepage = "https://github.com/OpenVPN/openvpn3-linux/";
    maintainers = with maintainers; [ shamilton ];
    platforms = platforms.linux;
  };
}
