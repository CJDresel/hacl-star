# A minimalistic Makefile for all testing options.
# Note: on OSX, this necessitates a recent OpenSSL, possibly installed by brew,
# so I had to do:
ifeq (,$(NOOPENSSLCHECK))
include ../Makefile.openssl
endif

include ../dist/gcc-compatible/Makefile.config

KRML_HOME?=../dist/karamel
USER_CFLAGS?=

# Add GF128 tests once code/experimental/gf128 is promoted to code
TARGETS := $(filter-out uint128-%, $(filter-out gf128-%, $(patsubst %.c,%.exe,$(wildcard *.c))))

# The idea of this Makefile is that each test is enabled depending on whether
# the required features for it have been detected by the configure script. The
# eventual goal is to have all tests in this directory be feature-controlled by
# this Makefile, which will remove the distinction between all/ARM: the Makefile
# will automatically strip tests for which features are missing.
#
# In the meanwhile:
# TODO: some tests are still not separated into different files
# Ideally, each algorithm has foo-test, foo-test-128, foo-test-256 and we run
# whatever Makefile.config tells us is supported for the current build
# configuration.

# Vec128
ifneq ($(COMPILE_VEC128),)
CFLAGS += -DHACL_CAN_COMPILE_VEC128
else
TARGETS := $(filter-out %-128-test-streaming.exe, $(filter-out %-128-test.exe, $(TARGETS)))
endif

# Vec256
ifneq ($(COMPILE_VEC256),)
CFLAGS += -DHACL_CAN_COMPILE_VEC256
else
TARGETS := $(filter-out %-256-test-streaming.exe, $(filter-out %-256-test.exe, $(TARGETS)))
endif

# Curve64
ifneq ($(COMPILE_INTRINSICS),)
CFLAGS += -DHACL_CAN_COMPILE_INTRINSICS
else
endif

ifneq ($(COMPILE_INLINE_ASM),)
CFLAGS += -DHACL_CAN_COMPILE_INLINE_ASM
else
TARGETS := $(filter-out curve64-%, $(TARGETS))
endif

# vec-128-test.c doesn't compile on ARM for some reason
ifeq ($(TARGET_ARCHITECTURE),ARM)
TARGETS := $(filter-out vec-128-test.exe, $(TARGETS))
ifeq ($(COMPILE_VEC128),1)
TARGETS += uint128-intrinsics-test.exe
endif
endif

CFLAGS += -I$(KRML_HOME)/include -I../dist/gcc-compatible \
  -I$(KRML_HOME)/krmllib/dist/minimal \
  -I../secure_api/merkle_tree \
  -O3 $(USER_CFLAGS) -Werror -Wall -Wno-deprecated-declarations -Wno-unused

all: $(TARGETS)

test: $(patsubst %.exe,%.test,$(TARGETS))

# Dependency

.PRECIOUS: %.d

%.d: %.c
	@set -e; rm -f $@; \
	  $(CC) -MM $(CFLAGS) $< > $@.$$$$; \
	  sed 's,\($(notdir $*)\)\.o[ :]*,$(dir $@)\1.o $@ : ,g' < $@.$$$$ > $@; \
	  rm -f $@.$$$$

# Compiling against individual files rather than a whole .a
# Side-effect: running with -B ensures *ALL* files get recompiled with optimized
# flags.

curve64-rfc.exe: $(patsubst %.c,%.o,$(wildcard rfc7748_src/*.c))

# Note that vec-128-test.exe uses lib/c and not dist/gcc-compatible:
# this allows to work on and test the vectorized instructions without
# rebuilding the whole HACL library.
vec-128-test.exe: ../lib/c/libintvector.h vec-128-test.c
	$(CC) -I../lib/c $(CFLAGS) $(CFLAGS_128) $(LDFLAGS) vec-128-test.c -o vec-128-test.exe

%.exe: %.o
	$(CC) $(CFLAGS) $(LDFLAGS) $^ ../dist/gcc-compatible/libevercrypt.a -o $@ -lcrypto

# Running tests

%.test: %.exe
	./$<

gen_uint128_intrinsics_vectors:
	python3 gen_vectors/gen_uint128_intrinsics_vectors.py

format:
	clang-format --style=Mozilla *.c *.h -i

clean:
	rm -f *.exe
