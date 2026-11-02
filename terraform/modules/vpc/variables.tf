variable "name" { type = string }
variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }
variable "app_subnet_cidrs" { type = list(string) }
variable "db_subnet_cidrs" { type = list(string) }
