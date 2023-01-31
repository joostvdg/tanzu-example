KAPP_CONTROLLER_NAMESPACE=${KAPP_CONTROLLER_NAMESPACE:-"tkg-system"}
SECRET_GEN_VERSION=${SECRET_GEN_VERSION:-"v0.9.1"}
PLATFORM=${PLATFORM:="tkgs"}
TKGS="tkgs"

echo "> Installing Kapp Controller"
if [[ $PLATFORM eq $TGKS ]]
then
  # This is a TKGs version
  ytt -f ytt/kapp-controller.ytt.yml \
    -v namespace="$KAPP_CONTROLLER_NAMESPACE" \
    -v caCert="${CA_CERT}" \
    > "kapp-controller.yml"
  kubectl apply -f kapp-controller.yml
else 
  # Non TKGs
  kubectl apply -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml
  echo "Configure Custom Cert for Kapp Controller"
  ytt -f ytt/kapp-controller-config.ytt.yml \
    -v namespace=kapp-controller \
    -v caCert="${CA_CERT}" \
    > "kapp-controller-config.yml"
  kubectl apply -f kapp-controller-config.yml --namespace kapp-controller
fi


echo "> Installing SecretGen Controller with version ${SECRET_GEN_VERSION}"
kapp deploy -y -a sg -f https://github.com/vmware-tanzu/carvel-secretgen-controller/releases/download/"$SECRET_GEN_VERSION"/release.yml