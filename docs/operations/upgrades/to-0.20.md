# To 0.20.x

`cluster-template` v0.20.x  brings compatibility with Kubernetes 1.22

## Upgrade `cert-manager` APIs

Any manifests defining `ClusterIssuer` objects must be upgraded to the stable API:

```diff
diff --git a/cert-manager.issuers.yaml b/cert-manager.issuers.yaml
index ebd08997..8dba5834 100644
--- a/cert-manager.issuers.yaml
+++ b/cert-manager.issuers.yaml
@@ -1,4 +1,4 @@
-apiVersion: cert-manager.io/v1alpha2
+apiVersion: cert-manager.io/v1
 kind: ClusterIssuer
```

## Upgrade `sealed-secrets` ingress config

The newer version of `sealed-secrets` has a new syntax for configuring its ingress:

```diff
diff --git a/sealed-secrets/release-values.yaml b/sealed-secrets/release-values.yaml
index eb3216c2..3fcef1d3 100644
--- a/sealed-secrets/release-values.yaml
+++ b/sealed-secrets/release-values.yaml
@@ -6,9 +6,5 @@ ingress:
   annotations:
     kubernetes.io/ingress.class: nginx
     cert-manager.io/cluster-issuer: letsencrypt-prod
-  hosts:
-    - sealed-secrets.sandbox.k8s.example.com
-  tls:
-    - secretName: sealed-secrets-tls
-      hosts:
-        - sealed-secrets.sandbox.k8s.example.com
+  hostname: sealed-secrets.sandbox.k8s.example.com
+  tls: true
```

## Upgrade RBAC APIs for any service account manifests

```diff
diff --git a/admins/project-admin.yaml b/admins/project-admin.yaml
index dc5c52d0..b3fedfcc 100644
--- a/admins/project-admin.yaml
+++ b/admins/project-admin.yaml
@@ -14,7 +14,7 @@ metadata:
 ---

 kind: Role
-apiVersion: rbac.authorization.k8s.io/v1beta1
+apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: deployment-admin
```

## Check for deprecated APIs

After deploying v0.20.x, check for any locally-defined manifests using deprecated APIs **before upgrading** the host cluster to Kubernetes v1.22+.

Check for deployed objects with deprecated APIs:

```bash
kubent --target-version 1.22.0
```

Check for helm chart snapshots:

```bash
pluto detect-helm
```

## Deployment

Before deploying an upgrade to v0.20.x, delete existing `ingress-nginx` jobs to prevent errors about immutable fields being changed:

```bash
kubectl -n ingress-nginx delete jobs ingress-nginx-admission-create ingress-nginx-admission-patch
```

For the same reason, also delete the `prometheus-kube-state-metrics` deployment:

```bash
kubectl -n prometheus delete deployment prometheus-kube-state-metrics
```
