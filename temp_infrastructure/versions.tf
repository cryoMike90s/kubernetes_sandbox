terraform {
  required_version = ">= 1.9"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.7"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5"
    }
  }

  backend "s3" {
    bucket         = "cryo-states"
    region         = "eu-central-1"
    key            = "temp_infrastructure/one_node/terraform.tfstate"
    dynamodb_table = "terraform_state"
    profile        = "terraform-role"
  }
}
