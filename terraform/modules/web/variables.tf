variable "name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "app_subnet_ids" { type = list(string) }
variable "alb_sg_id" { type = string }
variable "app_sg_id" { type = string }
variable "app_code" { type = string }

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "min_size" {
  type    = number
  default = 1
}

variable "desired_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 2
}
