# Proxmox IaC — Terraform + Ansible

Quản lý cụm **Proxmox 9 node** bằng code:

- **Terraform** → tạo/xóa **VM & LXC** (hạ tầng).
- **Ansible** → **cài đặt & cấu hình dịch vụ** bên trong VM (OS, Kubernetes, monitoring).
- **Ceph** → dựng bằng script `pveceph` (Terraform không làm được phần này).

> 🟢 **Bạn mới bắt đầu?** Đọc theo thứ tự trong thư mục [`docs/`](docs/) — từ cơ bản đến nâng cao.

---

## 📚 Tài liệu (đọc theo thứ tự)

| # | File | Nội dung |
|---|------|----------|
| 0 | [docs/00-tong-quan.md](docs/00-tong-quan.md) | IaC là gì, Terraform vs Ansible, kiến trúc tổng thể |
| 1 | [docs/01-chuan-bi.md](docs/01-chuan-bi.md) | Cài công cụ (Windows), tạo API token, SSH key, cloud-init template |
| 2 | [docs/02-terraform-co-ban.md](docs/02-terraform-co-ban.md) | init / plan / apply, tạo VM đầu tiên, hiểu state |
| 3 | [docs/03-ansible-co-ban.md](docs/03-ansible-co-ban.md) | Inventory động, provision OS, cài k3s + monitoring |
| 4 | [docs/04-ceph-pveceph.md](docs/04-ceph-pveceph.md) | Dựng Ceph bằng `pveceph`, dùng làm storage cho VM |
| 5 | [docs/05-nang-cao.md](docs/05-nang-cao.md) | Remote state, CI/CD, SDN/VLAN, HA, scale 9 node |
| 6 | [docs/06-van-hanh.md](docs/06-van-hanh.md) | Day-2: thêm VM/node, destroy an toàn, backup state |
|   | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Các lỗi hay gặp & cách xử lý |

---

## 🗂️ Cấu trúc repo

```
proxmox-iac/
├── terraform/
│   ├── providers.tf            # Provider bpg/proxmox
│   ├── main.tf                 # Root module — gọi các sub-module
│   ├── variables.tf            # Khai báo biến
│   ├── locals.tf               # Giá trị tính toán nội bộ
│   ├── outputs.tf              # Output sau apply (IP, ID, lệnh ssh…)
│   ├── terraform.tfvars.example# MẪU — copy thành terraform.tfvars
│   └── modules/
│       ├── vm/                 # Tạo QEMU/KVM VM từ template
│       ├── lxc/                # Tạo LXC container
│       └── network/            # VLAN interface (optional)
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/proxmox.yml   # Dynamic inventory (lấy VM từ Proxmox API)
│   ├── group_vars/
│   │   ├── all.yml
│   │   └── vault.yml.example   # MẪU — copy thành vault.yml rồi encrypt
│   ├── roles/
│   │   ├── base/               # OS: timezone, packages, hardening, k8s prereq
│   │   ├── kubernetes/         # Cài k3s (master + worker)
│   │   └── monitoring/         # Prometheus + Grafana + node_exporter
│   └── playbooks/
│       ├── provision.yml       # Chuẩn bị OS (chạy ngay sau terraform)
│       └── configure.yml       # Cài app (k3s, monitoring)
├── scripts/
│   ├── create-template.sh      # Tạo cloud-init template (chạy trên PVE node)
│   └── bootstrap-ceph.sh       # Dựng Ceph bằng pveceph (chạy trên PVE node)
└── .github/workflows/
    └── infra.yml               # CI/CD (tùy chọn, cần self-hosted runner)
```

---

## ⚡ Quick start (tóm tắt — chi tiết xem docs)

```bash
# 0. (Một lần) Trên 1 PVE node: tạo cloud-init template
#    bash scripts/create-template.sh

# 1. Khai báo hạ tầng
cd terraform
cp terraform.tfvars.example terraform.tfvars
#    -> sửa terraform.tfvars: 9 node, token, ssh key, danh sách VM

# 2. Tạo VM
terraform init
terraform plan        # xem trước sẽ tạo gì
terraform apply

# 3. Cấu hình OS + cài dịch vụ
cd ../ansible
export PROXMOX_TOKEN_SECRET="<secret-của-ansible-token>"
ansible-playbook playbooks/provision.yml     # chuẩn bị OS
ansible-playbook playbooks/configure.yml      # cài k3s + monitoring
```

> ⚠️ **An toàn:** `terraform.tfvars` và `ansible/group_vars/vault.yml` chứa bí mật và **đã được .gitignore** — không bao giờ commit chúng.

---

## 🧩 Ý tưởng cốt lõi: tag → group

Bạn gắn **tags** cho VM trong `terraform.tfvars` (vd `["k8s","k8s-master"]`).
Ansible dynamic inventory đọc tags đó và **tự gom nhóm** (`k8s_masters`, `k8s_workers`, `monitoring`…).
→ Thêm 1 VM worker = thêm 1 khối trong tfvars với tag `k8s-worker`, chạy lại `apply` + `configure`. Không sửa inventory thủ công.
