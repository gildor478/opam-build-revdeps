################################################################################
#  opam-build-revdeps: build reverse dependencies of a package in OPAM.        #
#                                                                              #
#  Copyright (C) 2016, Sylvain Le Gall                                         #
#                                                                              #
#  This library is free software; you can redistribute it and/or modify it     #
#  under the terms of the GNU Lesser General Public License as published by    #
#  the Free Software Foundation; either version 2.1 of the License, or (at     #
#  your option) any later version, with the OCaml static compilation           #
#  exception.                                                                  #
#                                                                              #
#  This library is distributed in the hope that it will be useful, but         #
#  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY  #
#  or FITNESS FOR A PARTICULAR PURPOSE. See the file COPYING for more          #
#  details.                                                                    #
#                                                                              #
#  You should have received a copy of the GNU Lesser General Public License    #
#  along with this library; if not, write to the Free Software Foundation,     #
#  Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA               #
################################################################################

default: self-compare

# OASIS_START
# DO NOT EDIT (digest: a3c674b4239234cbbe53afe090018954)

SETUP = ocaml setup.ml

build: setup.data
	$(SETUP) -build $(BUILDFLAGS)

doc: setup.data build
	$(SETUP) -doc $(DOCFLAGS)

test: setup.data build
	$(SETUP) -test $(TESTFLAGS)

all:
	$(SETUP) -all $(ALLFLAGS)

install: setup.data
	$(SETUP) -install $(INSTALLFLAGS)

uninstall: setup.data
	$(SETUP) -uninstall $(UNINSTALLFLAGS)

reinstall: setup.data
	$(SETUP) -reinstall $(REINSTALLFLAGS)

clean:
	$(SETUP) -clean $(CLEANFLAGS)

distclean:
	$(SETUP) -distclean $(DISTCLEANFLAGS)

setup.data:
	$(SETUP) -configure $(CONFIGUREFLAGS)

configure:
	$(SETUP) -configure $(CONFIGUREFLAGS)

.PHONY: build doc test all install uninstall reinstall clean distclean configure

# OASIS_STOP

# Clean extra files.
#  Remove extra files.

clean-extra:
	$(RM) output.html
	$(RM) run1.bin
	$(RM) run2.bin
	$(RM) logs.txt

clean: clean-extra
distclean: clean-extra

.PHONY: clean-extra

# Live tests
#  Really use the executable.

SELF_TEST_ARGS=
SELF_TEST_ARGS+=--only zipperposition
SELF_TEST_ARGS+=--only bistro
SELF_TEST_ARGS+=--only bap-warn-used
SELF_TEST_ARGS+=--only maildir
SELF_TEST_ARGS+=--only expect
SELF_TEST_ARGS+=--exclude bap-std

OUTPUT_PREFIX=tmp/partial-
OPAM_BUILD_REVDEPS=./OPAMBuildRevdeps.native
RUN1_PACKAGE=oasis.0.4.6
RUN2_PACKAGE=oasis.0.4.7

tmp/run1-output.bin: build
	$(OPAM_BUILD_REVDEPS) build --package $(RUN1_PACKAGE) \
		--output $@ $(SELF_TEST_ARGS) 2>&1 | tee tmp/run1-logs.txt
	$(OPAM_BUILD_REVDEPS) attach_logs --log tmp/run1-logs.txt --run $@ \
		> tmp/run1-attach_logs.txt 2>&1

tmp/run2-output.bin: build
	$(OPAM_BUILD_REVDEPS) build --package $(RUN2_PACKAGE) \
		--output $@ $(SELF_TEST_ARGS) 2>&1 | tee tmp/run2-logs.txt
	$(OPAM_BUILD_REVDEPS) attach_logs --log tmp/run2-logs.txt --run $@ \
		> tmp/run2-attach_logs.txt 2>&1

self-test: tmp/run1-output.bin tmp/run2-output.bin build
	$(OPAM_BUILD_REVDEPS) html \
		--run1_input tmp/run1-output.bin \
		--run2_input tmp/run2-output.bin \
		--output tmp/output.html

self-compare: build
	#$(OPAM_BUILD_REVDEPS) compare --package oasis --only zipperposition \
	#	--version1 latest --version2 latest \
	#	--pin2 'oasis:git://github.com/ocaml/oasis#opam/unstable'
	$(OPAM_BUILD_REVDEPS) html \
		--run1_input run1.bin \
		--run2_input run2.bin \
		--output output.html

.PHONY: self-test self-compare

# Headache target
#  Fix license header of file.

# TODO: update headache...
headache:
	find ./ \
	  -name .git -prune -false \
	  -o -name _build -prune -false \
	  -o -name dist -prune -false \
	  -o -name tmp -prune -false \
	  -o -name '*[^~]' -type f \
	  | xargs /usr/bin/headache -h _header -c _headache.config

.PHONY: headache

# Deploy target
#  Deploy/release the software.

deploy: headache
	mkdir dist || true
	admin-gallu-deploy --verbose
	admin-gallu-oasis-increment
	git commit -am "Update OASIS version."

.PHONY: deploy
