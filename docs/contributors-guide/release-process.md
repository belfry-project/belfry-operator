# Release Process

belfry-operator is released together with belfry, belfry-ee and the Helm chart, all with the same version tag (`X.Y.Z`, or `X.Y.Z-rc.N` for a release candidate, without a `v` prefix). The operator deploys `ghcr.io/belfry-project/belfry:<version>` and `ghcr.io/belfry-project/belfry-ee:<version>` by default, so belfry-ee and belfry are released first.

The whole procedure is in [RELEASING.md](https://github.com/belfry-project/.github/blob/main/RELEASING.md) in belfry-project/.github, and `tools/release.sh` there runs it.

Publishing a GitHub release in this repository runs the [Release](https://github.com/belfry-project/belfry-operator/blob/main/.github/workflows/release.yml) workflow, which:

- builds the operator for linux/amd64 and linux/arm64 with `DEFAULT_AWX_VERSION` and `OPERATOR_VERSION` set to the version;
- publishes `ghcr.io/belfry-project/belfry-operator:<version>` (final releases also `:latest`) with build provenance and SBOM attestations, and attaches the SBOM and a Trivy scan to the release;
- runs molecule and the upgrade test from AWX 24.6.1 against the release images;
- attaches the install manifest `belfry-operator.yaml` to the release.

Run the workflow manually (`dry_run` is the default) to test all of this without a release: it uses and publishes only `:release-test` images.
