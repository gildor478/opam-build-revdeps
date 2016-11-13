. "$(dirname "$0")/ci-opam.bash" || exit 1
. "$(dirname "$0")/ci-packages.bash" || exit 1
export OCAMLRUNPARAM=b
ocaml setup.ml -configure
ocaml setup.ml -build
