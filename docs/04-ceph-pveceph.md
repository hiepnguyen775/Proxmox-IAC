# 04 — Ceph bằng pveceph (storage dùng chung, chịu lỗi)

> **Quan trọng:** Terraform **không** dựng được Ceph. Phần này dùng lệnh `pveceph` qua script `scripts/bootstrap-ceph.sh`. Đây là việc làm **1 lần** cho cả cụm.

## 1. Ceph để làm gì?

Mặc định mỗi VM dùng `local-lvm` — đĩa **cục bộ của 1 node**. Hệ quả: VM **không** live-migrate sang node khác dễ dàng, và node chết là mất chỗ chứa.

**Ceph** gộp đĩa của nhiều node thành 1 kho lưu trữ **phân tán, nhân bản 3 bản**. Lợi ích cho cụm 9 node:

- VM disk nằm trên storage dùng chung → **live migration**, **HA** (VM tự bật lại ở node khác khi node chết).
- Mất 1–2 node vẫn không mất dữ liệu (size=3, min_size=2).

## 2. Điều kiện trước khi dựng

- [ ] 9 node đã **join chung 1 cluster** (`pvecm status` thấy đủ quorum).
- [ ] Mỗi node có **ít nhất 1 ổ đĩa trống** dành cho OSD (kiểm tra: `lsblk`). **Đĩa này sẽ bị xóa sạch.**
- [ ] Nên có **mạng riêng cho Ceph** (NIC/VLAN tốc độ cao) để replication không nghẽn mạng quản trị.

## 3. Khái niệm Ceph (đủ dùng)

| Thành phần | Vai trò | Nên có bao nhiêu (9 node) |
|---|---|---|
| **MON** (monitor) | Giữ "bản đồ" cluster, bầu quorum | **3** (lẻ, không cần 9) |
| **MGR** (manager) | Thống kê, dashboard | 2–3 (1 active) |
| **OSD** | 1 OSD = 1 ổ đĩa chứa data thật | càng nhiều đĩa càng tốt |
| **MDS** | Chỉ cần nếu dùng **CephFS** | 2 (1 active 1 standby) |
| **Pool** | "Vùng" chứa data (vd `ceph-vm` cho VM) | rbd cho VM |

## 4. Dựng Ceph

**Bước 1 — sửa cấu hình script.** Mở `scripts/bootstrap-ceph.sh`, sửa các biến (đánh dấu `ĐỔI`):

```bash
CEPH_NETWORK="..."          # subnet public
CEPH_CLUSTER_NETWORK="..."  # subnet replication (nên tách riêng)
MON_NODES=(...)             # 3 node làm monitor
declare -A NODE_DISKS=( ["pve-node-01"]="/dev/sdb" ... )   # ĐÚNG đĩa từng node!
```

> ⚠️ Kiểm tra tên đĩa trên TỪNG node bằng `lsblk` trước. Sai đĩa = xóa nhầm dữ liệu.

**Bước 2 — chạy trên node primary:**

```bash
# SSH vào node ĐẦU TIÊN của cluster
scp scripts/bootstrap-ceph.sh root@pve-node-01:/root/
ssh root@pve-node-01
bash /root/bootstrap-ceph.sh      # gõ 'yes' khi được hỏi
```

Script sẽ: cài gói Ceph mọi node → `pveceph init` → tạo MON/MGR → tạo OSD từng node → tạo pool `ceph-vm` và **tự đăng ký storage**.

**Bước 3 — kiểm tra:**

```bash
ceph -s            # mong muốn: health HEALTH_OK, osd: X up, X in
ceph osd tree      # thấy OSD trải đều các node
pvesm status       # thấy storage 'ceph-vm'
```

Hoặc PVE UI → `Datacenter → Ceph` (xanh = ổn).

## 5. Cho Terraform dùng Ceph

Sau khi storage `ceph-vm` sẵn sàng, sửa `terraform/terraform.tfvars`:

```hcl
storage_vm_pool = "ceph-vm"
```

Rồi:

```bash
terraform plan      # VM MỚI sẽ tạo trên ceph-vm
terraform apply
```

> 📌 VM **đã tạo** trên `local-lvm` **không** tự dời sang Ceph. Muốn chuyển: trong PVE UI → VM → Hardware → Disk → **Move Storage** sang `ceph-vm` (làm thủ công, hoặc tạo VM mới).

## 6. Bật HA cho VM (sau khi có Ceph)

Ceph cho phép HA. Trên 1 node bất kỳ:

```bash
ha-manager add vm:101 --state started --max_restart 3
ha-manager status
```

Khi node chứa VM 101 chết, Proxmox tự khởi động lại VM 101 ở node khác (vì disk nằm trên Ceph dùng chung).

## 7. Sự cố Ceph thường gặp

Xem [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) mục 7 (OSD down sau reboot, v.v.).

➡️ Tiếp theo: [05-nang-cao.md](05-nang-cao.md) — remote state, CI/CD, SDN, scale.
