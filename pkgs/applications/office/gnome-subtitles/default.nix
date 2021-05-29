{ lib, stdenv
, fetchFromGitLab
, pkg-config
, intltool
, gtk-doc
, yelp-tools
, itstool
, autoreconfHook
, wrapGAppsHook
, makeWrapper
, gtk3
, gtk-sharp-3_0
, mono
, gst_all_1
, glib
, enchant1
, gtkspell3
}:

stdenv.mkDerivation rec {
  pname = "gnome-subtitles";
  version = "1.6";

  src = fetchFromGitLab {
    domain = "gitlab.gnome.org";
    owner = "GNOME";
    repo = "gnome-subtitles";
    rev = "gnome-subtitles-${version}";
    sha256 = "1crmmcx32i6ca7dlr3xhnc7vgv9jhlpwh6hxhv2fl1x1zbasf42z";
  };

  nativeBuildInputs = [
    autoreconfHook
    intltool
    gtk-doc
    yelp-tools
    itstool
    pkg-config
    mono
    wrapGAppsHook
    makeWrapper
  ];

  buildInputs = [
    gtk3
    gtk-sharp-3_0
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    gst_all_1.gst-editing-services
    gst_all_1.gst-rtsp-server
    gst_all_1.gstreamer
  ];

  postInstall = ''
    wrapProgram "$out/bin/gnome-subtitles" \
        --set MONO_GAC_PREFIX ${lib.concatStringsSep ":" [
          gtk-sharp-3_0
        ]} \
        --set LD_LIBRARY_PATH=${lib.makeLibraryPath [
          glib
          gtk3
          enchant1
          gtkspell3
          gst_all_1.gst-plugins-good
          gst_all_1.gst-plugins-base
          gst_all_1.gst-plugins-bad
          gst_all_1.gst-plugins-ugly
          gst_all_1.gst-libav
          gst_all_1.gst-editing-services
          gst_all_1.gst-rtsp-server
          gst_all_1.gstreamer
        ]}:\$LD_LIBRARY_PATH
  '';

  meta = with lib; {
    description = "A simple color chooser written in GTK3";
    homepage = "http://www.gnomesubtitles.org/";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ shamilton ];
    platforms = platforms.linux;
  };
}
