# korekuta-operator

## About
Operator to obtain OCP usage data and upload it to masu. The operator utilizes [ansible](https://www.ansible.com/) to collect usage data from an OCP cluster installation.

You must have access to a Kubernetes v.1.9.0+ cluster.

## Development

This project was generated using Operator SDK. For a more in depth understanding of the structure of this repo, see the [user guide](https://github.com/operator-framework/operator-sdk/blob/master/doc/ansible/user-guide.md) that was used to generate it.

This is a go project and requires a go version of `1.13+`. To get started developing against `korekuta-operator` first clone a local copy of the git repository.

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

## Testing

We utilize [molecule](https://molecule.readthedocs.io/en/latest/) to test the ansible roles.

```
molecule test -s test-local
```

## Building & running the operator outside of a cluster

Although we are not going to run as a pod inside the cluster, Kubernetes needs to know about the new custom resource definition the operator will be watching. Make sure that you are logged into a cluster and run the following command to deploy the CRD:

```
kubectl create -f deploy/crds/cache.example.com_memcacheds_crd.yaml
```

Next, since we are running locally, we need to make sure that the path to the role in the `watches.yaml` points to an existing path on our local machine. Edit the `watches.yaml` to contain the absolute path to the memcached role in the current repository:

```
- version: v1alpha1
  group: cache.example.com
  kind: Memcached
  role: /ABSOLUTE_PATH_TO/korekuta-operator/roles/memcached
```

Finally, run the operator locally:

```
operator-sdk run --local
```

You will see some info level logs.