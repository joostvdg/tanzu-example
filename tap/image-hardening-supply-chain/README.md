# TAP Image Hardening Supply Chain

* TAP Build/Full
* OOTB Testing & Scanning Supply Chain
* Re-compose Supply Chain
    * Take first two sources `scanning-image-scan-to-url`
    * Take the first X sources from `source-test-scan-to-url`
* Supply Chain Sources:
    * Image Provider  -> Base Image
    * Image Scanner   -> Base Image
    * Source Provider -> Source that contains Dockerfile and other sources we might need
    * Source Tester   -> Not Required at this point
    * Image Provider  -> New Image based on Dockerfile + Base Image (see below)
    * Image Scanner   -> New Image
* Tekton Chains
    * For automated Signing/Attestation of the Kaniko build

The goal is take a Base Image, and everytime either our Source handling improving it or the Base Image changes, we want to update our output Image.

Both the Base Image as the resutiling _new_ Image needs to be scanned.

In addition, the _new_ Image needs to be signed as well. And this signing should be automated.

## Dockerfile

The `Dockerfile` format starts with an existing Image, via the `FROM` statement.

What is cool, and in our case required, we make that starting point variable.

We do this via the Build Arguments feature.
You define a Build Argument via the `ARG` keyword, and then supply a default value.

```Dockerfile
ARG APP_IMAGE=bitnami/minideb:bookworm
FROM $APP_IMAGE

ENV ALT_DATE="2024-01-01"
```

When initiating a build, either via Docker's Buildkit or Kaniko, you supply an override for this Build Argument.

For example, with Docker:

```sh
docker buildx build \
    --tag harbor.tap.example.com/tap-apps/debian-bookworm:0.0.1 \
     --build-arg APP_IMAGE=bitnami/minideb:bookworm:latest \
    -f ./tap/image-hardening-supply-chain/debian/bookworm/Dockerfile .
```

## Supply Chain

While we can re-compose the existing Supply Chains into a new one and have it work, we do need to make changes for them to work for our purpose.

We change the following (Cartographer) Templates and related CRs:

* **SupplyChain**: we also change some of the Template referenced or the Resource's input in the Supply Chain itself (not merely copy-paste and done)
* **ClusterImageTemplate - kaniko-template**: add build argument for Kaniko, so we supply it to the Dockerfile
    * This also requires us to supply the Base Image as `images` input in the Cartographer `resource` (see next paragraph)
* Tekton Task **kaniko**: in order to have Tekton Chains automate the Cosign signing of the Image, we need to export specific results keys
* **Workload**: we need to use both an `spec.image` and a `spec.source.git` definition in the Workload for this to work

### Supply Chain Structure

Below are the Cartographer `resources`.

The first two are related to receiving updates to the Base Image (set in the **Workload**) and scanning it.

We then export the result of the scan as an `images` input to the `SourceProvider`,
 purely for the cosmetic reason to ensure the TAP GUI Supply Chain view renders te full Supply Chain.

We use the SourceProvider to ensure we have an up-to-date version of the Dockerfile, which contains our changes to the Base Image.

We run a SourceTester, while in this case there are no things to test, we probably want to include a way of doing so.

Then we build the new Image via a Kaniko Tekton Task, and then scan the new Image like we did with the Base Image.

Voila, that concludes our `source-and-image-to-new-image` Supply Chain.

```yaml
resources:
  - name: image-provider-trigger
    params:
      - default: default
        name: serviceAccount
    templateRef:
      kind: ClusterImageTemplate
      name: image-provider-template
  - images:
      - name: image
        resource: image-provider-trigger
    name: image-scanner-base-image
    params:
      - default: scan-policy
        name: scanning_image_policy
      - default: private-image-scan-template
        name: scanning_image_template
      - name: registry
        value:
          repository: tap-apps
          server: harbor.tap.example.com
    templateRef:
      kind: ClusterImageTemplate
      name: image-scanner-template
  - images:
      - name: image
        resource: image-scanner-base-image
    name: source-provider
    params:
      - default: default
        name: serviceAccount
      - default: go-git
        name: gitImplementation
    templateRef:
      kind: ClusterSourceTemplate
      name: source-template
  - name: source-tester
    sources:
      - name: source
        resource: source-provider
    templateRef:
      kind: ClusterSourceTemplate
      name: testing-pipeline
  - images:
      - name: image
        resource: image-provider-trigger
    name: image-provider
    params:
      - default: default
        name: serviceAccount
      - name: registry
        value:
          repository: tap-apps
          server: harbor.tap.example.com
      - default: default
        name: clusterBuilder
      - default: ./Dockerfile
        name: dockerfile
      - default: ./
        name: docker_build_context
      - default: []
        name: docker_build_extra_args
    sources:
      - name: source
        resource: source-tester
    templateRef:
      kind: ClusterImageTemplate
      options:
        - name: kaniko-template-2
          selector:
            matchFields:
              - key: spec.params[?(@.name=="dockerfile")]
                operator: Exists
  - images:
      - name: image
        resource: image-provider
    name: image-scanner-hardened-image
    params:
      - default: scan-policy
        name: scanning_image_policy
      - default: private-image-scan-template
        name: scanning_image_template
      - name: registry
        value:
          repository: tap-apps
          server: harbor.tap.example.com
    templateRef:
      kind: ClusterImageTemplate
      name: image-scanner-template
```

