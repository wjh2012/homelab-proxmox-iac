# homelab-proxmox-iac

Proxmox 클러스터 `homelab`의 VM을 Terraform(생성) + Ansible(VM 내부 구성)으로 관리한다.

| 대상 | 담당 |
|---|---|
| Ubuntu Cloud Image, VM 하드웨어(CPU/RAM/디스크/네트워크) | Terraform (`proxmox/`) |
| 사용자, 비밀번호, 고정 IP, qemu-guest-agent 설치 | cloud-init (Terraform이 주입, `proxmox/cloud-init/`) |
| 패키지, 서비스, 시스템 설정 | Ansible (`ansible/`) |

기존 VM(WireGuard, Kubernetes)과 템플릿 8000/8001은 Terraform이 관리하지 않는다.

## 환경 전제

코드에 하드코딩되어 있거나 기본값으로 들어간 값. 다르면 `proxmox/variables.tf`, `proxmox/vms.tf`를 수정한다.

| 항목 | 값 |
|---|---|
| Proxmox | VE 9.2, 2노드 클러스터 `homelab` |
| 노드 | `n100-01` = 192.168.45.201, `n100-02` = 192.168.45.202 |
| 이미지/스니펫 스토리지 | `local` (dir, 노드별 로컬) |
| VM 디스크 / cloud-init 스토리지 | `local-lvm` (lvmthin) |
| 네트워크 | 브리지 `vmbr0`, 게이트웨이/DNS 192.168.45.1, 대역 192.168.45.0/24 |
| Proxmox 인증 | `root@pam` + 비밀번호 (API와 SSH 모두) |
| VM 사용자 | `wjh2012` + 비밀번호 |
| VM ID 대역 | 300번대 = 테스트, 8000번대 = 기존 템플릿 (미관리) |

VM 사용자명을 바꾸려면 `proxmox/terraform.tfvars`에 `vm_username = "새사용자명"`을 지정하고,
`ansible/inventory/group_vars/all.yml`의 `ansible_user`도 같은 값으로 수정한다.
두 설정은 자동으로 연동되지 않는다. 아래 SSH 예시의 `wjh2012`도 지정한 사용자명으로 바꾼다.
기존 VM의 사용자명 변경은 cloud-init 설정 변경만으로 적용되지 않을 수 있으므로 VM 내부에서 별도로 처리한다.

## 1. 작업 PC 준비 (최초 1회)

Terraform은 Windows, Ansible은 WSL Ubuntu에서 실행한다.

### Windows: Terraform (>= 1.9)

```powershell
choco install terraform
# 설치 후 새 터미널을 열어야 PATH 반영
terraform version
```

### WSL Ubuntu: Ansible

```bash
sudo apt update
sudo apt install -y ansible sshpass   # sshpass: 비밀번호 SSH 접속에 필요
ansible-galaxy collection install community.general   # timezone 모듈
```

## 2. Proxmox 준비 (최초 1회)

### 2-1. 클러스터 상태 확인

```bash
pvecm status   # Quorate: Yes 여야 /etc/pve 수정 가능
```

### 2-2. `local` 스토리지에 import, snippets 콘텐츠 허용

- `import`: Ubuntu Cloud Image(qcow2)를 받아 VM 디스크로 가져오기 위해 필요
- `snippets`: cloud-init vendor-data 파일 저장에 필요

`--content`는 목록을 **덮어쓰므로** 현재 값을 먼저 확인한다.

```bash
grep -A4 "^dir: local" /etc/pve/storage.cfg
```

`content iso,vztmpl,backup`이었다면 (기존 값 + import,snippets):

```bash
pvesm set local --content iso,vztmpl,backup,import,snippets
```

`/etc/pve/storage.cfg`는 클러스터 공통이므로 한 노드에서만 실행한다. 다른 노드에서 확인:

```bash
pvesm status --content import
pvesm status --content snippets
```

### 2-3. root SSH 비밀번호 로그인 확인

Terraform provider가 스니펫 업로드에 SSH를 사용한다. 작업 PC에서 각 노드에 접속되는지 확인:

