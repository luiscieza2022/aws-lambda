provider "aws" {
  region = "us-east-1"
}

module "app_dev" {
  source      = "../../modules/app_stack"
  environment = "dev"
}

output "dev_upload_url" {
  value = module.app_dev.api_upload_url
}