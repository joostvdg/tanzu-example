#!/bin/bash
CLUSTER_NAME=$1
PACKAGE_NAME=$2
VALUES_FILE=$3
PACKAGES_NAMESPACE="tanzu-packages"

echo "Retrieving latest version of ${PACKAGE_NAME}.tanzu.vmware.com package"
PACKAGE_VERSION=$(tanzu package \
    available list ${PACKAGE_NAME}.tanzu.vmware.com -A \
    --output json | jq --raw-output 'sort_by(.version)|reverse|.[0].version')

echo "Installing package ${PACKAGE_NAME} version ${PACKAGE_VERSION} into namespace ${PACKAGES_NAMESPACE}"
INSTALL_COMMAND="tanzu package installed update --install ${PACKAGE_NAME}  \
    --package-name ${PACKAGE_NAME}.tanzu.vmware.com \
    --namespace ${PACKAGES_NAMESPACE} \
    --version ${PACKAGE_VERSION} "

if [ -n "$3" ]; then
    echo "Found a values file, appending to command"
    INSTALL_COMMAND="${INSTALL_COMMAND} --values-file ${VALUES_FILE}"
fi
eval $INSTALL_COMMAND