# opencode global : pilotage des scripts via make.
#
#   make install      # écrit la config, installe les agents, monte le serveur
#   make diag         # diagnostique pourquoi le provider Ollama est ignoré
#   make fix          # recharge (ou démarre) le serveur
#   make restart      # redémarre le serveur
#   make stop         # arrête le serveur
#   make status       # le serveur répond-il ?
#   make logs         # suit les logs d'erreur du serveur
#   make refresh      # rafraîchit la liste des modèles depuis Ollama
#   make pin TAG=...  # épingle un modèle partout (config + agents)
#   make oc ARGS="..."        # TUI rattachée au serveur (dossier courant)
#   make ocr ARGS="..."       # prompt one-shot, sans TUI
#   make occ ARGS="..."       # reprend la dernière session
#   make ocA ARGS='infra "monte la stack"'   # agent précis

SHELL := /bin/bash

OLLAMA_URL        ?= http://192.168.2.40:11434
OPENCODE_SERVER_URL ?= http://127.0.0.1:4099
LABEL             := net.famillelallier.opencode
PLIST             := $(HOME)/Library/LaunchAgents/$(LABEL).plist
ERRLOG            := $(HOME)/Library/Logs/opencode-serve.err.log

.SHELLFLAGS := -ec

.PHONY: all
all:
	@echo "cibles disponibles :"
	@echo "  install   diag   fix   restart   stop   status   logs   refresh   pin   oc   ocr   occ   ocA   clean"
	@echo
	@echo "usage :"
	@echo "  make install            écrit la config, installe les agents, monte le serveur"
	@echo "  make diag              diagnostique pourquoi le provider Ollama est ignoré"
	@echo "  make fix               recharge (ou démarre) le serveur"
	@echo "  make restart           redémarre le serveur (relit toute la config)"
	@echo "  make stop              arrête le serveur"
	@echo "  make status            le serveur répond-il ?"
	@echo "  make logs              suit les logs d'erreur du serveur"
	@echo "  make refresh           rafraîchit la liste des modèles depuis Ollama"
	@echo "  make pin TAG=...        épingle un modèle partout (config + agents)"
	@echo "  make oc ARGS=\"...\"      TUI rattachée au serveur (dossier courant)"
	@echo "  make ocr ARGS=\"...\"     prompt one-shot, sans TUI"
	@echo "  make occ ARGS=\"...\"     reprend la dernière session"
	@echo "  make ocA ARGS='infra \"monte la stack\"'   agent précis"
	@echo
	@echo "variables : OLLAMA_URL   OPENCODE_SERVER_URL   TAG   ARGS"

.PHONY: install
install:
	@OLLAMA_URL="$(OLLAMA_URL)" ./install.sh

.PHONY: diag
diag:
	@./diag.sh

.PHONY: fix
fix:
	@./fix-service.sh

.PHONY: restart
restart:
	@launchctl kickstart -k "gui/$$(id -u)/$(LABEL)"

.PHONY: stop
stop:
	@launchctl bootout "gui/$$(id -u)/$(LABEL)"

.PHONY: status
status:
	@if curl -fsS --max-time 2 "$(OPENCODE_SERVER_URL)/doc" >/dev/null 2>&1; then \
		echo "opencode UP   -> $(OPENCODE_SERVER_URL)"; \
	else \
		echo "opencode DOWN. relancez : make fix"; \
	fi

.PHONY: logs
logs:
	@tail -f "$(ERRLOG)"

.PHONY: refresh
refresh:
	@python3 $(HOME)/.config/opencode/refresh-models.py --url "$(OLLAMA_URL)"

.PHONY: pin
pin:
	@./pin-model.sh $(if $(TAG),$(TAG),)

.PHONY: oc
oc:
	@opencode attach "$(OPENCODE_SERVER_URL)" --dir "$$PWD" $(ARGS)

.PHONY: ocr
ocr:
	@opencode run --attach "$(OPENCODE_SERVER_URL)" --dir "$$PWD" $(ARGS)

.PHONY: occ
occ:
	@opencode attach "$(OPENCODE_SERVER_URL)" --dir "$$PWD" --continue $(ARGS)

# ocA : `make ocA ARGS='infra "monte la stack"'`
#   ou, sans espace dans l'agent, : make ocA ARG... via ARGS
.PHONY: ocA
ocA:
	@opencode run --attach "$(OPENCODE_SERVER_URL)" --dir "$$PWD" --agent $(ARGS)

.PHONY: clean
clean:
	@rm -f *.bak-*
	@echo "sauvegardes ( *.bak-* ) effacées"
