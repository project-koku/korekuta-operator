FROM quay.io/operator-framework/ansible-operator:v0.15.2

COPY watches.yaml ${HOME}/watches.yaml
COPY roles/ ${HOME}/roles/
COPY uid_entrypoint.sh /usr/local/bin/uid_entrypoint.sh

USER root

ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
# put tini into our path
RUN ln -f -s /tini /usr/bin/tini
# make the entrypoint executable
RUN chmod +x /usr/local/bin/uid_entrypoint.sh
RUN chown -R 1001:0 $HOME && \
    chmod -R 777 $HOME /etc/passwd

# run as the user we are
USER 1000580000
ENTRYPOINT [ "uid_entrypoint.sh" ]