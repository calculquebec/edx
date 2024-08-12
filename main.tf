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
  source         = "git::https://github.com/mboisson/magic_castle.git//openstack?ref=main"
  config_git_url = "https://github.com/mboisson/puppet-magic_castle.git"
  config_version = "main"

  cluster_name = "edx"
  domain       = "calculquebec.cloud"
  image        = "AlmaLinux-9"

  instances = {
    puppet = { type = "p2-3.75gb", tags = ["puppet"], count = 1 }
    mgmt   = { type = "p2-3.75gb", tags = ["mgmt", "nfs"], count = 1, disk_size=100, disk_type = "OS or Database" }
    login  = { type = "c8-60gb", tags = ["login", "public", "worldssh"], count = 1}
    jupyter  = { type = "p1-2gb", tags = ["proxy", "public"], count = 1 }
    #haproxy  = { type = "p1-2gb", tags = ["haproxy"], count = 1 }
    node   = { type = "c8-60gb", tags = ["node" ], count = 4 }
    edx = { type = "c8-60gb", tags = ["edx", "public"], count = 1 }
  }

  # var.pool is managed by Slurm through Terraform REST API.
  # To let Slurm manage a type of nodes, add "pool" to its tag list.
  # When using Terraform CLI, this parameter is ignored.
  # Refer to Magic Castle Documentation - Enable Magic Castle Autoscaling
  pool = var.pool
#  os_floating_ips = {
#    login1 = "206.12.97.59"
#    jupyter1 = "206.12.100.156"
#    cvmfs-client1 = "206.12.95.235"
#    cvmfs-client-dev1 = "206.12.94.16"
#    publisher1 = "206.12.97.173"
#  }

  firewall_rules = {
    ssh      = { "from_port" = 22,    "to_port" = 22,    tag = "login", "protocol" = "tcp", "cidr" = "0.0.0.0/0" },
    worldssh = { "from_port" = 22,    "to_port" = 22,    tag = "worldssh", "protocol" = "tcp", "cidr" = "0.0.0.0/0" },
    http     = { "from_port" = 80,    "to_port" = 80,    tag = "proxy", "protocol" = "tcp", "cidr" = "0.0.0.0/0" },
    https    = { "from_port" = 443,   "to_port" = 443,   tag = "proxy", "protocol" = "tcp", "cidr" = "0.0.0.0/0" },
  }

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
  hieradata_folder_path = "hieradata"
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
   source           = "git::https://github.com/ComputeCanada/magic_castle.git//dns/cloudflare?ref=13.3.1"
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
