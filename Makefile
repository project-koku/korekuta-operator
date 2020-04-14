OS := $(shell uname)
ifeq ($(OS),Darwin)
	PREFIX	=
else
	PREFIX	= sudo
endif

help:
	@echo "Please use \`make <target>' where <target> is one of:"
	@echo "--- Setup Commands ---"
	@echo "  setup-auth                         setup your authentication secret"
	@echo "      username=<cloud.redhat.com username>       @param - Optional. The cloud.redhat.com username if using basic authentication"
	@echo "      password=<cloud.redhat.com password>       @param - Optional. The cloud.redhat.com password if using basic authentication"
	@echo "  setup-operator                     operator resource configuration"
	@echo "      clusterID=<cluster ID>                     @param - Required. The cluster ID"
	@echo "      report_token_name=<reporting token name>   @param - Required. The name of the reporting operator token"
	@echo "      validate_cert=<validate_boolean>           @param - Optional. Boolean on whether or not to validate the cert when dowloading metering reports. Defaults to false"
	@echo "      authentication=<authentication_method>     @param - Optional. The authentication method. Defaults to token"
	@echo "      ingress_url=<ingress_url>                  @param - Optional. The ingress_url if you want to upload to an environment other than production"
	@echo "--- General Commands ---"
	@echo "  test-local                          run local molecule tests"
	@echo "  run-locally                         run the operator outside of the cluster"
	@echo "  build-operator-image                build and push the image to quay"
	@echo "      username=<quay_username>                   @param - Required. The quay.io username where the image should be pushed"
	@echo "  deploy-operator-quay-user           edit the operator.yaml to have your image name and deploy the operator to the cluster"
	@echo "      username=<quay_username>                   @param - Required. The quay.io username where the image is hosted"
	@echo "  deploy-operator-dev-branch          edit the operator.yaml to have your image name and deploy the operator to the cluster"
	@echo "      branch=<git_branch>                        @param - Required. The git branch name for the development image"
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
	oc apply -f testing/operator.yaml

deploy-operator-quay-user:
	cp deploy/operator.yaml testing/operator.yaml
	sed -i "" 's|{{ REPLACE_IMAGE }}|quay.io/$(username)/cost-mgmt-operator:v0.0.1|g' testing/operator.yaml
	sed -i "" "s?{{ pull_policy|default('Always') }}?Always?g" testing/operator.yaml
	oc apply -f testing/operator.yaml

deploy-operator-dev-branch:
	cp deploy/operator.yaml testing/operator.yaml
	sed -i "" 's|{{ REPLACE_IMAGE }}|quay.io/project-koku/korekuta-operator:$(branch)|g' testing/operator.yaml
	sed -i "" "s?{{ pull_policy|default('Always') }}?Always?g" testing/operator.yaml
	oc apply -f testing/operator.yaml

deploy-dependencies:
	oc apply -f deploy/crds/cost_mgmt_crd.yaml || true
	oc apply -f deploy/crds/cost_mgmt_data_crd.yaml || true
	oc apply -f testing/authentication_secret.yaml
	oc apply -f deploy/service_account.yaml
	oc apply -f deploy/role.yaml
	oc apply -f deploy/role_binding.yaml

deploy-custom-resources:
	oc apply -f testing/cost_mgmt_cr.yaml
	oc apply -f deploy/crds/cost_mgmt_data_cr.yaml

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

get-auth-token:
	@oc project openshift-config > /dev/null
	@oc get secret pull-secret -o "jsonpath={.data.\.dockerconfigjson}" | base64 --decode | jq '.auths."cloud.openshift.com".auth'
	@oc project openshift-metering > /dev/null

# replaces the username and password with your base64 encoded username and password and looks up the token value for you
setup-auth:
	@cp deploy/crds/authentication_secret.yaml testing/authentication_secret.yaml
	@sed -i "" 's/Y2xvdWQucmVkaGF0LmNvbSB1c2VybmFtZQ==/$(shell printf "$(shell echo $(or $(username),cloud.redhat.com username))" | base64)/g' testing/authentication_secret.yaml
	@sed -i "" 's/Y2xvdWQucmVkaGF0LmNvbSBwYXNzd29yZA==/$(shell printf "$(shell echo $(or $(password),cloud.redhat.com password))" | base64)/g' testing/authentication_secret.yaml
	@sed -i "" 's/Y2xvdWQucmVkaGF0LmNvbSB0b2tlbg==/$(shell echo $(shell $(MAKE) get-auth-token))/g' testing/authentication_secret.yaml

setup-operator:
	@cp deploy/crds/cost_mgmt_cr.yaml testing/cost_mgmt_cr.yaml
	@sed -i "" 's/cluster-id-placeholder/$(clusterID)/g' testing/cost_mgmt_cr.yaml
	@sed -i "" 's/reporting-operator-token-placeholder/$(report_token_name)/g' testing/cost_mgmt_cr.yaml
	@sed -i "" 's/false/$(shell echo $(or $(validate_cert),false))/g' testing/cost_mgmt_cr.yaml
	@sed -i "" 's/token/$(shell echo $(or $(authentication),token))/g' testing/cost_mgmt_cr.yaml
	@sed -i "" 's|https://cloud.redhat.com/api/ingress/v1/upload|$(shell echo $(or $(ingress_url),https://cloud.redhat.com/api/ingress/v1/upload))|g' testing/cost_mgmt_cr.yaml

encode:
	printf '$(username)' | openssl base64
