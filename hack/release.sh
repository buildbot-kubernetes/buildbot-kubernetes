#!/bin/bash

set -e

print_help() {
    echo "./hack/release.sh [--options]"
    echo ""
    echo "-c|--check-release: Check if release is needed"
    echo "-r|--release:       Perform release (implies a release check before)"
    echo "-p|--publish:       Publish release to repo"
    exit 0
}

vercomp() {
    local IFS=.
    local i ver1=($1) ver2=($2)
    for ((i=0; i<${#ver2[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            return 0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 0
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 1
        fi
    done
    return 0
}

check_release() {
    if git tag | grep -q "v${VERSION}"; then
        echo "Version v${VERSION} already released"
        exit 1
    fi
    DONE=true
}

release() {
    check_release

    PREVIOUS_VERSION=$(git describe --abbrev=0 --tags || echo "0.0.0")

    if ! vercomp ${VERSION} ${PREVIOUS_VERSION//v/}; then
        echo "Version(v$VERSION) can't be lower than previous version(${PREVIOUS_VERSION})"
        exit 1
    fi

    echo "Found version ${VERSION}"

    helm dependency build ${BASE_REPO}/helm/buildbot
    helm package ${BASE_REPO}/helm/buildbot \
        --destination ${BUILD_DIR}

    git tag -a "v${VERSION}" -m "Release of v${VERSION}"

    hub release create \
        -a ${BUILD_DIR}/buildbot-*.tgz \
        -m "v${VERSION}" \
        "v${VERSION}"
    DONE=true
}

clone() {
    : "${STATIC_REPO:=git@github.com:buildbot-kubernetes/buildbot-kubernetes.github.io}"

    CLONE_DIR=buildbot-kubernetes.github.io

    if [ ! -d "${BUILD_DIR}/${CLONE_DIR}" ]; then
        git clone ${STATIC_REPO} ${BUILD_DIR}/${CLONE_DIR}
    fi

}

publish() {
    : "${RELEASE_BASE_URL:=https://github.com/buildbot-kubernetes/buildbot-kubernetes/releases/download}"

    clone

    helm repo index ${BUILD_DIR} \
        --url ${RELEASE_BASE_URL}/v${VERSION}/ \
        --merge ${BUILD_DIR}/${CLONE_DIR}/charts/stable/index.yaml

    cp ${BUILD_DIR}/index.yaml ${BUILD_DIR}/${CLONE_DIR}/charts/stable/index.yaml

    (cd ${BUILD_DIR}/${CLONE_DIR}; git add .; git commit -m "Release of v${VERSION}")
    DONE=true
}

BASE_REPO=$(git rev-parse --show-toplevel)
BUILD_DIR=${BASE_REPO}/build
mkdir -p ${BUILD_DIR}
VERSION=$(helm inspect chart ${BASE_REPO}/helm/buildbot|grep version|cut -d' ' -f2)

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -c|--check-release)
    check_release
    shift
    ;;
    -r|--release)
    release
    shift
    ;;
    -p|--publish)
    publish
    shift
    ;;
    -h|--help)
    print_help
    shift
    ;;
    *)    # unknown option
    POSITIONAL+=("$1")
    print_help
    shift
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [ ! ${DONE} ] ; then
    release
    publish
fi
