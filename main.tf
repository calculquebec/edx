terraform {
  required_version = ">= 1.4.0"
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
variable "config_type" {
  type = string
  default = ""
}
variable "subnet_id" {
  type = string
  default = ""
}
variable "os_ext_network" {
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

locals {
  default_pod = {
    user_quotas_sizes = {
      home = "4g"
      project = "1g"
      scratch = "1g"
    }
    user_quotas_inodes = {
      home = 100000
      project = 100000
      scratch = 100000
    }
  }

  user_quotas = {
    home = {
      bsoft = local.default_pod.user_quotas_sizes.home
      bhard = local.default_pod.user_quotas_sizes.home
      isoft = local.default_pod.user_quotas_inodes.home
      ihard = local.default_pod.user_quotas_inodes.home
    }
    project = {
      bsoft = local.default_pod.user_quotas_sizes.project
      bhard = local.default_pod.user_quotas_sizes.project
      isoft = local.default_pod.user_quotas_inodes.project
      ihard = local.default_pod.user_quotas_inodes.project
    }
    scratch = {
      bsoft = local.default_pod.user_quotas_sizes.scratch
      bhard = local.default_pod.user_quotas_sizes.scratch
      isoft = local.default_pod.user_quotas_inodes.scratch
      ihard = local.default_pod.user_quotas_inodes.scratch
    }
  }

  instances_type_map = {
      prod = {
        mgmt = "ha2-4gb"
	puppet = "ha2-4gb"
        login = "ha1-2gb"
	caddy = "ha1-1.25gb"
        jupyter = "ha1-2gb"
	cip101 = "c1-3.75gb"
	node = "c1-3.75gb"
	edx = "ha16-60gb"
      }
      test = {
        mgmt = "c1-3.75gb"
	puppet = "c1-3.75gb"
        login = "c1-3.75gb"
	caddy = "c1-3.75gb"
        jupyter = "c1-3.75gb"
	cip101 = "c1-3.75gb"
	node = "c1-3.75gb"
	edx = "c8-30gb"
      }
      dev = {
        mgmt = "p2-3.5gb"
	puppet = "p2-3.5gb"
        login = "p2-3.75gb"
	caddy = "p2-3.75gb"
        jupyter = "p2-3.75gb"
	cip101 = "c2-7.5gb"
	node = "c2-7.5gb"
	edx = "c8-60gb"
      }
  }

  volumes = {
    prod = {
        nfs = {
          home     = { size = 100, quota = local.user_quotas.home, mkfs_options = "-K", enable_resize = true }
          project  = { size = 100, quota = local.user_quotas.project, mkfs_options = "-K", enable_resize = true }
          scratch  = { size = 100, quota = local.user_quotas.scratch, mkfs_options = "-K", enable_resize = true  }
        }
    }
    test = {
        nfs = {
          home     = { size = 100, quota = local.user_quotas.home, mkfs_options = "-K", enable_resize = true }
          project  = { size = 100, quota = local.user_quotas.project, mkfs_options = "-K", enable_resize = true }
          scratch  = { size = 100, quota = local.user_quotas.scratch, mkfs_options = "-K", enable_resize = true  }
        }
    }
  }
  image = "snapshot-cpunode-2026.1-A9.7"
}

module "openstack" {
  source         = "git::https://github.com/calculquebec/magic_castle_formation.git//openstack?ref=edx"
  config_git_url = "https://github.com/calculquebec/puppet-magic_castle_formation.git"
  config_version = "012a4ba"

  cluster_name = "evolo${var.suffix}"
  domain       = "calculquebec.cloud"
  image        = "AlmaLinux-9"

  instances = {
    mgmt   = { type = local.instances_type_map[var.config_type].mgmt, tags = ["mgmt", "nfs", "mgmt_extra"], count = 1, disk_size=100 }
    puppet = { type = local.instances_type_map[var.config_type].puppet, tags = ["puppet"], count = 1 }
    login  = { type = local.instances_type_map[var.config_type].login, tags = ["login", "public"], count = 1}
    caddy = { type = local.instances_type_map[var.config_type].caddy, tags = ["public", "proxy"], count = 1}
    jupyter = { type = local.instances_type_map[var.config_type].jupyter, tags = ["jupyterhub"], count = 1}
    cip101- = { type = local.instances_type_map[var.config_type].cip101, tags = ["node", "pool"], feature = ["cip101"], image = local.image, count = 5 }
    node   = { type = local.instances_type_map[var.config_type].node, tags = ["node"], count = 0 }
    nodepool   = { type = local.instances_type_map[var.config_type].node, tags = ["node", "pool"], image = local.image, count = 5 }
    evolo = { type = local.instances_type_map[var.config_type].login, tags = ["internal_login"], count = 1 }
    edx = { type = local.instances_type_map[var.config_type].edx, tags = ["edx"], count = 1, disk_size = 500 }
  }

  # var.pool is managed by Slurm through Terraform REST API.
  # To let Slurm manage a type of nodes, add "pool" to its tag list.
  # When using Terraform CLI, this parameter is ignored.
  # Refer to Magic Castle Documentation - Enable Magic Castle Autoscaling
  pool = var.pool

  volumes = local.volumes[var.config_type]

  public_keys = compact(concat(split("\n", file("keys/sshkeys.pub")), ))

  nb_users = 1
  # Shared password, randomly chosen if blank
  guest_passwd = ""
  hieradata = yamlencode(merge(
  {
    "profile::slurm::controller::tfe_workspace" = data.tfe_workspace.test.id
    "profile::slurm::controller::tfe_token" =  var.tfe_token
    "suffix" = var.suffix
    "cluster_name" = "evolo${var.suffix}"
    "prometheus_password" = var.prometheus_password
    "cloud_name" = var.cloud_name
  },
  yamldecode(file("config.yaml")),
  ))

  hieradata_dir = "hieradata${var.suffix}"
  software_stack = "alliance"
  eyaml_key = base64decode(var.eyaml_key)

  subnet_id = "${var.subnet_id}"
  os_ext_network = "${var.os_ext_network}"

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
   source           = "git::https://github.com/calculquebec/magic_castle_formation.git//dns/cloudflare?ref=edx"
   name             = module.openstack.cluster_name
   domain           = module.openstack.domain
   public_instances = module.openstack.public_instances
   domain_tag       = "proxy"
   vhosts           = ["*.edx", "edx", "ipa", "jupyter", "mokey", "explore"]
   dkim_public_key  = file("keys/dkim_public.pem")
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
