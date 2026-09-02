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
variable "support_email" {
  type = string
  default = ""
}
variable "gitlab_token" {
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
        caddy = "ha1-2gb"
        jupyter = "ha1-2gb"
        cip101 = "c2-7.5gb"
        node = "c2-7.5gb"
        edx = "ha16-60gb"
        metrix = "ha1-1.25gb"
      }
      test = {
        mgmt = "c1-3.75gb"
        puppet = "c1-3.75gb"
        login = "c1-3.75gb"
        caddy = "c1-3.75gb"
        jupyter = "c1-3.75gb"
        cip101 = "c2-7.5gb"
        node = "c2-7.5gb"
        edx = "c8-60gb"
        metrix = "c1-3.75gb"
      }
      dev = {
        mgmt = "p4-7.5gb"
        puppet = "p2-3.75gb"
        login = "p2-3.75gb"
        caddy = "p2-3.75gb"
        jupyter = "p2-3.75gb"
        cip101 = "c2-7.5gb"
        node = "c2-7.5gb"
        edx = "c8-60gb"
        metrix = "p2-3.75gb"
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
    dev = {
        nfs = {
          home     = { size = 100, quota = local.user_quotas.home, mkfs_options = "-K", enable_resize = true }
          project  = { size = 100, quota = local.user_quotas.project, mkfs_options = "-K", enable_resize = true }
          scratch  = { size = 100, quota = local.user_quotas.scratch, mkfs_options = "-K", enable_resize = true  }
        }
    }
  }
  image = "snapshot-cpunode-MC16-A9.8-1"
}

module "openstack" {
  source         = "git::https://github.com/computecanada/magic_castle.git//openstack?ref=2dace5d"
  config_git_url = "https://github.com/computecanada/puppet-magic_castle.git"
  config_version = "7e03ce0"

  cluster_name = "evolo${var.suffix}"
  domain       = "calculquebec.cloud"
  image        = "AlmaLinux-9"

  instances = {
    mgmt   = { type = local.instances_type_map[var.config_type].mgmt, tags = ["mgmt", "nfs", "mgmt_extra", "allcq"], count = 1, disk_size=100 }
    puppet = { type = local.instances_type_map[var.config_type].puppet, tags = ["puppet", "allcq"], count = 1 }
    login  = { type = local.instances_type_map[var.config_type].login, tags = ["login", "public", "allcq"], count = 1}
    caddy = { type = local.instances_type_map[var.config_type].caddy, tags = ["public", "proxy", "allcq"], count = 1}
    jupyter = { type = local.instances_type_map[var.config_type].jupyter, tags = ["jupyterhub", "allcq"], count = 1}
    cip101- = { type = local.instances_type_map[var.config_type].cip101, tags = ["node", "pool", "allcq"], feature = ["cip101"], image = local.image, count = 5 }
    node   = { type = local.instances_type_map[var.config_type].node, tags = ["node", "allcq"], count = 0 }
    nodepool   = { type = local.instances_type_map[var.config_type].node, tags = ["node", "pool", "allcq"], image = local.image, count = 5 }
    evolo = { type = local.instances_type_map[var.config_type].login, tags = ["internal_login", "allcq"], count = 1 }
    edx = { type = local.instances_type_map[var.config_type].edx, tags = ["edx", "allcq"], count = 1, disk_size = 500 }
    metrix = { type = local.instances_type_map[var.config_type].metrix, tags = ["metrix", "allcq"], count = 1 }
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
    "cluster_purpose" = "evolo"
    "gitlab_token" = var.gitlab_token
  },
  yamldecode(file("config.yaml")),
  ))

  hieradata_dir = "hieradata${var.suffix}"
  software_stack = "alliance"
  eyaml_key = base64decode(var.eyaml_key)

  subnet_id = "${var.subnet_id}"
  os_ext_network = "${var.os_ext_network}"

  puppetfile = file("Puppetfile")
  puppet_conf = [ { key = "runtimeout", value = "2h" } ]
}

output "accounts" {
  value = module.openstack.accounts
}

output "public_ip" {
  value = module.openstack.public_ip
}

terraform {
  required_providers {
    gitlab = {
      source = "gitlabhq/gitlab"
    }
    prettyjson = {
      source = "graysievert/prettyjson"
    }
  }
}

locals {
  assets = [
    for host in keys(module.openstack.assets): {
        host = {
          "name" = "${host}.int.${module.openstack.cluster_name}.${module.openstack.domain}",
          "id"   = "CQ/${host}.int.${module.openstack.cluster_name}.${module.openstack.domain}"
          "uuid" = module.openstack.assets[host].uuid,
          "ip"   = compact([module.openstack.assets[host].local_ip, try(module.openstack.assets[host].public_ip, "")]),
          "exposure" = coalesce(
            contains(module.openstack.assets[host].tags, "login") ? "login" : "",
            contains(module.openstack.assets[host].tags, "proxy") ? "portal" : "",
	    contains(module.openstack.assets[host].tags, "node") ? "node" : "",
            "infra"
          ),
          "type" = "virtual",
        },
        service = {
          "name" = module.openstack.cluster_name,
          "state" = "production",
          "type" = "Magic castle cluster for evolo",
        },
        location = {
          "site" = "${var.cloud_name} cloud"
        },
        user = {
          "email" = var.support_email
        },
      }
    ]
}
output "assets" {
  value = local.assets
}

resource "gitlab_repository_file" "assets_file" {
  project = "calculquebec/formation-assets"
  file_path = "evolo/${module.openstack.cluster_name}/assets/${module.openstack.cluster_name}-assets.json"
  branch = "main"
  encoding = "text"
  content = provider::prettyjson::jsonprettyprint(jsonencode(local.assets))
  author_email = var.support_email
  author_name = "Terraform"
  commit_message = "Automatic update of assets"
}
## Uncomment to register your domain name with CloudFlare
module "dns" {
   source           = "git::https://github.com/computecanada/magic_castle.git//dns/cloudflare?ref=4ae5ab9"
   name             = module.openstack.cluster_name
   domain           = module.openstack.domain
   public_instances = module.openstack.public_instances
   domain_tag       = "proxy"
   vhosts           = ["*.edx", "edx", "ipa", "jupyter", "mokey", "explore", "metrix"]
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
