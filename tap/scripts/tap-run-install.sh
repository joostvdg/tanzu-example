#!/usr/bin/env bash

set -euo pipefail

TAP_VERSION=${TAP_VERSION:-"1.3.0"}
TAP_INSTALL_NAMESPACE="tap-install"
KAPP_CONTROLLER_NAMESPACE=${KAPP_CONTROLLER_NAMESPACE:-"tkg-system"}
SECRET_GEN_VERSION=${SECRET_GEN_VERSION:-"v0.9.1"}
DOMAIN_NAME=${DOMAIN_NAME:-"127.0.0.1.nip.io"}
INSTALL_REGISTRY_SECRET="tap-registry"
BUILD_REGISTRY_SECRET="registry-credentials"

echo "> Installing Kapp Controller"
ytt -f ytt/kapp-controller.ytt.yml \
  -v namespace="$KAPP_CONTROLLER_NAMESPACE" \
  -v caCert="${CA_CERT}" \
  > "kapp-controller.yml"
kubectl apply -f kapp-controller.yml

echo "> Installing SecretGen Controller with version ${SECRET_GEN_VERSION}"
kapp deploy -y -a sg -f https://github.com/vmware-tanzu/carvel-secretgen-controller/releases/download/"$SECRET_GEN_VERSION"/release.yml

echo "> Creating tap-install namespace"
kubectl create ns tap-install || true

INSTALL_REGISTRY_HOSTNAME=${INSTALL_REGISTRY_HOSTNAME:-"registry.tanzu.vmware.com"}
INSTALL_REGISTRY_USERNAME=${INSTALL_REGISTRY_USERNAME:-""}
INSTALL_REGISTRY_PASSWORD=${INSTALL_REGISTRY_PASSWORD:-""}
INSTALL_REGISTRY_REPO=${INSTALL_REGISTRY_REPO:-"tap/tap-packages"}

echo "> Creating tap-registry secret"
tanzu secret registry add ${INSTALL_REGISTRY_SECRET} \
    --server    $INSTALL_REGISTRY_HOSTNAME \
    --username  $INSTALL_REGISTRY_USERNAME \
    --password  $INSTALL_REGISTRY_PASSWORD \
    --namespace ${TAP_INSTALL_NAMESPACE} \
    --export-to-all-namespaces \
    --yes 

BUILD_REGISTRY=${BUILD_REGISTRY:-"dev.registry.tanzu.vmware.com"}
BUILD_REGISTRY_REPO=${BUILD_REGISTRY_REPO:-""} 
BUILD_REGISTRY_USER=${BUILD_USERNAME:-""}
BUILD_REGISTRY_PASS=${BUILD_PASSWORD:-""}

echo "> Creating tap-registry secret"
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

ytt -f ytt/tap-run-profile.ytt.yml \
  -v domainName="$DOMAIN_NAME" \
  -v buildRegistry="$BUILD_REGISTRY" \
  -v buildRepo="$BUILD_REGISTRY_REPO" \
  -v caCert="${CA_CERT}" \
  > "tap-values.yml"

tanzu package installed update --install tap \
  -p tap.tanzu.vmware.com \
  -v $TAP_VERSION \
  --values-file tap-values.yml \
  -n ${TAP_INSTALL_NAMESPACE}
