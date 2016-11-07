OPAM_PKGS="ocamlify fileutils opam-lib uuidm calendar cmdliner re jingoo oasis"

export OPAMYES=1
if [ -f "$HOME/.opam/config" ]; then
    opam update
    opam upgrade
else
    opam init
fi
if [ -n "${OPAM_SWITCH}" ]; then
    opam switch ${OPAM_SWITCH}
fi
eval `opam config env`

opam install $OPAM_PKGS

export OCAMLRUNPARAM=b

ocaml setup.ml -configure
ocaml setup.ml -build
