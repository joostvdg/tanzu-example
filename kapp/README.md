# KAPP

> kapp (part of the open source Carvel suite) is a lightweight application-centric tool for deploying resources on Kubernetes. - [Tanzu Developer Guide - Carvel Kapp](https://tanzu.vmware.com/developer/guides/kapp-gs/)

## Developer Guide for KAPP

### Install

Follow the docs: https://carvel.dev/kapp/docs/v0.51.0/install/

### Prerequisites

KAPP needs a namespace to store its state.

```sh
kubectl create namespace kapp-demo
```

### Hello World App

```sh
kapp deploy -n kapp-demo -a spring-petclinic -f spring-petclinic/ --diff-changes
```

```sh
kubectl -n spring-petclinic get deployment,service spring-petclinic
```

### Inspect KAPP Resources

```sh
kubectl get cm -n kapp-demo | grep spring-petclinic
```

```sh
kapp list -n kapp-demo
```

```sh
kapp -n kapp-demo inspect -a spring-petclinic
```

```sh
kapp -n kapp-demo logs -a spring-petclinic
```

### Update To LoadBalancer

```sh
kapp deploy -n kapp-demo -a spring-petclinic -c -f spring-petclinic-loadbalancer/ --diff-changes
```

```sh
kubectl -n spring-petclinic get svc -l app=spring-petclinic
```

#### CleanUp

```sh
kapp delete -n kapp-demo -a spring-petclinic
```

## References

* https://tanzu.vmware.com/developer/guides/kapp-gs/