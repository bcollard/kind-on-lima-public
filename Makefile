
.ONESHELL:
.DEFAULT_GOAL := help
.PHONY: help start stop

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


dl-install-lima: ## download the provided Lima version (prompt) and install it in the current folder
	@./lima/01-install-lima.sh
	
print-current-instance: ## show the current Lima instance (machine name)
	@echo ${LIMA_INSTANCE}

create: ## create the default Lima instance
	@./lima/02-lima-create.sh; \
	echo "now run: make config-network-end-to-end"

delete: ## delete the default Lima instance
	@./lima/95-lima-delete.sh

start: ## start the default Lima instance
	@./lima/10-lima-start.sh; \
	echo "now run: make config-network-end-to-end"

stop: ## stop the current Lima instance
	@./lima/91-lima-stop.sh

shell: ## open Lima shell
	@./lima/12-lima-shell.sh

clear-obsolete-kind-context: ## remove a kind context from the kubeconfig file 
	@read -p "enter kind context to delete: " CONTEXT; \
	kubectl config delete-context $$CONTEXT; \
	kubectl config delete-cluster $$CONTEXT; \
	kubectl config delete-user $$CONTEXT

kind-create: ## create a new kind cluster. Usage: make kind-create <id> <name>
	@./kind/20-kind-create.sh $(filter-out $@,$(MAKECMDGOALS))

kind-create-triple: ## create three clusters named after Gloo Platform typical arch
	@./kind/22-kind-create-triple.sh

kind-create-three: kind-create-triple

kind-delete: ## delete a kind cluster. Usage: make kind-delete <name>
	@./kind/90-kind-delete.sh $(filter-out $@,$(MAKECMDGOALS))

kind-delete-all: ## delete all kind clusters
	@./kind/93-kind-delete-all.sh

list-machines: ## list Lima machines
	@${LIMACTL_BIN} list

list-kind-clusters: ## list KinD clusters
	@kind get clusters

kind-list: list-kind-clusters

%:
    @:

setup-kind-bridge: ## setup the KinD bridge network
	@./kind/19-kind-bridge.sh

setup-host-network: ## prepare the Host (macbook) for Lima networking
	@./macos-setup/25-network-setup.sh

setup-lima-network: ## prepare the Lima VM for networking
	${LIMA_BIN} -- sh ./lima/35-lima-to-kind-routing.sh

config-network-end-to-end: setup-kind-bridge setup-host-network setup-lima-network ## configure the network end-to-end

test: ## deploy nginx and curl it from the host
	kubectl run nginx --image nginx:1.22; \
	kubectl expose po/nginx --port 80 --type LoadBalancer; \
	kubectl get svc; \
	kubectl wait po --for condition=Ready --timeout 20s nginx; \
	curl --max-time 11 --connect-timeout 10 -I -v $$(kubectl get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

clean-test: ## clean the resources created by the test target
	kubectl delete svc nginx; \
	kubectl delete po nginx;

registries: setup-kind-bridge ## start the registries and try to connect them to the kind network
	@./lima/17-docker-registries.sh

registries-stop: ## stop the registries
	@./lima/18-stop-docker-registries.sh

prepare-mac-host: ## create the lima workdir and save common images to the work dir
	@./macos-setup/05-prepare-mac-host.sh

rename-contexts-workshop: ## rename the contexts of the kind clusters to match the workshop
	@./kind/24-rename-contexts-workshop.sh