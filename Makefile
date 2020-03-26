OS := $(shell uname)
COMMIT := $(shell git rev-parse HEAD)
ifeq ($(OS),Darwin)
	PREFIX	=
else
	PREFIX	= sudo
endif

help:
	@echo "Please use \`make <target>' where <target> is one of:"
	@echo "--- General Commands ---"
	@echo "  test-local                          run local molecule tests"
	@echo "  run-locally                         run the operator outside of the cluster"
	@echo "  build-operator-image                build and push the image to quay"
	@echo "      username=<quay_username>           @param - Required. The quay.io username where the image should be pushed"
	@echo "  sed-replace-deploy-operator         edit the operator.yaml to have your image name and deploy the operator to the cluster"
	@echo "      username=<quay_username>           @param - Required. The quay.io username where the image is hosted"
	@echo "  deploy-operator                     deploy the operator to the cluster"
	@echo "  deploy-dependencies                 deploy all operator dependencies to the cluster"
	@echo "  deploy-custom-resources             deploy the cost management custom resources to trigger the operator roles"
	@echo "  delete-dependencies-and-resources   delete the custom resources and dependencies in the cluster"
	@echo "  delete-operator                     delete the operator deployment in the cluster"
	@echo "  delete-metering-report-resources    delete the report and report queries created by the setup role in the cluster"

test-local:
	tox -e test-local

run-locally:
	operator-sdk run --local

build-operator-image:
	operator-sdk build quay.io/$(username)/cost-mgmt-operator:v0.0.1 --image-build-args "--build-arg GIT_COMMIT=$(COMMIT)"
	docker push quay.io/$(username)/cost-mgmt-operator:v0.0.1

deploy-operator:
	oc create -f deploy/operator.yaml

sed-replace-deploy-operator:
	sed -i "" 's|{{ REPLACE_IMAGE }}|quay.io/$(username)/cost-mgmt-operator:v0.0.1|g' deploy/operator.yaml
	sed -i "" "s?{{ pull_policy|default('Always') }}?Always?g" deploy/operator.yaml
	oc create -f deploy/operator.yaml

deploy-dependencies:
	oc create -f deploy/crds/cost_mgmt_crd.yaml
	oc create -f deploy/crds/cost_mgmt_data_crd.yaml
	oc create -f deploy/crds/authentication_secret.yaml
	oc create -f deploy/service_account.yaml
	oc create -f deploy/role.yaml
	oc create -f deploy/role_binding.yaml

deploy-custom-resources:
	oc create -f deploy/crds/cost_mgmt_cr.yaml
	oc create -f deploy/crds/cost_mgmt_data_cr.yaml

delete-dependencies-and-resources:
	oc create -f deploy/crds/cost_mgmt_cr.yaml
	oc create -f deploy/crds/cost_mgmt_data_cr.yaml
	oc delete -f deploy/crds/cost_mgmt_crd.yaml
	oc delete -f deploy/crds/cost_mgmt_data_crd.yaml
	oc delete -f deploy/crds/authentication_secret.yaml
	oc delete -f deploy/service_account.yaml
	oc delete -f deploy/role.yaml
	oc delete -f deploy/role_binding.yaml

delete-operator:
	oc delete -f deploy/operator.yaml

delete-metering-report-resources:
	oc delete report cm-openshift-node-labels
	oc delete report cm-openshift-node-labels-lookback
	oc delete report cm-openshift-persistentvolumeclaim
	oc delete report cm-openshift-persistentvolumeclaim-lookback
	oc delete report cm-openshift-usage
	oc delete report cm-openshift-usage-lookback
	oc delete reportquery cm-node-labels-raw
	oc delete reportquery cm-openshift-node-labels
	oc delete reportquery cm-openshift-node-labels-lookback
	oc delete reportquery cm-openshift-persistentvolumeclaim
	oc delete reportquery cm-openshift-persistentvolumeclaim-lookback
	oc delete reportquery cm-openshift-usage
	oc delete reportquery cm-openshift-usage-lookback
	oc delete reportquery cm-persistentvolume-labels-raw
	oc delete reportquery cm-persistentvolumeclaim-labels-raw
	oc delete reportquery cm-pod-cpu-limit-raw
	oc delete reportquery cm-pod-labels-raw
	oc delete reportquery cm-pod-memory-limit-raw
	oc delete reportquery cm-pod-persistentvolumeclaim-info-raw
