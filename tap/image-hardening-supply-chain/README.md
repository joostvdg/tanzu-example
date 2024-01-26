# TAP Image Hardening Supply Chain


## Relocate Minideb

### Bookworm

```sh
docker pull bitnami/minideb:bookworm
docker tag bitnami/minideb:bookworm harbor.tap.h2o-2-19271.h2o.vmware.com/tap-apps/debian-bookworm
docker push harbor.tap.h2o-2-19271.h2o.vmware.com/tap-apps/debian-bookworm 
```

Testing uploading a fake update:

```sh
docker buildx build --platform=linux/amd64,linux/arm64 \
    --tag harbor.tap.h2o-2-19271.h2o.vmware.com/tap-apps/debian-bookworm --push \
    --build-arg APP_IMAGE=bitnami/minideb:bookworm \
    --build-arg TEST=test001
    -f ./tap/image-hardening-supply-chain/debian/bookworm/Dockerfile .
```