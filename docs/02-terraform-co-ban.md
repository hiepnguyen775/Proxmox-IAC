# 02 — Terraform cơ bản: tạo VM đầu tiên

> Giả sử đã xong [01-chuan-bi.md](01-chuan-bi.md): có token, ssh key, template 9000.

## 1. Điền `terraform.tfvars`

Mở `terraform/terraform.tfvars` (đã copy từ `.example`). Tối thiểu sửa 4 chỗ:

```hcl
proxmox_endpoint  = "https://<IP-1-node>:8006"
proxmox_api_token = "terraform@pve!tf-token=<secret>"
vm_ssh_public_key = "ssh-ed25519 AAAA... (nội dung id_ed25519.pub)"
proxmox_nodes = { "pve-node-01" = "..." , ... }   # 9 node thật, TÊN khớp PVE UI
```

Rồi xem khối `vm_definitions` — mỗi khối là 1 VM. **Bắt đầu nhỏ**: comment bớt, chỉ để lại 1 VM để thử:

```hcl
vm_definitions = {
  "test-01" = {
    vm_id      = 150
    node       = "pve-node-01"        # phải có trong proxmox_nodes
    cpu_cores  = 2
    memory_mb  = 2048
    disk_gb    = 20
    ip_address = "192.168.1.150/24"   # IP còn trống trong mạng
    tags       = ["test"]
  }
}
```

## 2. Ba lệnh cốt lõi

```bash
cd terraform

terraform init     # tải provider (chạy 1 lần, hoặc khi đổi version)
terraform plan     # XEM TRƯỚC: sẽ tạo/sửa/xóa gì — KHÔNG đổi gì thật
terraform apply    # thực thi (gõ 'yes' để xác nhận)
```

**Luôn đọc `plan` trước khi `apply`.** Plan in ra dạng:

```
Plan: 1 to add, 0 to change, 0 to destroy.
```

- `add` = tạo mới · `change` = sửa tại chỗ · `destroy` = xóa (⚠️ chú ý dòng này!).

Sau `apply`, xem kết quả:

```bash
terraform output            # IP, ID, lệnh ssh của các VM
ssh ubuntu@192.168.1.150    # thử vào VM
```

## 3. Hiểu chuyện gì vừa xảy ra

1. Terraform đọc `vm_definitions` (trong [`terraform.tfvars`](../terraform/terraform.tfvars.example)) → với mỗi VM gọi **module `vm`** ([`modules/vm/main.tf`](../terraform/modules/vm/main.tf)). Việc nối này nằm ở [`main.tf`](../terraform/main.tf).
2. Module clone từ template 9000, set CPU/RAM/disk, gắn network, và **cloud-init** (IP tĩnh + SSH key + user) — xem trực tiếp trong [`modules/vm/main.tf`](../terraform/modules/vm/main.tf).
3. Kết quả ghi vào **`terraform.tfstate`** — Terraform nhớ VM này tồn tại.

> 🗺️ "Muốn đổi gì sửa file nào" → xem bảng **Bản đồ cấu hình** ở [`LAB.md`](../LAB.md).

## 4. Sửa & thêm VM

- **Thêm VM**: thêm 1 khối trong `vm_definitions` → `plan` → `apply`. Chỉ VM mới được tạo.
- **Đổi RAM/CPU**: sửa số trong khối → `apply`. Một số thay đổi áp dụng nóng, số khác cần VM khởi động lại.
- **Đổi disk_gb**: chỉ **tăng** được, không giảm.

> ⚠️ **Cẩn thận với `vm_id` và `node`:** đổi 2 field này khiến Terraform **xóa VM cũ tạo VM mới** (replace). Plan sẽ báo `1 to add, 1 to destroy` — đọc kỹ trước khi apply.

## 5. State — quy tắc sống còn

- `terraform.tfstate` là **nguồn sự thật**. Mất nó = Terraform "quên" hết VM đang quản.
- **Đừng** sửa tay, **đừng** commit (đã .gitignore).
- Làm việc nhóm / CI → dùng **remote state** (xem [05-nang-cao.md](05-nang-cao.md)).
- Đồng bộ lại state với thực tế: `terraform refresh` (hoặc `plan` tự refresh).

Lệnh state hữu ích:

```bash
terraform state list                                   # liệt kê resource đang quản
terraform state show 'module.vms["test-01"].proxmox_virtual_environment_vm.this'
```

## 6. Xóa VM (an toàn)

```bash
# Xóa 1 VM cụ thể: bỏ khối của nó khỏi vm_definitions -> apply
# HOẶC nhắm trực tiếp:
terraform destroy -target='module.vms["test-01"]'

# Xóa TẤT CẢ (⚠️ nguy hiểm):
terraform destroy
```

➡️ VM đã chạy nhưng còn "trống". Tiếp theo: [03-ansible-co-ban.md](03-ansible-co-ban.md) để cài dịch vụ.
