# AWS High Availability Architecture

A highly available web application on AWS, built first by hand in the console, then rebuilt with Terraform and deployed through a GitHub Actions pipeline. I tested it by terminating a server while the site stayed up.

> Built as a learning project in `ap-south-1` (Mumbai). Resources were destroyed after testing to avoid cost.

**Stack:** AWS (VPC, ALB, Auto Scaling, EC2, RDS, IAM, SSM, CloudWatch) · Terraform · GitHub Actions · Flask

---

## Architecture

```
                    Internet
                       |
                       v
     Application Load Balancer  (public subnets, 2 AZs)   <- alb-sg
                       |
                       v
     Auto Scaling Group: 2-4 x EC2 t3.micro (2 AZs)       <- web-sg
                       |
                       v
     RDS MySQL  (private subnets, no route to internet)   <- db-sg
```

| Layer | Service | Details |
| --- | --- | --- |
| Network | VPC | `10.0.0.0/16`, public and private subnets across 2 AZs |
| Load balancing | ALB + Target Group | Public subnets, health check on `/health` |
| Compute | Launch Template + Auto Scaling Group | 2-4 EC2 instances, Amazon Linux 2023 (AMI from SSM Parameter Store) |
| Database | RDS MySQL | Private subnets, master password managed by RDS in Secrets Manager |
| Monitoring | CloudWatch | EC2, ALB and ASG metrics |
| Access | IAM + SSM Session Manager | MFA on root account, no SSH keys |

Each web server shows its own private IP, so refreshing the ALB URL shows traffic being spread across both servers.

---

## Security design

Traffic is allowed through a chain of security groups, so each layer only accepts traffic from the layer in front of it:

1. `alb-sg`: HTTP 80 from anywhere (`0.0.0.0/0`)
2. `web-sg`: HTTP 80 **only** from `alb-sg`
3. `db-sg`: MySQL 3306 **only** from `web-sg`

Also:

- **No SSH port is open** on any server. I used AWS Systems Manager Session Manager for access.
- **The database is in private subnets** with no route to an internet gateway.
- **No password in code.** The database master password is managed by RDS through Secrets Manager.
- **MFA** is enabled on the root account.

---

## Phase 1: Console build and failover test

I built everything manually in the console first to understand how each piece connects.

**Failover test**

1. Opened the ALB URL and refreshed to confirm traffic was going to both servers.
2. Terminated one EC2 instance on purpose.
3. The site kept working because the ALB stopped sending traffic to the terminated instance and used the healthy one.
4. The Auto Scaling Group launched a replacement instance automatically.

| Event | Time | What happened |
| --- | --- | --- |
| Instance terminated | 06:02 | Manual termination for testing |
| Replacement instance running | 06:04 | Auto Scaling Group reacted to the failed health check |
| Both targets healthy again | 06:07 | Verified in the ALB target group |

**Screenshots**

| | |
| --- | --- |
| ![Both targets healthy](screenshots/Screenshot%202026-10-04%20181112.png) | ![ASG activity after termination](screenshots/Screenshot%202026-10-04%20181013.png) |
| Both targets healthy in the target group | Auto Scaling Group activity after termination |
| ![Response from server 1a](screenshots/Screenshot%202026-10-04%20180751.png) | ![Response from server 1b](screenshots/Screenshot%202026-10-04%20174720.png) |
| Response from the server in AZ 1a | Response from the server in AZ 1b |
| ![Security group rules](screenshots/Screenshot%202026-10-04%20192123.png) | |

---

## Problems I hit and how I fixed them

**502 Bad Gateway from the ALB**

- **Cause:** the instances had no route to the internet, so they could not download packages and start the web server. The ALB health checks failed and it had nothing healthy to send traffic to.
- **Fix:** placed the instances in public subnets with auto-assign public IP enabled. Their security group still accepts traffic only from the ALB.
- **Learning:** ALB health checks depend on correct routing and on the target actually returning the expected response code.

**Hard-coded database password in the user-data script**

- **Cause:** I left a placeholder password in plain text in the user-data script.
- **Fix:** removed it and let RDS manage the master password in Secrets Manager.
- **Learning:** secrets never belong in code or user-data scripts.

---

## Phase 2: Infrastructure as Code (Terraform)

The same architecture is created with Terraform in `main.tf`: VPC and subnets, security groups, ALB and target group, launch template, Auto Scaling Group, IAM role for SSM, and RDS.

```bash
terraform init      # download providers and set up the remote backend
terraform plan      # preview what will change
terraform apply     # create the infrastructure (needs approval)
terraform destroy   # clean up when done
```

---

## Phase 3: CI/CD pipeline (GitHub Actions)

- **Trigger:** a push to `main` automatically runs `terraform plan`.
- **Approval:** a manual review is required before `terraform apply` runs.
- **State management:** remote state in an S3 bucket with a DynamoDB table for state locking, so two runs can never change the same infrastructure at once.

---

## Design decisions and trade-offs

- **No NAT Gateway.** It costs money every hour and is not covered by free credits. The instances sit in public subnets, but their security group only accepts traffic from the load balancer. In production I would use private subnets with one NAT Gateway per AZ.
- **RDS is Single-AZ.** The free plan did not allow Multi-AZ. In production I would enable Multi-AZ for automatic database failover.
- **Resources were destroyed after testing** to keep the cost close to zero.

---

## What this project covers

VPC design and routing, security group chaining, load balancing, Auto Scaling and health checks, private database placement, secrets management, Terraform with remote state, CI/CD with GitHub Actions, cost awareness, and troubleshooting.

---

## Next steps

- Move the instances to private subnets behind NAT Gateways
- Enable RDS Multi-AZ
- Add CloudWatch alarms with notifications
- Record a short demo of the Terraform-built stack

---

## Repo structure

```
.
├── README.md
├── main.tf
├── .gitignore
├── .terraform.lock.hcl
├── .github/workflows/     # GitHub Actions pipeline
├── scripts/user-data.sh   # EC2 bootstrap script
└── screenshots/           # Proof of the failover test
```

---

## About

Built by **Samir Pathan** as a hands-on portfolio project to practice cloud infrastructure and high availability on AWS.

**Certifications:** Google Cloud Cybersecurity Professional · AWS Generative AI and AI Agents with Amazon Bedrock · Designing Hybrid and Multicloud Architectures · Cloud Native, Microservices, Containers, DevOps and Agile

**LinkedIn:** [samir-pathan-218b84239](https://www.linkedin.com/in/samir-pathan-218b84239)
