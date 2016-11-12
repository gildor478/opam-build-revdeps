<!--- OASIS_START --->
<!--- DO NOT EDIT (digest: d71c53c3c57334cdeee1291710ae577d) --->

This is the INSTALL file for the opam-build-revdeps distribution.

This package uses OASIS to generate its build system. See section OASIS for
full information.

Dependencies
============

In order to compile this package, you will need:

* ocaml (>= 3.12.1)
* findlib (>= 1.3.1)
* fileutils (>= 0.5.1)
* opam-lib (>= 1.2.2)
* uuidm (>= 0.9.6)
* calendar (>= 2.03)
* cmdliner (>= 0.9)
* re (>= 1.7)
* jingoo (>= 1.2)

Installing
==========

1. Uncompress the source archive and go to the root of the package
2. Run 'ocaml setup.ml -configure'
3. Run 'ocaml setup.ml -build'
4. Run 'ocaml setup.ml -install'

Uninstalling
============

1. Go to the root of the package
2. Run 'ocaml setup.ml -uninstall'

OASIS
=====

OASIS is a program that generates a setup.ml file using a simple '_oasis'
configuration file. The generated setup only depends on the standard OCaml
installation: no additional library is required.

<!--- OASIS_STOP --->
