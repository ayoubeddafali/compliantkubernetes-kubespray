# Upgrade v2.21 to v2.22

## Prerequisites

- [ ] Notify the users (if any) before the upgrade starts;
- [ ] Check if there are any pending changes to the environment;
- [ ] Check the state of the environment, pods, nodes and backup jobs:

    ```bash
    ./compliantkubernetes-apps/bin/ck8s test sc|wc
    ./compliantkubernetes-apps/bin/ck8s ops kubectl sc|wc get pods -A -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,READY-false:status.containerStatuses[*].ready,REASON:status.containerStatuses[*].state.terminated.reason | grep false | grep -v Completed
    ./compliantkubernetes-apps/bin/ck8s ops kubectl sc|wc get nodes
    ./compliantkubernetes-apps/bin/ck8s ops kubectl sc|wc get jobs -A
    velero get backup
    ```

- [ ] Silence the notifications for the alerts. e.g you can use [alertmanager silences](https://prometheus.io/docs/alerting/latest/alertmanager/#silences);

## Steps that can be done before the upgrade - non-disruptive

1. Checkout the new release: `git switch -d v2.22.x-ck8sx`

1. Switch to the correct remote: `git submodule sync`

1. Update the kubespray submodule: `git submodule update --init --recursive`

1. Set `ck8sKubesprayVersion` to `any` in `sc-config/group_vars/all/ck8s-kubespray-general.yaml` and `wc-config/group_vars/all/ck8s-kubespray-general.yaml`

    ```bash
    yq4 -i '.ck8sKubesprayVersion = "any"' ${CK8S_CONFIG_PATH}/sc-config/group_vars/all/ck8s-kubespray-general.yaml
    yq4 -i '.ck8sKubesprayVersion = "any"' ${CK8S_CONFIG_PATH}/wc-config/group_vars/all/ck8s-kubespray-general.yaml
    ```

1. Run `bin/ck8s-kubespray upgrade v2.22 prepare` to update your config.

1. *If UpCloud* Add `target_port` to each loadbalancer config (typically same as `port`) in `sc-config/cluster.tfvars` and `wc-config/cluster.tfvars`

    Example:

    ```diff
    loadbalancers = {
      "http" : {
        "port" : 80,
    +   "target_port" : 80,
        "backend_servers" : [
          ...
        ]
      }
    }
    ```

1. Download the required files on the nodes

    ```bash
    ./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b --tags=download
    ./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b --tags=download
    ```

1. Optional. Update audit log policy

    ```bash
    (
      : "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
      for cluster in sc wc; do
          yq4 -i '.audit_policy_custom_rules |= (load("config/common/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml") | .audit_policy_custom_rules)' ${CK8S_CONFIG_PATH}/${cluster}-config/group_vars/k8s_cluster/ck8s-k8s-cluster.yaml
      done
    )
    ```

## Upgrade steps

These steps will cause disruptions in the environment.

1. Upgrade the cluster to a new kubernetes version:

    ```bash
    ./bin/ck8s-kubespray run-playbook sc upgrade-cluster.yml -b --skip-tags=download
    ./bin/ck8s-kubespray run-playbook wc upgrade-cluster.yml -b --skip-tags=download
    ```

1. Optional. Restart Kubernetes API servers to load new audit log policy

    ```bash
    (
      : "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
      for cluster in sc wc; do
        export TERRAFORM_STATE_ROOT=${CK8S_CONFIG_PATH}/${cluster}-config/
        ansible -i "${CK8S_CONFIG_PATH}/${cluster}-config/inventory.ini" kube_control_plane -b -m shell -a 'nerdctl container stop $(nerdctl container list | grep kube-apiserver:v1.26.5 | awk "{print \$1}")'
      done
    )
    ```

## Postrequisite

- [ ] Check the state of the environment, pods and nodes:

    ```bash
    ./compliantkubernetes-apps/bin/ck8s test sc|wc
    ./compliantkubernetes-apps/bin/ck8s ops kubectl sc|wc get pods -A -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,READY-false:status.containerStatuses[*].ready,REASON:status.containerStatuses[*].state.terminated.reason | grep false | grep -v Completed
    ./compliantkubernetes-apps/bin/ck8s ops kubectl sc|wc get nodes
    ```

- [ ] Enable the notifications for the alerts;
- [ ] Notify the users (if any) when the upgrade is complete;

> **_Note:_** Additionally it is good to check:

- if any alerts generated by the upgrade didn't close.
- if you can login to Grafana, Opensearch or Harbor.
- if you can see fresh metrics and logs.