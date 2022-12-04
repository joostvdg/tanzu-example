---
title: Carvel Package from scratch
description: Create a Carvel Package for a Kubernetes application from scratch
author: Joost van der Griendt
tags: [carvel, kubernetes, yaml, ytt, helm]
---

We are going to create a Carvel package for managing an application installation in Kubernetes.

We start with an empty dir, and create everything via copy-pastable commandline instructions.

We execute the following steps:

* Initialize the **Package**
* Create the templates
* Test the package
* Initialize the **Package Repository**
* Build & Publish the **Package**
* Publish the **Package**
* Install the **Package Repository**
* Install the **Package**

## Prerequisites

* kubectl client
* Carvel toolsuite
    * YTT
    * kbld
    * kctrl
    * kapp

## Init Package

```sh
mkdir -p packages/silly-demo/config
mkdir -p package-repository
```

```sh
cd packages/silly-demo
```

```sh
kctrl package init
```

* **Name**: `cncf-demo.joostvdg.github.com`
* **Content**: **1** (_Local directory_)
* **Source**: `config` (Carvel convention)

Our folder now looks like this:

```sh
tree -a ../../
```

```sh
../../
├── package-repository
└── packages
    └── silly-demo
        ├── config
        ├── package-build.yml
        └── package-resources.yml
```

## Setup Templates

Helm charts have templates, where you set alternative values at runtime.
We will use Carvel's YTT for this templating.

We creat the following:

* Deployment template
* Service template
* Ingress template
* Template schema (for YTT validations)


### Add Deployment Template

```sh
kubectl create deployment placeholder \
    --image=imageRepo:imageTag \
    --output=yaml \
    --dry-run=client \
    --port 8080 > config/01-deployment.ytt.yml
```

```sh
echo '#@ load("@ytt:data", "data")\n---\n' | cat - config/01-deployment.ytt.yml > temp && mv temp config/02-service.ytt.yml
```

```sh
yq e -i '.metadata.labels."app.kubernetes.io/name" = "#@ data.values.appName"' config/01-deployment.ytt.yml
yq e -i '.metadata.name = "#@ data.values.appName"' config/01-deployment.ytt.yml
yq e -i '.spec.metadata.name = "#@ data.values.appName"' config/01-deployment.ytt.yml
yq e -i '.spec.metadata.labels."app.kubernetes.io/name" = "#@ data.values.appName"' config/01-deployment.ytt.yml
yq e -i '.spec.selector.matchLabels."app.kubernetes.io/name" = "#@ data.values.appName"' config/01-deployment.ytt.yml
yq e -i '.spec.template.metadata.labels."app.kubernetes.io/name" = "#@ data.values.appName"' config/01-deployment.ytt.yml
yq e -i '.spec.template.spec.containers[0].image = "#@ data.values.imageRepo + \":\" + #@ data.values.imageTag"' config/01-deployment.ytt.yml
yq e -i '.spec.template.spec.containers[0].name = "#@ data.values.appName"' config/01-deployment.ytt.yml
```

```sh
yq e -i '.spec.template.spec.containers[0].livenessProbe = "{\"httpGet\": {\"path\": \"/\",\"port\": 8080}}"' config/01-deployment.ytt.yml
yq e -i '.spec.template.spec.containers[0].readinessProbe = "{\"httpGet\": {\"path\": \"/\",\"port\": 8080}}"' config/01-deployment.ytt.yml
yq e -i '.spec.template.spec.containers[0].resources = "{\"limits\":{\"cpu\": \"500m\",\"memory\": \"512Mi\"},\"requests\":{\"cpu\": \"250m\",\"memory\": \"256Mi\"}}"' config/01-deployment.ytt.yml
```

```sh
yq e -i '.spec.template.spec.containers[0].env = "#@ data.values.env"' config/01-deployment.ytt.yml
```

### Service Template

```sh
echo '#@ load("@ytt:data", "data")\n---\n' config/02-service.ytt.yml
```

!!! Warning
    The `kubectl expose` command requires the deployment to exist!

```sh
kubectl expose deployment podinfo \
  --port=8080 --target-port=8000 \
  --labels=app.kubernetes.io/name=test \
  --selector=app.kubernetes.io/name=test \
  --output yaml --dry-run=client >> config/02-service.ytt.yml
```

```sh
yq e -i '.metadata.name = "#@ data.values.appName"' config/02-service.ytt.yml
yq e -i '.metadata.labels."app.kubernetes.io/name" = "#@ data.values.appName"' config/02-service.ytt.yml
yq e -i '.spec.selector."app.kubernetes.io/name" = "#@ data.values.appName"' config/02-service.ytt.yml
```

### Ingress Template

### Schema Template


## Test the package

TODO: `kctrl dev`

## Initialize Package Repository

## Build & Publish the Package

## Publish the Package

## Install the Package Repository

## Install the Package
