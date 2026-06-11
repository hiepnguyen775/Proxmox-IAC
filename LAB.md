# 🧪 LAB — Học Proxmox IaC theo từng ngày

> Cách dùng: mỗi "Ngày" là 1 buổi ~45–90 phút. **Gõ từng lệnh, đọc phần "Vì sao"**, đừng copy cả khối rồi chạy một lần. Hiểu *tại sao* quan trọng hơn chạy xong.

## ⚠️ Quy tắc an toàn (đọc trước)
- **KHÔNG lab trên cụm Proxmox production.** Dùng 1 Proxmox lab riêng (nested/VM/node test). Một lệnh `apply`/`destroy` nhầm = đụng VM thật.
- Mọi thứ đều **idempotent** — chạy lại nhiều lần an toàn. Cứ thử, sai thì sửa.
- Mỗi ngày kết thúc bằng phần **✅ Checkpoint** — làm được mới sang ngày sau.

---

## Ngày 1 — Làm quen công cụ & repo

**Mục tiêu:** cài terraform + ansible, tải repo, hiểu cấu trúc.

```bash
# Cập nhật danh sách gói + cài git
sudo apt update && sudo apt install -y git curl
```
> **Vì sao:** `apt update` làm mới "danh mục" gói (không phải nâng cấp); `git` để tải repo; `curl` để tải file từ internet.

```bash
# Tải repo về máy
git clone https://github.com/hiepnguyen775/Proxmox-IAC.git
cd Proxmox-IAC
```
> **Vì sao:** `git clone` sao chép toàn bộ repo + lịch sử về máy. Mọi lệnh lab sau đều chạy trong thư mục này.

Cài Terraform & Ansible: làm theo [docs/01-chuan-bi.md](docs/01-chuan-bi.md) mục 1. Kiểm tra:
```bash
terraform version     # mong: Terraform v1.x
ansible --version     # mong: ansible [core 2.x]
```
> **Vì sao:** xác nhận công cụ đã cài đúng trước khi đi tiếp — tránh "lỗi vì chưa cài".

```bash
# Nhìn tổng thể repo
ls -la
cat README.md
```
> **Vì sao:** `ls -la` liệt kê cả file ẩn (như `.gitignore`); đọc README để có bản đồ tổng thể.

**✅ Checkpoint:** `terraform version` và `ansible --version` đều chạy; bạn chỉ ra được đâu là thư mục `terraform/` và `ansible/`.

---

## Ngày 2 — Terraform: 3 lệnh nền tảng (an toàn, chưa tạo gì)

**Mục tiêu:** hiểu `init / fmt / validate` mà **không** đụng tới hạ tầng.

```bash
cd terraform
terraform init
```
> **Vì sao:** `init` tải "provider" (bpg/proxmox) — phần mềm để Terraform nói chuyện với Proxmox. Chạy 1 lần cho mỗi thư mục, hoặc khi đổi version provider. Tạo thư mục ẩn `.terraform/`.

```bash
terraform fmt -recursive
```
> **Vì sao:** tự canh lề/định dạng file `.tf` cho chuẩn. `-recursive` áp dụng cả thư mục con (`modules/`). Code đẹp = dễ đọc, dễ review.

```bash
terraform validate
```
> **Vì sao:** kiểm tra **cú pháp** và tham chiếu biến có hợp lệ không — **không** kết nối Proxmox, **không** tạo gì. Đây là "biên dịch thử". Nếu báo lỗi, đọc kỹ dòng lỗi và sửa file tương ứng.

> 💡 **Vì sao chưa `plan`/`apply`?** `plan` cần kết nối Proxmox + token thật. Ta để dành tới Ngày 3 khi đã có Proxmox lab.

**✅ Checkpoint:** `terraform validate` in `Success!`. Bạn hiểu init/fmt/validate khác nhau thế nào.

---

## Ngày 3 — Dựng Proxmox lab + chuẩn bị (token, key, template)

**Mục tiêu:** có 1 Proxmox để nghịch + token + template.

**Chọn 1 trong 2:**
- **(A) Proxmox nested**: cài Proxmox trong 1 VM (VirtualBox/KVM) — miễn phí, gọn. Bật "nested virtualization".
- **(B) 1 node test** tách hẳn khỏi cụm production.

Sau khi có Proxmox lab, làm theo [docs/01-chuan-bi.md](docs/01-chuan-bi.md):
```bash
# Tạo SSH key (nếu chưa có)
ssh-keygen -t ed25519 -C "proxmox-lab"
cat ~/.ssh/id_ed25519.pub        # copy để dán vào terraform.tfvars
```
> **Vì sao:** key **public** sẽ được cloud-init nhét vào VM; bạn dùng key **private** để SSH. Không dùng mật khẩu = an toàn hơn.

- Tạo **API token** trong Proxmox UI (docs/01 mục 3) → copy secret.
- Trên Proxmox node, tạo template:
```bash
bash scripts/create-template.sh
```
> **Vì sao:** Terraform **clone** VM từ template này (ID 9000). Không có template → không tạo được VM.

**✅ Checkpoint:** `qm list` trên node thấy VM 9000 (template); bạn có token secret và nội dung key public.

---

## Ngày 4 — Tạo VM đầu tiên (vòng đời đầy đủ)

