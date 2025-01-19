#!/usr/bin/env bash
set -euo pipefail

#IMAGE="${IMAGE:-docker.io/library/ubuntu:latest}"
#IMAGE="${IMAGE:-docker.io/curlimages/curl:8.11.1}"
IMAGE="${IMAGE:-ghcr.io/opentofu/opentofu:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-myrunccontainer}"
COMMAND="${COMMAND:-tofu init}"
#COMMAND="${COMMAND:-curl https://registry.opentofu.org/.well-known/terraform.json}"
#COMMAND="${COMMAND:-nslookup registry.opentofu.org}"
#COMMAND="${COMMAND:-ls -al /etc/reslov.conf}"
#COMMAND="${COMMAND:-/bin/sh}"

OCI_LAYOUT_DIR="./oci-image"
BUNDLE_DIR="./bundle-dir"

echo "==> Pulling OCI image '${IMAGE}' into '${OCI_LAYOUT_DIR}'"
skopeo copy "docker://${IMAGE}" "oci:${OCI_LAYOUT_DIR}:latest"

echo "==> Unpacking OCI image into '${BUNDLE_DIR}'"
rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}"

umoci unpack --rootless --image "${OCI_LAYOUT_DIR}:latest" "${BUNDLE_DIR}"

cp tofu-example.tf ${BUNDLE_DIR}/rootfs/
#cp my_resolv.conf ${BUNDLE_DIR}/rootfs/etc/my_reslov.conf
#cp /usr/bin/curl ${BUNDLE_DIR}/rootfs/usr/bin/curl

echo "nameserver 1.1.1.1" > ${BUNDLE_DIR}/rootfs/etc/resolv.conf
cd "${BUNDLE_DIR}"

echo "==> Generating default runc spec (config.json)"
[ -f config.json ] && rm config.json
runc --debug spec

# Remove "gid=5" if runc spec added it (common rootless issue)
jq '
  .mounts |= map(
    if .destination == "/dev/pts" then
      .options |= map(select(. != "gid=5"))
    else
      .
    end
  )
' config.json > config.tmp && mv config.tmp config.json

# Remove network namespace
jq 'del(.linux.namespaces[] | select(.type == "network"))' config.json > updated_config.json && mv updated_config.json config.json

jq '.root.readonly = false' config.json > updated_config.json && mv updated_config.json config.json

jq '. | .network.nameservers = ["8.8.8.8", "1.1.1.1"]' config.json > config.json.tmp && mv config.json.tmp config.json

#jq '. | .reslovConfPath = "/etc/my_reslov.conf"' config.json > config.json.tmp && mv config.json.tmp config.json
echo "==> Updating process args to: ${COMMAND}"
jq --arg cmd "${COMMAND}" '.process.args = ($cmd | split(" "))' config.json > config.tmp
mv config.tmp config.json
cat config.json | jq .

echo "==> Running container with runc"
# No --rootless needed, because RootlessKit already gave us a user namespace
runc run "${CONTAINER_NAME}"


echo "==> Container process finished."
