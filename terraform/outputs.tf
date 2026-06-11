# =============================================
#  outputs.tf  —  Export sau terraform apply
# =============================================

output "vm_ips" {
  description = "Map tên VM → IP address"
  value = {
    for k, v in module.vms :
    k => v.ip_address
  }
}

output "vm_ids" {
  description = "Map tên VM → Proxmox VM ID"
  value = {
    for k, v in module.vms :
    k => v.vm_id
  }
}

output "lxc_ips" {
  description = "Map tên LXC → IP address"
  value = {
    for k, v in module.lxc :
    k => v.ip_address
  }
}

output "ansible_inventory_cmd" {
  description = "Lệnh kiểm tra Ansible dynamic inventory"
  value       = "ansible-inventory -i ansible/inventory/proxmox.yml --list"
}

output "ssh_commands" {
  description = "SSH vào từng VM"
  value = {
    for k, v in module.vms :
    k => "ssh ${var.vm_default_user}@${split("/", v.ip_address)[0]}"
  }
}
