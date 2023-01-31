#!/usr/bin/env bash

set -euo pipefail

TAP_VERSION=${TAP_VERSION:-"1.3.4"}
TAP_INSTALL_NAMESPACE="tap-install"
SECRET_GEN_VERSION=${SECRET_GEN_VERSION:-"v0.9.1"}
DOMAIN_NAME=${DOMAIN_NAME:-"127.0.0.1.nip.io"}
DEVELOPER_NAMESPACE=${DEVELOPER_NAMESPACE:-"default"}
INSTALL_TAP_FUNDAMENTALS=${INSTALL_TAP_FUNDAMENTALS:-"true"}
INSTALL_CLUSTER_ESSENTIALS=${INSTALL_CLUSTER_ESSENTIALS:-"false"}

if [ "$INSTALL_CLUSTER_ESSENTIALS" = "true" ]; then
  echo "> Installing Cluster Essentials (Kapp Controller, SecretGen Controller)"
  ./install-cluster-essentials.sh
fi

if [ "$INSTALL_TAP_FUNDAMENTALS" = "true" ]; then
  echo "> Installing TAP Fundamentals (namespace, secrets)"
  ./install-tap-fundamentals.sh
fi

ytt -f ytt/tap-build-profile-basic.ytt.yml \
  -v tbsRepo="$TBS_REPO" \
  -v buildRegistry="$BUILD_REGISTRY" \
  -v buildRegistrySecret="$BUILD_REGISTRY_SECRET" \
  -v buildRepo="$BUILD_REGISTRY_REPO" \
  -v domainName="$DOMAIN_NAME" \
  -v caCert="${CA_CERT}" \
  > "tap-build-basic-values.yml"


tanzu package installed update --install tap \
  -p tap.tanzu.vmware.com \
  -v $TAP_VERSION \
  --values-file tap-build-basic-values.yml \
  -n ${TAP_INSTALL_NAMESPACE}
