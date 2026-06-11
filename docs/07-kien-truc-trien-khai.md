# 07 — Kiến trúc triển khai: IaC chạy ở đâu? 1-node vs HA

> Trả lời câu hỏi: *"con IaC này chạy trên server nào, nếu 1 node thì sao, HA thì sao?"*

## 1. "Control node" là gì — nơi chạy Terraform/Ansible

Terraform và Ansible **không phải dịch vụ chạy nền**. Chúng là công cụ CLI bạn **chạy từ 1 máy Linux** gọi là **control node** (máy điều khiển). Control node chỉ cần:

- Cài `terraform`, `ansible`, `git`.
- **Mạng tới Proxmox API** (cổng `8006`) của ít nhất 1 node.
- **SSH tới các VM** (cổng `22`) để Ansible cấu hình.
- Giữ (hoặc truy cập) **state** + **secret** (`terraform.tfvars`, `vault.yml`, ssh key).

> ⚠️ Control node **KHÔNG nên là một trong 9 node Proxmox** (không cài thêm gói lên hypervisor). Nó là máy/VM/LXC **riêng**.

Control node có thể là:

| Lựa chọn | Khi nào dùng |
|---|---|
| **Laptop/PC Ubuntu của bạn** | Học, 1 người, lab |
| **1 LXC/VM "mgmt" trong cụm** | Nhiều người, cần luôn-bật, gần cụm |
| **CI runner (self-hosted)** | Tự động hóa, team, production |

```
   ┌─────────────────┐        API 8006         ┌───────────────────────────┐
   │  CONTROL NODE    │ ───────────────────────▶│  Proxmox cluster (9 node) │
   │ (Ubuntu)         │                         │   pve-node-01 ... 09      │
   │  terraform ──────┼── tạo/xóa VM,LXC ───────▶│                           │
   │  ansible ────────┼── SSH 22 cấu hình ──────▶│   VM: k8s, monitoring...  │
   │  git, state,     │                         │   LXC: proxy...           │
   │  secrets         │                         └───────────────────────────┘
   └─────────────────┘
```

## 2. Phân biệt 3 tầng "HA" (đừng lẫn)

"HA" ở đây có thể là 1 trong 3 thứ khác nhau — bạn cần quyết từng tầng:

| Tầng | HA nghĩa là gì | Làm sao |
|---|---|---|
| **A. Hypervisor** (Proxmox) | Node chết → VM tự bật lại ở node khác | Cần **shared storage = Ceph** + `ha-manager` ([04](04-ceph-pveceph.md)) |
| **B. Kubernetes** | 1 control-plane chết → cluster vẫn sống | **3 master + VIP** ([05](05-nang-cao.md) mục 4b) |
| **C. IaC/Control** | Control node chết → vẫn deploy được, state không mất | **Remote state** + Git + CI ([05](05-nang-cao.md) mục 1-2) |

Control node bản thân nó **không cần "luôn chạy"** — nó chết cũng không làm sập hạ tầng đang chạy. Cái cần bảo vệ là **state** và **secrets**, không phải bản thân máy.

---

## 3. Mô hình A — Single (1 người / lab / bắt đầu)

Đơn giản nhất. Chạy mọi thứ từ 1 control node, state để local.

```
        ┌────────────────────────┐
        │  Control node (Ubuntu) │  terraform.tfstate (local file)
        │  - terraform           │  terraform.tfvars (secrets)
        │  - ansible             │  ~/.ssh/id_ed25519
        └───────────┬────────────┘
                    │ API + SSH
        ┌───────────▼────────────────────────────────┐
        │  Proxmox 9-node  (storage: local-lvm)       │
        │  VM: 1 k8s-master + N worker + monitoring   │
        └─────────────────────────────────────────────┘
```

- **Ưu:** dựng nhanh, không phụ thuộc gì thêm.
- **Nhược:** state nằm 1 chỗ (backup tay!); chỉ 1 người làm; control node chết phải dựng lại tooling.
- **Storage:** `local-lvm` — VM gắn với node, **không** live-migrate/HA.
- **k8s:** 1 master.

👉 Hợp để **học và chạy thật quy mô nhỏ**. Chính là mặc định của repo này.

---

## 4. Mô hình B — HA / Team / Production

```
   Người dùng ──push──▶  Git (GitHub repo)
                              │  webhook
                              ▼
                   ┌──────────────────────┐      ┌─────────────────────┐
                   │ CI self-hosted runner │◀────▶│ Remote state + lock │
                   │ (LXC trong cụm)       │      │ MinIO / S3          │
                   │  terraform plan/apply │      └─────────────────────┘
                   │  ansible-playbook     │
                   └───────────┬───────────┘
                               │ API 8006 + SSH 22
   ┌───────────────────────────▼──────────────────────────────────────┐
   │  Proxmox 9-node   (storage: CEPH dùng chung, ha-manager)          │
   │  k8s: 3 master + VIP (kube-vip)  ·  N worker  ·  monitoring        │
   └───────────────────────────────────────────────────────────────────┘
```

