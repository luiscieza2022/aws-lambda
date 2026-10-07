variable "environment" {
  type        = string
  description = "Entorno de despliegue (dev, qa, prod)"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}