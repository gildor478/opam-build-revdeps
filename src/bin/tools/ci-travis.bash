export OPAMROOT="$HOME/.opam"
export OCAMLRUNPARAM=b
. "$(dirname "$0")/ci-build.bash" || exit 1
