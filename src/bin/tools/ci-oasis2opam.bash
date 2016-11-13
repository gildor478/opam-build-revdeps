. "$(dirname $0)/ci-opam.bash" || exit 1
opam install oasis2opam oasis

restore_oasis () {
  git checkout origin/master -- _oasis 
}

# Merge with current master branch.
restore_oasis
VERSION="$(oasis -ignore-plugins query version)-$(date +'%Y-%m-%dT%H:%M:%S%:z')"

# Generate opam files.
# TODO: remove when oasis2opam will support BugReports field.
sed -i "s/BugReports:/XBugReports:/" _oasis
sed -i "s/^Version:.*/Version: ${VERSION}/" _oasis
oasis2opam --local -y

# Commit changes.
restore_oasis
git add opam _oasis_remove.ml opam-build-revdeps.install
git commit  -m "Setup OPAM pinning v${VERSION}."
