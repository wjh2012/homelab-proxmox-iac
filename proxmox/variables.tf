variable "proxmox_endpoint" {
  type    = string
  default = "https://192.168.45.201:8006/"
}

# 노드 이름 → SSH 접속 IP
variable "nodes" {
  type = map(string)
  default = {
    "n100-01" = "192.168.45.201"
    "n100-02" = "192.168.45.202"
  }
}

variable "gateway" {
  type    = string
  default = "192.168.45.1"
}

variable "dns_servers" {
  type    = list(string)
  default = ["192.168.45.1"]
}

variable "vm_username" {
  type    = string
  default = "wjh2012"
}

# 환경변수 TF_VAR_vm_password 로 전달
variable "vm_password" {
  type      = string
  sensitive = true
}

variable "vms" {
  description = "생성할 VM 목록 (키 = VM 이름)"
  type = map(object({
    vm_id  = number
    node   = string
    ip     = string # CIDR 표기, 예: 192.168.45.211/24
    cores  = optional(number, 2)
    memory = optional(number, 4096)
    disk   = optional(number, 32)
  }))
}