### Supply Chain Selector

To keep things simple, I set the Selector to this:

```yaml
selectorMatchExpressions:
  - key: apps.tanzu.vmware.com/workload-type
    operator: In
    values:
      - image
```

Meaning, only those **Workload**s with the Label `apps.tanzu.vmware.com/workload-type=image` select this Supply Chain.

### Kaniko Task


```sh
--registry-certificate=harbor.tap.example.com=/kaniko/.custom-certs/ca-certificates.crt
```


### Kaniko Build Instructions

In the ClusterImageTemplate `Kaniko` we add need to ensure we add the `build-arg` flag with the `APP_IMAGE` key, and the value pointing to the new Base Image.

Resulting in this in the Kaniko execution:

```sh
--build-arg=APP_IMAGE=bitnami/minideb:bookworm:latest
```

We do that by giving the Kaniko build `resource` the `image-provider-base-image` as input:

```yaml
resources:
  - name: image-provider
    images:
      - name: image
        resource: image-provider-trigger
```

We now have access to the URI of the new image in our ClusterImageTemplate via `data.values.image`.

We edit the ClusterImageTemplate `Kaniko` to add this line to the YTT function `merge_docker_extra_args`:

```yaml
extra_args.append("--build-arg=APP_IMAGE={}".format(data.values.image))
```

NOTE: to see the resources in Kubernetes, use `kubectl describe` as it "unrolls" the YTT template (e.g., `kubectl describe ClusterImageTemplate kaniko-template-2`)

## Automated Image Signing

We can leverage [Tekton Chain](https://tekton.dev/docs/chains/) to automate the signing of Images and create build Attestation (Tasks or Pipelines).

What to do?

* Install Tekton Chains
    * And configure it (see below)
* Create a Cosign Signing Key
* Ensure we export the expected Results

### Configuration

The base of these commands is derived from the Tekton Chains docs.

By default, it uses the `in-toto` format, which is `slsa v1`, whereas we want to use `slsa v2`.

The Transparency is disbaled, as we need to upload to a [Rekor](https://github.com/sigstore/rekor) server.

By default it tries to connect our Image repository to the public server, which doesn't accept our self-signed certificate (self-hosted Harbor).

```sh
kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"artifacts.taskrun.format": "slsa/v2alpha2"}}'
kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"artifacts.taskrun.storage": "tekton,oci"}}'
kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"artifacts.oci.format": "simplesigning"}}'
kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"artifacts.oci.storage": "tekton,oci"}}'
kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"transparency.enabled": "false"}}'
```

This also shows we are configuring the `taskrun`, so Tekton handles signing and attestation per TaskRun's, rather than PipelineRuns.

### Create Cosign Key

Tekton Chain controller expects a Cosign key in its own namespace, by the name `signing-secrets`.

Which we create as follows:

```sh
cosign generate-key-pair k8s://tekton-chains/signing-secrets
```

### Task Results

Tekton Chains expects a **PipelineRun**, or in our case a **TaskRun** to export specific fields in the **Results** section.

These end up in the CR field `status.results`, and are then leveraged to Sign the Image and create the build Attestation.

The expected names are `IMAGE_DIGEST` and `IMAGE_URL`.

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: test
spec:
    results:
    - description: Ref of the image just built.
        name: image_ref
        type: string
    - description: Digest of the image just built.
        name: IMAGE_DIGEST
        type: string
    - description: URL of the image just built.
        name: IMAGE_URL
        type: string
    params: {}
    steps: {}
```

We need a third output, by the name of `image_ref`.
This is for the Cartographer Supply Chain, to be able to use this as an Images input.

## Full Supply Chain Files

Below are complete files used, so the snippets in earlier stages can stay focused on the explanation.

They are in this folder or the subfolders for the Workload/Dockerfiles.