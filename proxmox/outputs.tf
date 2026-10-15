output "vms" {
  value = {
    for name, vm in proxmox_virtual_environment_vm.vm : name => {
      vm_id = vm.vm_id
      node  = vm.node_name
      ip    = split("/", var.vms[name].ip)[0]
    }
  }
}
