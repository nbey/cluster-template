
# Step 1: Configure .kube/config

test -e ~/.kube || mkdir ~/.kube

echo "${{ secrets.KUBECONFIG_BASE64 }}" | base64 -d > ~/.kube/config

# initialize empty log of kube operations
echo -n '' > /tmp/kube.log

# Step 2: Apply manifests: CRD resources

if [ -d ./_/CustomResourceDefinition ]; then
  kubectl apply -Rf ./_/CustomResourceDefinition | tee -a /tmp/kube.log
fi

# Step 3: Apply manifests: non-CRD global resources

if [ -d ./_ ]; then
  (
    find _ \
      -maxdepth 1 \
      -mindepth 1 \
      -type d \
      -not -name 'CustomResourceDefinition' \
      -print0 \
    | sort -z \
    | xargs -r0 -n 1 kubectl apply -Rf
  ) | tee -a /tmp/kube.log
fi

# Step 4: Apply manifests: namespaced resources

(
  find . \
    -maxdepth 1 \
    -type d \
    -not -name '_' \
    -not -name '.*' \
    -print0 \
  | sort -z \
  | xargs -r0 -n 1 kubectl apply -Rf
) | tee -a /tmp/kube.log


# Step 5: Apply manifests: generated regcred secrets

# apply a copy of regcred secret for every deployed namespace
while IFS= read -r namespace; do
  namespace="$(basename "${namespace}")"
  cat <<EOF | kubectl apply -f - | tee -a /tmp/kube.log
apiVersion: v1
kind: Secret
metadata:
  name: regcred
  namespace: ${namespace}
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ${{ secrets.DOCKER_CONFIG_BASE64 }}
EOF
done <<< "$(find . -maxdepth 1 -type d -not -name '_' -not -name '.*')"

# Step 6: Apply manifests: deleted resources

for manifest_path in $(git diff-tree --name-only --diff-filter=D -r HEAD^ HEAD); do
  manifest_path="${manifest_path%.yaml}"
  namespace="${manifest_path%%/*}"
  kind_name="${manifest_path#*/}"
  kind="${kind_name%%/*}"
  name="${kind_name##*/}"

  if [ "${namespace}" == "_" ]; then
    kubectl delete $kind $name | tee -a /tmp/kube.log
  else
    kubectl -n $namespace delete $kind $name | tee -a /tmp/kube.log
  fi
done

# Step 7: Add comment to PR

# format comment
pr_comment="$(cat <<EOF
\`kubectl apply\` output (excluding unchanged) for $(git describe --always --tag) was:

\`\`\`
$(cat /tmp/kube.log | grep -v ' unchanged$')
\`\`\`
EOF
)"


# get last PR
last_pr_number=$(hub pr list -s merged -b "${BRANCH_DEPLOY}" -h "${BRANCH_RELEASE}" -f '%I' -L 1)


# post comment
if [ -n "${last_pr_number}" ]; then
  echo "Adding comment to PR #${last_pr_number}"
  hub api "/repos/${GITHUB_REPOSITORY}/issues/${last_pr_number}/comments" -f body="${pr_comment}"
fi