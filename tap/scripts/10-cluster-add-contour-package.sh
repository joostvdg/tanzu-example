#!/bin/bash
CLUSTER_NAME=$1
INFRA=vsphere
PACKAGES_NAMESPACE="tanzu-packages"

echo "Creating namespace ${PACKAGES_NAMESPACE} for holding package installations"
kubectl create namespace ${PACKAGES_NAMESPACE}

./install-package-with-latest-version.sh $CLUSTER_NAME cert-manager
kubectl get po,svc -n cert-manager

./install-package-with-latest-version.sh $CLUSTER_NAME contour "${INFRA}-values/contour.yaml"
kubectl get po,svc,ing --namespace tanzu-system-ingress