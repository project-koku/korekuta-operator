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

First, switch to the OpenShift project called `openshift-metering`. This is where we are going to deploy our Operator and its dependencies:

```
oc project openshift-metering
```
### Authentication setup

Decide if you are going to use `basic` authentication or `token` authentication to upload the Cost Reports to Ingress.

#### Token authentication

The default authentication method is token authentication. Inside of the cluster in the `openshift-config` namespace, there is a secret called `pull-secret` which has a `data` section that contains a `.dockerconfigjson`. In the `.dockerconfigjson` you need to grab the `auth` value associated with `cloud.openshift.com`. Edit the secret found at [deploy/crds/authentication_secret.yaml](https://github.com/project-koku/korekuta-operator/blob/master/deploy/crds/authentication_secret.yaml) to replace the token value with the `auth` value associated with `cloud.openshift.com`.

#### Basic authentication

Since basic authentication is not the default, we have to specify that we want to use it inside our our CostManagement custom resource. Edit the resource at [deploy/crds/cost_mgmt_cr.yaml](https://github.com/project-koku/korekuta-operator/blob/master/deploy/crds/cost_mgmt_cr.yaml) to add an authentication value under the spec. It should look like the following:

```
---

apiVersion: cost-mgmt.openshift.io/v1alpha1
kind: CostManagement
metadata:
  name: cost-mgmt-setup
spec:
  clusterID: 'cluster-id-placeholder'
  reporting_operator_token_name: 'reporting-operator-token-placeholder'
  validate_cert: 'false'
  authentication_secret_name: 'auth-secret-name-placeholder'
  authentication: 'basic'
```

Next, edit the secret found at [deploy/crds/authentication_secret.yaml](https://github.com/project-koku/korekuta-operator/blob/master/deploy/crds/authentication_secret.yaml) to replace the username and password values with your base64 encoded username and password for connecting to [cloud.redhat.com](https://cloud.redhat.com/).

For both methods of authentication, the name of the secret found at [deploy/crds/authentication_secret.yaml](https://github.com/project-koku/korekuta-operator/blob/master/deploy/crds/authentication_secret.yaml) should match the `authentication_secret_name` set in the CostManagement custom resource found at [deploy/crds/cost_mgmt_cr.yaml](https://github.com/project-koku/korekuta-operator/blob/master/deploy/crds/cost_mgmt_cr.yaml).


### Operator Configuration

The `clusterID` and `reporting_operator_token_name` must be set in the CostManagement custom resource found at [deploy/crds/cost_mgmt_cr.yaml](https://github.com/project-koku/korekuta-operator/blob/master/deploy/crds/cost_mgmt_cr.yaml). Change the `clusterID` value to your cluster ID. Change the `reporting_operator_token_name` to be the name of the `reporting-operator-token` secret found inside of the `openshift-metering` namespace. For example, if your cluster ID is `123a45b6-cd8e-9101-112f-g131415hi1jk`, your reporting operator token name is `reporting-operator-token-123ab`, you want to use basic auth and the name of your authentication secret is `basic_auth_creds-123ab`, the `CostManagement` custom resource should look like the following:

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

Note: You can also specify the `ingress_url` inside of the CostManagement CR spec. This will allow you to upload to different environments.

### Creating the dependencies

OpenShift needs to know about the new custom resource definitions that the operator will be watching. Make sure that you are logged into a cluster and run the following command to deploy both the `CostManagment` and `CostManagementData` CRDs, the authentication secret, service account, role, and role binding to the cluster:

```
make deploy-dependencies
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

Now, run the operator locally:

```
make run-locally
```

You will see some info level logs about the operator starting up. The operator works by watching for a known resource and then triggering a role based off of the presence of that resource.

## Building & running the Operator as a pod inside the cluster
Below are flows for the main development team and for external contributors.

### Development team options
If you have pushed your changes to a branch within the repository then an associated image branch will have been built in [quay.io/project-koku/korekuta-operator](https://quay.io/project-koku/korekuta-operator). You need only specify the branch you want to deploy the operator with using the following command:

```
make deploy-operator-dev-branch branch=$GIT_BRANCH
```

### Contributor options
To build the cost-mgmt-operator image and push it to a registry, run the following where `QUAY_USERNAME` is your quay username where the image will be pushed:

```
make build-operator-image username=$QUAY_USERNAME
```
Under the quay repository settings, make sure that you change the `Repository Visibility` to public.

OpenShift deployment manifests are generated in deploy/operator.yaml. The deployment image in this file needs to be modified from the placeholder REPLACE_IMAGE to the previous built image. To correctly SED replace the image and deploy the Operator, run the following where `QUAY_USERNAME` is the username under which the image has been pushed:

```
make deploy-operator-quay-user username=$QUAY_USERNAME
```

### Validating Deployment

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

Note: If you need to redeploy the operator, but do not need to sed replace the `operator.yaml` you can run:

```
make deploy-operator
```

## Kicking off the roles

The setup role is going to create the reports defined in `roles/setup/files` using the namespace defined inside of `roles/setup/defaults/main.yml`. The default is `openshift-metering`.

To start the setup and collect role, the associated custom resource in the `watches.yml` has to be present. To deploy both the `CostManagement` and `CostManagementData` custom resources, run the following:

```
make deploy-custom-resources
```


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
make delete-operator
make delete-dependencies-and-resources
make delete-metering-report-resources
```
