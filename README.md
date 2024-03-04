# IP Forwarding modes in Red Hat OpenShift Container Platform

Since Red Hat OpenShift Container Platform 4.14, administrators can control IP forwarding for all traffic on
OVN-Kubernetes managed interfaces by using the `.spec.defaultNetwork.ovnKubernetesConfig.gatewayConfig.ipForwarding`
knob of the `cluster` `network.operator` CR.

OpenShift Container Platform supports 2 modes:

* Specify `Restricted` to only allow IP forwarding for Kubernetes related traffic.
* Specify `Global` to allow forwarding of all IP traffic.

For new installations, the default is `Restricted`. For updates to OpenShift Container Platform 4.14, the default is
`Global`. For versions of Red Hat OpenShift Container Platform prior to 4.14, the system behaves as in `Global` mode.

## Global mode

In `Global` mode, Red Hat OpenShift Container Platform enables IP Forwarding on all interfaces. The cluster nodes work
as routers for all virtual networking components as well as for all external networks, on all interfaces.

![Global mode IP Forwarding](https://github.com/andreaskaris/enable-restricted-forwarding/assets/3291433/e4f1b1e7-331c-43c3-bd04-121ba6049be9)

As a consequence:

* ExternalIP services can be configured on `br-ex` as well as on any external interface.
* The node will act as a router between all its external interfaces.

## Restricted mode

In order to address security concerns with `Global` mode, Red Hat OpenShift Container Platform 4.14 introduced
`Restricted` mode as the new default for IP Forwarding for new cluster deployments.
Forwarding is enabled selectively only for `br-ex` and all interfaces that enable `br-ex` traffic, and the cluster
nodes no longer work as routers for all external networks.

![Restricted mode IP Forwarding](https://github.com/andreaskaris/enable-restricted-forwarding/assets/3291433/4104977e-5c11-4c67-9461-0a1ac4b99853)

As a consequence:

* ExternalIP services can be configured on `br-ex` only.
* The node will no longer act as a router between its external interfaces.

# Restricted mode with ExternalIPs on specific external interfaces

## The missing use case: Restricted mode with ExternalIPs on specific external interfaces

For specific deployment use cases, the currently available IP Forwarding modes may be either too permissive, or too
restrictive. One such use case is disabling routing globally, but enabling ExternalIPs selectively for specific external
interfaces.

![Restricted mode IP Forwarding with ExternalIPs on specific external interfaces](https://github.com/andreaskaris/enable-restricted-forwarding/assets/3291433/a1336400-4b3c-4b3c-bd49-591888d82643)

As a consequence:

* ExternalIP services can be configured on `br-ex`, as well as on select external interfaces only.
* The node will no longer act as a router between its external interfaces.

## Configuring Restricted mode with ExternalIPs on specific external interfaces

It is possible to configure `Restricted` mode with ExternalIPs on specific external interfaces by using a workaround
procedure. 

First, make sure that the `network.operator` `cluster` Custom Resource is configured with
`.spec.defaultNetwork.ovnKubernetesConfig.gatewayConfig.ipForwarding` `Restricted` (the default in OCP 4.14 and  above).

Then, enable ExternalIPs for a list of provided interfaces via a MachineConfiguration. The MachineConfiguration will
inject a script and systemd service into all selected nodes. The script will enable IP
forwarding for the provided set of interfaces; and it will instruct iptables to only forward cluster related traffic
via these interfaces so that they will not act as router interfaces. The script will run its commands in a loop, to make
sure that its changes are applied, by default every 300 seconds.

Take note that the script can only enable and monitor the enforcement of rules for the provided interfaces. It cannot
roll back its own changes on the fly. If one needs to roll back changes, one should delete the MachineConfiguration
which in turn will trigger a node reboot.

### How to apply the workaround

First, download scripts [apply-machine-config.sh](https://raw.githubusercontent.com/andreaskaris/enable-restricted-forwarding/master/apply-machine-config.sh)
and [enable-restricted-forwarding.sh](https://raw.githubusercontent.com/andreaskaris/enable-restricted-forwarding/master/enable-restricted-forwarding.sh) and store them inside the same directory.

Run script `apply-machine-config.sh` for each role. The script accepts parameters
in the following order:
```
./apply-machine-config.sh <role name> <if1> <if2> <if3> <...>
```

For example:
```
./apply-machine-config.sh master eno12409.123 eno12409.124
```

The script stores a backup of the generated and applied MachineConfiguration and provides the location of that backup.
