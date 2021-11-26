mesonShlibsToStaticPhase() {
	replaceMesonFunction() {
		foundFiles=$(find . -name "meson.build" -exec grep -El "	* *$1 *\(" {} \;)
		for mesonFile in $foundFiles
		do
			echo "$mesonFile";
			cp "$mesonFile" "$mesonFile.tmp_file_mesonShlibsToStaticPhase"
			sed -i -E "s=(	* *)$1( *)\(=\1$2(\2=g" "$mesonFile";
			echo -n "[meson-shlibs-to-static] applied patch : "
			diff -u "$mesonFile.tmp_file_mesonShlibsToStaticPhase" "$mesonFile" || echo ""
			rm -f "$mesonFile.tmp_file_mesonShlibsToStaticPhase"
		done
	}
	replaceMesonFunction "shared_library" "static_library"
	replaceMesonFunction "shared_module" "static_library"
}

mesonConfigurePhase() {
    runHook preConfigure
	mesonForceReplaceSharedLibsByStaticLibs=${mesonForceReplaceSharedLibsByStaticLibs:=@targetIsStatic@}
	if [ ! -z $mesonForceReplaceSharedLibsByStaticLibs ]; then
		mesonShlibsToStaticPhase
	fi

    if [ -z "${dontAddPrefix-}" ]; then
        mesonFlags="--prefix=$prefix $mesonFlags"
    fi

    # See multiple-outputs.sh and meson’s coredata.py
    mesonFlags="\
        --libdir=${!outputLib}/lib --libexecdir=${!outputLib}/libexec \
        --bindir=${!outputBin}/bin --sbindir=${!outputBin}/sbin \
        --includedir=${!outputInclude}/include \
        --mandir=${!outputMan}/share/man --infodir=${!outputInfo}/share/info \
        --localedir=${!outputLib}/share/locale \
        -Dauto_features=${mesonAutoFeatures:-enabled} \
        -Dwrap_mode=${mesonWrapMode:-nodownload} \
        $mesonFlags"

    mesonFlags="${crossMesonFlags+$crossMesonFlags }--buildtype=${mesonBuildType:-plain} $mesonFlags"

    echo "meson flags: $mesonFlags ${mesonFlagsArray[@]}"

    meson build $mesonFlags "${mesonFlagsArray[@]}"
    cd build

    if ! [[ -v enableParallelBuilding ]]; then
        enableParallelBuilding=1
        echo "meson: enabled parallel building"
    fi

    runHook postConfigure
}

if [ -z "${dontUseMesonConfigure-}" -a -z "${configurePhase-}" ]; then
    setOutputFlags=
    configurePhase=mesonConfigurePhase
fi
