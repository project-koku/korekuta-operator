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

## Building & running the operator outside of a cluster

Switch to the OpenShift project called `openshift-metering`:

```
oc project openshift-metering
```

Although we are not going to run as a pod inside the cluster, OpenShift needs to know about the new custom resource definitions that the operator will be watching. Make sure that you are logged into a cluster and run the following command to deploy the CRD:

```
oc create -f deploy/crds/cost_mgmt_crd.yaml
```

Next, since we are running locally, we need to make sure that the path to the role in the `watches.yaml` points to an existing path on our local machine. Edit the `watches.yaml` to contain the absolute path to the setup role in the current repository:

```
# initial setup steps
- version: v1alpha1
  group: cost-mgmt.openshift.io
  kind: CostManagement
  role: /ABSOLUTE_PATH_TO/korekuta-operator/roles/setup
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
sed -i 's|REPLACE_IMAGE|quay.io/example/cost-mgmt-operator:v0.0.1|g' deploy/operator.yaml
```

Note If you are performing these steps on OSX, use the following sed commands instead:

```
sed -i "" 's|REPLACE_IMAGE|quay.io/example/cost-mgmt-operator:v0.0.1|g' deploy/operator.yaml
```

Under the quay repository settings, make sure that you change the `Repository Visibility` to public. Now, deploy the cost-mgmt-operator:

```
oc create -f deploy/service_account.yaml
oc create -f deploy/role.yaml
oc create -f deploy/role_binding.yaml
oc create -f deploy/operator.yaml
```

Verify that the cost-mgmt-operator is up and running:

```
oc get deployment
NAME                     DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
cost-mgmt-operator
```

In order to see the logs from a particular you can run:

```
oc logs deployment/cost-mgmt-operator
```

## Kicking off the setup role
The setup role is going to create the reports defined in `roles/setup/files` using the namespace defined inside of `roles/setup/defaults/main.yml`. The default is `openshift-metering`.

To start the setup role, a CostManagement custom resource has to be present. Run the following to create a CostManagement CR:

```
oc create -f deploy/crds/cost_mgmt_cr.yaml
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
oc delete -f deploy/operator.yaml
oc delete -f deploy/role_binding.yaml
oc delete -f deploy/role.yaml
oc delete -f deploy/service_account.yaml
```
