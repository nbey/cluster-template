# Sealed Secrets

The [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) controller will automatically generate a public+private keypair for each cluster that will be used to encrypt and decrypt secrets.

After any new cluster is provisioned, the generated keypair should be backed up externally (i.e. to a shared VaultWarden/BitWarden collection). With the keypair backed up, secrets can be [decrypted locally](https://github.com/bitnami-labs/sealed-secrets#can-i-decrypt-my-secrets-offline-with-a-backup-key) or [restored to a new cluster](https://github.com/bitnami-labs/sealed-secrets#can-i-bring-my-own-pre-generated-certificates) in the future.

## Back up generated keys

[From the `sealed-secrets` README.md](https://github.com/bitnami-labs/sealed-secrets#can-i-decrypt-my-secrets-offline-with-a-backup-key):

```bash
kubectl get secret \
    -n sealed-secrets \
    -l sealedsecrets.bitnami.com/sealed-secrets-key \
    -o yaml \
> cluster-sealed-secrets-master.key
```

!!! warning "Sensitive data!"

    Be sure to keep this file secure and delete from your working directory after uploading it to a secure credentials vault for backup.

    **Do not commit this file to source control**

## Enable ingress

The `sealed-secrets` helm chart includes an ingress that can be configured to provide a public URL to the cluster's public certificate that can be used for local `kubeseal` client operations.

To enable the ingress, configure and deploy `sealed-secrets/release-values.yaml`:

=== "sealed-secrets/release-values.yaml"

    ```yaml
    ingress:
    enabled: true
    annotations:
        kubernetes.io/ingress.class: nginx
        cert-manager.io/cluster-issuer: {{ cluster.cluster_issuer }}
    hosts:
        - sealed-secrets.{{ cluster.wildcard_hostname }}
    tls:
        - secretName: sealed-secrets-tls
        hosts:
            - sealed-secrets.{{ cluster.wildcard_hostname }}
    ```

Once deployed, local `kubeseal` clients can be configured to use it by setting the `SEALED_SECRETS_CERT` environment variable:

```bash
export SEALED_SECRETS_CERT=https://sealed-secrets.{{ cluster.wildcard_hostname }}/v1/cert.pem
```
