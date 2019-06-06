PROJECT = esqlite
DIALYZER = dialyzer

REBAR3 := $(shell which rebar3 2>/dev/null || echo ./rebar3)
REBAR3_VERSION := 3.10.0
REBAR3_URL := https://github.com/erlang/rebar3/releases/download/$(REBAR3_VERSION)/rebar3

ifeq ($(ERL_EI_INCLUDE_DIR),)
$(error ERL_EI_INCLUDE_DIR not set. Invoke via mix)
endif

ifeq ($(ERL_EI_LIBDIR),)
$(error ERL_EI_LIBDIR not set. Invoke via mix)
endif


# Set Erlang-specific compile and linker flags
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR) -lei

SRC = $(wildcard c_src/*.c)

LDFLAGS ?= -fPIC -shared -pedantic

CFLAGS ?= -fPIC -O2
SQLITE_CFLAGS  = -DSQLITE_ENABLE_COLUMN_METADATA
SQLITE_CFLAGS += -DSQLITE_THREADSAFE=2
#WAL_SYNCHRONOUS sets PRAGMA_synchronous to EXTRA (FULL +1) for maximum data-base's safety following the power loss.
SQLITE_CFLAGS += -DSQLITE_DEFAULT_WAL_SYNCHRONOUS=3
SQLITE_CFLAGS += -DSQLITE_OMIT_DEPRECATED=1
SQLITE_CFLAGS += -DSQLITE_OMIT_SHARED_CACHE=1
SQLITE_CFLAGS += -DSQLITE_ENABLE_COLUMN_METADATA=1
SQLITE_CFLAGS += -DSQLITE_DISABLE_FTS3
SQLITE_CFLAGS += -DSQLITE_ENABLE_LOCKING_STYLE=POSIX
SQLITE_CFLAGS += -DSQLITE_LIKE_DOESNT_MATCH_BLOBS
SQLITE_CFLAGS += -DSQLITE_ENABLE_UNLOCK_NOTIFY=1
SQLITE_CFLAGS += -DSQLITE_ENABLE_FTS3_PARENTHESIS
SQLITE_CFLAGS += -DSQLITE_USE_URI
#Use memory to store temporary files. PRAGMA_temp_store allows to override
SQLITE_CFLAGS += -DSQLITE_TEMP_STORE=2
#SQLITE_CFLAGS += -DSQLITE_CONFIG_MULTITHREAD=1


#-DSQLITE_USE_URI -DSQLITE_ENABLE_FTS3 \
#-DSQLITE_ENABLE_FTS3_PARENTHESIS -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_JSON1 \
#-DSQLITE_ENABLE_RTREE


# dializer
ifdef ESQLITE_USE_SYSTEM
	CFLAGS += -fPIC
	LDFLAGS += -fPIC -shared -pedantic -lsqlite3
else
	SRC += $(wildcard c_src/sqlite3/*.c)
	CFLAGS += $(SQLITE_CFLAGS) -fPIC -Ic_src/sqlite3
endif

OBJ = $(SRC:.c=.o)

NIF=priv/esqlite3_nif.so

all: priv $(NIF)

priv:
	mkdir -p priv

%.o: %.c
	$(CC) -c $(ERL_CFLAGS) $(CFLAGS) -o $@ $<

$(NIF): $(OBJ)
	$(CC) $^ $(ERL_LDFLAGS) $(LDFLAGS) -o $@

clean:
	$(RM) $(NIF)
	$(RM) $(OBJ)

./rebar3:
	wget $(REBAR3_URL)
	chmod +x ./rebar3

compile: rebar3
	$(REBAR3) compile

test: compile
	$(REBAR3) eunit


distclean:
	rm $(REBAR3)

# dializer

build-plt:
	@$(DIALYZER) --build_plt --output_plt .$(PROJECT).plt \
		--apps kernel stdlib

dialyze:
	@$(DIALYZER) --src src --plt .$(PROJECT).plt --no_native \
		-Werror_handling -Wrace_conditions -Wunmatched_returns -Wunderspecs


