#!/usr/bin/env bash

set -euo pipefail

TAP_VERSION=${TAP_VERSION:-"1.3.4"}
TAP_INSTALL_NAMESPACE="tap-install"
DOMAIN_NAME=${DOMAIN_NAME:-"127.0.0.1.nip.io"}
VIEW_DOMAIN_NAME=${VIEW_DOMAIN_NAME:-"127.0.0.1.nip.io"}
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

ytt -f ytt/tap-run-profile.ytt.yml \
  -v domainName="$DOMAIN_NAME" \
  -v buildRegistry="$BUILD_REGISTRY" \
  -v buildRepo="$BUILD_REGISTRY_REPO" \
  -v viewDomainName="$VIEW_DOMAIN_NAME" \
  -v caCert="${CA_CERT}" \
  > "tap-run-values.yml"

tanzu package installed update --install tap \
  -p tap.tanzu.vmware.com \
  -v $TAP_VERSION \
  --values-file tap-run-values.yml \
  -n ${TAP_INSTALL_NAMESPACE}
