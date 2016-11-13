export OPAMROOT="$HOME/.opam"
export OCAMLRUNPARAM=b
. "$(dirname "$0")/ci-opam.bash" || exit 1
. "$(dirname "$0")/ci-packages.bash" || exit 1
opam install $OPAM_PKGS
ocaml setup.ml -configure
ocaml setup.ml -build
