# Contributing to the Belfry Operator

Thanks for helping. The process (issues, pull requests against `main`, commit messages, CI, code of conduct) is the same for every Belfry repository and is described in the organization's [contributing guide](https://github.com/belfry-project/.github/blob/main/CONTRIBUTING.md). This file only covers what is specific to this repository.

- Branch from `main` and open the pull request against `main` (there is no `devel` branch). No Developer Certificate of Origin sign-off is required.
- Fill in the pull request template. CI checks that the `##### ISSUE TYPE` section contains exactly one of the listed lines.
- Keep diffs small: Belfry stays close to upstream awx-operator so upstream changes can still be merged.
- Report vulnerabilities privately, as described in the [security policy](https://github.com/belfry-project/.github/blob/main/SECURITY.md), never in a public issue.

## Development environment

See [docs/development.md](docs/development.md) for prerequisites, build and deploy instructions, and the available Makefile targets.

## Testing

- **Linting** (required for all PRs): `make lint`
- **Molecule tests**: the operator includes a [Molecule](https://ansible.readthedocs.io/projects/molecule/)-based test environment for integration testing. See the [Testing section in docs/development.md](docs/development.md#testing) for running the tests locally. CI runs them on kind; `.github/workflows/upgrade-test.yml` tests the upgrade from AWX and awx-operator.

## Reporting issues

Open bugs and feature requests in [belfry-project/belfry-operator](https://github.com/belfry-project/belfry-operator/issues). Migration reports from AWX are welcome, also when everything worked. For questions, see the [Belfry documentation](https://belfry-project.github.io/docs/) first.
