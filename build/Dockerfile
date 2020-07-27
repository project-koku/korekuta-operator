FROM quay.io/operator-framework/ansible-operator:v0.19.0

USER root

COPY .git /tmp/repo/.git
RUN dnf -y install git && \
    git -C /tmp/repo rev-parse HEAD > /tmp/commit && \
    rm -fr /tmp/repo && \
    dnf -y remove git && \
    cat /tmp/commit

# run as the user we are
USER 1001

COPY watches.yaml ${HOME}/watches.yaml
COPY roles/ ${HOME}/roles/
COPY deploy/olm-catalog/cost-mgmt-operator /manifests

COPY requirements.yml ${HOME}/requirements.yml
RUN ansible-galaxy collection install -r ${HOME}/requirements.yml \
    && chmod -R ug+rwx ${HOME}/.ansible

RUN cp /tmp/commit ${HOME}/commit

