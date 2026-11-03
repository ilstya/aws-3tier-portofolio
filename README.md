# AWS 3-Tier Portfolio

Highly available 3-tier architecture on AWS, built entirely with Terraform.

## Status
- [x] Phase 1: Networking (VPC, 2 AZ, public/app/db subnets, IGW, NAT)
- [x] Phase 2: Security groups, ALB, Auto Scaling (Flask app)
- [x] Phase 2b: RDS MySQL with Secrets Manager
- [x] Phase 3a: CloudWatch alarms and SNS email notifications
- [ ] Phase 3b: GitHub Actions with OIDC (no access keys)
- [ ] Phase 3c: HTTPS with ACM and Route 53 (optional, needs a domain)
- [ ] Phase 4: Multi-instance failover test and cost estimate

## Architecture
- Region: ap-southeast-1 (Singapore)
- VPC 10.0.0.0/16 across 2 Availability Zones
- Web tier: Application Load Balancer in 2 public subnets
- App tier: Auto Scaling Group (Flask on EC2) in 2 private app subnets
- Data tier: RDS MySQL in 2 private DB subnets with no internet route
- Single NAT Gateway gives app instances outbound internet access
- Layered security groups: ALB (80 from internet) -> App (8080 from ALB only) -> DB (3306 from App only)
- EC2 instances have no public IPs, enforce IMDSv2, and are managed through SSM instead of SSH

![VPC resource map](docs/vpc-resource-map.png)
![Subnets](docs/subnets.png)
![Auto Scaling group healthy](docs/asg-healthy.png)

## Database tier (RDS MySQL)
- RDS MySQL in private DB subnets, no public access, encrypted storage
- Master password is generated and stored by AWS Secrets Manager, never written in code
- The app reads the secret at runtime through an IAM role limited to that one secret
- The DB security group accepts port 3306 only from the app security group
- The `/db` endpoint proves the full path: ALB -> EC2 -> Secrets Manager -> RDS

![App connected to RDS](docs/db-connected.png)
![RDS private](docs/rds-private.png)
![Secrets Manager](docs/secrets-manager.png)
![Targets healthy](docs/target-group-healthy.png)

## Monitoring and alerting
- SNS topic with an email subscription receives all alerts
- CloudWatch alarms: unhealthy ALB targets, ALB 5xx errors, high ASG CPU, low RDS free storage
- The unhealthy-targets alarm also notifies on recovery
- Verified end to end by forcing an alarm state and receiving the email

![CloudWatch alarms](docs/cloudwatch-alarms.png)
![Alarm email](docs/alarm-email.png)

## Failover test (1 instance)
I terminated the only running instance while polling the ALB health endpoint.

- Before: Hello from ip-10-0-10-94
- During: 503 then 502 responses
- After: health check OK again, served by a new instance (ip-10-0-10-57)
- Visible disruption: about 1 minute until Auto Scaling replaced the instance

With a single instance there is a short outage. Phase 4 repeats this test with a minimum of 2 instances across 2 AZs.

![Failover test](docs/failover-test.png)

## Tech
Terraform, AWS (VPC, EC2, ALB, Auto Scaling, RDS, Secrets Manager, IAM, CloudWatch, SNS), Python Flask, GitHub Actions

## Project structure
```
terraform/
  modules/ (vpc, security, web, db, monitoring)
  envs/dev/
app/app.py
docs/
```

## Deploy
Create `terraform/envs/dev/terraform.tfvars` (not committed) with your email for alerts:
```
alert_email = "you@example.com"
```
Then run:
```
cd terraform/envs/dev
terraform init
terraform plan
terraform apply
terraform destroy   # always destroy after use to avoid NAT, ALB and RDS cost
```
After apply, confirm the SNS subscription email and test with:
```
curl http://<alb_dns>/health
curl http://<alb_dns>/db
```

## Design decisions
- Single NAT Gateway in dev to reduce cost; production would use one per AZ.
- DB subnets have no internet route; the database is reachable only from the app tier.
- Passwords are managed by Secrets Manager, so no credentials live in the repository.
- `/health` does not touch the database, so a DB outage does not make the load balancer kill healthy app instances.
- RDS is single-AZ in dev to save cost; Multi-AZ is planned for the failover phase.
- Terraform state in S3 with versioning and native locking.
- Modular layout (vpc, security, web, db, monitoring) so each tier can change independently.
- Sensitive values such as the alert email live in an uncommitted tfvars file.

## Cost note
NAT Gateway, ALB and RDS are billed hourly (roughly US$2.5-3 per day for the full stack). The environment is destroyed after each session.
