#!/bin/sh
# Fetch official operator install YAML for KEYCLOAK_VERSION and rewrite
# quay.io/keycloak images to this repo's GHCR packages.
# Does not store upstream YAML in git. Output is dist/ (gitignored).
set -eu

KEYCLOAK_VERSION="${KEYCLOAK_VERSION:-26.7.2}"
OWNER="${OWNER:-yet-another-solutions}"
OWNER="$(printf '%s' "$OWNER" | tr '[:upper:]' '[:lower:]')"
REGISTRY="${REGISTRY:-ghcr.io}"
SRC_REPO="${SRC_REPO:-https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources}"
SRC="${SRC_REPO}/${KEYCLOAK_VERSION}/kubernetes"
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-${ROOT}/dist/operator-manifests}"

OPERATOR_IMAGE="${REGISTRY}/${OWNER}/stripped-keycloak-operator:${KEYCLOAK_VERSION}"
KEYCLOAK_IMAGE="${REGISTRY}/${OWNER}/stripped-keycloak:${KEYCLOAK_VERSION}"
UPSTREAM_OPERATOR="quay.io/keycloak/keycloak-operator:${KEYCLOAK_VERSION}"
UPSTREAM_KEYCLOAK="quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}"

CRDS="
keycloaks.k8s.keycloak.org-v1.yml
keycloakrealmimports.k8s.keycloak.org-v1.yml
keycloaksamlclients.k8s.keycloak.org-v1.yml
keycloakoidcclients.k8s.keycloak.org-v1.yml
"

fetch() {
  src="$1"
  dest="$2"
  echo "fetch ${src}"
  curl -fsSL --retry 3 --retry-delay 2 "$src" -o "$dest"
  test -s "$dest"
}

rewrite_images() {
  file="$1"
  grep -F "$UPSTREAM_OPERATOR" "$file" >/dev/null
  grep -F "$UPSTREAM_KEYCLOAK" "$file" >/dev/null
  # Operator ref first so it is not eaten by the keycloak: prefix.
  tmp="${file}.tmp"
  sed -e "s|${UPSTREAM_OPERATOR}|${OPERATOR_IMAGE}|g" \
      -e "s|${UPSTREAM_KEYCLOAK}|${KEYCLOAK_IMAGE}|g" \
      "$file" > "$tmp"
  {
    echo "# Rewritten from keycloak/keycloak-k8s-resources ${KEYCLOAK_VERSION}; quay images -> ${REGISTRY}/${OWNER}/stripped-keycloak*."
    cat "$tmp"
  } > "$file"
  rm -f "$tmp"
  grep -F "$OPERATOR_IMAGE" "$file" >/dev/null
  grep -F "$KEYCLOAK_IMAGE" "$file" >/dev/null
  if grep -F "quay.io/keycloak/" "$file" >/dev/null; then
    echo "leftover quay.io/keycloak refs in ${file}" >&2
    grep -n "quay.io/keycloak/" "$file" >&2 || true
    exit 1
  fi
}

rm -rf "$OUT"
mkdir -p "$OUT"

fetch "${SRC}/kubernetes.yml" "${OUT}/kubernetes.yml"
rewrite_images "${OUT}/kubernetes.yml"

for crd in $CRDS; do
  fetch "${SRC}/${crd}" "${OUT}/${crd}"
done

fetch "${SRC}/kustomization.yml" "${OUT}/kustomization.yml" || {
  echo "upstream kustomization.yml missing; writing a local one" >&2
  cat > "${OUT}/kustomization.yml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - keycloakoidcclients.k8s.keycloak.org-v1.yml
  - keycloakrealmimports.k8s.keycloak.org-v1.yml
  - keycloaks.k8s.keycloak.org-v1.yml
  - keycloaksamlclients.k8s.keycloak.org-v1.yml
  - kubernetes.yml
EOF
}

install="${OUT}/../stripped-keycloak-operator-install-${KEYCLOAK_VERSION}.yml"
{
  echo "# CRDs + rewritten operator Deployment from keycloak/keycloak-k8s-resources ${KEYCLOAK_VERSION}"
  echo "---"
  first=1
  for crd in $CRDS; do
    if [ "$first" -eq 1 ]; then
      first=0
    else
      echo "---"
    fi
    cat "${OUT}/${crd}"
    echo
  done
  echo "---"
  cat "${OUT}/kubernetes.yml"
} > "$install"

echo "wrote ${OUT}/kubernetes.yml"
echo "wrote ${install}"
