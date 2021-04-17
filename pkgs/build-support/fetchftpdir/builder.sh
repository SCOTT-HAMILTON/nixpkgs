source "$stdenv/setup"

header "Downloading everything in \`$url' into \`$out'"

mkdir -p "$out"
wget --passive-ftp -np -nv --recursive --level=1 --no-check-certificate --directory-prefix=$out $url

stopNest
