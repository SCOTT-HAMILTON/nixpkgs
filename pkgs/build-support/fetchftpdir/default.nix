{ stdenvNoCC, wget }:
{ url, sha256 }:

stdenvNoCC.mkDerivation {
  name = "ftpdir";

  builder = ./builder.sh;
  nativeBuildInputs = [ wget ];

  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = sha256;

  inherit url;
}
