\# AWS 3-Tier Portfolio



Highly available 3-tier architecture on AWS, built with Terraform.



\## Status

\- \[x] Phase 1: Networking (VPC, 2 AZ, public/app/db subnets, IGW, NAT)

\- \[ ] Phase 2: Security groups, ALB, Auto Scaling, RDS

\- \[ ] Phase 3: HTTPS, CloudWatch, SNS, GitHub Actions (OIDC)

\- \[ ] Phase 4: Failover test and cost estimate



\## Architecture (Phase 1)

\- Region: ap-southeast-1 (Singapore)

\- VPC 10.0.0.0/16 across 2 Availability Zones

\- 2 public, 2 private app, and 2 private DB subnets

\- Internet Gateway for public subnets, single NAT Gateway for app subnets

\- DB subnets have no internet route



!\[VPC resource map](docs/vpc-resource-map.png)

!\[Subnets](docs/subnets.png)



\## Tech

Terraform, AWS (VPC, EC2, ALB, RDS), GitHub Actions



\## Deploy

```

cd terraform/envs/dev

terraform init

terraform plan

terraform apply

terraform destroy   # always destroy after use to avoid NAT Gateway cost

```



\## Design decisions

\- Single NAT Gateway in dev to reduce cost; production would use one per AZ.

\- DB subnets isolated from the internet.

\- Terraform state in S3 with versioning and native locking.



\## Cost note

NAT Gateway is billed hourly. Environment is destroyed after each session.

