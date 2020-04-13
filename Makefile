OS := $(shell uname)
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
	@echo "  deploy-operator-quay-user           edit the operator.yaml to have your image name and deploy the operator to the cluster"
	@echo "      username=<quay_username>           @param - Required. The quay.io username where the image is hosted"
	@echo "  deploy-operator-dev-branch          edit the operator.yaml to have your image name and deploy the operator to the cluster"
	@echo "      branch=<git_branch>                @param - Required. The git branch name for the development image"
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
	operator-sdk build quay.io/$(username)/cost-mgmt-operator:v0.0.1
	docker push quay.io/$(username)/cost-mgmt-operator:v0.0.1

deploy-operator:
	oc create -f testing/operator.yaml

deploy-operator-quay-user:
	sed -i "" 's|{{ REPLACE_IMAGE }}|quay.io/$(username)/cost-mgmt-operator:v0.0.1|g' testing/operator.yaml
	sed -i "" "s?{{ pull_policy|default('Always') }}?Always?g" deploy/operator.yaml
	oc create -f testing/operator.yaml

deploy-operator-dev-branch:
	sed -i "" 's|{{ REPLACE_IMAGE }}|quay.io/project-koku/korekuta-operator:$(branch)|g' testing/operator.yaml
	sed -i "" "s?{{ pull_policy|default('Always') }}?Always?g" deploy/operator.yaml
	oc create -f testing/operator.yaml

deploy-dependencies:
	oc create -f deploy/crds/cost_mgmt_crd.yaml || true
	oc create -f deploy/crds/cost_mgmt_data_crd.yaml || true
	oc create -f testing/authentication_secret.yaml
	oc create -f deploy/service_account.yaml
	oc create -f deploy/role.yaml
	oc create -f deploy/role_binding.yaml

deploy-custom-resources:
	oc create -f testing/cost_mgmt_cr.yaml
	oc create -f deploy/crds/cost_mgmt_data_cr.yaml

delete-dependencies-and-resources:
	oc delete -f testing/cost_mgmt_cr.yaml
	oc delete -f deploy/crds/cost_mgmt_data_cr.yaml
	oc delete -f deploy/crds/cost_mgmt_crd.yaml
	oc delete -f deploy/crds/cost_mgmt_data_crd.yaml
	oc delete -f testing/authentication_secret.yaml
	oc delete -f deploy/service_account.yaml
	oc delete -f deploy/role.yaml
	oc delete -f deploy/role_binding.yaml

delete-operator:
	oc delete -f testing/operator.yaml

delete-metering-report-resources:
	oc delete report cm-openshift-node-labels || true
	oc delete -f roles/setup/files || true
	oc delete report --selector cost-management=true || true
