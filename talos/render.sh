#!/usr/bin/env bash
set -euo pipefail
umask 077

TALOS_VERSION="v1.14.5"
KUBERNETES_VERSION="v1.37.1"
CLUSTER_NAME="management"
CLUSTER_ENDPOINT="https://10.212.212.10:6443"
ADDITIONAL_SANS="kube.home.arpa"
NODE_IP="10.212.212.10"

SCHEMATIC_ID=$(
  curl -fsSL \
    --data-binary @schematic.yaml \
    https://factory.talos.dev/schematics |
    jq -er '.id'
)
INSTALL_IMAGE="factory.talos.dev/metal-installer-secureboot/${SCHEMATIC_ID}:${TALOS_VERSION}"

RENDER_DIR="./rendered"
SECRETS_DIR="./secrets"
NODE_PATCH_DIR="./patches/nodes"

install -d -m 700 \
  "$RENDER_DIR" \
  "$SECRETS_DIR" \
  "$HOME/.talos"

if [[ ! -s "$SECRETS_DIR/secrets.yaml" ]]; then
  talosctl gen secrets \
    --talos-version "$TALOS_VERSION" \
    --output-file "$SECRETS_DIR/secrets.yaml"
fi

chmod 600 "$SECRETS_DIR/secrets.yaml"

talosctl gen config --force \
  "$CLUSTER_NAME" \
  "$CLUSTER_ENDPOINT" \
  --version "v1alpha1" \
  --talos-version "$TALOS_VERSION" \
  --kubernetes-version "$KUBERNETES_VERSION" \
  --install-image "$INSTALL_IMAGE" \
  --additional-sans "$ADDITIONAL_SANS" \
  --with-secrets "$SECRETS_DIR/secrets.yaml" \
  --with-docs=false \
  --with-examples=false \
  --with-kubespan=false \
  --with-cluster-discovery=false \
  --output-types "controlplane,talosconfig" \
  --output "$SECRETS_DIR"

chmod 600 "$SECRETS_DIR"/*.yaml
chmod 600 "$SECRETS_DIR/talosconfig"

talosctl machineconfig patch \
  "$SECRETS_DIR/controlplane.yaml" \
  --patch @"$NODE_PATCH_DIR/cp-0/machine.yaml" \
  --patch @"$NODE_PATCH_DIR/cp-0/storage.yaml" \
  --patch @"$NODE_PATCH_DIR/cp-0/kubernetes.yaml" \
  --output "$RENDER_DIR/cp-0.yaml"

#--patch @"$NODE_PATCH_DIR/cp-0/logging.yaml" \

talosctl validate \
  --config "$RENDER_DIR/cp-0.yaml" \
  --mode metal

install -m 600 \
  "$SECRETS_DIR/talosconfig" \
  "$HOME/.talos/config"

talosctl config context "$CLUSTER_NAME"
talosctl config endpoint "$NODE_IP"
talosctl config node "$NODE_IP"
