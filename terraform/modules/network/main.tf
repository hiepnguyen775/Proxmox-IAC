# =============================================
#  modules/network/main.tf
#  SDN Zones, VNets, Subnets
# =============================================

variable "nodes"      { type = map(string) }
variable "sdn_zones"  { type = list(any); default = [] }

locals {
  primary_node = keys(var.nodes)[0]

  # Chỉ lấy VLAN zones
  vlan_zones = [for z in var.sdn_zones : z if z.type == "vlan"]
}

# ---------- VLAN Zone ----------
resource "proxmox_virtual_environment_network_linux_vlan" "vlans" {
  for_each = {
    for z in local.vlan_zones : z.zone_id => z
  }

  node_name = local.primary_node
  name      = "vmbr0.${each.value.vlan_id}"
  interface = each.value.bridge
  vlan      = each.value.vlan_id
  comment   = "VLAN ${each.value.vlan_id} — ${each.value.zone_id}"
}

# ---------- SDN Simple Zone (VXLAN overlay) ----------
# Uncomment khi cần VXLAN giữa các nodes
# resource "proxmox_virtual_environment_sdn_zone" "vxlan" {
#   zone    = "vxlan-zone"
#   type    = "vxlan"
#   peers   = values(var.nodes)
# }

# ---------- Linux Bridge cho internal traffic ----------
resource "proxmox_virtual_environment_network_linux_bridge" "internal" {
  for_each  = var.nodes
  node_name = each.key

  name    = "vmbr1"
  comment = "Internal VM-to-VM network"
  ports   = []

  # Tắt STP để không gây loop trong lab
  vlan_aware = true
}
