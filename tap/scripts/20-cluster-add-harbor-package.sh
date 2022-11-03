#!/bin/bash
CLUSTER_NAME=$1
INFRA=vsphere
HARBOR_VALUES_CLUSTER="${INFRA}-values/${CLUSTER_NAME}-harbor.yml"
PACKAGES_NAMESPACE="tanzu-packages"

./install-package-with-latest-version.sh $CLUSTER_NAME harbor "${HARBOR_VALUES_CLUSTER}"
kubectl --namespace tanzu-system-registry get po,svc