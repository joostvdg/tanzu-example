set -euo pipefail

DEVELOPER_NAMESPACE=${DEVELOPER_NAMESPACE:-"default"}
BUILD_REGISTRY=${BUILD_REGISTRY:-""}
BUILD_REGISTRY_USER=${BUILD_REGISTRY_USER:-""}
BUILD_REGISTRY_PASS=${BUILD_REGISTRY_PASS:-""}

echo "> Creating Dev namspace $DEVELOPER_NAMESPACE"
kubectl create ns ${DEVELOPER_NAMESPACE} || true

echo "> Creating Dev namespace registry secret"
tanzu secret registry add registry-credentials  \
  --server    $BUILD_REGISTRY \
  --username  $BUILD_REGISTRY_USER \
  --password  $BUILD_REGISTRY_PASS \
  --namespace ${DEVELOPER_NAMESPACE} \
  --yes

echo "> Configuring RBAC for developer namespace"
kubectl apply -f dev-namespace-rbac.yml -n $DEVELOPER_NAMESPACE