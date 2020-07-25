# Jarvus Cluster Template

This template provides a common foundation for lightweight k8s clusters.

## Getting started

The `.holo/branches/k8s-manifests` tree defines a holobranch named `k8s-manifest`, which can be projected with the `git-holo` tool:

```bash
npm install -g hologit
cd ./cluster-template
git holo project k8s-manifest # output is tree hash
```

The output is the hash of a git tree object, which could be passed to `git archive` to generate a tar stream or file, or you could instead have `git-holo` commit it to a named branch for you:

```bash
git holo project k8s-manifest --commit-to=k8s/master
```

## How it works

- `.holo/config.toml` assigns the source name `jarvus-cluster-template` to the local repository
- `.holo/sources/cert-manager.toml` defines a named remote content source
- `.holo/branches/k8s-manifests/_jarvus-cluster-template.toml` populates the root of the `k8s-manifests` holobranch with a filtered subset of the local repository's contents
- `.holo/branches/k8s-manifests/infra/cert-manager.toml` populates the `infra/cert-manager/` path of the `k8s-manifests` holobranch with content from the `cert-manager` source
- `.holo/branches/k8s-manifests/infra/cert-manager.crd.toml` populates the `infra/cert-manager.crd/` path of the `k8s-manifests` holobranch with content from the `cert-manager` source
- `.holo/lenses/cert-manager` applies `helm template` to the `infra/cert-manager/` path, replacing it with the rendered output
- `.holo/lenses/k8s-normalize` applies (after all other lenses) a NodeJS script to the entire tree converting it to a normal form

## Using

While you could apply the output of this repository directly to a cluster, the real power is using it from your own repository as a base layer for your own content:

```bash
# create a new repo
git init /tmp/my-cluster; cd /tmp/my-cluster

# create an initial commit before using git-holo
echo "# my-cluster" > README.md; git add README.md; git commit -m "docs: initial commit"

# initialize git-holo configuration
git holo init
git commit -m "chore: git holo init"

# create k8s-manifest holobranch
git holo branch create k8s-manifests --template=passthrough
git commit -m "feat: add k8s-manifests holobranch"

# test holobranch projection
git ls-tree $(git holo project k8s-manifests) # just a README.md for now

# add jarvus-cluster-template as a source
git holo source create https://github.com/JarvusInnovations/cluster-template --name jarvus-cluster-template
git commit -m "feat: add jarvus-cluster-template holosource"

# underlay k8s-blueprint holobranch from jarvus-cluster-template holosource
echo '[holomapping]
holosource = "=>k8s-blueprint"
files = "**"
before = "*"
' > .holo/branches/k8s-manifests/_jarvus-cluster-template.toml
git add --all
git commit -m "feat: add jarvus-cluster-template content to k8s-manifest holobranch"

# commit projection to a branch
git holo project k8s-manifests --commit-to=k8s/manifests

# inspect the tree
git ls-tree -r k8s/manifests

# see what the tree looks like pre-lensing (.holo/lenses/ contains pending lenses)
git ls-tree -r $(git holo project k8s-manifests --no-lens)

# override a source file
mkdir -p "infra/cert-manager/"
echo 'prometheus:
  enabled: true
' > infra/cert-manager/values.yaml
git add --all
git commit -m "feat: enable prometheus in cert-manager"

# re-project and commit to previous branch
git holo project k8s-manifests --commit-to=k8s/manifests
```
