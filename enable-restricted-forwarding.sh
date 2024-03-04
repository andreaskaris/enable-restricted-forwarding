#!/bin/bash
#
# Enable ExternalIPs (and other cluster IPs) for all provided $INTERFACES.
# To be used with network.operator .spec.defaultNetwork.ovnKubernetesConfig.gatewayConfig.ipForwarding: Restricted.
# By default, Red Hat OpenShift Container platform clusters will restrict all forwarding other than forwarding on br-ex.
# This is known to break ExternalIPs (and other cluster IPs) for all other interfaces. This script will enable
# forwarding for the provided set of interfaces; and it will instruct iptables to only forward cluster related traffic
# via these interfaces so that they will not act as router interfaces. This script will run its commands in a loop,
# every $SLEEP_INTERVAL.
#
# This script can only enable and monitor the enforcement of rules for the provided $INTERFACES. It cannot roll back
# its own changes. If you need to roll back changes, prevent this script from running on startup and reboot the node.
#
# Usage: ./enable-restricted-forwarding.sh <INTERFACE1> <INTERFACE2> <...>
#
# 2024-03-01, Andreas Karis <akaris@redhat.com>

set -eux

INTERFACES=$*

IPTABLES="$(which iptables)"
IP6TABLES="$(which ip6tables)"
IPTABLES_TABLE="filter"
IPTABLES_CHAIN="FORWARD"
IPTABLES_FORWARD_DROP_CHAIN="OVN-KUBE-FORWARD-DROP" 
SLEEP_INTERVAL="300"

function append_drop_chain() {
    if ! ${IPTABLES} -t "${IPTABLES_TABLE}" -L "${IPTABLES_CHAIN}" | grep -q "${IPTABLES_FORWARD_DROP_CHAIN}"; then
        ${IPTABLES} -t "${IPTABLES_TABLE}" -N "${IPTABLES_FORWARD_DROP_CHAIN}"
        ${IPTABLES} -t "${IPTABLES_TABLE}" -A "${IPTABLES_CHAIN}" -j "${IPTABLES_FORWARD_DROP_CHAIN}"
    fi
    if ! ${IP6TABLES} -t "${IPTABLES_TABLE}" -L "${IPTABLES_CHAIN}" | grep -q "${IPTABLES_FORWARD_DROP_CHAIN}"; then
        ${IP6TABLES} -t "${IPTABLES_TABLE}" -N "${IPTABLES_FORWARD_DROP_CHAIN}"
        ${IP6TABLES} -t "${IPTABLES_TABLE}" -A "${IPTABLES_CHAIN}" -j "${IPTABLES_FORWARD_DROP_CHAIN}"
    fi
}

function sync_drop_rules() {
    for intf in "$@"; do
        for dir in i o; do
            rule="-${dir} ${intf} -j DROP"
            if ! ${IPTABLES} -t "${IPTABLES_TABLE}" -S "${IPTABLES_FORWARD_DROP_CHAIN}" | grep -q -- "${rule}"; then
                ${IPTABLES} -t "${IPTABLES_TABLE}" -A "${IPTABLES_FORWARD_DROP_CHAIN}" ${rule}
            fi
            if ! ${IP6TABLES} -t "${IPTABLES_TABLE}" -S "${IPTABLES_FORWARD_DROP_CHAIN}" | grep -q -- "${rule}"; then
                ${IP6TABLES} -t "${IPTABLES_TABLE}" -A "${IPTABLES_FORWARD_DROP_CHAIN}" ${rule}
            fi
        done
    done
}

function enable_forwarding_on_interfaces() {
    for intf in "$@"; do
        intf=$(echo "${intf}" | sed 's#\.#/#g')
        sysctl -w "net.ipv4.conf.${intf}.forwarding=1"
        sysctl -w "net.ipv6.conf.${intf}.forwarding=1"
    done
}

function check_interfaces() {
    if [ $# -lt 1 ]; then
        echo "No interfaces provided"
        exit 1
    fi
    for intf in "$@"; do
        if ! [ -e "/sys/class/net/${intf}" ]; then
            echo "Invalid interface name provided: could not find '${intf}'"
            exit 1
        fi
    done
}

while true; do
    check_interfaces ${INTERFACES}
    append_drop_chain
    sync_drop_rules ${INTERFACES}
    enable_forwarding_on_interfaces ${INTERFACES}
    sleep "${SLEEP_INTERVAL}"
done
