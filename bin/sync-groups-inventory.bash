#!/bin/bash

set -eu -o pipefail


here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

# shellcheck source=bin/common.bash
source "${here}/inventory-parser.bash"


log_info "Inventories sync in process .."

# shellcheck disable=SC2154
# shellcheck disable=SC2091
for host in $(get_group_hosts "${config[groups_inventory_file]}" all); do
    if $(! contains_element "$host" "$(get_group_hosts "${config[inventory_file]}" all)"); then
        log_info "Removing $host from groups inventory.."
        remove_host_from_group "${config[groups_inventory_file]}" "$host" all
    fi
done

# shellcheck disable=SC2091
for host in $(get_group_hosts "${config[inventory_file]}" all); do
    if $(! contains_element "$host" "$(get_group_hosts "${config[groups_inventory_file]}" all)"); then
        log_info "Adding $host to groups inventory.."
        add_host_to_group "${config[groups_inventory_file]}" "$host" "all"
        hostvars=$(get_host_vars "${config[inventory_file]}" "$host")
        log_info "Syncing hostvars for new host: $host .."
        for hostvar in $hostvars; do
            value=$(get_host_var "${config[inventory_file]}" "$host" "$hostvar")
            set_host_var "${config[groups_inventory_file]}" "$host" "$hostvar" "$value"
        done
        assignHost "$host"
    fi
done

for host in $(get_group_hosts "${config[groups_inventory_file]}" all); do
    hostvars=$(get_host_vars "${config[inventory_file]}" "$host")
    log_info "Syncing hostvars for existing host: $host"
    for hostvar in $hostvars; do
        value=$(get_host_var "${config[inventory_file]}" "$host" "$hostvar")
        update_host_var "${config[groups_inventory_file]}" "$host" "$hostvar" "$value"
    done
done
