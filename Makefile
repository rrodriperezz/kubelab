SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

CLUSTER ?= plataforma
K3D_CONFIG := cluster/k3d-config.yaml
TF := terraform -chdir=terraform
TF_FLAGS := -input=false -no-color

.PHONY: help cluster-up cluster-down init apply destroy test up down fmt validate clean

help: ## Lista los objetivos disponibles
	@grep -hE '^[a-z][a-z-]*:.*##' $(MAKEFILE_LIST) | \
		awk -F':.*##[[:space:]]*' '{ printf "%-14s %s\n", $$1, $$2 }'

cluster-up: ## Crea el cluster k3d desde la configuracion declarativa
	k3d cluster create --config $(K3D_CONFIG) --wait

cluster-down: ## Borra el cluster k3d y su registry
	k3d cluster delete $(CLUSTER)

init: ## Descarga los providers de Terraform
	$(TF) init $(TF_FLAGS)

# Dos pasadas a proposito: kubernetes_manifest resuelve el esquema del recurso
# durante el plan, asi que los CRDs de cert-manager tienen que existir antes de
# que Terraform planifique el ClusterIssuer. depends_on ordena el apply, no el plan.
apply: ## Instala la plataforma sobre el cluster
	$(TF) apply $(TF_FLAGS) -auto-approve -target=helm_release.cert_manager
	$(TF) apply $(TF_FLAGS) -auto-approve

destroy: ## Desinstala la plataforma dejando el cluster en pie
	$(TF) destroy $(TF_FLAGS) -auto-approve

test: ## Corre el smoke test contra el cluster
	bash tests/smoke.sh

up: ## Cluster mas plataforma, de cero a listo
	$(MAKE) cluster-up
	$(MAKE) init
	$(MAKE) apply

down: ## Deshace todo lo que hizo up
	-$(MAKE) destroy
	$(MAKE) cluster-down

fmt: ## Formatea los archivos de Terraform
	$(TF) fmt -recursive

validate: ## Chequea formato, sintaxis de Terraform, shell y YAML
	$(TF) fmt -check -recursive
	$(TF) init -backend=false $(TF_FLAGS)
	$(TF) validate
	shellcheck tests/smoke.sh
	yamllint -c .yamllint.yml cluster/ terraform/values/ .github/

clean: ## Borra los artefactos locales de Terraform
	rm -rf terraform/.terraform terraform/tfplan
