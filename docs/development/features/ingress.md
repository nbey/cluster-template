# Ingress

## Exposing services

`*.{{ cluster.wildcard_hostname }}` should be configured to resolve to the cluster's `ingress-nginx` service.

To route a public hostname to a service in the cluster:

1. Create an Ingress
2. Apply the annotation `kubernetes.io/ingress.class: nginx` to associate with the cluster's main ingress service
3. Apply the annotation `cert-manager.io/cluster-issuer: {{ cluster.cluster_issuer }}` to enable automatic setup of an SSL certificate
4. Assign an unused hostname under `.{{ cluster.wildcard_hostname }}` (every public service should start with one of these)
5. Optionally, CNAME a custom hostname to the `.{{ cluster.wildcard_hostname }}` hostname and add it to the same ingress
