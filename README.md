# AWS 3-Tier Portfolio

Highly available 3-tier architecture on AWS, built with Terraform.

## Status
- [x] Phase 1: Networking (VPC, 2 AZ, public/app/db subnets, IGW, NAT)
- [x] Phase 2: Security groups, ALB, Auto Scaling (Flask app)
- [ ] Phase 2b: RDS MySQL with Secrets Manager
- [ ] Phase 3: HTTPS, CloudWatch, SNS, GitHub Actions (OIDC)
- [ ] Phase 4: Multi-instance failover test and cost estimate

## Architecture
- Region: ap-southeast-1 (Singapore)
- VPC 10.0.0.0/16 across 2 Availability Zones
- 2 public, 2 private app, and 2 private DB subnets
- Internet Gateway for public subnets, single NAT Gateway for app subnets
- Application Load Balancer (public) forwards to Auto Scaling Group (private subnets)
- Layered security groups: ALB (80 from internet) -> App (8080 from ALB only) -> DB (3306 from App only)
- EC2 instances use an IAM role with SSM access, IMDSv2 enforced, no public IPs

![VPC resource map](docs/vpc-resource-map.png)
![Subnets](docs/subnets.png)
![Auto Scaling group healthy](docs/asg-healthy.png)

## Failover test (1 instance)
I terminated the only running instance while polling the ALB health endpoint.

- Before: Hello from ip-10-0-10-94
- During: 503 then 502 responses
- After: health check OK again, served by a new instance (ip-10-0-10-57)
- Visible disruption: about 1 minute until Auto Scaling replaced the instance

With a single instance there is a short outage. Phase 4 repeats this test with a minimum of 2 instances across 2 AZs.

![Failover test](docs/failover-test.png)

## Tech
Terraform, AWS (VPC, EC2, ALB, Auto Scaling, IAM), Python Flask, GitHub Actions

## Deploy
```
cd terraform/envs/dev
terraform init
terraform plan
terraform apply
terraform destroy   # always destroy after use to avoid NAT Gateway and ALB cost
```

## Design decisions
- Single NAT Gateway in dev to reduce cost; production would use one per AZ.
- DB subnets have no internet route.
- App instances have no public IPs and accept traffic only from the ALB security group.
- Terraform state in S3 with versioning and native locking.
- Modules: vpc, security, web.

## Cost note
NAT Gateway and ALB are billed hourly (roughly US$2 per day for the full stack). The environment is destroyed after each session.
