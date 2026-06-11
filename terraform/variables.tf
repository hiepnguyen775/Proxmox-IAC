# =============================================
#  PROXMOX CONNECTION
# =============================================

variable "proxmox_endpoint" {
  description = "URL Proxmox API — trỏ vào 1 node bất kỳ trong cluster (hoặc VIP nếu có HA proxy)"
  type        = string
  default     = "https://192.168.1.10:8006"
}

variable "proxmox_api_token" {
  description = "API token — format: user@realm!token-id=secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Bỏ qua TLS verify (lab dùng self-signed cert). Production nên để false + cert hợp lệ."
  type        = bool
  default     = true
}

variable "proxmox_ssh_user" {
  description = "SSH user để upload snippet/cloud-init lên Proxmox node"
  type        = string
  default     = "root"
}

# =============================================
#  CLUSTER NODES  (9-node cluster)
#  -> Đổi tên + IP cho khớp cluster thật của bạn.
#     Tên phải GIỐNG HỆT tên node hiển thị trong Proxmox UI.
# =============================================

variable "proxmox_nodes" {
  description = "Map tên node Proxmox → IP quản trị. Thêm/bớt node ở đây."
  type        = map(string)
  default = {
    "pve-node-01" = "192.168.1.11"
    "pve-node-02" = "192.168.1.12"
    "pve-node-03" = "192.168.1.13"
    "pve-node-04" = "192.168.1.14"
    "pve-node-05" = "192.168.1.15"
    "pve-node-06" = "192.168.1.16"
    "pve-node-07" = "192.168.1.17"
    "pve-node-08" = "192.168.1.18"
    "pve-node-09" = "192.168.1.19"
  }
}

# =============================================
#  VM DEFAULTS
# =============================================

variable "vm_template_id" {
  description = "ID của cloud-init template đã tạo sẵn (scripts/create-template.sh)"
  type        = number
  default     = 9000
}

variable "vm_ssh_public_key" {
  description = "SSH public key inject vào cloud-init (nội dung ~/.ssh/id_ed25519.pub)"
  type        = string
}

variable "vm_default_user" {
  description = "Default OS user trong VM (Ubuntu cloud image mặc định là 'ubuntu')"
  type        = string
  default     = "ubuntu"
}

variable "vm_dns_server" {
  description = "DNS server cho cloud-init"
  type        = string
  default     = "1.1.1.1"
}

variable "vm_dns_domain" {
  description = "Search domain"
  type        = string
  default     = "lab.local"
}

# =============================================
#  STORAGE
# =============================================

variable "storage_vm_pool" {
  description = "Tên storage pool cho VM disk. 'local-lvm' (mỗi node) hoặc 'ceph-vm' (sau khi dựng Ceph)."
  type        = string
  default     = "local-lvm"
}

# =============================================
#  NETWORK
# =============================================

variable "vm_bridge" {
  description = "Linux bridge mặc định gắn vào VM"
  type        = string
  default     = "vmbr0"
}

variable "vm_gateway" {
  description = "Default gateway cho VM"
  type        = string
  default     = "192.168.1.1"
}

# =============================================
#  VM DEFINITIONS  (định nghĩa từng VM cụ thể)
# =============================================

variable "vm_definitions" {
  description = "Map định nghĩa các VM cần tạo. Key = tên VM (cũng là hostname)."
  type = map(object({
    vm_id       = number
    node        = string # tên node Proxmox (phải có trong proxmox_nodes)
    cpu_cores   = number
    memory_mb   = number
    disk_gb     = number
    ip_address  = string # CIDR, ví dụ "192.168.1.101/24"
    vlan_id     = optional(number, null)
    tags        = list(string)
    description = optional(string, "")
  }))
  default = {}
}

# =============================================
#  LXC DEFINITIONS
# =============================================

variable "lxc_definitions" {
  description = "Map định nghĩa LXC containers"
  type = map(object({
    ct_id       = number
    node        = string
    cpu_cores   = number
    memory_mb   = number
    disk_gb     = number
    ip_address  = string
    tags        = list(string)
    os_template = string # ví dụ "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  }))
  default = {}
}

# =============================================
#  SDN / VLAN  (optional — nâng cao)
# =============================================

variable "sdn_enabled" {
  description = "Có tạo VLAN interface / bridge phụ không (xem docs/05-nang-cao.md)"
  type        = bool
  default     = false
}

variable "sdn_zones" {
  description = "Danh sách VLAN cần tạo trên node primary"
  type = list(object({
    zone_id = string # tên gợi nhớ, ví dụ "vlan-100"
    type    = string # hiện hỗ trợ "vlan"
    bridge  = string # bridge cha, ví dụ "vmbr0"
    vlan_id = number # số VLAN, ví dụ 100
  }))
  default = []
}
