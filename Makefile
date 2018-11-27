V=@

BUILD_DIR=build
RELEASE_REPO_SRC=git@github.com:buildbot-kubernetes/buildbot-kubernetes.github.io
RELEASE_REPO=$(BUILD_DIR)/buildbot-kubernetes.github.io
RELEASE_BASE_URL=https://github.com/buildbot-kubernetes/buildbot-kubernetes/releases/download
HUGO_THEME_REPO=docs/themes/kube

COMMIT=$(shell git rev-parse --short HEAD)
VERSION=$(shell helm inspect chart helm/buildbot|grep version|cut -d' ' -f2)
PREV_VERSION=$(shell git describe --abbrev=0 --tags || echo "0.0.0")
ALREADY_RELEASED=git tag | grep -q "v$(VERSION)"

.PHONY: test
test:
	$(V)skaffold run

$(BUILD_DIR):
	$(V)mkdir -p $@

$(RELEASE_REPO): |$(BUILD_DIR)
	$(V)git clone $(RELEASE_REPO_SRC) $@

$(HUGO_THEME_REPO)/theme.toml:
	$(V)git submodule init $(dir $@)
	$(V)git submodule update $(dir $@)

.PHONY: docs
docs build/docs: |$(BUILD_DIR) $(HUGO_THEME_REPO)/theme.toml
	$(V)cd docs; hugo

.PHONY: release-docs
UNTOUCHED_FILE=.git charts LICENSE README.md
release-docs: | build/docs $(RELEASE_REPO)
	$(V)rsync -av --delete \
	$(foreach file,$(UNTOUCHED_FILE),--exclude $(file)) \
	build/docs/ $(RELEASE_REPO)/

	$(V)cd $(RELEASE_REPO); \
	git add .; \
	git commit -m "Doc update $(COMMIT)" || true

check-release:
	$(V)if $(ALREADY_RELEASED); then \
	    echo "Version v$(VERSION) already released"; \
	    exit 1; \
	fi

ifeq ($(CHECK_RELEASE),)

release:
	$(V)if ! $(ALREADY_RELEASED); then \
	    make release CHECK_RELEASE=0; \
	else \
	    echo "Version v$(VERSION) already released"; \
	fi

else

release: $(RELEASE_REPO)
	$(V)./hack/version-compare.sh $(VERSION) $(PREV_VERSION)
	$(V)echo "Found version $(VERSION)"
	$(V)helm dependency build helm/buildbot
	$(V)helm package helm/buildbot --destination $(BUILD_DIR)
	$(V)git tag -a "v$(VERSION)" -m "Release of v$(VERSION)"
	$(V)hub release create -a ${BUILD_DIR}/buildbot-$(VERSION).tgz \
	  -m "v$(VERSION)" \
	  "v$(VERSION)"
	$(V)helm repo index $(BUILD_DIR) \
        --url $(RELEASE_BASE_URL)/v$(VERSION)/ \
        --merge $(RELEASE_REPO)/charts/stable/index.yaml
	cp ${BUILD_DIR}/index.yaml $(RELEASE_REPO)/charts/stable/index.yaml
	$(V)(cd $(RELEASE_REPO); git add .; git commit -m "Release of v$(VERSION)")
endif

#:vim set noexpandtab shiftwidth=8 softtabstop=0
