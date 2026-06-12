# 05 — Nâng cao

> Khi đã chạy mượt phần cơ bản, đây là các bước "lên đời".

## 1. Remote state (bắt buộc khi nhiều người / CI)

Mặc định state nằm ở file `terraform.tfstate` trên máy bạn → người khác hoặc CI không thấy, dễ xung đột. Giải pháp: lưu state ở nơi chung (S3/MinIO) + **khóa** để tránh 2 người apply cùng lúc.

Cấu hình backend nằm ở file riêng `terraform/backend.tf`, dùng **"partial config"**: block `backend "s3" {}` để trống, còn giá trị thật (endpoint/bucket MinIO) để ở file `backend.hcl` **không commit**. Cách làm:

```bash
cd terraform
cp backend.hcl.example backend.hcl     # điền endpoint/bucket MinIO THẬT
# mở backend.tf, bỏ comment block: terraform { backend "s3" {} }
export AWS_ACCESS_KEY_ID=<minio-key>
export AWS_SECRET_ACCESS_KEY=<minio-secret>
terraform init -backend-config=backend.hcl -migrate-state
```

Nội dung mẫu `backend.hcl.example` (lưu ý dùng `use_path_style`, tên mới thay cho `force_path_style` đã deprecated):

```hcl
bucket                      = "terraform-state"
key                         = "proxmox/prod/terraform.tfstate"
region                      = "ap-southeast-1"
endpoint                    = "https://minio.example.com"
skip_credentials_validation = true
skip_metadata_api_check     = true
skip_region_validation      = true
use_path_style              = true
```

> Credentials MinIO truyền qua biến môi trường `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (không để trong `backend.hcl`).
> 💡 Sau `init`, file `.terraform.lock.hcl` được sinh ra và **nên commit** (repo đã bỏ ignore nó) để khóa đúng hash provider.

## 2. CI/CD (`.github/workflows/infra.yml`)

Pipeline có sẵn: PR → `plan`; merge vào `main` → `apply` → Ansible → thông báo Telegram.

**Cần để CI chạy thật:**

1. **Self-hosted runner** nằm trong mạng Proxmox (vì cần tới được API 8006 + SSH VM). GitHub-hosted runner ngoài internet không vào được mạng nội bộ.
2. **Secrets** (Repo → Settings → Secrets and variables → Actions):
   - `PROXMOX_API_TOKEN`, `VM_SSH_PUBLIC_KEY`, `SSH_PRIVATE_KEY`, `ANSIBLE_VAULT_PASSWORD`, `PROXMOX_TOKEN_SECRET`
   - (tùy chọn) `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` + variable `TELEGRAM_ENABLED=true`
3. **Environment `production`** có required reviewers (để `apply` cần người duyệt).

> ⚠️ **Quan trọng — CI cần `vm_definitions`:** file `terraform.tfvars` bị gitignore nên trên CI Terraform **không thấy danh sách VM** → plan ra rỗng. Cách xử lý:
> - **Tách biến nhạy cảm khỏi non-nhạy cảm**: đưa `vm_definitions`, `proxmox_nodes` (không bí mật) vào 1 file **được commit**, ví dụ `terraform/cluster.auto.tfvars`; chỉ giữ token/secret ngoài Git (qua `TF_VAR_*`).
> - Terraform tự nạp mọi file `*.auto.tfvars`. Như vậy CI có định nghĩa VM mà secret vẫn an toàn.

## 3. SDN / VLAN

Bật trong `terraform.tfvars`:

```hcl
sdn_enabled = true
sdn_zones = [
  { zone_id = "vlan-100", type = "vlan", bridge = "vmbr0", vlan_id = 100 },
]
```

Module `network` tạo VLAN interface trên node primary. Sau đó gán VM vào VLAN bằng field `vlan_id` trong `vm_definitions`:

```hcl
"db-01" = { ... vlan_id = 100 ... }
```

> Đây là phần dễ làm sập mạng nếu cấu hình switch/bridge chưa sẵn sàng — thử trên 1 VM test trước.

## 4. Giám sát Kubernetes (đúng cách)

Prometheus đứng ngoài **không** scrape thẳng kubelet (cổng 10250 cần TLS + token). Cách chuẩn là deploy **kube-prometheus-stack** *bên trong* cluster bằng Helm:

```bash
export KUBECONFIG=ansible/kubeconfig.yaml
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kps prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

Sau đó (tùy chọn) federate hoặc remote-write về Prometheus trung tâm ở VM `monitoring-01`.

## 4b. HA Kubernetes (nhiều control-plane)

Mặc định repo dùng **1 master** (`--cluster-init`, embedded etcd) — đơn giản, chạy chắc. Lên HA cần **số lẻ master (3)** và master phụ phải *join* chứ không *init*:

- Master #1: `k3s server --cluster-init` (đã có trong role).
- Master #2, #3: `k3s server --server https://<master1>:6443 --token <token>` (KHÔNG `--cluster-init`).
- Cần 1 **VIP / load balancer** trước 3 API server (kube-vip hoặc HAProxy) để kubeconfig trỏ vào VIP thay vì IP 1 master.

Vì cần xử lý "node đầu init, các node sau join" theo đúng thứ tự, đây là việc nên làm sau khi đã quen. Khi sẵn sàng, sửa `roles/kubernetes/tasks/main.yml` tách logic master-đầu vs master-phụ, rồi mới thêm `k8s-master-02/03` vào `vm_definitions`.

## 5. Scale lên đủ 9 node

- **Thêm node Proxmox**: thêm dòng vào `proxmox_nodes` (+ vào `NODE_DISKS` nếu dùng Ceph). Join node vào cluster bằng `pvecm add` trước.
- **Phân bổ VM đều tay**: rải `node = pve-node-0X` trong `vm_definitions` để cân tải. Hiện chưa có auto-scheduler — bạn tự chọn node cho từng VM.
- **Template trên nhiều node**: với local-lvm, clone nhanh nhất khi template cùng node. Có Ceph rồi thì 1 template dùng chung cho cả cụm.

## 6. An ninh nên siết cho production

- `proxmox_insecure = false` + cert hợp lệ cho API.
- Token role **hẹp** thay vì PVEAdmin.
- Tách mạng quản trị / VM / Ceph.
- Bật HA + backup (Proxmox Backup Server).

## 7. pre-commit — bắt lỗi ngay tại máy (trước khi push)

Repo có `.pre-commit-config.yaml`: tự chạy `terraform fmt`, `terraform validate`, `ansible-lint`, và chặn lỡ commit private key... **trước mỗi `git commit`**. Bắt lỗi tại máy nhanh & rẻ hơn để CI báo đỏ.

```bash
pip install pre-commit        # cần Python
pre-commit install            # gắn hook vào repo (làm 1 lần)
pre-commit run --all-files    # chạy thử toàn bộ ngay
```
> **Vì sao:** từ giờ mỗi `git commit` sẽ tự kiểm. Nếu `fmt` sửa file, commit dừng lại để bạn `git add` rồi commit tiếp. Hook `terraform_*` cần đã cài `terraform`; `ansible-lint` chạy hơi chậm — muốn bỏ qua 1 lần: `SKIP=ansible-lint git commit ...`.

➡️ Vận hành hằng ngày: [06-van-hanh.md](06-van-hanh.md).
