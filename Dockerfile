# quay.io/operator-framework/ansible-operator rebuilt with current Go, Go modules,
# UBI and Python packages: https://github.com/belfry-project/image-mirror
FROM ghcr.io/belfry-project/ansible-operator:v1.42.3-belfry.1@sha256:1b9cfc6c8322d5ab994fc76b8373d448b634402bd5967077de5cfde4f179a4f2

USER root
RUN microdnf update -y && \
    microdnf install -y openssl

USER 1001

ARG DEFAULT_AWX_VERSION
ARG OPERATOR_VERSION
ENV DEFAULT_AWX_VERSION=${DEFAULT_AWX_VERSION}
ENV OPERATOR_VERSION=${OPERATOR_VERSION}

COPY requirements.yml ${HOME}/requirements.yml
RUN ansible-galaxy collection install -r ${HOME}/requirements.yml \
 && chmod -R ug+rwx ${HOME}/.ansible

COPY watches.yaml ${HOME}/watches.yaml
COPY roles/ ${HOME}/roles/
COPY playbooks/ ${HOME}/playbooks/

ENTRYPOINT ["/tini", "--", "/usr/local/bin/ansible-operator", "run", \
    "--watches-file=./watches.yaml", \
    "--reconcile-period=0s" \
    ]
