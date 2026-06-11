# =============================================
#  modules/network/main.tf
#  Tạo VLAN interface trên node primary (optional)
#  Chỉ chạy khi sdn_enabled = true
# =============================================

variable "nodes" { type = map(string) }

variable "sdn_zones" {
  type = list(object({
    zone_id = string
    type    = string
    bridge  = string
    vlan_id = number
  }))
  default = []
}

locals {
  primary_node = keys(var.nodes)[0]

  # Chỉ lấy các zone kiểu "vlan"
  vlan_zones = {
    for z in var.sdn_zones : z.zone_id => z if z.type == "vlan"
  }
}

# ---------- VLAN interface trên bridge cha ----------
resource "proxmox_virtual_environment_network_linux_vlan" "vlans" {
  for_each = local.vlan_zones

  node_name = local.primary_node
  name      = "${each.value.bridge}.${each.value.vlan_id}"
  interface = each.value.bridge
  vlan      = each.value.vlan_id
  comment   = "VLAN ${each.value.vlan_id} — ${each.value.zone_id} (managed by Terraform)"
}

output "vlan_interfaces" {
  description = "Các VLAN interface đã tạo"
  value       = [for v in proxmox_virtual_environment_network_linux_vlan.vlans : v.name]
}
