# =============================================
#  locals.tf  —  computed values, không cần sửa
# =============================================

locals {
  # Node primary (đầu tiên trong map) — dùng cho global tasks như Ceph init
  primary_node = keys(var.proxmox_nodes)[0]

  # Flatten tags thành string cho Proxmox API
  vm_tags_map = {
    for k, v in var.vm_definitions :
    k => join(";", sort(v.tags))
  }

  lxc_tags_map = {
    for k, v in var.lxc_definitions :
    k => join(";", sort(v.tags))
  }

  # SDN zone map để lookup
  sdn_zone_map = {
    for z in var.sdn_zones :
    z.zone_id => z
  }

  # Common cloud-init config
  cloud_init_meta = {
    dns_server = var.vm_dns_server
    dns_domain = var.vm_dns_domain
    gateway    = var.vm_gateway
    ssh_key    = var.vm_ssh_public_key
    username   = var.vm_default_user
  }
}
