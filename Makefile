.PHONY: docs
docs:
	mkdocs serve

.PHONY: publish-docs
publish-docs: generate-docs
	mkdocs gh-deploy -b gh-pages