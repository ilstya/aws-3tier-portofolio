# AWS 3-Tier Portfolio

Highly available 3-tier architecture on AWS, built entirely with Terraform. A GitHub Actions pipeline checks every change and authenticates to AWS through OIDC, so the repository holds no access keys.

## Status
- [x] Phase 1: Networking (VPC, 2 AZ, public/app/db subnets, IGW, NAT)
- [x] Phase 2: Security groups, ALB, Auto Scaling (Flask app)
- [x] Phase 2b: RDS MySQL with Secrets Manager
- [x] Phase 3a: CloudWatch alarms and SNS email notifications
- [x] Phase 3b: GitHub Actions CI with OIDC (no access keys)
- [ ] Phase 3c: HTTPS with ACM and Route 53 (optional, needs a domain)
- [x] Phase 4: High availability test (2 instances across 2 AZ, RDS Multi-AZ)

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

## CI/CD (GitHub Actions with OIDC)
- Workflow runs on every pull request and push to main: `terraform fmt -check`, `init`, `validate`, `plan`
- GitHub authenticates to AWS through OIDC, so there are no long-lived access keys in the repository or in GitHub secrets
- The IAM role trust policy only accepts tokens from this repository (pull requests and the main branch)
- The role has ReadOnlyAccess only, and the pipeline never runs `apply`, so a pipeline mistake cannot create or delete resources
- The OIDC provider and role live in `terraform/bootstrap`, separate from `envs/dev`, so they survive a `terraform destroy` of the environment

![GitHub Actions run](docs/github-actions-ci.png)
![OIDC role assumed](docs/github-oidc-assume-role.png)

## High availability test
The environment was tested twice: first with a single app instance, then with 2 instances across 2 AZ and a Multi-AZ database. Both tests used `curl` in a polling loop against the load balancer.

### Baseline: 1 instance
I terminated the only running instance while polling the ALB health endpoint every 15 seconds.

- Before: Hello from ip-10-0-10-94
- During: 503 then 502 responses
- After: health check OK again, served by a new instance (ip-10-0-10-57)
- Visible disruption: at least 46 seconds, and every request failed until Auto Scaling replaced the instance

![Failover test with 1 instance](docs/failover-test.png)

### Improved: 2 instances across 2 AZ
Auto Scaling was changed to a minimum of 2 instances. Responses alternate between the two hosts, one in each AZ (`ip-10-0-10-122` and `ip-10-0-11-37`).

![Two targets healthy](docs/ha-targets.png)

I then terminated one instance while polling the root endpoint every 5 seconds.

- 09:39:09 to 09:39:51: requests alternate between both hosts
- 09:39:56: one 502 response
- 09:40:01: one request timed out
- From 09:40:11: all requests are served by the surviving instance, while Auto Scaling launches a replacement

Only 2 polls failed, against every poll failing in the single-instance test. Note that the two tests used different polling intervals (15 s on `/health` versus 5 s on `/`), so treat the comparison as indicative, not exact.

![Failover test with 2 instances](docs/ha-failover-test.png)

### Database failover (RDS Multi-AZ)
RDS was switched to Multi-AZ, with the primary in ap-southeast-1a and the standby in ap-southeast-1b.

![RDS Multi-AZ](docs/rds-multi-az.png)

I forced a failover with `aws rds reboot-db-instance --force-failover` while polling `/db` and `/health`.

- 09:53:12: `/db` connected
- 09:53:20: one `OperationalError` from `/db`
- 09:53:28: `/db` connected again
- `/health` stayed OK during the failover. It does not query the database, so the load balancer keeps healthy app instances instead of replacing them during a DB event.

![RDS failover test](docs/rds-failover-test.png)

## Tech
Terraform, AWS (VPC, EC2, ALB, Auto Scaling, RDS, Secrets Manager, IAM, CloudWatch, SNS), Python Flask, GitHub Actions (OIDC)

## Project structure
```
terraform/
  bootstrap/ (OIDC provider and CI role)
  modules/ (vpc, security, web, db, monitoring)
  envs/dev/
app/app.py
docs/
.github/workflows/terraform.yml
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
Use `http://`, not `https://`: the load balancer only has an HTTP listener until Phase 3c.

The CI role in `terraform/bootstrap` is applied once and kept, since it costs nothing.

## Design decisions
- Single NAT Gateway in dev to reduce cost; production would use one per AZ.
- DB subnets have no internet route; the database is reachable only from the app tier.
- Passwords are managed by Secrets Manager, so no credentials live in the repository.
- `/health` does not touch the database, so a DB outage does not make the load balancer kill healthy app instances.
- Single-AZ RDS and a single app instance are the default for cheap experiments; the HA test raises them to Multi-AZ and 2 instances.
- Terraform state in S3 with versioning and native locking.
- Modular layout (vpc, security, web, db, monitoring) so each tier can change independently.
- Sensitive values such as the alert email live in an uncommitted tfvars file.
- CI is plan-only on purpose: apply is manual because the full stack costs money while running.
- CI uses OIDC with a read-only role scoped to this repository instead of stored access keys.

## Troubleshooting notes
- First `apply` failed on the Auto Scaling Group with an access denied error for the service-linked role. This was a one-time delay while AWS created the role in a new account; running `apply` again fixed it.
- Testing with `https://` timed out because the ALB only listens on port 80.
- The GitHub Actions run failed until the OIDC provider and role from `terraform/bootstrap` had been applied.

## Cost note
NAT Gateway, ALB and RDS are billed hourly. Rough estimates: about US$2.5-3 per day for the single-instance stack and about US$4-5 per day with 2 instances and Multi-AZ RDS. The environment is destroyed after each session.
