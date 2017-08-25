{ stdenv, buildPythonPackage, fetchurl
, pytest, django, setuptools_scm
, fetchpatch
}:
buildPythonPackage rec {
  pname = "pytest-django";
  name = "${pname}-${version}";
  version = "3.1.2";

  src = fetchurl {
    url = "mirror://pypi/p/pytest-django/${name}.tar.gz";
    sha256 = "02932m2sr8x22m4az8syr8g835g4ak77varrnw71n6xakmdcr303";
  };

  buildInputs = [ pytest setuptools_scm ];
  propagatedBuildInputs = [ django ];

  patches = [
    # Unpin setuptools-scm
    (fetchpatch {
      url = "https://github.com/pytest-dev/pytest-django/commit/25cbc3b395dcdeb92bdc9414e296680c2b9d602e.patch";
      sha256 = "1mx06y4kz2zs41mb2h9bh5p4jc6s6hfsq6fghhsks5b7qak05xjp";
    })
  ];

  # Complicated. Requires Django setup.
  doCheck = false;

  meta = with stdenv.lib; {
    description = "py.test plugin for testing of Django applications";
    homepage = http://pytest-django.readthedocs.org/en/latest/;
    license = licenses.bsd3;
  };
}
