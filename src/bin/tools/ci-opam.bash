# Install required tools.
export OPAMYES=1
export OPAMROOT="$(pwd)/.opam"
if [ -f "$OPAMROOT/config" ]; then
    opam update
    opam upgrade
else
    opam init
fi
eval `opam config env`
