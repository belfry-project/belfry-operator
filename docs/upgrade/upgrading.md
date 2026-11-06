# Upgrading

To upgrade AWX, it is recommended to upgrade the awx-operator to the version that maps to the desired version of AWX. To find the version of AWX that will be installed by the awx-operator by default, check the version specified in the `DEFAULT_AWX_VERSION` variable for that particular release. You can do so by running the following command

```shell
AWX_OPERATOR_VERSION=2.8.0
docker run --entrypoint="" ghcr.io/belfry-project/belfry-operator:$AWX_OPERATOR_VERSION bash -c "env | grep DEFAULT_AWX_VERSION"
```

Make sure you have a backup before upgrading, then upgrade operator by invoking `make deploy` on the desired tag or by applying the `kustomization.yaml` that contains desired version of the operator, and in turn also upgrade your AWX deployment.

## Backup

The first part of any upgrade should be a backup. Note, there are secrets in the pod which work in conjunction with the database. Having just a database backup without the required secrets will not be sufficient for recovering from an issue when upgrading to a new version. See the [backup role documentation](https://github.com/belfry-project/belfry-operator/tree/main/roles/backup) for information on how to backup your database and secrets.

In the event you need to recover the backup see the [restore role documentation](https://github.com/belfry-project/belfry-operator/tree/main/roles/restore). _Before Restoring from a backup_, be sure to:

- delete the old existing AWX CR
- delete the persistent volume claim (PVC) for the database from the old deployment, which has a name like `postgres-18-<deployment-name>-postgres-18-0` (`postgres-15-<deployment-name>-postgres-15-0` before the move to PostgreSQL 18)

**Note**: Do not delete the namespace/project, as that will delete the backup and the backup's PVC as well.

## Upgrading the managed PostgreSQL database

belfry-operator 1.0.0, like awx-operator 2.15.0 to 2.19.1, runs the managed database on PostgreSQL 15 (`quay.io/sclorg/postgresql-15-c9s`). Later versions of belfry-operator run it on PostgreSQL 18 (`quay.io/sclorg/postgresql-18-c10s`): PostgreSQL 15 is supported until November 2027, PostgreSQL 18 until November 2030.

When you upgrade the operator, it migrates a managed PostgreSQL 15 (or older) database once, during the first reconciliation of each AWX instance:

1. It scales down the web and task deployments, so AWX is unavailable during the migration.
2. It creates the StatefulSet `<deployment-name>-postgres-18`, with a new PVC `postgres-18-<deployment-name>-postgres-18-0` of the same size (`postgres_storage_requirements`) and storage class as configured in the AWX spec.
3. It streams the data from the old database into the new one with `pg_dump` and `pg_restore`, and points the `<deployment-name>-postgres-configuration` secret to the new database.
4. It removes the old StatefulSet, Service and NetworkPolicy (`<deployment-name>-postgres-15`), sets `status.upgradedPostgresVersion` to `18` and starts AWX again.

What you need to do:

- Make a backup (see above) before upgrading the operator.
- Make sure the cluster can provision a second database volume: the old PVC stays until you delete it, so both need room during and after the migration.
- If your AWX spec sets `postgres_image` or `postgres_image_version`, remove them (or point them to a PostgreSQL 18 image) before the upgrade.
- Plan for downtime: the migration takes about as long as a `pg_dump` and restore of your database.
- After checking that AWX works, delete the old PVC: `kubectl -n <namespace> delete pvc postgres-15-<deployment-name>-postgres-15-0`. Until then you can still go back to the old database.

External databases (a `postgres_configuration_secret` of type `unmanaged`) are not touched; you upgrade them yourself when you want to. Belfry needs at least PostgreSQL 12, and CI tests the version the operator deploys (18).

Backups made from a PostgreSQL 15 database, including backups made with awx-operator, can be restored with an AWXRestore: the operator restores them into a new PostgreSQL 18 database.

## Caveats for upgrading to v0.14.0

### Cluster-scope to Namespace-scope considerations

Starting with awx-operator 0.14.0, AWX can only be deployed in the namespace that the operator exists in. This is called a namespace-scoped operator. If you are upgrading from an earlier version, you will want to delete your existing `awx-operator` service account, role and role binding.

### Project is now based on v1.x of the operator-sdk project

Starting with awx-operator 0.14.0, the project is now based on operator-sdk 1.x. You may need to manually delete your old operator Deployment to avoid issues.

### Steps to upgrade to v0.14.0

Delete your old AWX Operator and existing `awx-operator` service account, role and role binding in `default` namespace first:

```sh
kubectl -n default delete deployment awx-operator
kubectl -n default delete serviceaccount awx-operator
kubectl -n default delete clusterrolebinding awx-operator
kubectl -n default delete clusterrole awx-operator
```

Then install the new AWX Operator by following the instructions in [Basic Install](../installation/basic-install.md). The `NAMESPACE` environment variable have to be the name of the namespace in which your old AWX instance resides.

Once the new AWX Operator is up and running, your AWX deployment will also be upgraded.
