# =============================================
#  main.tf  —  Root module
#  Gọi tất cả sub-modules từ đây
# =============================================

# ---------- VMs ----------
module "vms" {
  source   = "./modules/vm"
  for_each = var.vm_definitions

  # Identity
  vm_name     = each.key
  vm_id       = each.value.vm_id
  node_name   = each.value.node
  description = each.value.description

  # Compute
  cpu_cores = each.value.cpu_cores
  memory_mb = each.value.memory_mb

  # Storage
  disk_gb          = each.value.disk_gb
  storage_pool     = var.storage_vm_pool
  template_vm_id   = var.vm_template_id

  # Network
  bridge     = var.vm_bridge
  ip_address = each.value.ip_address
  gateway    = var.vm_gateway
  vlan_id    = each.value.vlan_id
  dns_server = var.vm_dns_server
  dns_domain = var.vm_dns_domain

  # Auth
  ssh_public_key = var.vm_ssh_public_key
  username       = var.vm_default_user

  # Tags (dùng bởi Ansible dynamic inventory)
  tags = local.vm_tags_map[each.key]
}

# ---------- LXC Containers ----------
module "lxc" {
  source   = "./modules/lxc"
  for_each = var.lxc_definitions

  ct_name    = each.key
  ct_id      = each.value.ct_id
  node_name  = each.value.node
  cpu_cores  = each.value.cpu_cores
  memory_mb  = each.value.memory_mb
  disk_gb    = each.value.disk_gb
  ip_address = each.value.ip_address
  gateway    = var.vm_gateway
  tags       = local.lxc_tags_map[each.key]
  os_template = each.value.os_template

  ssh_public_key = var.vm_ssh_public_key
  storage_pool   = var.storage_vm_pool
}

# ---------- SDN Network ----------
module "network" {
  source  = "./modules/network"
  count   = var.sdn_enabled ? 1 : 0

  nodes       = var.proxmox_nodes
  sdn_zones   = var.sdn_zones
}

# ---------- Ceph ----------
module "ceph" {
  source  = "./modules/ceph"
  count   = var.ceph_enabled ? 1 : 0

  nodes               = var.proxmox_nodes
  primary_node        = local.primary_node
  ceph_network        = var.ceph_network
  ceph_cluster_network = var.ceph_cluster_network
}

# ---------- Storage Pools ----------
module "storage" {
  source  = "./modules/storage"
  count   = var.ceph_enabled ? 1 : 0

  primary_node = local.primary_node
  nodes        = var.proxmox_nodes
}
