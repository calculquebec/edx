terraform {
  required_version = ">= 1.4.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.38.0"
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
data "tfe_workspace" "test" {
  name         = var.TFC_WORKSPACE_NAME
  organization = "CalculQuebec"
}


module "openstack" {
  source         = "git::https://github.com/ComputeCanada/magic_castle.git//openstack?ref=main"
  config_git_url = "https://github.com/ComputeCanada/puppet-magic_castle.git"
  config_version = "main"

  cluster_name = "edx"
  domain       = "calculquebec.cloud"
  image        = "AlmaLinux-9"

  instances = {
    mgmt   = { type = "p4-7.5gb", tags = ["puppet", "mgmt", "nfs"], count = 1, disk_size=100}
    login  = { type = "c8-60gb", tags = ["login", "public", "proxy"], count = 1}
    node   = { type = "c8-60gb", tags = ["node" ], count = 1 }
    edx = { type = "c8-60gb", tags = ["edx"], count = 1 }
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

  generate_ssh_key = true
  public_keys = compact(concat(split("\n", file("sshkeys.pub")), ))

  nb_users = 1
  # Shared password, randomly chosen if blank
  guest_passwd = ""
  hieradata = yamlencode(merge(
  		{
			"profile::slurm::controller::tfe_workspace" = data.tfe_workspace.test.id
		},
	))
  hieradata_dir = "hieradata"
  software_stack = "computecanada"

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
   source           = "git::https://github.com/ComputeCanada/magic_castle.git//dns/cloudflare?ref=main"
   name             = module.openstack.cluster_name
   domain           = module.openstack.domain
   bastions         = module.openstack.bastions
   public_instances = module.openstack.public_instances
   ssh_private_key  = module.openstack.ssh_private_key
   sudoer_username  = module.openstack.accounts.sudoer.username
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
