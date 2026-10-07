provider "aws" {
  region = "us-east-1"
}

module "app_qa" {
  source      = "../../modules/app_stack"
  environment = "qa"
}

output "qa_upload_url" {
  value = module.app_qa.api_upload_url
}