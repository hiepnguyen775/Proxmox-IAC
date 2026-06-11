output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}

output "ip_address" {
  value = var.ip_address
}

output "node_name" {
  value = proxmox_virtual_environment_vm.this.node_name
}

output "mac_address" {
  value = proxmox_virtual_environment_vm.this.network_device[0].mac_address
}
