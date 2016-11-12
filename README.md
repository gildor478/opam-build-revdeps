[![Travis-CI Build Status](https://travis-ci.org/gildor478/opam-build-revdeps.svg?branch=master)](https://travis-ci.org/gildor478/opam-build-revdeps)

<!--- OASIS_START --->
<!--- DO NOT EDIT (digest: 0960dc0edb22b48e6a11234160d6d656) --->

opam-build-revdeps - Build reverse dependencies of a package in OPAM.
=====================================================================

opam-build-revdeps builds the reverse dependencies of a given OPAM package.
It can also build two different versions of the same package, in order to
compare the results.

This program has been designed to test what can other packages can break in
OPAM, if we inject a new version. It was specifically targeted to check OASIS
reverse dependencies.

See the file [INSTALL.md](INSTALL.md) for building and installation
instructions.

[Home page](https://github.com/gildor478/opam-build-revdeps)

Copyright and license
---------------------

(C) 2016 Sylvain Le Gall

opam-build-revdeps is distributed under the terms of the GNU Lesser General
Public License version 2.1 with OCaml linking exception.

<!--- OASIS_STOP --->

Typical usage
-------------

### Compare the two last version in OPAM

```
$> opam-build-revdeps compare --package oasis
```

If the version of OASIS in OPAM are 0.4.5, 0.4.6 and 0.4.7. The command above
will build 0.4.6 and 0.4.7.

[HTML Results](https://gildor478.github.io/opam-build-revdeps/oasis-0.4.6-0.4.7.html)


## Compare the last version and dev. version

```
$> compare --package oasis \
		--version1 latest \
    --version2 latest -pin2 'oasis:git://github.com/ocaml/oasis#opam/unstable'
```

This will build the last version in official OPAM repository, pin a new oasis
repository and built the version from there.
