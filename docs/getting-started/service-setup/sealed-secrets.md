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
