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

Although we are not going to run as a pod inside the cluster, OpenShift needs to know about the new custom resource definitions that the operator will be watching. Make sure that you are logged into a cluster and run the following command to deploy the CRDs:

```
oc create -f deploy/crds/cache.example.com_memcacheds_crd.yaml
oc create -f deploy/crds/korekuta_crd.yaml
```

Next, since we are running locally, we need to make sure that the path to the role in the `watches.yaml` points to an existing path on our local machine. Edit the `watches.yaml` to contain the absolute path to the memcached role and the setup role in the current repository:

```
- version: v1alpha1
  group: cache.example.com
  kind: Memcached
  role: /ABSOLUTE_PATH_TO/korekuta-operator/roles/memcached

# initial setup steps
- version: v1alpha1
  group: korekuta.example.com
  kind: Korekuta
  role: /ABSOLUTE_PATH_TO/korekuta-operator/roles/
```

Finally, run the operator locally:

```
operator-sdk run --local
```

You will see some info level logs about the operator starting up. In order to kick off the memcached role, we want to deploy a Memcached CR.
Edit the `deploy/crds/cache.example.com_v1alpha1_memcached_cr.yaml` as follows:

```
apiVersion: "cache.example.com/v1alpha1"
kind: "Memcached"
metadata:
  name: "example-memcached"
spec:
  size: 3
```
Now create a Memcached custom resource:

```
oc apply -f deploy/crds/cache.example.com_v1alpha1_memcached_cr.yaml
```
You should now see ansible log output from the memcached role.

The setup role is going to create the files inside of `roles/setup/files` inside of the namespace defined inside of `roles/setup/defaults/main.yml`. The default is a namespace called `testing_korekuta`. If this namespace does not exist, create it using the following command:

```
oc new-project testing_korekuta
```

To start the setup role, a Korekuta custom resource has to be present. Run the following to create a Korekuta CR:

```
oc create -f korekuta_cr.yaml
```

You should now see the Ansible logs from the setup role.

## Running Ansible locally for development

When developing and debugging roles locally, it can be quicker to run via Ansible than through the Operator. At the top level directory, there is a `playbook.yml` file. It currently points to the setup role, but can be edited to point at any role. Use the following command to run the playbook:

```
ansible-playbook playbook.yml
```
This should show you the same output as if the role was being ran inside of the Operator. Once you are satisfied with the output of your role, test it by running the Operator locally.
