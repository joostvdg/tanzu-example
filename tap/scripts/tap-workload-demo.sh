DEVELOPER_NAMESPACE=${DEVELOPER_NAMESPACE:-"default"}

tanzu apps workload delete smoke-app -y -n "$DEVELOPER_NAMESPACE" || true
tanzu apps workload create smoke-app --git-repo https://github.com/sample-accelerators/tanzu-java-web-app.git --git-branch main --type web -y -n "$DEVELOPER_NAMESPACE"
kubectl wait --for=condition=Ready Workload smoke-app --timeout=10m -n "$DEVELOPER_NAMESPACE"
tanzu apps workload delete smoke-app -y -n "$DEVELOPER_NAMESPACE"