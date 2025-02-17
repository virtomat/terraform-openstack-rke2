locals {
  auth_url = "https://api.pub1.infomaniak.cloud/identity"
  region   = "dc3-a"
  config   = <<EOF
# https://docs.rke2.io/install/install_options/server_config/

etcd-snapshot-schedule-cron: "0 */6 * * *"
etcd-snapshot-retention: 20

control-plane-resource-requests: kube-apiserver-cpu=75m,kube-apiserver-memory=128M,kube-scheduler-cpu=75m,kube-scheduler-memory=128M,kube-controller-manager-cpu=75m,kube-controller-manager-memory=128M,kube-proxy-cpu=75m,kube-proxy-memory=128M,etcd-cpu=75m,etcd-memory=128M,cloud-controller-manager-cpu=75m,cloud-controller-manager-memory=128M
  EOF
}

module "rke2" {
  # source = "zifeo/rke2/openstack"
  source = "./.."

  # must be true for single-server cluster or only on first run for HA cluster 
  bootstrap           = true
  name                = "cluster"
  ssh_public_key_file = "~/.ssh/id_rsa.pub"
  floating_pool       = "ext-floating1"
  # should be restricted to a secure bastion
  rules_ssh_cidr = "0.0.0.0/0"
  rules_k8s_cidr = "0.0.0.0/0"
  # auto load manifest form a folder (https://docs.rke2.io/advanced#auto-deploying-manifests)
  manifests_folder = "./manifests"

  servers = [{
    name = "server"

    flavor_name      = "a2-ram4-disk0"
    image_name       = "Ubuntu 22.04 LTS Jammy Jellyfish"
    system_user      = "ubuntu"
    boot_volume_size = 4

    rke2_version     = "v1.25.5+rke2r2"
    rke2_volume_size = 8
    # https://docs.rke2.io/install/install_options/install_options/#configuration-file
    rke2_config = local.config
  }]

  agents = [
    {
      name        = "pool-a"
      nodes_count = 1

      flavor_name      = "a1-ram2-disk0"
      image_name       = "Ubuntu 22.04 LTS Jammy Jellyfish"
      system_user      = "ubuntu"
      boot_volume_size = 4

      rke2_version     = "v1.25.5+rke2r2"
      rke2_volume_size = 8
    }
  ]

  # enable automatically `kubectl delete node AGENT-NAME` after an agent change
  ff_autoremove_agent = true
  # rewrite kubeconfig
  ff_write_kubeconfig = true
  # deploy etcd backup
  ff_native_backup = true

  identity_endpoint     = local.auth_url
  object_store_endpoint = "s3.pub1.infomaniak.cloud"
}

variable "tenant_name" {
  type = string
}

variable "user_name" {
  type = string
}

variable "password" {
  type = string
}

output "floating_ip" {
  value = module.rke2.external_ip
}

provider "openstack" {
  tenant_name = var.tenant_name
  user_name   = var.user_name
  # checkov:skip=CKV_OPENSTACK_1
  password = var.password
  auth_url = local.auth_url
  region   = local.region
}

terraform {
  required_version = ">= 0.14.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 1.49.0"
    }
  }
}
