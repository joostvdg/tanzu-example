

## Relocate Minideb

### Bookworm

```sh
docker pull bitnami/minideb:bookworm --platform linux/amd64
docker tag bitnami/minideb:bookworm harbor.tap.h2o-2-19271.h2o.vmware.com/tap-apps/debian-bookworm:0.0.3
docker push harbor.tap.h2o-2-19271.h2o.vmware.com/tap-apps/debian-bookworm:0.0.3
```

```sh
imgpkg copy -i bitnami/minideb:bookworm \
    --to-repo harbor.tap.h2o-2-19271.h2o.vmware.com/tap-apps/debian-bookworm
```

Testing uploading a fake update:

```sh
docker buildx build --platform=linux/amd64,linux/arm64 \
    --tag harbor.tap.h2o-2-19271.h2o.vmware.com/tap-apps/debian-bookworm:0.0.1 \
    --provenance=false --sbom=false \
    --build-arg BUILDKIT_INLINE_BUILDINFO_ATTRS=1 \
    --push \
    --build-arg APP_IMAGE=bitnami/minideb:bookworm \
    --build-arg TEST=test001 \
    -f ./tap/image-hardening-supply-chain/debian/bookworm/Dockerfile .
```

```sh
docker buildx create --use --config buildkitd.toml
```


```toml
[registry."harbor.tap.h2o-2-19271.h2o.vmware.com"]
  ca=["/Users/joostvdg/Projects/vmware-docs/labs/h20/tap/150/scripts/ssl/ca.crt"]
```

```yaml
apiVersion: source.apps.tanzu.vmware.com/v1alpha1
kind: ImageRepository
metadata:
  name: debian-bookworm-4
  namespace: debian
spec:
  image: harbor.tap.h2o-2-19271.h2o.vmware.com/tap-apps/debian-bookworm
  interval: 1m0s
  serviceAccountName: default
```


```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: OCIRepository
metadata:
  name: debian-bookworm-5
  namespace: debian
spec:
  interval: 5m0s
  url: oci://harbor.tap.h2o-2-19271.h2o.vmware.com/tap-apps/debian-bookworm
  ref:
    tag: 0.0.2
```