**Mục tiêu:** trải nghiệm `plan → apply → ssh → destroy`.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```
> **Vì sao:** `.example` là mẫu (commit lên git được); `terraform.tfvars` là giá trị thật (đã .gitignore). Tách ra để không lộ secret.

Sửa `terraform.tfvars`: điền `proxmox_endpoint`, `proxmox_api_token`, `ssh_public_key`, `proxmox_nodes` (tên node lab), và **rút gọn `vm_definitions` còn 1 VM test**.

```bash
terraform plan
```
> **Vì sao:** `plan` cho xem **trước** Terraform định làm gì (`+ create`, `~ change`, `- destroy`) — **không thực thi**. Luôn đọc dòng cuối: `Plan: 1 to add, 0 to change, 0 to destroy.`

```bash
terraform apply
```
> **Vì sao:** thực thi kế hoạch (gõ `yes` xác nhận). Kết quả ghi vào `terraform.tfstate` — "sổ ghi nhớ" của Terraform.

```bash
terraform output            # in IP, lệnh ssh
ssh ubuntu@<ip-vm>          # vào VM thật
```
> **Vì sao:** `output` lấy thông tin sau khi tạo (IP, id...). SSH để xác nhận VM sống thật.

```bash
terraform destroy           # xóa VM test
```
> **Vì sao:** dọn dẹp môi trường lab. Đọc plan trước khi gõ `yes` — đảm bảo chỉ xóa đúng VM test.

**✅ Checkpoint:** bạn tạo được 1 VM, SSH vào được, rồi destroy sạch. Hiểu vai trò của `tfstate`.

---

## Ngày 5 — Ansible: cấu hình OS

**Mục tiêu:** dùng inventory động + chạy `provision.yml`.

> Tạo lại VM test (Ngày 4 `apply`). Lần này giữ VM để Ansible cấu hình.

```bash
cd ../ansible
export PROXMOX_TOKEN_SECRET="<secret-token-ansible>"
ansible-inventory -i inventory/proxmox.yml --graph
```
> **Vì sao:** `export` đưa secret vào biến môi trường (không ghi vào file). `ansible-inventory --graph` cho thấy Ansible "nhìn thấy" VM nào, gom nhóm theo tag ra sao — kiểm tra trước khi chạy thật.

```bash
ansible all -m ping
```
> **Vì sao:** `-m ping` chạy module `ping` (kiểm tra SSH + Python trên VM), **không phải** ping ICMP. Đây là "bắt tay" trước khi cấu hình.

```bash
ansible-playbook playbooks/provision.yml
```
> **Vì sao:** chạy role `base`: hostname, timezone, package, hardening, nạp module kernel cho k8s... Chạy lại nhiều lần cũng an toàn (idempotent).

```bash
ansible-playbook playbooks/provision.yml --check --diff
```
> **Vì sao:** `--check` = chạy thử không đổi gì (dry-run); `--diff` = hiện file sẽ thay đổi chỗ nào. Cực hữu ích để "xem trước" với Ansible.

**✅ Checkpoint:** `--graph` thấy VM trong nhóm; `ping` trả `pong`; `provision.yml` chạy xanh (ok/changed, không failed).

---

## Ngày 6 — Cài Kubernetes (k3s)

**Mục tiêu:** dựng 1 cluster k3s nhỏ.

> Đảm bảo `vm_definitions` có ít nhất 1 VM tag `["k8s","k8s-master"]` (và vài worker nếu muốn). Đã `apply` + `provision`.

```bash
ansible-playbook playbooks/configure.yml --tags k8s
```
> **Vì sao:** `--tags k8s` chỉ chạy phần Kubernetes (bỏ qua monitoring) → nhanh, tập trung. Play master chạy trước, worker join sau.

```bash
export KUBECONFIG=$PWD/kubeconfig.yaml
kubectl get nodes
```
> **Vì sao:** `kubeconfig.yaml` được Ansible kéo về máy bạn; `KUBECONFIG` trỏ `kubectl` vào cluster đó. `get nodes` xác nhận master/worker `Ready`.

**✅ Checkpoint:** `kubectl get nodes` thấy node `Ready`. Bạn vừa dựng Kubernetes bằng code!

---

## Ngày 7 — Monitoring + Git workflow + tổng kết

**Mục tiêu:** dựng Prometheus/Grafana, và lưu thay đổi của mình đúng cách.

```bash
ansible-playbook playbooks/configure.yml --tags monitoring --limit monitoring
```
> **Vì sao:** `--limit monitoring` chỉ chạy trên VM nhóm monitoring → không đụng VM khác. Mở Grafana ở `http://<ip-monitoring>:3000`.

```bash
git status
git checkout -b my-lab-changes
git add -A
git commit -m "Lab: cấu hình cụm test của tôi"
```
> **Vì sao:** `status` xem mình đã đổi gì; tạo nhánh riêng (`checkout -b`) để không lẫn với `main`; `add`+`commit` lưu mốc. **Nhớ:** đừng commit `terraform.tfvars`/`vault.yml` (đã .gitignore).

```bash
# Dọn dẹp khi học xong
cd ../terraform && terraform destroy
```
> **Vì sao:** trả môi trường lab về sạch. Lần sau `apply` lại từ đầu — đó chính là sức mạnh của IaC.

**✅ Checkpoint:** Grafana mở được; bạn commit thay đổi lên nhánh riêng; destroy sạch.

---

## 🎯 Sau 7 ngày bạn đã biết
- Vòng đời Terraform: `init → validate → plan → apply → destroy` và vai trò `tfstate`.
- Ansible: inventory động, `ping`, `playbook`, `--tags`, `--limit`, `--check`.
- Dựng VM → cấu hình OS → k3s → monitoring hoàn toàn bằng code.

**Học tiếp:** [docs/05-nang-cao.md](docs/05-nang-cao.md) (remote state, CI, HA), [docs/04-ceph-pveceph.md](docs/04-ceph-pveceph.md) (Ceph), [docs/07-kien-truc-trien-khai.md](docs/07-kien-truc-trien-khai.md) (mô hình triển khai). Gặp lỗi? → [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
