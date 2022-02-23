# google_client_config and kubernetes provider must be explicitly specified like the following.
# data "google_client_config" "default" {}

# provider "kubernetes" {
#   host                   = "https://${module.gke.endpoint}"
#   token                  = data.google_client_config.default.access_token
#   cluster_ca_certificate = base64decode(module.gke.ca_certificate)
# }

terraform {
  required_version = ">= 0.13.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "< 5.0, >= 3.83"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "< 5.0, >= 3.45"
    }
  }

  provider_meta "google" {
    module_name = "blueprints/terraform/terraform-google-network/v4.1.0"
  }
}

module "vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 4.0"

    project_id   = "gen3-workspace-1"
    network_name = "dev-gen3-workspace-1-vpc"
    routing_mode = "GLOBAL"

    subnets = [
        {
            subnet_name           = "subnet-01"
            subnet_ip             = "172.27.32.0/20"
            subnet_region         = "us-central1"
            subnet_private_access = "true"
            subnet_flow_logs      = "true"
            subnet_flow_logs_interval = "INTERVAL_10_MIN"
            subnet_flow_logs_sampling = 0.7
            subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
        }
    ]

    secondary_ranges = {
        subnet-01 = [
            {
                range_name    = "kubernetes-pods"
                ip_cidr_range = "10.139.0.0/16"
            },
            {
                range_name    = "kubernetes-services"
                ip_cidr_range = "10.138.128.0/20"
            },
        ]
    }
}

resource "google_compute_instance" "squid" {
  count                   = "1"
  name                    = "proxy-${count.index}"
  machine_type            = "g1-small"
  zone                    = "us-central1-b"
  project                 = "gen3-workspace-1"
  tags                    = ["squid"]
  # metadata_startup_script = file(local.squid_install_script_path)
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }
  scheduling {
    preemptible       = true
    automatic_restart = false
  }
  network_interface {
    network    = module.vpc.network_id
    subnetwork = module.vpc.subnets_ids[0]
    # Assign ephemeral external ip addres
    access_config {
    }
  }
  metadata = {
    test_vm = "true"
  }
  service_account {
    scopes = ["cloud-platform"]
  }
}


module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  project_id                 = "gen3-workspace-1"
  name                       = "occ-workspace-dev-cluster-1"
  region                     = "us-central1"
  zones                      = ["us-central1-b"]
  network                    = module.vpc.network_name
  subnetwork                 = "subnet-01"
  ip_range_pods              = "kubernetes-pods"
  ip_range_services          = "kubernetes-services"
  http_load_balancing        = false
  horizontal_pod_autoscaling = false
  network_policy             = false
  enable_private_endpoint    = true
  enable_private_nodes       = true
  master_ipv4_cidr_block     = "10.0.0.0/28"
  master_authorized_networks = [
    {
      cidr_block = "172.27.32.14/32" 
      display_name = "dev-gen3-workspace-1-vpc"
    },
  ]
  create_service_account     = true
  regional                   = true

  node_pools = [
    {
      name                      = "default-node-pool"
      machine_type              = "e2-medium"
      node_locations            = "us-central1-b"
      min_count                 = 1
      max_count                 = 1
      local_ssd_count           = 0
      disk_size_gb              = 50
      disk_type                 = "pd-standard"
      image_type                = "COS_CONTAINERD"
      auto_repair               = true
      auto_upgrade              = true
      service_account           = "tf-gke-gen3-workspace--sz9k@gen3-workspace-1.iam.gserviceaccount.com"
      preemptible               = true
      initial_node_count        = 1
    },
  ]

  node_pools_oauth_scopes = {
    all = []

    default-node-pool = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  node_pools_labels = {
    all = {}

    default-node-pool = {
      default-node-pool = true
    }
  }

  node_pools_metadata = {
    all = {}

    default-node-pool = {
      node-pool-metadata-custom-value = "my-node-pool"
    }
  }

#   node_pools_taints = {
#     all = []

#     default-node-pool = [
#       {
#         key    = "default-node-pool"
#         value  = true
#         effect = "PREFER_NO_SCHEDULE"
#       },
#     ]
#   }

  node_pools_tags = {
    all = []

    default-node-pool = [
      "default-node-pool",
    ]
  }
}