set -euo pipefail

TAP_VERSION=${TAP_VERSION:-"1.3.4"}
TAP_INSTALL_NAMESPACE="tap-install"
DOMAIN_NAME=${DOMAIN_NAME:-"127.0.0.1.nip.io"}
INSTALL_REGISTRY_SECRET="tap-registry"
BUILD_REGISTRY_SECRET="registry-credentials"

echo "> Creating tap-install namespace: $TAP_INSTALL_NAMESPACE"
kubectl create ns $TAP_INSTALL_NAMESPACE || true

INSTALL_REGISTRY_HOSTNAME=${INSTALL_REGISTRY_HOSTNAME:-"registry.tanzu.vmware.com"}
INSTALL_REGISTRY_USERNAME=${INSTALL_REGISTRY_USERNAME:-""}
INSTALL_REGISTRY_PASSWORD=${INSTALL_REGISTRY_PASSWORD:-""}
INSTALL_REGISTRY_REPO=${INSTALL_REGISTRY_REPO:-"tap/tap-packages"}

echo "> Creating ${INSTALL_REGISTRY_SECRET} secret"
tanzu secret registry add ${INSTALL_REGISTRY_SECRET} \
    --server    $INSTALL_REGISTRY_HOSTNAME \
    --username  $INSTALL_REGISTRY_USERNAME \
    --password  $INSTALL_REGISTRY_PASSWORD \
    --namespace ${TAP_INSTALL_NAMESPACE} \
    --export-to-all-namespaces \
    --yes 

BUILD_REGISTRY=${BUILD_REGISTRY:-"dev.registry.tanzu.vmware.com"}
BUILD_REGISTRY_REPO=${BUILD_REGISTRY_REPO:-""} 
BUILD_REGISTRY_USER=${BUILD_REGISTRY_USER:-""}
BUILD_REGISTRY_PASS=${BUILD_REGISTRY_PASS:-""}

echo "> Creating ${BUILD_REGISTRY_SECRET} secret"
tanzu secret registry add ${BUILD_REGISTRY_SECRET} \
    --server    $BUILD_REGISTRY \
    --username  $BUILD_REGISTRY_USER \
    --password  $BUILD_REGISTRY_PASS \
    --namespace ${TAP_INSTALL_NAMESPACE} \
    --export-to-all-namespaces \
    --yes

PACKAGE_REPOSITORY="$INSTALL_REGISTRY_HOSTNAME"/$INSTALL_REGISTRY_REPO:"$TAP_VERSION"
echo "> Install TAP Package Repository: ${PACKAGE_REPOSITORY}"
tanzu package repository add tanzu-tap-repository --url "$PACKAGE_REPOSITORY" --namespace ${TAP_INSTALL_NAMESPACE} || true
kubectl wait --for=condition=ReconcileSucceeded PackageRepository tanzu-tap-repository -n ${TAP_INSTALL_NAMESPACE} --timeout=15m