#!/bin/bash

set -eux

DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
OUTPUT_DIR="${DIR}/_output"

ROLE="${1}"
shift
INTERFACES=$*

mkdir -p "${OUTPUT_DIR}"

cat <<EOF | tee "_output/${ROLE}.yaml" | oc apply -f -
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
          source: data:text/plain;charset=utf-8;base64,$(base64 -w0 < "${DIR}/enable-restricted-forwarding.sh")
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
          RestartSec=1
          ExecStart=/usr/local/bin/enable-restricted-forwarding.sh ${INTERFACES}
          [Install]
          WantedBy=multi-user.target
        enabled: true
        name: one-shot-enable-tty-audit.service
EOF
