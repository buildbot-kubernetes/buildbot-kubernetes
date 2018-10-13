
V=@

all:
	skaffold run


release:

	$(V)if ./hack/release.sh --check-release; then \
	   ./hack/release.sh --release; \
	fi

publish: release
	$(V)./hack/release.sh --publish;

#:vim set noexpandtab shiftwidth=8 softtabstop=0
