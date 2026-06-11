# =============================================
#  modules/ceph/main.tf
#  Ceph cluster bootstrap qua Proxmox API
# =============================================

variable "nodes"               { type = map(string) }
variable "primary_node"        { type = string }
variable "ceph_network"        { type = string }
variable "ceph_cluster_network" { type = string }

# Khởi tạo Ceph trên primary node
resource "proxmox_virtual_environment_ceph_cluster" "main" {
  node_name       = var.primary_node
  network         = var.ceph_network
  cluster_network = var.ceph_cluster_network
}

# Tạo Ceph MON trên mỗi node (cần ít nhất 3 cho quorum)
resource "proxmox_virtual_environment_ceph_mon" "mons" {
  for_each  = var.nodes
  node_name = each.key

  depends_on = [proxmox_virtual_environment_ceph_cluster.main]
}

# Tạo Ceph MGR
resource "proxmox_virtual_environment_ceph_mgr" "mgrs" {
  for_each  = var.nodes
  node_name = each.key

  depends_on = [proxmox_virtual_environment_ceph_mon.mons]
}

# MDS cho CephFS (optional — bật khi cần shared filesystem)
resource "proxmox_virtual_environment_ceph_mds" "mds" {
  for_each  = var.nodes
  node_name = each.key

  depends_on = [proxmox_virtual_environment_ceph_mgr.mgrs]
}

# OSD trên từng node — mỗi node dùng /dev/sdb làm OSD disk
# Thực tế nên map disk cụ thể cho từng node
resource "proxmox_virtual_environment_ceph_osd" "osds" {
  for_each  = var.nodes
  node_name = each.key
  device    = "/dev/sdb"   # !! Đổi theo disk thực của từng node

  crush_device_class = "hdd"  # hoặc "ssd" / "nvme"

  depends_on = [proxmox_virtual_environment_ceph_mgr.mgrs]
}

output "ceph_status" {
  value = "Ceph cluster initialized on ${var.primary_node} — check PVE web UI → Ceph"
}
