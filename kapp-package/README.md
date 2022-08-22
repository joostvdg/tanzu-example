# KAPP Package

## Install KAPP Controller

```sh
kapp deploy -a kc -f kapp-controller-v0.39.0.yml
```

```sh
kubectl get all -n kapp-controller
```

```sh
kubectl api-resources --api-group packaging.carvel.dev
```

```sh
kubectl api-resources --api-group data.packaging.carvel.dev
```

```sh
kubectl api-resources --api-group kappctrl.k14s.io
```

## Prepare Package

See content of `package-contents`.

### Generate Image Lock with kbld

```sh
kbld -f package-contents/config/ --imgpkg-lock-output package-contents/.imgpkg/images.yml
```

## Push Package

### Run Unsecure Registry

```sh
docker run -d -p 5000:5000 --restart=always --name registry registry:2
```

```sh
export REPO_HOST="`ifconfig | grep -A1 docker | grep inet | cut -f10 -d' '`:5000/packages"
```

### Use Secure Registry

```sh
export REPO_HOST=""
```

### Create Package

```sh
imgpkg push -b ${REPO_HOST}/simple-app:1.0.0 -f package-contents/
```

## Create Schema

```sh
ytt -f package-contents/config/values.yml --data-values-schema-inspect -o openapi-v3 > schema-openapi.yml
```

## Automation Of Package Creation

- create the directory skeleton:

```shell
CR='ghcr.io'
REPO_BASE='vmware-tanzu/tanzu-application-platform-reference-packages'

IAAS='google'
METHOD='config-connector'
SERVICE='cloudsql'

mkdir -p "./bundles/${IAAS}/${METHOD}/${SERVICE}/bundle"/{config,.impgkg}
mkdir -p "./${IAAS}/${METHOD}/${SERVICE}"
mkdir -p "./repository/packages/${IAAS}/${SERVICE}"
```

- Add the package files:

```shell
# copy the images.yml from another package, this will stay the same as long as we don't ship any "workload images"
cp ./bundles/amazon/ack/rds/bundle/.imgpkg/images.yml ./bundles/${IAAS}/${METHOD}/${SERVICE}/bundle/impgkg"

# add the actual package implementation
touch "/bundles/${IAAS}/${METHOD}/${SERVICE}/bundle/config"/{00-schema.yml,10-main.yml}
```

- Push the bundle for the package itself

```shell
REPO_NAME='<FOOBAR>' # e.g. psql.google.references.services.apps.tanzu.vmware.com
VERSION='0.0.1-alpha'

PKG_BUNDLE="$(
imgpkg push \
    -b "${CR}/${REPO_BASE}/${REPO_NAME}:${VERSION}" \
    -f "./bundles/${IAAS}/${METHOD}/${SERVICE}/bundle" \
    --lock-output /dev/stdout \
    | yq -r .bundle.image
)"
```

- Add the new package to the repo:

```shell
OPEN_API_SCHEMA="$(
ytt -f "./bundles/${IAAS}/${METHOD}/${SERVICE}/bundle/" \
    --data-values-schema-inspect -o openapi-v3 \
    | yq -y .components.schemas.dataValues
)"

# we should probably ytt that
cat <<EOF > "./repository/packages/${IAAS}/${SERVICE}"/meta.yaml"
apiVersion: data.packaging.carvel.dev/v1alpha1
kind: PackageMetadata
metadata:
name: ${REPO_NAME}
spec:
categories:
- services
displayName: "TODO: change me"
longDescription: |
    TODO: change me
maintainers:
- name: The Services Toolkit team
providerName: VMware
shortDescription: cloudsql
supportDescription: Not supported - provided as reference package only
EOF

cat <<'EOF' | ytt -f - -v refName="${REPO_NAME}" -v version="${VERSION}" -v date="$(date --iso-8601=s)" -v pkgBundle="${PKG_BUNDLE}" --data-value-yaml="schema=${OPEN_API_SCHEMA}" foo=bar > "./repository/packages/${IAAS}/${SERVICE}/package.yaml"
#@ load("@ytt:data", "data")
apiVersion: data.packaging.carvel.dev/v1alpha1
---
kind: Package
metadata:
name: '{}.{}'.format(data.values.refName, data.values.version)
spec:
refName: #@ data.values.refName
version: #@ data.values.version
releasedAt: #@ data.values.date
releaseNotes: https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu/0.7/services-toolkit-0-7/GUID-overview.html
valuesSchema:
    openAPIv3: #@ data.values.schema
template:
spec:
    fetch:
    - imgpkgBundle:
        image: #@ data.values.pkgBundle
    template:
    - ytt:  {"paths": ["config/"]}
    - kbld: {"paths": ["-",".imgpkg/images.yml"]}
    deploy:
    - kapp: {}
EOF

touch "./repository/packages/${IAAS}/${SERVICE}"/{meta.yaml,package.yml,package-install.yml}
```

## References

* https://carvel.dev/kapp-controller/docs/v0.38.0/packaging-tutorial/#getting-started