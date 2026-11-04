SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

CLUSTER ?= platform
K3D_CONFIG := cluster/k3d-config.yaml
TF := terraform -chdir=terraform
TF_FLAGS := -input=false -no-color

.PHONY: help cluster-up cluster-down init apply destroy test up down fmt validate clean

help: ## List the available targets
	@grep -hE '^[a-z][a-z-]*:.*##' $(MAKEFILE_LIST) | \
		awk -F':.*##[[:space:]]*' '{ printf "%-14s %s\n", $$1, $$2 }'

cluster-up: ## Create the k3d cluster from the declarative config
	k3d cluster create --config $(K3D_CONFIG) --wait

cluster-down: ## Delete the k3d cluster and its registry
	k3d cluster delete $(CLUSTER)

init: ## Download the Terraform providers
	$(TF) init $(TF_FLAGS)

# Two passes on purpose: kubernetes_manifest resolves the resource schema during
# plan, so the cert-manager CRDs must exist before Terraform plans the
# ClusterIssuer. depends_on orders the apply, not the plan.
apply: ## Install the platform on the cluster
	$(TF) apply $(TF_FLAGS) -auto-approve -target=helm_release.cert_manager
	$(TF) apply $(TF_FLAGS) -auto-approve

destroy: ## Uninstall the platform and keep the cluster running
	$(TF) destroy $(TF_FLAGS) -auto-approve

test: ## Run the smoke test against the cluster
	bash tests/smoke.sh

up: ## Cluster plus platform, from zero to ready
	$(MAKE) cluster-up
	$(MAKE) init
	$(MAKE) apply

down: ## Undo everything up did
	-$(MAKE) destroy
	$(MAKE) cluster-down

fmt: ## Format the Terraform files
	$(TF) fmt -recursive

validate: ## Check formatting and Terraform, shell and YAML syntax
	$(TF) fmt -check -recursive
	$(TF) init -backend=false $(TF_FLAGS)
	$(TF) validate
	shellcheck tests/smoke.sh
	yamllint -c .yamllint.yml cluster/ terraform/values/ .github/

clean: ## Delete local Terraform artifacts
	rm -rf terraform/.terraform terraform/tfplan
