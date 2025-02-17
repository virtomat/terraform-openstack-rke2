terraform {
  required_version = ">= 1.3.3"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "1.49.0"
    }
  }
}
