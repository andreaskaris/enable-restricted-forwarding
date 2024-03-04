#!/bin/bash
#
# Apply a MachineConfiguration to a given $ROLE to enable ExternalIPs (and other cluster IPs) on all provided
# $INTERFACES.
# Requires script enable-restricted-forwarding.sh in the same location.
# A backup of the generated MachineConfiguration will be saved to the /tmp/enable-restricted-forwarding
# directory.
#
# Usage: ./apply-machine-config.sh <ROLE> <INTERFACE1> <INTERFACE2> <...>
#
# 2024-03-01, Andreas Karis <akaris@redhat.com>

set -eu

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ENABLE_RESTRICTED_FORWARDING_SCRIPT="${DIR}/enable-restricted-forwarding.sh"
OUTPUT_DIR="/tmp/enable-restricted-forwarding"

if ! [ -f "${ENABLE_RESTRICTED_FORWARDING_SCRIPT}" ]; then
    echo "Missing dependency, could not find script ${ENABLE_RESTRICTED_FORWARDING_SCRIPT}"
    exit 1
fi

if [ $# -le 1 ]; then
    echo "Please provide the <role name> first, followed by a list of interfaces"
    exit 1
fi

ROLE="${1}"
shift
INTERFACES=$*

mkdir -p "${OUTPUT_DIR}"
OUTPUT_FILE="${OUTPUT_DIR}/${ROLE}.yaml"

cat <<EOF | tee "${OUTPUT_FILE}" | oc apply -f -
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: ${ROLE}
  name: 99-${ROLE}-enable-restricted-forwarding
spec:
  config:
    ignition:
      version: 3.1.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,$(base64 -w0 < "${ENABLE_RESTRICTED_FORWARDING_SCRIPT}")
        filesystem: root
        mode: 0750
        path: /usr/local/bin/enable-restricted-forwarding.sh
    systemd:
      units:
      - contents: |
          [Unit]
          After=network.target
          [Service]
          Type=simple
          Restart=always
          RestartSec=30
          ExecStart=/usr/local/bin/enable-restricted-forwarding.sh ${INTERFACES}
          [Install]
          WantedBy=multi-user.target
        enabled: true
        name: enable-restricted-forwarding.service
EOF
echo "Backup saved to ${OUTPUT_FILE}"
