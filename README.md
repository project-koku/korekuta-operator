# korekuta-operator

## About

Operator to obtain OCP usage data and upload it to koku. The operator utilizes [ansible](https://www.ansible.com/) to collect usage data from an OCP cluster installation.

You must have access to an OpenShift v.4.3.0+ cluster..

## Development

This project was generated using Operator SDK. For a more in depth understanding of the structure of this repo, see the [user guide](https://github.com/operator-framework/operator-sdk/blob/master/doc/ansible/user-guide.md) that was used to generate it.

This project requires Python 3.6 or greater and Go 1.13 or greater if you plan on running the operator locally. To get started developing against `korekuta-operator` first clone a local copy of the git repository.

```
git clone https://github.com/project-koku/korekuta-operator.git
```

Developing inside a virtual environment is recommended. A Pipfile is provided. Pipenv is recommended for combining virtual environment (virtualenv) and dependency management (pip).

To install pipenv, use pip

```
pip3 install pipenv
```

Then project dependencies and a virtual environment can be created using

```
pipenv install --dev
```

**NOTE:** For Linux systems, use `pipenv --site-packages` or `mkvirtualenv --system-site-packages` to set up the virtual environment. Ansible requires access to libselinux-python, which should be installed system-wide on most distributions.

To activate the virtual environment run

```
pipenv shell
```

Finally, install the Operator SDK CLI using the following [documentation](https://github.com/operator-framework/operator-sdk/blob/master/doc/user/install-operator-sdk.md).

## Testing

We utilize [molecule](https://molecule.readthedocs.io/en/latest/) to test the ansible roles.

```
make test-local
```
## Setup for running the Operator

Switch to the OpenShift project called `openshift-metering`:

```
oc project openshift-metering
```

OpenShift needs to know about the new custom resource definitions that the operator will be watching. Make sure that you are logged into a cluster and run the following command to deploy the CRDs:

```
oc create -f deploy/crds/cost_mgmt_crd.yaml
oc create -f deploy/crds/cost_mgmt_data_crd.yaml
```

We also need to deploy the ConfigMap containing the certificate authority chain for ssl verification when uploading the cost reports to ingress. This must be done before deploying the Operator because it is consumed through a volume:

```
oc create -f deploy/crds/trusted_ca_certmap.yaml
```

## Building & running the operator outside of a cluster

When running locally, we need to make sure that the path to the role in the `watches.yaml` points to an existing path on our local machine. Edit the `watches.yaml` to contain the absolute path to the setup and collect roles in the current repository:

```
# initial setup steps
- version: v1alpha1
  group: cost-mgmt.openshift.io
  kind: CostManagement
  role: /ABSOLUTE_PATH_TO/korekuta-operator/roles/setup

# collect the reports
- version: v1alpha1
  group: cost-mgmt-data.openshift.io
  kind: CostManagementData
  role: /ABSOLUTE_PATH_TO/korekuta-operator/roles/collect
  reconcilePeriod: 360m
```

Finally, run the operator locally:

```
operator-sdk run --local
```

You will see some info level logs about the operator starting up. The operator works by watching for a known resource and then triggering a role based off of the presence of that resource.

## Building & running the Operator as a pod inside the cluster

Build the cost-mgmt-operator image and push it to a registry:

```
operator-sdk build quay.io/example/cost-mgmt-operator:v0.0.1
docker push quay.io/example/cost-mgmt-operator:v0.0.1
```

OpenShift deployment manifests are generated in deploy/operator.yaml. The deployment image in this file needs to be modified from the placeholder REPLACE_IMAGE to the previous built image. To do this run:

```
sed -i 's|{{ REPLACE_IMAGE }}|quay.io/example/cost-mgmt-operator:v0.0.1|g' deploy/operator.yaml
```

Note: If you are performing these steps on OSX, use the following sed commands instead:

```
sed -i "" 's|{{ REPLACE_IMAGE }}|quay.io/example/cost-mgmt-operator:v0.0.1|g' deploy/operator.yaml
```

Under the quay repository settings, make sure that you change the `Repository Visibility` to public. Now, deploy the cost-mgmt-operator:

```
oc create -f deploy/service_account.yaml
oc create -f deploy/role.yaml
oc create -f deploy/role_binding.yaml
oc create -f deploy/operator.yaml
```

Note: If you get an error about the `ImagePullPolicy` when deploying the operator, search for and replace `"{{ pull_policy|default('Always') }}"` with `"Always"` inside of the `deploy/operator.yaml` and redeploy the operator.

Verify that the cost-mgmt-operator is up and running:

```
oc get deployment
NAME                     DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
cost-mgmt-operator
```

In order to see the logs from the operator deployment you can run:

```
oc logs -f deployment/cost-mgmt-operator --container ansible
oc logs -f deployment/cost-mgmt-operator --container operator
```

## Kicking off the roles

The setup role is going to create the reports defined in `roles/setup/files` using the namespace defined inside of `roles/setup/defaults/main.yml`. The default is `openshift-metering`.

To start the setup and collect role, the associated custom resource in the `watches.yml` has to be present. Before deploying the `cost_mgmt_cr.yaml` edit it to have your cluster ID and Reporting Operator service account token name instead of the placeholders. For example, if your cluster ID is `123a45b6-cd8e-9101-112f-g131415hi1jk`, your service account token name is `reporting-operator-token-123ab`, you want to use basic auth and the name of your authentication secret is `basic_auth_creds-123ab`, the `deploy/crds/cost_mgmt_cr.yaml` should look like the following:

```
---

apiVersion: cost-mgmt.openshift.io/v1alpha1
kind: CostManagement
metadata:
  name: cost-mgmt-setup
spec:
  clusterID: '123a45b6-cd8e-9101-112f-g131415hi1jk'
  reporting_operator_token_name: 'reporting-operator-token-123ab'
  validate_cert: 'false'
  authentication: 'basic'
  authentication_secret_name: 'basic_auth_creds-123ab'
```

Note: You can also specify the `ingress_url` inside of the CostManagement CR. This will allow you to upload to different environments. When you specify that you want to use ``basic`` authentication inside of the CostManagement CR you must deploy the authentication secret that holds your base64 encoded username and password. If you use token authentication (the default), you should pull the token from the `openshift-config` namespace in a secret called `pull-secret` which has a `data` section that contains a `.dockerconfigjson`. In the `.dockerconfigjson` you need to grab the `auth` value associated with `cloud.openshift.com`. You can save this as the token for your secret. Feel free to use the authentication secret template at ``deploy/crds/authentication_secret.yaml`` but make sure that you edit the name to match the `authentication_secret_name` inside of the CostManagement CR.

Then deploy the authentication secret using the following:

```
oc create -f deploy/crds/authentication_secret.yaml
```

Run the following to create both a CostManagement CR and a CostManagementData CR:

```
oc create -f deploy/crds/cost_mgmt_cr.yaml
oc create -f deploy/crds/cost_mgmt_data_cr.yaml
```

You should now see the Ansible logs from the setup role.

## Running Ansible locally for development

When developing and debugging roles locally, it can be quicker to run via Ansible than through the Operator.

At the top level directory, create a `playbook.yml` file:

```
---
- hosts: localhost
  roles:
    - setup
```

The above example points to the setup role but can be modified to point at any role. Use the following command to run the playbook:

```
ansible-playbook playbook.yml
```
This should show you the same output as if the role was being ran inside of the Operator. Once you are satisfied with the output of your role, test it by running the Operator locally.


## Cleaning up resources

After testing, you can cleanup the resources using the following:

```
oc delete -f deploy/crds/cost_mgmt_cr.yaml
oc delete -f deploy/crds/cost_mgmt_crd.yaml
oc delete -f deploy/crds/trusted_ca_certmap.yaml
oc delete -f deploy/crds/authentication_secret.yaml
oc delete -f deploy/operator.yaml
oc delete -f deploy/role_binding.yaml
oc delete -f deploy/role.yaml
oc delete -f deploy/service_account.yaml
```
