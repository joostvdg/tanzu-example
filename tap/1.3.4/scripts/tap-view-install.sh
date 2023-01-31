set -euo pipefail

TAP_VERSION=${TAP_VERSION:-"1.3.4"}
TAP_INSTALL_NAMESPACE="tap-install"
DOMAIN_NAME=${DOMAIN_NAME:-"127.0.0.1.nip.io"}
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

echo "> Generating tap-view-values.yml"
ytt -f ytt/tap-view-profile.ytt.yml \
  -v caCert="${CA_CERT}" \
  -v domainName="$DOMAIN_NAME" \
  -v buildClusterUrl="${BUILD_CLUSTER_URL}" \
  -v buildClusterName="${BUILD_CLUSTER_NAME}" \
  -v buildClusterToken="${BUILD_CLUSTER_TOKEN}" \
  -v buildClusterTls="${BUILD_CLUSTER_TLS}" \
  -v runClusterUrl="${RUN_CLUSTER_URL}" \
  -v runClusterName="${RUN_CLUSTER_NAME}" \
  -v runClusterToken="${RUN_CLUSTER_TOKEN}" \
  -v runClusteTls="${RUN_CLUSTER_TLS}" \
  > "tap-view-values.yml"

echo "> Installing TAP $TAP_VERSION in $TAP_INSTALL_NAMESPACE"
tanzu package installed update --install tap \
  -p tap.tanzu.vmware.com \
  -v $TAP_VERSION \
  --values-file tap-view-values.yml \
  -n ${TAP_INSTALL_NAMESPACE}
