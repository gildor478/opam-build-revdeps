# TODO: reactivate
# . "$(dirname $0)/ci-opam.sh" || exit 1
# opam install oasis2opam oasis

# Merge with current master branch.
git checkout master -- _oasis 
git merge master
VERSION="$(oasis -ignore-plugins query version)-$(date +'%Y-%m-%dT%H:%M:%S%:z')"

# Generate opam files.
# TODO: remove when oasis2opam will support BugReports field.
sed -i "s/BugReports:/XBugReports:/" _oasis
sed -i "s/^Version:.*/Version: ${VERSION}/" _oasis
oasis2opam --local -y

git checkout master -- _oasis

# TODO: activate
# # Commit changes.
# git add opam _oasis_remove.ml opam-build-revdeps.install
# git commit  -m "Setup OPAM pinning v${VERSION}"
# git push
