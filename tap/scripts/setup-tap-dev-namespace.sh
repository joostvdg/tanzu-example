
DEV_NAMESPACE=${1}
REGISTRY_SERVER=${2}
REGISTRY_USER=${3}
REGISTRY_PASS=${4}

kubectl create namespace $DEV_NAMESPACE || true

tanzu secret registry add registry-credentials  \
  --server   $REGISTRY_SERVER \
  --username $REGISTRY_USER \
  --password $REGISTRY_PASS \
  --namespace ${DEV_NAMESPACE} \
  --yes

kubectl apply -f dev-namespace-rbac.yml -n $DEV_NAMESPACE
