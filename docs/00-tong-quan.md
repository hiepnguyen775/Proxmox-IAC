# 00 — Tổng quan: IaC, Terraform & Ansible

> Mục tiêu: hiểu *tại sao* dùng các công cụ này trước khi gõ lệnh.

## 1. IaC (Infrastructure as Code) là gì?

Thay vì bấm chuột trong giao diện Proxmox để tạo VM, ta **mô tả hạ tầng bằng file text** (code) rồi để công cụ tự dựng. Lợi ích:

- **Lặp lại được**: dựng lại y hệt khi cần, không "tôi quên đã config gì".
- **Lưu vết (Git)**: ai đổi gì, khi nào, rollback được.
- **Review trước khi làm**: `terraform plan` cho xem trước sẽ thay đổi gì.
- **Quy mô**: 9 node, 50 VM cũng quản như 1.

## 2. Terraform lo gì? Ansible lo gì?

Hai công cụ giải quyết hai tầng khác nhau — **không thay thế nhau**:

| | **Terraform** | **Ansible** |
|---|---|---|
| Tầng | Hạ tầng (bên ngoài VM) | Bên trong OS của VM |
| Việc | Tạo/xóa VM, LXC, disk, network | Cài package, cấu hình service, deploy app |
| Cách nghĩ | *Khai báo* (declarative): "tôi muốn 6 VM" | *Tác vụ* (procedural-ish): "chạy các bước này" |
| Trạng thái | Có **state file** theo dõi thực tế | Không giữ state, chạy là áp dụng |
| Câu thần chú | `terraform apply` | `ansible-playbook` |

**Luồng chuẩn:**

```
terraform apply   →  6 VM trống được tạo trên Proxmox
        ↓
ansible provision →  cài timezone, package, hardening, prereq k8s
        ↓
ansible configure →  cài k3s (master/worker), Prometheus, Grafana
```

## 3. Vì sao Ceph KHÔNG nằm trong Terraform?

Provider Terraform `bpg/proxmox` **không** quản lý được việc dựng Ceph (mon/mgr/osd). Đó là việc của lệnh `pveceph` chạy trực tiếp trên node. Nên trong repo này:

- Ceph được dựng bằng **`scripts/bootstrap-ceph.sh`** (chạy 1 lần trên node).
- Sau đó Terraform chỉ việc dùng storage `ceph-vm` như một pool bình thường.

Chi tiết: [04-ceph-pveceph.md](04-ceph-pveceph.md).

## 4. Kiến trúc repo này tạo ra

```
                ┌───────────────────────── Proxmox cluster (9 node) ─────────────────────────┐
                │                                                                            │
  terraform ───▶│  k8s-master-01/02/03   k8s-worker-01/02/03   monitoring-01   proxy-01(LXC) │
                │        (VM)                  (VM)                 (VM)            (LXC)      │
                └────────────┬───────────────────┬────────────────────┬──────────────────────┘
                             │                   │                    │
            ansible ─────────┴───────────────────┴────────────────────┘
              provision.yml : OS chung cho tất cả
              configure.yml : k3s cho nhóm k8s_*, Prometheus/Grafana cho monitoring
```

- **VM** = máy ảo đầy đủ (kernel riêng) → chạy Kubernetes, DB, app nặng.
- **LXC** = container nhẹ (chia sẻ kernel host) → reverse proxy, service nhỏ.

## 5. Khái niệm phải nhớ

- **State** (`terraform.tfstate`): Terraform ghi lại "thực tế đang có gì". **Đừng xóa/sửa tay.** Xem [05-nang-cao.md](05-nang-cao.md) về remote state.
- **Template / cloud-init**: VM được clone từ 1 *template* Ubuntu có sẵn cloud-init; cloud-init nhận IP/SSH key lúc boot lần đầu.
- **Tag → group**: tag gắn cho VM trong Terraform → Ansible tự gom nhóm để biết cài gì cho máy nào.
- **Idempotent**: chạy lại nhiều lần cho cùng kết quả; cả Terraform lẫn Ansible đều thiết kế như vậy → cứ chạy lại an tâm.

➡️ Tiếp theo: [01-chuan-bi.md](01-chuan-bi.md) — cài công cụ và chuẩn bị Proxmox.
