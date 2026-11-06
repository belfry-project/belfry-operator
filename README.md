# Belfry Operator

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![CI](https://github.com/belfry-project/belfry-operator/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/belfry-project/belfry-operator/actions)

A Kubernetes operator for [Belfry](https://github.com/belfry-project/belfry), the community continuation of AWX, built with [Operator SDK](https://github.com/operator-framework/operator-sdk) and Ansible.

The Belfry Operator is meant to be deployed in your Kubernetes cluster(s) and can be used to install and manage the lifecycle of a Belfry instance in the same namespace. It is a continuation of the [AWX Operator](https://github.com/ansible/awx-operator), and keeps its resources: instances are still described by `AWX`, `AWXBackup` and `AWXRestore` resources in the `awx.ansible.com` API group, so installations made with awx-operator can switch to belfry-operator.

Images: `ghcr.io/belfry-project/belfry-operator`. A Helm chart is available in [belfry-project/helm-charts](https://github.com/belfry-project/helm-charts).

## Documentation

The Belfry documentation is available at <https://belfry-project.github.io/>. The operator documentation in [docs/](https://github.com/belfry-project/belfry-operator/tree/main/docs) is based on the [AWX Operator documentation](https://ansible.readthedocs.io/projects/awx-operator/).

AWX and Ansible are trademarks of Red Hat, Inc. Belfry is not affiliated with or endorsed by Red Hat, Inc.

## Contributing

Please visit our [contributing guidelines](https://github.com/belfry-project/belfry-operator/blob/main/CONTRIBUTING.md) and [development guide](https://github.com/belfry-project/belfry-operator/blob/main/docs/development.md) for information on how to set up your environment, build and deploy the operator, and submit changes.

## Author

This operator was originally built in 2019 by [Jeff Geerling](https://www.jeffgeerling.com) as the AWX Operator and was maintained by the Ansible Team. The Belfry Operator is maintained by the [Belfry project](https://github.com/belfry-project).

Issues and pull requests for the Belfry Operator go to [belfry-project/belfry-operator](https://github.com/belfry-project/belfry-operator/issues).

## Code of Conduct

Everyone taking part in Belfry follows the [Code of Conduct](https://github.com/belfry-project/.github/blob/main/CODE_OF_CONDUCT.md).

## Get Involved

We welcome your feedback, questions and ideas.

* Questions on installing, migrating from AWX and upgrading: see the [Belfry documentation](https://belfry-project.github.io/docs/).
* Bugs and feature requests: open an [issue](https://github.com/belfry-project/belfry-operator/issues). Migration reports from AWX are welcome, also when everything worked.
* Security vulnerabilities: report them privately as described in the [security policy](https://github.com/belfry-project/.github/blob/main/SECURITY.md), never in a public issue.
