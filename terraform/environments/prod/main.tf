provider "aws" {
  region = "us-east-1"
}

module "app_prod" {
  source      = "../../modules/app_stack"
  environment = "prod"
}

output "prod_upload_url" {
  value = module.app_prod.api_upload_url
}