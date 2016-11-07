
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
#	$(OPAM_BUILD_REVDEPS) build --package $(RUN1_PACKAGE) \
#		--output $@ $(SELF_TEST_ARGS) 2>&1 | tee tmp/run1-logs.txt
	$(OPAM_BUILD_REVDEPS) attach_logs --log tmp/run1-logs.txt --run $@ \
		> tmp/run1-attach_logs.txt 2>&1

tmp/run2-output.bin: build
# 	$(OPAM_BUILD_REVDEPS) build --package $(RUN2_PACKAGE) \
# 		--output $@ $(SELF_TEST_ARGS) 2>&1 | tee tmp/run2-logs.txt
	$(OPAM_BUILD_REVDEPS) attach_logs --log tmp/run2-logs.txt --run $@ \
		> tmp/run2-attach_logs.txt 2>&1

self-test: tmp/run1-output.bin tmp/run2-output.bin build
	$(OPAM_BUILD_REVDEPS) html \
		--run1_input tmp/run1-output.bin \
		--run2_input tmp/run2-output.bin \
		--output tmp/output.html

.PHONY: self-test
