SHELL := /usr/bin/env bash

CACHIX_CACHE = datakurre

PYTHON ?= python37
PLONE ?= plone521

NIX_ARGS ?= \
	--argstr python $(PYTHON) \
	--argstr plone $(PLONE)

.PHONY: all
all:

.cache:
	if [ -d ~/.cache/pip ]; then mkdir -p ./.cache && ln -sf ~/.cache/pip ./.cache/pip; else mkdir -p .cache; fi

.PHONY: nix-%
nix-%:
	nix-shell $(NIX_ARGS) --run "$(MAKE) $*"

.PHONY: cachix
cachix:
	nix-store --query --references $$(nix-instantiate shell.nix) --references $$(nix-instantiate setup.nix -A plonePython)  | \
	xargs nix-store --realise | xargs nix-store --query --requisites | cachix push $(CACHIX_CACHE)

.PHONY: requirements
requirements: requirements-$(PLONE)-$(PYTHON).nix

requirements-$(PLONE)-$(PYTHON).nix: .cache requirements.txt requirements-$(PLONE)-$(PYTHON).txt constraints-$(PLONE).txt
	nix-shell setup.nix $(NIX_ARGS) -A pip2nix --run "pip2nix generate -r requirements.txt -r requirements-$(PLONE)-$(PYTHON).txt --output=requirements-$(PLONE)-$(PYTHON).nix"

requirements-$(PLONE)-$(PYTHON).txt: .cache requirements.txt requirements-$(PLONE).txt constraints-$(PLONE).txt
	nix-shell setup.nix $(NIX_ARGS) -A pip2nix --run "pip2nix generate -r requirements.txt -r requirements-$(PLONE).txt -c constraints-$(PLONE).txt --output=requirements-$(PLONE)-$(PYTHON).nix"
	@grep "pname =\|version =" requirements-$(PLONE)-$(PYTHON).nix|awk "ORS=NR%2?FS:RS"|sed 's|.*"\(.*\)";.*version = "\(.*\)".*|\1==\2|' > requirements-$(PLONE)-$(PYTHON).txt

.PHONY: shell
shell:
	nix-shell $(NIX_ARGS)

###

bin/instance: buildout.cfg
	buildout install instance

env:
	nix-build $(NIX_ARGS) setup.nix -A plonePython -o env

.PHONY: watch
watch: bin/instance
	LC_ALL=C bin/instance fg