Khác biệt so với mô hình A:

1. **Không ai chạy `apply` từ laptop.** Thay đổi đi qua **Git → Pull Request → CI**. Review trước khi apply.
2. **Remote state + lock** (MinIO/S3): nhiều người không ghi đè nhau, state được versioned/backup. ([05](05-nang-cao.md) mục 1)
3. **CI runner là 1 LXC nhỏ trong cụm** (luôn bật, ở trong mạng nội bộ để tới được API + VM). Đây chính là "control node" phiên bản tự động.
4. **Ceph** cho VM disk → live-migration + `ha-manager` (HA tầng hypervisor).
5. **k8s 3 master + VIP** → HA tầng Kubernetes.

> Bạn có thể tạo CI runner bằng chính repo này: thêm 1 LXC `tags=["mgmt","ci"]` trong `lxc_definitions`, rồi cài GitHub Actions runner lên nó.

### So sánh nhanh

| | Mô hình A (Single) | Mô hình B (HA) |
|---|---|---|
| Chạy IaC từ | Laptop/1 máy | Git + CI runner |
| State | Local file | Remote (MinIO/S3) + lock |
| Storage VM | local-lvm | Ceph |
| Hypervisor HA | ❌ | ✅ ha-manager |
| k8s control-plane | 1 master | 3 master + VIP |
| Hợp với | Học, lab, nhỏ | Team, production |

**Lộ trình lên HA:** A → bật remote state → dựng Ceph → đổi `storage_vm_pool=ceph-vm` → bật ha-manager → lên 3 master k8s → đưa apply vào CI. Làm **từng bước**, mỗi bước verify xong mới sang bước sau.

---

## 5. Hướng mở rộng: nhiều IaC (on-prem + Cloud)

Khi muốn quản lý cả **on-prem (Proxmox)** lẫn **Cloud (AWS/GCP)** bằng cùng một cách, **không** trộn chung vào 1 thư mục Terraform. Mỗi "môi trường" (environment) có provider, state, secret **riêng**, nhưng **dùng chung pattern và module nơi có thể**.

Cấu trúc đề xuất (monorepo):

```
infra/                          # 1 repo, nhiều môi trường
├── modules/                    # module DÙNG CHUNG (viết 1 lần)
│   ├── proxmox-vm/             # = modules/vm hiện tại
│   ├── aws-ec2/
│   ├── gcp-vm/
│   └── k8s-bootstrap/          # (ansible) cài k3s — provider-agnostic
├── live/
│   ├── onprem/                 # = repo proxmox-iac hiện tại
│   │   ├── providers.tf  (bpg/proxmox)
│   │   ├── backend → minio/onprem.tfstate
│   │   └── *.tf, *.tfvars
│   ├── aws/
│   │   ├── providers.tf  (hashicorp/aws)
│   │   ├── backend → s3/aws.tfstate
│   │   └── *.tf (VPC, EC2, EKS...)
│   └── gcp/
│       ├── providers.tf  (hashicorp/google)
│       ├── backend → gcs/gcp.tfstate
│       └── *.tf (VPC, GCE, GKE...)
└── ansible/                    # roles dùng chung cho MỌI môi trường
    └── roles/ (base, kubernetes, monitoring)
```

Nguyên tắc:

- **Mỗi env = 1 state riêng** (không bao giờ 1 state ôm cả cloud + on-prem).
- **Ansible roles tái sử dụng được** vì chúng làm việc với OS Ubuntu, không quan tâm máy chạy ở Proxmox hay AWS — chỉ cần inventory đúng. Đây là phần "lời" nhất khi đa môi trường.
- **Terraform module thì KHÁC nhau theo provider** (tạo VM Proxmox ≠ tạo EC2), nhưng *interface* (tên biến: cpu, ram, disk, tags…) nên giữ giống nhau để dễ đọc.
- Inventory động: Proxmox dùng plugin `community.general.proxmox`; AWS dùng `amazon.aws.aws_ec2`; GCP dùng `google.cloud.gcp_compute`. Cùng cơ chế **tag → group** như on-prem.

> ⚠️ Cloud tốn tiền theo giờ và cần tài khoản/credentials riêng. Khi bắt đầu nên dựng **1 thứ nhỏ** (1 VPC + 1 VM) ở **1 cloud** trước, chạy thông rồi mới mở rộng.

Khi bạn sẵn sàng, mình sẽ scaffold `live/aws/` (hoặc `live/gcp/`) theo đúng khung này, tách module dùng chung, và viết doc tương ứng.
