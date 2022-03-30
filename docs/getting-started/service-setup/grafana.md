# Grafana

New clusters will start with the `grafana` deployment blocked from starting a pod for lack of the `grafana-initial-admin` secret existing.

Creating this secret will enable `grafana` to start up and create an initial admin login. The secret should be left on the cluster after that as the deployment requires it, but making changes to it will not update any Grafana login unless Grafana's persistent storage is reset.

## Creating `grafana-admin-secret`

Use this command to generate a usable secret with a random password:

```bash
kubectl -n grafana create secret generic grafana-initial-admin \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$(LC_ALL=C </dev/urandom tr -dc '[:alnum:]_' | head -c 32)"
```