```powershell
ssh root@192.168.45.201 hostname
ssh root@192.168.45.202 hostname
```

## 3. Terraform으로 VM 생성 (Windows PowerShell)

```powershell
cd proxmox
$env:PROXMOX_VE_USERNAME = "root@pam"
$env:PROXMOX_VE_PASSWORD = "<proxmox root 비밀번호>"
$env:TF_VAR_vm_password  = "<VM wjh2012 비밀번호>"

terraform init
terraform plan    # 기존 VM은 나타나지 않아야 함
terraform apply
```

첫 apply 시 노드마다 이미지(약 600MB)를 받고, VM 첫 부팅에서 패키지 업그레이드와
qemu-guest-agent 설치가 끝날 때까지 기다리므로 수 분 걸린다.

### VM 추가

`proxmox/terraform.tfvars`의 `vms`에 항목을 추가하고 `terraform apply`.
`ansible/inventory/hosts.yml`에도 같은 VM을 추가한다.

```hcl
"ubuntu-test-02" = {
  vm_id  = 301
  node   = "n100-02"
  ip     = "192.168.45.212/24"
  cores  = 2      # 생략 시 2
  memory = 4096   # 생략 시 4096 (MB)
  disk   = 32     # 생략 시 32 (GB)
}
```

### VM 삭제

`terraform.tfvars`에서 항목을 지우고 `terraform apply`. 전체 삭제는 `terraform destroy`
(다운로드한 이미지와 스니펫도 함께 삭제된다).

### 확인

```bash
ssh wjh2012@192.168.45.211
```

Proxmox UI → VM → Summary에 IP가 표시되면 qemu-guest-agent가 정상 동작 중이다.

## 4. Ansible로 VM 구성 (WSL Ubuntu)

```bash
cd /mnt/d/prj/wjh/homelab-proxmox-iac/ansible
# /mnt/d 는 world-writable이라 Ansible이 현재 디렉터리의 ansible.cfg를 무시하므로 경로를 명시
export ANSIBLE_CONFIG=$PWD/ansible.cfg

ansible ubuntu -m ping -k                  # -k: SSH 비밀번호 입력
ansible-playbook playbooks/site.yml -k -K  # -K: sudo 비밀번호 입력
```

## 주의

- `proxmox/terraform.tfstate`에 VM 비밀번호가 평문으로 저장된다. git에 올리지 않는다 (`.gitignore` 처리됨).
  state 파일을 잃어버리면 Terraform이 기존 VM을 인식하지 못하므로 따로 백업한다.
- Ubuntu 이미지는 `overwrite = false`라 upstream이 갱신돼도 자동으로 다시 받지 않는다.
  `proxmox/`에서 `terraform apply -replace='proxmox_download_file.ubuntu_2404["n100-01"]'`을 실행하면
  해당 노드의 다운로드 이미지를 갱신한다. 다른 노드도 갱신하려면 노드별로 실행한다.
  `disk.import_from`은 디스크 최초 생성에만 사용되므로 새 이미지는 이후 생성하는 VM에 적용되고,
  기존 VM은 재생성되거나 OS가 갱신되지 않는다.
  기존 VM의 OS 패키지는 VM 내부에서 업데이트한다. 새 이미지로 다시 구축하려면 필요한 데이터를 백업하고,
  해당 VM 리소스를 명시적으로 교체해야 한다 (기존 VM과 디스크가 삭제됨).

## 문제 해결

| 증상 | 원인 / 조치 |
|---|---|
| 이미지 다운로드 실패: content type `import` not allowed | 2-2 단계 미실행 |
| 스니펫 업로드 실패: SSH 인증 오류 | 2-3 단계 확인, 환경변수 비밀번호 확인 |
| apply가 agent 대기에서 멈춤 (최대 15분) | VM 콘솔에서 cloud-init 진행 확인: `cloud-init status --long` |
| `ssh wjh2012@...` 비밀번호 거부 | vendor-data의 `ssh_pwauth` 적용 확인: `sudo cloud-init query vendordata` |
| `ansible.cfg` 설정이 적용 안 됨 | `ANSIBLE_CONFIG` 환경변수 설정 확인 |
