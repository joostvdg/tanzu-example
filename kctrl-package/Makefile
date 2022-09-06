LOCAL_VERSION = $(shell git describe --tags --always)
PACKAGE_VERSION ?= "0.0.0-${LOCAL_VERSION}"
SHELL := $(shell which bash)
KDEV_SA_NAME=kctrl-dev-sa
KDEV_SA_NAMESPACE=default
DEV_PACKAGE_NAME ?= ${PACKAGE_NAME}
DEV_NAMESPACE ?= default

clean:
	rm -f package-kdev.yml || true

kdev-prepare: clean
	yq e '... comments="" | .spec.template.spec.template[] |= select(.ytt != null).ytt.paths=["config","dev-data"]' package.yml > package-kdev.yml

kdev: kdev-prepare image-lock
	kctrl dev -f package-kdev.yml -f package-metadata.yml -f package-install.yml  -l --debug
	
kdev-cleanup: kdev-prepare
	kctrl dev -f package-kdev.yml -f package-metadata.yml -f package-install.yml -l --delete

image-lock:
	mkdir -p .imgpkg
	ytt -f config -v name=podinfo-demo | kbld -f - --imgpkg-lock-output .imgpkg/images.yml

create-kdev-sa:
	kubectl create serviceaccount ${KDEV_SA_NAME} -n ${KDEV_SA_NAMESPACE} || true
	kubectl delete clusterrolebinding kdev-cluster-admin || true
	kubectl create clusterrolebinding kdev-cluster-admin --clusterrole=cluster-admin --serviceaccount=${KDEV_SA_NAMESPACE}:${KDEV_SA_NAME}	

release-prep:
	rm package-resources.yml || true
	ytt -f package.yml -f package-metadata.yml -f package-install.yml > package-resources.yml

release: image-lock release-prep
	kctrl package release -v ${PACKAGE_VERSION} --repo-output ../kctrl-package-repo/packages  -y
	rm -rf carvel-artifacts