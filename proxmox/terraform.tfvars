# VM ID 대역: 300번대 = 테스트, 8000번대 = 기존 템플릿 (Terraform 미관리)
vms = {
  "ubuntu-test-01" = {
    vm_id = 300
    node  = "n100-01"
    ip    = "192.168.45.211/24"
  }
}
