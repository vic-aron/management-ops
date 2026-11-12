#!/usr/bin/env bash
set -euo pipefail

FLUX_SSH_KEY="$HOME/.ssh/id_ed25519_flux"
SOPS_AGE_KEY="$HOME/.config/sops/age/mgmt.txt"

# Prerequisites
for file in "$FLUX_SSH_KEY" "$SOPS_AGE_KEY"; do
  [[ -r "$file" ]] || {
    printf 'Missing or unreadable file: %s\n' "$file" >&2
    exit 1
  }
done

# CNI
#helm upgrade --install kube-ovn \
#  oci://ghcr.io/kubeovn/charts/kube-ovn-v2 \
#  --version v1.16.17 \
#  --namespace kube-system \
#  --create-namespace \
#  --set ovsOvn.disableModulesManagement=true \
#  --set ovsOvn.ovsDirectory="/var/lib/openvswitch" \
#  --set ovsOvn.ovnDirectory="/var/lib/ovn" \
#  --set ovsOvn.ovsIpsecKeysDirectory="/var/lib/ovs_ipsec_keys" \
#  --set cni.mountToolingDirectory=false \
#  --wait

# Flux bootstrap
flux bootstrap git \
  --url=ssh://git@github.com/vic-aron/management-ops \
  --branch=main \
  --path=clusters/management \
  --components-extra image-reflector-controller,image-automation-controller,source-watcher \
  --private-key-file="$FLUX_SSH_KEY"

# Flux Age
kubectl create secret generic sops-age \
  --namespace flux-system \
  --from-file=age.agekey="$SOPS_AGE_KEY" \
  --dry-run=client -o yaml |
  kubectl apply -f -
