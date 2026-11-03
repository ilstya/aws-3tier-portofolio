variable "name" { type = string }
variable "db_subnet_ids" { type = list(string) }
variable "db_sg_id" { type = string }

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "multi_az" {
  type    = bool
  default = false
}
