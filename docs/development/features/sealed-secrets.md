# Sealed Secrets

## Prerequisites

- [Configure and deploy a public ingress for sealed-secrets on the cluster](../../getting-started/service-setup/sealed-secrets.md)
- Install the `kubeseal` client command on your local workstation from the latest stable release: <https://github.com/bitnami-labs/sealed-secrets/releases>

## Configure public certificate

Place the public URL for the target cluster's sealed secret's certificate into the `SEALED_SECRETS_CERT` environment variable:

```bash
export SEALED_SECRETS_CERT=https://sealed-secrets.{{ cluster.wildcard_hostname }}/v1/cert.pem
```

## Encrypt secrets to cluster repository

Create a Kubernetes `Secret` manifest containing one or more key+value pair, and then use the `kubeseal` client to encrypt it into a `SealedSecret` manifest. The target namespace must be provided and will become part of the encryption such that the secret can only be loaded into that namespace. Commit the sealed secret to the cluster's repository under the path `${project_namespace}.secrets/` where it will be added to the cluster's deployed manifests:

```bash
kubeseal \
    --namespace "my-project" \
    -f my-secret.yaml \
    -w ~/Repositories/my-cluster/my-project.secrets/my-secret.yaml
```
