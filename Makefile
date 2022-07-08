
.ONESHELL:
.DEFAULT_GOAL := help
.PHONY: help start stop

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


dl-install-lima: ## download the provided Lima version and install it in the current folder
	@read -p "enter Lima version to install: " VERSION; \
	curl -L -v -O https://github.com/lima-vm/lima/releases/download/v$$VERSION/lima-$$VERSION-Darwin-x86_64.tar.gz; \
	tar xvfz lima-$$VERSION-Darwin-x86_64.tar.gz; \
	echo "version $$VERSION installed under ./bin"; \
	./bin/limactl --version


stop: ## stop the current Lima instance
	./lima/91-lima-stop.sh

start: ## start the default Lima instance
	./lima/10-lima-start.sh

delete: ## delete the default Lima instance
	./lima/95-lima-delete.sh

create: ## create the default Lima instance
	./lima/02-lima-create.sh

clear-obsolete-kind-context: ## remove a kind context from the kubeconfig file 
	@read -p "enter kind context to delete: " CONTEXT; \
	kubectl config delete-context $$CONTEXT; \
	kubectl config delete-cluster $$CONTEXT; \
	kubectl config delete-user $$CONTEXT

kind-create: ## create a new kind cluster. Usage: make kind-create <id> <name>
	@./kind/20-kind-create.sh $(filter-out $@,$(MAKECMDGOALS))

kind-delete: ## delete a kind cluster. Usage: make kind-delete <name>
	@./kind/90-kind-delete.sh $(filter-out $@,$(MAKECMDGOALS))

list-kind-clusters: ## list KinD clusters
	@kind get clusters

%:
    @:

setup-host-network: ## prepare the Host (macbook) for Lima networking
	@./macos-setup/25-network-setup.sh


setup-lima-network: ## prepare the Lima VM for networking
	./bin/lima -- sh ./lima/35-lima-to-kind-routing.sh

test: ## delpoy nginx and curl it from the host
	kubectl run nginx --image nginx; \
	kubectl expose po/nginx --port 80 --type LoadBalancer; \
	kubectl get svc; \
	sleep 4; \
	curl -I -v $$(kubectl get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

clean-test: ## clean the resources created by the test target
	kubectl delete svc nginx; \
	kubectl delete po nginx;