# Highly Available Web Architecture on AWS

A highly available, auto-healing web application on AWS (region `ap-south-1`, Mumbai), built in four phases: manually in the console, then as Infrastructure as Code with Terraform, then with a CI pipeline on GitHub Actions.

**Stack:** VPC · Application Load Balancer · Auto Scaling Group · EC2 (Amazon Linux 2023) · RDS MySQL · Secrets Manager · IAM · Terraform · GitHub Actions · Flask

---

## Architecture

```
                         Internet
                            |
                   [ Internet Gateway ]
                            |
              +-------------+-------------+
              |   Application Load Balancer   (HTTP :80)
              +------+--------------+-----+
                     |              |
        Public subnet 1a      Public subnet 1b
        +--------------+      +--------------+
        |  EC2 (Flask) |      |  EC2 (Flask) |   <- Auto Scaling Group
        +------+-------+      +------+-------+      min 2 / desired 2 / max 4
               |                     |
        Private subnet 1a     Private subnet 1b
        +--------------------------------------+
        |   RDS MySQL (DB subnet group)        |
        |   master password in Secrets Manager |
        +--------------------------------------+
```

| Component | Details |
|---|---|
| VPC | 2 public + 2 private subnets across 2 Availability Zones, Internet Gateway, route tables |
| Load balancer | Internet-facing ALB, HTTP listener on port 80, target group with health checks |
| Compute | Auto Scaling Group (min 2, desired 2, max 4) using a Launch Template, `t3.micro`, Amazon Linux 2023 |
| Application | Small Flask app on port 80 that shows the instance ID and Availability Zone serving the request |
| Database | RDS MySQL 8.0 (`db.t3.micro`) in private subnets, only reachable from the web security group |
| Secrets | RDS master password managed by AWS Secrets Manager (no password in code or state files) |
| IAM | Instance role and profile allowing instances to read the DB secret |
| Security groups | ALB (public :80) → web (from ALB only) → DB (from web only) |

---

## Phases

### Phase 1: Manual build (AWS Console)
Built the whole stack by hand to understand each service: VPC and subnets, security groups, ALB with target group, Launch Template, Auto Scaling Group and RDS. Verified that traffic reaches the instances through the ALB and that targets turn healthy.

### Phase 2: Infrastructure as Code (Terraform)
Recreated the same architecture in a single `main.tf`, so the whole environment can be created with `terraform apply` and removed with `terraform destroy`.

### Phase 3: CI with GitHub Actions
A **Terraform CI** workflow runs on every push and pull request (formatting and validation checks), so broken Terraform is caught before it reaches `main`.

### Phase 4: Hardening and improvements
- AMI is no longer hardcoded: the Launch Template reads the latest Amazon Linux 2023 AMI from an **SSM public parameter**.
- App uses **IMDSv2** (token-based metadata) to show the real instance ID and AZ.
- RDS uses a **Secrets Manager managed master password** (`manage_master_user_password = true`) instead of a plain password.
- Rolling **Instance Refresh** to replace instances with zero downtime.

---

## Screenshots

> Replace the file names below with your own screenshot files in the `screenshots/` folder.

| What it shows | Screenshot |
|---|---|
| App served from AZ `ap-south-1a` | `screenshots/app-az-1a.png` |
| App served from AZ `ap-south-1b` | `screenshots/app-az-1b.png` |
| Target group: both targets healthy | `screenshots/targets-healthy.png` |
| Auto Scaling Group details | `screenshots/asg-details.png` |
| Instance refresh: Successful | `screenshots/instance-refresh.png` |
| EC2 instances in two AZs | `screenshots/ec2-instances.png` |
| RDS: master credentials managed by Secrets Manager | `screenshots/rds-secret.png` |
| `terraform apply` complete | `screenshots/terraform-apply.png` |

![App on AZ 1a](screenshots/app-az-1a.png)
![App on AZ 1b](screenshots/app-az-1b.png)

---

## How high availability works here

- **Two Availability Zones:** instances are spread over two AZs, so one AZ failing does not take the site down.
- **Health checks:** the ALB only sends traffic to targets that pass the health check.
- **Self-healing:** the Auto Scaling Group keeps the desired number of instances and launches a replacement if one is terminated or becomes unhealthy.
- **Rolling replacement:** during Instance Refresh (50% minimum healthy), old instances drained while new ones came up, and the site stayed available.

---

## Deploy it self

**Prerequisites:** AWS account, AWS CLI configured, Terraform installed.

```bash
git clone https://github.com/SamirPathan8124/aws-ha-architecture-project.git
cd aws-ha-architecture-project

terraform init
terraform plan
terraform apply
```

Open the ALB DNS name (shown in the EC2 console under Load Balancers) in a browser using **`http://`**. Reload a few times; the instance ID and AZ change as the ALB balances traffic.

### Tear down (important, to avoid charges)

```bash
terraform destroy
```

---

## Issues I ran into and how I fixed them

| Problem | Cause | Fix |
|---|---|---|
| Terraform "No changes" after editing AMI | I was editing on the `main` branch on GitHub, but working in a different branch locally | Merged `origin/main` into my branch and edited the right file |
| `Invalid index` on the IAM policy | Policy referenced the RDS managed secret before it existed | Applied the RDS change first with `-target`, then did the full apply |
| Targets unhealthy after changing health check to `/health` | The app had no `/health` route | Set the health check path back to `/` |
| App showed `Instance ID: Local`, `AZ: Unknown` | Amazon Linux 2023 requires **IMDSv2**; plain metadata requests fail | Rewrote the app to fetch a session token first |
| User-data script failed in under a second | `#!/bin/bash` was indented inside the Terraform heredoc, so it was not the first characters of the script | Aligned the shebang to the heredoc's base indentation |
| `yum`/package behaviour differs from Amazon Linux 2 | Different OS release | Verified the user-data on AL2023 using the instance system log |

---

## What I learned

- Designing a multi-AZ architecture and why each layer sits in a public or private subnet.
- Terraform workflow: plan before apply, targeted applies, reading plan output for `replace` vs `update in-place`.
- Why metadata service versions matter (IMDSv2) and how to debug boot-time scripts from the EC2 system log.
- Handling secrets properly with Secrets Manager and IAM instead of storing passwords in code.
- Safe rollouts with Auto Scaling Instance Refresh.

---

## Cost note

ALB, RDS and Secrets Manager are not fully covered by the AWS Free Tier. Run `terraform destroy` when you finish testing.

## Possible next steps

- HTTPS with ACM and a custom domain (Route 53)
- RDS Multi-AZ standby for database failover
- Auto Scaling policies based on CPU
- `terraform apply` in CI with remote state (S3 + DynamoDB lock)
- CloudWatch dashboards and alarms
