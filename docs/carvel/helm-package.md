---
title: Helm To Carvel Package
description: Translate a Helm chart to a Carvel Package
author: joostvdg
tags: [carvel, kubernetes, yaml, ytt, helm]
---

Converting a Helm chart to a Carvel Package.

* Helm starting point: https://github.com/vfarcic/cncf-demo/tree/main/helm

```sh
mkdir .imgpkg
mkdir config
```

```sh
kctrl package init
```

* **Name**: `cncf-demo.joostvdg.github.com`
* **Content**: **1** (_Local directory_)
* **Source**: `https://github.com/vfarcic/cncf-demo/`

Result:

```sh
.
├── .imgpkg
├── config
├── package-build.yml
└── package-resources.yml
```

Add content:

```sh
tree -a
```

```sh
.
├── .imgpkg
│   └── images.yml
├── config
│   ├── 01-schema.yml
│   ├── 02-deployment.ytt.yml
│   ├── 03-service.ytt.yml
│   └── 04-ingress.ytt.yml
├── package-build.yml
└── package-resources.yml
```

```sh
ytt -f config | kbld -f - --imgpkg-lock-output .imgpkg/images.yml
```

```sh
cat .imgpkg/images.yml
```

```yaml
---
apiVersion: imgpkg.carvel.dev/v1alpha1
images:
- annotations:
    kbld.carvel.dev/id: docker.io/vfarcic/cncf-demo:v0.0.1
    kbld.carvel.dev/origins: |
      - resolved:
          tag: v0.0.1
          url: docker.io/vfarcic/cncf-demo:v0.0.1
  image: index.docker.io/vfarcic/cncf-demo@sha256:a21e1ad0a4d071dde5e5533bbe2281ba05f44926f937c15a98f9485cc30c4782
kind: ImagesLock
```

```sh
kctrl package release --version 0.1.1 \
    --repo-output ../kctrl-package-repo
```

* **Repository**: `index.docker.io/caladreas/carvel-helm`

## Kctrl Dev

**T.B.D**

## Package Repository

```sh
kctrl package repository release
```

* **Repository name**: `tanzu-example.joostvdg.github.com`
* **Registry**: `index.docker.io/caladreas/tanzu-example-repo`


## Install Kapp Controller

```sh
kubectl apply -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml
```

### Install Package Repository


```sh
kctrl package repository add \
    --repository tanzu-example-repo\
    --url caladreas/tanzu-example-repo:0.0.0-build.1668725066 \
    --namespace kapp-controller-packaging-global
```

!!! Notes
    `kapp-controller-packaging-global` ...
    **T.B.D**

```sh
kubectl get packagerepository -A
```

```sh
NAMESPACE                          NAME                 AGE   DESCRIPTION
kapp-controller-packaging-global   tanzu-example-repo   15s   Reconcile succeeded
```

### Install Package

```sh
kctrl package available list
```

```sh
Target cluster 'https://pineapple:6443' (nodes: pineapple, 6+)

Available summarized packages in namespace 'default'

Name                           Display name
cncf-demo.joostvdg.github.com  cncf-demo
kctrl-package.demo.kearos.net  kctrl-package

Succeeded
```

```sh
kctrl package available list \
  -p cncf-demo.joostvdg.github.com
```

```sh
Target cluster 'https://pineapple:6443' (nodes: pineapple, 6+)

Available packages in namespace 'default'

Name                           Version  Released at
cncf-demo.joostvdg.github.com  0.1.1    2022-11-17 23:41:29 +0100 CET

Succeeded
```

```sh
kctrl package available get -p cncf-demo.joostvdg.github.com
```

```sh
Target cluster 'https://pineapple:6443' (nodes: pineapple, 6+)

Name                 cncf-demo.joostvdg.github.com
Display name         cncf-demo
Categories           -
Short description    cncf-demo.joostvdg.github.com
Long description     cncf-demo.joostvdg.github.com
Provider             -
Maintainers          -
Support description  -

Version  Released at
0.1.1    2022-11-17 23:41:29 +0100 CET

Succeeded
```

```sh
kctrl package available get \
  --package cncf-demo.joostvdg.github.com/0.1.1 \
  --values-schema
```

```sh
Target cluster 'https://pineapple:6443' (nodes: pineapple, 6+)

Values schema for 'cncf-demo.joostvdg.github.com/0.1.1'

Key               Default                      Type    Description
image.repository  docker.io/vfarcic/cncf-demo  string  The Container Image Repository
image.tag         v0.0.1                       string  The Container Image Tag
ingress.host      ""                           string  The Ingress hostname
name              cncf-demo                    string  Name for the resources

Succeeded
```

```sh
echo "
ingress:
  host: kiwi.fritz.box
" > cncf-demo-values.yml
```

```sh
kubectl create namespace cncf-demo
```

```sh
kctrl package install \
  --package-install cncf-demo-install \
  --package cncf-demo.joostvdg.github.com \
  --version 0.1.1 \
  --namespace cncf-demo \
  --values-file cncf-demo-values.yml
```

```sh
http kiwi.fritz.box
```

```sh
HTTP/1.1 200 OK
content-length: 21
content-type: text/plain; charset=utf-8
date: Thu, 17 Nov 2022 23:05:21 GMT
server: envoy
x-envoy-upstream-service-time: 0

This is a silly demo
```