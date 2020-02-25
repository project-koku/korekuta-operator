OS := $(shell uname)
ifeq ($(OS),Darwin)
	PREFIX	=
else
	PREFIX	= sudo
endif

help:
	@echo "Please use \`make <target>' where <target> is one of:"
	@echo "--- General Commands ---"
	@echo "  test-local            run local molecule tests"

test-local:
	tox -e test-local
