#!/usr/bin/env bash
# ============================================================
#  scripts/bootstrap-ceph.sh
#  Dựng Ceph cho cụm Proxmox bằng lệnh pveceph (KHÔNG dùng Terraform).
#
#  CHẠY Ở ĐÂU:  SSH vào node ĐẦU TIÊN (primary) của cluster rồi chạy.
#               Script sẽ tự SSH sang các node khác (Proxmox cluster đã
#               có sẵn ssh trust giữa các node bằng root).
#
#  YÊU CẦU:
#    - Các node đã JOIN chung 1 Proxmox cluster (pvecm status thấy đủ).
#    - Mỗi node có ÍT NHẤT 1 ổ đĩa TRỐNG, CHƯA format để làm OSD.
#    - Mạng Ceph nên tách riêng (xem CEPH_NETWORK / CEPH_CLUSTER_NETWORK).
#
#  ⚠️  ĐỌC & SỬA phần CẤU HÌNH bên dưới cho khớp cụm thật rồi mới chạy.
#  ⚠️  Tạo OSD sẽ XÓA TOÀN BỘ dữ liệu trên đĩa được chỉ định!
# ============================================================
set -euo pipefail

# ----------------------- CẤU HÌNH --------------------------
# Mạng Ceph. public = client<->ceph; cluster = replication giữa OSD.
# Nên để cluster network trên 1 NIC/VLAN riêng tốc độ cao.
CEPH_NETWORK="192.168.1.0/24"          # ĐỔI
CEPH_CLUSTER_NETWORK="10.10.10.0/24"   # ĐỔI (có thể trùng public nếu chỉ 1 NIC)

# 3–5 node chạy MON/MGR (quorum). KHÔNG nên để cả 9 node làm mon.
MON_NODES=("pve-node-01" "pve-node-02" "pve-node-03")     # ĐỔI
MGR_NODES=("pve-node-01" "pve-node-02" "pve-node-03")     # ĐỔI
MDS_NODES=("pve-node-01" "pve-node-02")                   # ĐỔI (chỉ cần nếu dùng CephFS)

# Map node -> (các) đĩa làm OSD. Mỗi node có thể nhiều đĩa, cách nhau dấu cách.
# ⚠️ ĐỔI tên đĩa cho ĐÚNG từng node (kiểm tra bằng: lsblk).
declare -A NODE_DISKS=(
  ["pve-node-01"]="/dev/sdb"
  ["pve-node-02"]="/dev/sdb"
  ["pve-node-03"]="/dev/sdb"
  ["pve-node-04"]="/dev/sdb"
  ["pve-node-05"]="/dev/sdb"
  ["pve-node-06"]="/dev/sdb"
  ["pve-node-07"]="/dev/sdb"
  ["pve-node-08"]="/dev/sdb"
  ["pve-node-09"]="/dev/sdb"
)

# Pool cho VM disk. Tên này khớp với storage_vm_pool trong terraform.tfvars.
RBD_POOL="ceph-vm"
RBD_PG_NUM=128          # 9-node, vài chục OSD: 128 hợp lý (autoscale sẽ tinh chỉnh)

# CephFS (shared filesystem). Để "yes" nếu cần, "no" nếu không.
ENABLE_CEPHFS="no"
CEPHFS_NAME="cephfs"

REPLICAS=3              # size: số bản sao mỗi object
MIN_REPLICAS=2          # min_size: tối thiểu để cho phép ghi
# -----------------------------------------------------------

ssh_node() { ssh -o StrictHostKeyChecking=no "root@$1" "$2"; }

echo "######################################################"
echo "#  Bootstrap Ceph trên cụm Proxmox"
echo "#  Public net : ${CEPH_NETWORK}"
echo "#  Cluster net: ${CEPH_CLUSTER_NETWORK}"
echo "#  MON nodes  : ${MON_NODES[*]}"
echo "#  OSD disks  :"
for n in "${!NODE_DISKS[@]}"; do echo "#    - ${n}: ${NODE_DISKS[$n]}"; done
echo "######################################################"
read -rp ">> Các đĩa OSD ở trên sẽ BỊ XÓA SẠCH. Gõ 'yes' để tiếp tục: " ok
[[ "$ok" == "yes" ]] || { echo "Hủy."; exit 1; }

# 1) Cài gói Ceph trên TẤT CẢ node
echo "==> [1/6] Cài Ceph packages trên mọi node..."
for n in "${!NODE_DISKS[@]}"; do
  echo "    - $n"
  ssh_node "$n" "pveceph install --repository no-subscription" || true
done

# 2) Khởi tạo Ceph trên node hiện tại (primary)
echo "==> [2/6] pveceph init (chạy trên node primary hiện tại)..."
pveceph init --network "${CEPH_NETWORK}" --cluster-network "${CEPH_CLUSTER_NETWORK}"

# 3) Tạo MON + MGR
echo "==> [3/6] Tạo MON..."
for n in "${MON_NODES[@]}"; do
  echo "    - mon: $n"
  ssh_node "$n" "pveceph mon create" || echo "      (mon trên $n có thể đã tồn tại, bỏ qua)"
done

echo "==> Tạo MGR..."
for n in "${MGR_NODES[@]}"; do
  echo "    - mgr: $n"
  ssh_node "$n" "pveceph mgr create" || echo "      (mgr trên $n có thể đã tồn tại, bỏ qua)"
done

# 4) Tạo OSD trên từng node theo NODE_DISKS
echo "==> [4/6] Tạo OSD..."
for n in "${!NODE_DISKS[@]}"; do
  for disk in ${NODE_DISKS[$n]}; do
    echo "    - osd: $n $disk"
    ssh_node "$n" "pveceph osd create ${disk}" || echo "      (không tạo được OSD $disk trên $n — kiểm tra lsblk)"
  done
done

echo "==> Chờ cluster ổn định 15s..."
sleep 15
ceph -s || true

# 5) Tạo RBD pool cho VM + tự đăng ký storage (--add-storages)
echo "==> [5/6] Tạo RBD pool '${RBD_POOL}' + đăng ký storage..."
pveceph pool create "${RBD_POOL}" \
  --application rbd \
  --pg_num "${RBD_PG_NUM}" \
  --size "${REPLICAS}" \
  --min_size "${MIN_REPLICAS}" \
  --add-storages 1

# 6) (Tùy chọn) CephFS
if [[ "${ENABLE_CEPHFS}" == "yes" ]]; then
  echo "==> [6/6] Tạo CephFS '${CEPHFS_NAME}'..."
  for n in "${MDS_NODES[@]}"; do
    echo "    - mds: $n"
    ssh_node "$n" "pveceph mds create" || true
  done
  pveceph fs create --name "${CEPHFS_NAME}" --add-storages 1
else
  echo "==> [6/6] Bỏ qua CephFS (ENABLE_CEPHFS=no)."
fi

echo ""
echo "######################################################"
ceph -s || true
echo "######################################################"
echo "✓ Xong. Kiểm tra trong PVE UI → Datacenter → Ceph."
echo "  Storage RBD '${RBD_POOL}' đã sẵn sàng."
echo "  -> Sửa terraform.tfvars:  storage_vm_pool = \"${RBD_POOL}\""
echo "  -> Rồi: terraform plan && terraform apply"
