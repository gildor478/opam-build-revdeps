
default: self-test

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

SELF_TEST_ARGS=
SELF_TEST_ARGS+=--dry_run
SELF_TEST_ARGS+=--only zipperposition
SELF_TEST_ARGS+=--only bistro
SELF_TEST_ARGS+=--only bap-warn-used
SELF_TEST_ARGS+=--only maildir
SELF_TEST_ARGS+=--only expect

self-test: build
	./OPAMBuildRevdeps.native attach_logs \
		--log tmp/full-2016-10-30-logs.txt \
		--result tmp/full-2016-10-30-output.bin
#	./OPAMBuildRevdeps.native build --package oasis \
#		--exclude bap-std $(SELF_TEST_ARGS) 2>&1 | tee logs.txt

.PHONY: self-test
