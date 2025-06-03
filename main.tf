terraform {
  required_version = ">= 1.4.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.51.0"
    }
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "< 3.1"
    }
  }
}

variable "pool" {
  description = "Slurm pool of compute nodes"
  default = []
}

variable "TFC_WORKSPACE_NAME" {
  type = string
}
variable "tfe_token" {
  type = string
  default = ""
}
variable "cloud_name" {
  type = string
  default = ""
}
variable "eyaml_key" { }
variable "prometheus_password" {
  type = string
  default = ""
}
variable "suffix" {
  type = string
  default = ""
}
data "tfe_workspace" "test" {
  name         = var.TFC_WORKSPACE_NAME
  organization = "CalculQuebec"
}


module "openstack" {
  source         = "git::https://github.com/ComputeCanada/magic_castle.git//openstack?ref=14.3.0"
  config_git_url = "https://github.com/ComputeCanada/puppet-magic_castle.git"
  config_version = "14.3.0"

  cluster_name = "edu${var.suffix}"
  domain       = "calculquebec.cloud"
  image        = "AlmaLinux-9"

  instances = {
    mgmt   = { type = "p4-7.5gb", tags = ["puppet", "mgmt", "nfs"], count = 1, disk_size=100}
    login  = { type = "p4-7.5gb", tags = ["login", "public", "proxy", "loginedx"], count = 1}
    node   = { type = "c2-7.5gb", tags = ["node"], count = 1 }
    nodepool   = { type = "c2-7.5gb", tags = ["node", "pool"], count = 5 }
    edx = { type = "c8-60gb", tags = ["edx"], count = 1, disk_size = 500 }
  }

  # var.pool is managed by Slurm through Terraform REST API.
  # To let Slurm manage a type of nodes, add "pool" to its tag list.
  # When using Terraform CLI, this parameter is ignored.
  # Refer to Magic Castle Documentation - Enable Magic Castle Autoscaling
  pool = var.pool

  volumes = {
        nfs = {
          home     = { size = 100, type = "volumes-ssd"  }
          project  = { size = 100, type = "volumes-ec"  }
          scratch  = { size = 100, type = "volumes-ec"  }
        }
  }

  public_keys = compact(concat(split("\n", file("sshkeys.pub")), ))

  nb_users = 1
  # Shared password, randomly chosen if blank
  guest_passwd = ""
  hieradata = yamlencode(merge(
  {
    "profile::slurm::controller::tfe_workspace" = data.tfe_workspace.test.id
    "profile::slurm::controller::tfe_token" =  var.tfe_token
    "suffix" = var.suffix
    "cluster_name" = "edu${var.suffix}"
    "prometheus_password" = var.prometheus_password
    "cloud_name" = var.cloud_name
  },
  yamldecode(file("config.yaml")),
  ))

  hieradata_dir = "hieradata${var.suffix}"
  software_stack = "computecanada"
  eyaml_key = base64decode(var.eyaml_key)

  puppetfile = file("Puppetfile")
}

output "accounts" {
  value = module.openstack.accounts
}

output "public_ip" {
  value = module.openstack.public_ip
}

## Uncomment to register your domain name with CloudFlare
module "dns" {
   source           = "git::https://github.com/ComputeCanada/magic_castle.git//dns/cloudflare?ref=14.1.2"
   name             = module.openstack.cluster_name
   domain           = module.openstack.domain
   public_instances = module.openstack.public_instances
   vhosts           = ["*.edx", "edx", "ipa", "jupyter", "mokey", "explore"]
}

## Uncomment to register your domain name with Google Cloud
# module "dns" {
#   source           = "./dns/gcloud"
#   project          = "your-project-id"
#   zone_name        = "you-zone-name"
#   name             = module.openstack.cluster_name
#   domain           = module.openstack.domain
#   bastions         = module.openstack.bastions
#   public_instances = module.openstack.public_instances
#   ssh_private_key  = module.openstack.ssh_private_key
#   sudoer_username  = module.openstack.accounts.sudoer.username
# }

# output "hostnames" {
#   value = module.dns.hostnames
# }
