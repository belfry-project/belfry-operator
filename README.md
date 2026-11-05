# Belfry Operator

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![CI](https://github.com/belfry-project/belfry-operator/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/belfry-project/belfry-operator/actions)

A Kubernetes operator for [Belfry](https://github.com/belfry-project/belfry), the community continuation of AWX, built with [Operator SDK](https://github.com/operator-framework/operator-sdk) and Ansible.

The Belfry Operator is meant to be deployed in your Kubernetes cluster(s) and can be used to install and manage the lifecycle of a Belfry instance in the same namespace. It is a continuation of the [AWX Operator](https://github.com/ansible/awx-operator), and keeps its resources: instances are still described by `AWX`, `AWXBackup` and `AWXRestore` resources in the `awx.ansible.com` API group, so installations made with awx-operator can switch to belfry-operator.

Images: `ghcr.io/belfry-project/belfry-operator`. A Helm chart is available in [belfry-project/helm-charts](https://github.com/belfry-project/helm-charts).

## Documentation

The Belfry documentation is available at <https://belfry-project.github.io/>. The operator documentation in [docs/](./docs) is based on the [AWX Operator documentation](https://ansible.readthedocs.io/projects/awx-operator/).

AWX and Ansible are trademarks of Red Hat, Inc. Belfry is not affiliated with or endorsed by Red Hat, Inc.

## Contributing

Please visit our [contributing guidelines](./CONTRIBUTING.md) and [development guide](./docs/development.md) for information on how to set up your environment, build and deploy the operator, and submit changes.

## Author

This operator was originally built in 2019 by [Jeff Geerling](https://www.jeffgeerling.com) as the AWX Operator and was maintained by the Ansible Team. The Belfry Operator is maintained by the [Belfry project](https://github.com/belfry-project).

Issues and pull requests for the Belfry Operator go to [belfry-project/belfry-operator](https://github.com/belfry-project/belfry-operator/issues).

## Code of Conduct

We ask all of our community members and contributors to adhere to the [Ansible code of conduct](http://docs.ansible.com/ansible/latest/community/code_of_conduct.html). If you have questions or need assistance, please reach out to our community team at [codeofconduct@ansible.com](mailto:codeofconduct@ansible.com)

## Get Involved

We welcome your feedback, questions and ideas. Here's how to reach the community.

### Forum

Join the [Ansible Forum](https://forum.ansible.com) as a single starting point and our default communication platform for questions and help, development discussions, events, and much more. [Register](https://forum.ansible.com/signup?) to join the community. Search by categories and tags to find interesting topics or start a new one; subscribe only to topics you need!

* [Get Help](https://forum.ansible.com/c/help/6): get help or help others. Please add appropriate tags if you start new discussions, for example `awx-operator` and  `documentation`.
* [Posts tagged with 'awx-operator'](https://forum.ansible.com/tag/awx-operator): subscribe to participate in project-related conversations.
* [Bullhorn newsletter](https://docs.ansible.com/ansible/devel/community/communication.html#the-bullhorn) used to announce releases and important changes.
* [Social Spaces](https://forum.ansible.com/c/chat/4): gather and interact with fellow enthusiasts.
* [News & Announcements](https://forum.ansible.com/c/news/5): track project-wide announcements including social events.

For more information on the forum navigation, see [Navigating the Ansible forum](https://forum.ansible.com/t/navigating-the-ansible-forum-tags-categories-and-concepts/39) post.

### Matrix

For real-time interactions, conversations in the community happen over the Matrix protocol in the following channels:

* [#awx:ansible.com](https://matrix.to/#/#awx:ansible.com): AWX and AWX-Operator project-related discussions.
* [#docs:ansible.im](https://matrix.to/#/#docs:ansible.im): Ansible, AWX and AWX-Operator documentation-related discussions.

For more information, see the community-hosted [Matrix FAQ](https://hackmd.io/@ansible-community/community-matrix-faq).
