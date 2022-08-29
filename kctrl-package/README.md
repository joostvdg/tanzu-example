# Carvel Package with KCTRL

Starting with `0.40.0` the [kctrl](https://carvel.dev/kapp-controller/docs/v0.40.0/kctrl-package-authoring/) (K App Controller) supports managing Carvel Packages and Carvel Package Repositories.

## Prerequisites

* `ytt`
* `kbld`
* `kctrl` (=> 0.40.0)
* `vendir`

## Steps

* create root folder for the package
* initialize Carvel Package with `kctrl package init`
* update your package with the required content
* prepare Image Lock with `ytt` and `kbld` (optional step, which should become redundant)
* build and publish your `kapp` with `kctrl package release`
* build and publish your `kapp repo` with `kctrl package repo release`

## Init

Lets create our package folder, the folder we'll use for the `kbld` ImageLock file  (`.imgpkg`), and the folder where we store our Kubernetes resources (`config`).

```sh
mkdir -p kctrl-package/.imgpkg
mkdir -p kctrl-package/config
```

```sh
cd kctrl-package
```

```sh
kctrl package init
```

We'll use a local folder called `config` to house our `ytt` templated Kubernetes resources.
So when prompted, select `1: Local Directory` with `1` and hit enter.
And then answer with `config` for the folder location.

### Post Init Folder State

```sh
tree -a
```

Should return the following:

```sh
.
├── .imgpkg
├── README.md
├── config
├── package-build.yml
└── package-resources.yml
```

## Add Content

As the focus here is on packaging a Kubernetes application with Carvel packages, let us use a simple application as example.

I've taken a liking to [PodInfo](https://github.com/stefanprodan/podinfo), as it is a good demo application for various reasons and very well managed (GitHub repo, Helm chart, and so on).

The Helm chart is available on [Artifact Hub](https://artifacthub.io/packages/helm/podinfo/podinfo), where we can also inspect all the resource files and default values.

I've made the effort of translating the Helm chart's Deployment and Service resources into `ytt` templated versions.

### Post Add Content State

```sh
tree -a
```

Results in:

```sh
.
├── .imgpkg
├── README.md
├── config
│   ├── config.yml
│   └── values.yml
├── package-build.yml
└── package-resources.yml
```

### Config.yaml

```yaml
#@ load("@ytt:data", "data")
#@ load("@ytt:assert", "assert")


#@ if data.values.name == "":
#@   assert.fail('data value "name" must not be empty')
#@ end
#@ instanceName    = data.values.name
#@ labels          = { "app.kubernetes.io/name": instanceName }
#@ podHttpPort     = "8080"
#@ podMetricsPort  = "8081"

---

apiVersion: v1
kind: Service
metadata:
  name: #@ instanceName
  labels: #@ labels
spec:
  type: #@ data.values.service.type
  ports:
    - port: #@ int(data.values.service.httpPort)
      targetPort: http
      protocol: TCP
      name: http
    - port: #@ int(data.values.service.metricsPort)
      targetPort: http-metrics
      protocol: TCP
      name: http-metrics
  selector: #@ labels

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: #@ instanceName
  labels: #@ labels
spec:
  replicas: #@ data.values.replicaCount
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels: #@ labels
  template:
    metadata:
      labels: #@ labels
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: #@ data.values.service.metricsPort
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - name: #@ instanceName
          image: #@ "ghcr.io/stefanprodan/podinfo:"+data.values.imageTag
          imagePullPolicy: #@ data.values.pullPolicy
          command:
            - ./podinfo
            - #@ "--port=" + podHttpPort
            - #@ "--port-metrics=" + podMetricsPort
          env:
          - name: PODINFO_UI_MESSAGE
            value: #@ data.values.ui.message
          - name: PODINFO_UI_COLOR
            value: #@ data.values.ui.color
          ports:
            - name: http
              containerPort: #@ int(podHttpPort)
              protocol: TCP
            - name: http-metrics
              containerPort: #@ int(podMetricsPort)
              protocol: TCP
          livenessProbe:
            exec:
              command:
              - podcli
              - check
              - http
              - #@ "localhost:" + podHttpPort + "/healthz"
            initialDelaySeconds: 1
            timeoutSeconds: 5
          readinessProbe:
            exec:
              command:
              - podcli
              - check
              - http
              - #@ "localhost:" + podHttpPort + "/readyz"
            initialDelaySeconds: 1
            timeoutSeconds: 5
          volumeMounts:
          - name: data
            mountPath: /data
      volumes:
      - name: data
        emptyDir: {}
```

### Values.yaml

```yaml
#@data/values-schema
---
#@schema/title "Instance Name"
#@schema/desc "The name of the instance and related objects"
name: ""

#@schema/title "Instance Namespace"
#@schema/desc "The namespace the instance objects should be deployed into"
#@schema/nullable
namespace: ""

#@schema/title "Labels"
#@schema/desc "A set of labels which will be applied to all resources related to this instance"
#@schema/default {"app.kubernetes.io/app":"podinfo"}
#@schema/type any=True
labels:

#@schema/title "ReplicaCount"
#@schema/desc "Number of Replicas"
#@schema/default 1
replicaCount: 0

#@schema/title "PullPolicy"
#@schema/desc "Pull Policyd of the Container Image"
#@schema/default "IfNotPresent"
pullPolicy: ""

#@schema/title "ImageTag"
#@schema/desc "Tag of the Container Image"
#@schema/default "6.2.0"
imageTag: ""

#@schema/title "Service Configuration"
#@schema/desc "Options related to the Service"
service:

  #@schema/default "ClusterIP"
  type: ""

  #@schema/default "9797"
  metricsPort: ""

  #@schema/default "80"
  httpPort: ""

#@schema/title "UI Configuration"
#@schema/desc "Options related to the UI, such as the message and the color"
ui:
  message: ""

  #@schema/default "#34577c"
  color: ""
```

## Create Image Lock file

I really like the ImageLock feature of `kbld`.
It is strongly recommend to always point to a OCI image SHA, rather than an image _tag_.

But that is always so cumbersome.
Assuming you already have a valid OCI image that is used by your resource(s), we can let `kbld` resolve the classic OCI image with tag to its SHA.

Unfortunately, at this time of writing (August 22, 2022) with version `0.40.0` of the `kctrl` CLI, the release command doesn't do this properly.

So we have to run this ourselves.
The resources used are `ytt` templates, so we first run `ytt` before handing the files to `kbld`.

```sh
ytt -f config -v name=podinfo-demo | kbld -f - --imgpkg-lock-output .imgpkg/images.yml
```

### Post Image Lock State

```sh
tree -a
```

Results in:

```sh
.
├── .imgpkg
│   └── images.yml
├── README.md
├── config
│   ├── config.yml
│   └── values.yml
├── package-build.yml
└── package-resources.yml
```

### Image.yml

The `images.yml` file resides in the `.imgpkg` folder.

```yaml
---
apiVersion: imgpkg.carvel.dev/v1alpha1
images:
- annotations:
    kbld.carvel.dev/id: ghcr.io/stefanprodan/podinfo:6.2.0
    kbld.carvel.dev/origins: |
      - resolved:
          tag: 6.2.0
          url: ghcr.io/stefanprodan/podinfo:6.2.0
  image: ghcr.io/stefanprodan/podinfo@sha256:fbc7e3038e8f8235d4d0c04484ee5d3019eb941a9643b733e60c18443d228f3a
kind: ImagesLock
```

## Verify Package

The `kctrl` CLI supports deploying your package to a Kubernetes cluster directly for testing. This makes the development loop shorter, as it bypasses package release, installation via the KAPP Controller, and any intermediary steps (such a package repo updates).

You can do this via the `kctrl dev` command.

* update `package-resources.yml` for `ytt` template data
* add data values file
* setup Kubernetes Service Account
* run `kctrl dev` command

### Update Package-Resources.yml

The `ytt` template in `config/config.yml` contains a required value, `name`, which does not have a default value defined in `config/values.yml`.

This is on purpose, to verify we are supplying the values correctly and they are used.

In this case, we have to edit the `package-resources.yml`.

Add a `data` path to the `ytt` template in the `Package` CR.

The path: `spec.template.spec.template.ytt.paths`

Which will them look like this:

```yaml
spec:
  template:
    spec:
      template:
      - ytt:
          paths:
          - config
          - data
```

### Add Data Values file

We just told `ytt` to _also_ look into the folder `./data` for its templating.

Lets add a value defition for the `name` property.
We can do this by creating a file which is annotated with `ytt`'s annotation `#@data/values`.

```yaml
#@data/values
---
name: podinfo-demo-01
```

### Create Kubernetes Service Account

```sh
kubectl create sa kctrl-package-sa
```

```sh
kubectl create rolebinding kctrl-admin \
  --clusterrole=admin \
  --serviceaccount=default:kctrl-package-sa
```

### Kctrl Dev

```sh
kctrl dev -f package-resources.yml -l
```

### End State After Dev

```sh
tree -a
```

```sh
.
├── .imgpkg
│   └── images.yml
├── README.md
├── config
│   ├── config.yml
│   └── values.yml
├── data
│   └── default-values.yml
├── package-build.yml
└── package-resources.yml
```

## Release Package

We currently have package metadata, content and an image lock file.
The package is now ready to be released.

Releasing a package creates meta data for a Package Repository, and pushes an OCI image with the package (also called a Bundle) to your OCI registry of choice.

As with pushing any OCI image, such as a Docker container image, you need to have write access to a the registry. To verify you have that access, login to that registry with `docker login` or your Docker alternative's equivalent.

### Docker Login

```sh
$ docker login
Authenticating with existing credentials...
Login Succeeded
```

### Release Package Command

The first time you run the `kctrl package release` command, it is interactive.
It asks you about your image's URL, such as `index.docker.io/joostvdgtanzu/kctrl-package-demo-1`.

Besides creating your package, you can also generate the meta data for a Package Repository, if you have one, with the `--repo-output` flag.

```sh
kctrl package release -v 0.1.0 \
    --repo-output ../kctrl-package-repo/packages \
```

## Sign Bundle With Cosign

* https://carvel.dev/blog/signing-imgpkg-bundles-with-cosign/

TODO
