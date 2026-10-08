# AWS High Availability Web Architecture

A highly available web application on AWS, built by hand in the console first, then rebuilt as Terraform code and deployed through a GitHub Actions pipeline with a manual approval gate. I tested resilience by terminating a server on purpose while the site stayed online.

> Built as a learning project in `ap-south-1` (Mumbai). All resources were destroyed after testing to avoid cost.

**Tech:** AWS (VPC, ALB, Auto Scaling, EC2, RDS, IAM, SSM, Secrets Manager, CloudWatch) · Terraform · GitHub Actions · Flask

---

## Problem statement

A single server is a single point of failure: if it crashes, the website goes down. This project removes that risk by running the application on multiple servers in different Availability Zones behind a load balancer, with automatic replacement of failed servers.

---

## Architecture

```
                         Internet
                            |
                            v
        Application Load Balancer (public subnets, 2 AZs)   <- alb-sg
                            |
              +-------------+-------------+
              |                           |
              v                           v
        EC2 (AZ 1a)                 EC2 (AZ 1b)             <- web-sg
              \                           /
               +--- Auto Scaling Group ---+
                     (min 2, max 4)
                            |
                            v
              RDS MySQL (private subnets)                   <- db-sg
```

| Layer | Service | Details |
| --- | --- | --- |
| Network | VPC | `10.0.0.0/16`, subnets across 2 Availability Zones |
| Entry point | Application Load Balancer | Public subnets, health check on `/health` |
| Compute | Launch Template + Auto Scaling Group | 2 to 4 `t3.micro` instances, Amazon Linux 2023 (AMI from SSM Parameter Store) |
| Database | RDS MySQL | Private subnets, master password managed by RDS in Secrets Manager |
| Access | IAM role + SSM Session Manager | No SSH keys, no open SSH port |
| Monitoring | CloudWatch | EC2, ALB and ASG metrics |
| IaC and CI/CD | Terraform + GitHub Actions | Remote state in S3 with DynamoDB locking |

Each web server shows its own private IP, so refreshing the load balancer URL shows requests being spread across servers.

---

## Why this architecture is highly available

- **Multiple Availability Zones:** servers run in two separate data centers, so one AZ failing does not take the site down.
- **Load balancer:** the ALB spreads traffic across servers and stops sending requests to any server that fails its health check.
- **Auto Scaling Group:** keeps at least 2 servers running and automatically launches a replacement when one is terminated or unhealthy.
- **Health checks:** the ALB checks `/health` on every server. Failed servers are removed from rotation and replaced.

---

## Security design

Traffic is allowed through a chain of security groups, so each layer only accepts traffic from the layer in front of it:

1. `alb-sg`: HTTP 80 from anywhere (`0.0.0.0/0`)
2. `web-sg`: HTTP 80 **only** from `alb-sg`
3. `db-sg`: MySQL 3306 **only** from `web-sg`

Other measures:

- **No SSH access.** Servers are managed through AWS Systems Manager Session Manager.
- **Private database.** RDS sits in private subnets with no route to an internet gateway.
- **No secrets in code.** The database master password is managed by RDS through Secrets Manager.
- **IAM role for servers** instead of stored credentials.
- **MFA** enabled on the root account.

---

## Terraform and CI/CD

**Terraform** (`main.tf`) creates the whole stack: VPC and subnets, security groups, ALB and target group, launch template, Auto Scaling Group, IAM role for SSM, and RDS.

```bash
terraform init      # download providers, connect to remote state
terraform plan      # preview changes
terraform apply     # create infrastructure (asks for approval)
terraform destroy   # remove everything when done
```

**GitHub Actions pipeline** (`.github/workflows/`):

- A push to `main` runs `terraform plan` automatically.
- A manual approval is required before `terraform apply`.
- State is stored in S3 with a DynamoDB table for locking, so two runs can never change the infrastructure at the same time.

---

## Failure testing

| Test | What I did | Result |
| --- | --- | --- |
| Instance failure | Terminated one EC2 instance manually | The site stayed up on the other server; the ASG launched a replacement; both targets became healthy again |
| Rolling replacement | Ran an Auto Scaling instance refresh | Servers were replaced while the load balancer kept serving traffic |

**Timeline of the instance failure test**

| Event | Time | What happened |
| --- | --- | --- |
| Instance terminated | 06:02 | Manual termination for testing |
| Replacement instance running | 06:04 | Auto Scaling Group reacted to the failed health check |
| Both targets healthy again | 06:07 | Verified in the ALB target group |

### Evidence

**Both targets healthy in the target group**

![Both targets healthy](screenshots/Screenshot%202026-10-04%20181112.png)

**Auto Scaling Group activity after termination**

![ASG activity after termination](screenshots/Screenshot%202026-10-04%20181013.png)

**Response from the server in AZ 1a**

![Response from server 1a](screenshots/Screenshot%202026-10-04%20180751.png)

**Response from the server in AZ 1b**

![Response from server 1b](screenshots/Screenshot%202026-10-04%20174720.png)

**Chained security group rules**

![Security group rules](screenshots/Screenshot%202026-10-04%20192123.png)

---

## Challenges and solutions

**502 Bad Gateway from the ALB**

- **Cause:** the instances had no route to the internet, so they could not download packages and start the web server. Health checks failed and the ALB had nothing healthy to send traffic to.
- **Fix:** placed the instances in public subnets with auto-assign public IP enabled. Their security group still accepts traffic only from the ALB.
- **Learning:** ALB health checks depend on correct routing and on the target returning the expected response code.

**Hard-coded database password in the user-data script**

- **Cause:** I left a placeholder password in plain text in the script.
- **Fix:** removed it and let RDS manage the master password in Secrets Manager.
- **Learning:** secrets never belong in code or user-data scripts.

---

## Cost considerations

- **No NAT Gateway.** It is billed every hour and is not covered by free credits, so I did not use one.
- **`t3.micro` instances** and a small RDS instance keep the cost low.
- **Everything is destroyed after testing** with `terraform destroy`.

---

## Design decisions and limitations

I kept these choices on purpose because this is a low-cost learning project. Here is what I would change in production:

| Current choice | Why | Production change |
| --- | --- | --- |
| Servers in public subnets (locked down by `web-sg`) | A NAT Gateway costs money every hour | Private subnets with a NAT Gateway per AZ |
| RDS is Single-AZ | The free plan did not allow Multi-AZ | Enable Multi-AZ for automatic database failover |
| HTTP only | No domain name for an HTTPS certificate | Route 53 + ACM certificate, redirect HTTP to HTTPS |
| Database not used by the app for data yet | Focus was on infrastructure and its protection | Add a small app that stores data in RDS |

---

## Future improvements

- Move instances to private subnets with NAT Gateways
- Enable RDS Multi-AZ and test failover
- Add HTTPS with ACM and Route 53
- Add CloudWatch alarms with SNS email notifications
- Add a CPU-based Auto Scaling policy and test it
- Record a short demo of the Terraform-built stack

---

## Repo structure

```
.
├── README.md
├── main.tf                 # all infrastructure
├── .gitignore
├── .terraform.lock.hcl
├── .github/workflows/      # GitHub Actions pipeline
├── scripts/user-data.sh    # EC2 bootstrap script
└── screenshots/            # evidence of the failure test
```

---

## About

Built by **Samir Pathan** as a hands-on portfolio project to practice cloud infrastructure and high availability on AWS.

**Certifications:** Google Cloud Cybersecurity Professional · AWS Generative AI and AI Agents with Amazon Bedrock · Designing Hybrid and Multicloud Architectures · Cloud Native, Microservices, Containers, DevOps and Agile

**LinkedIn:** [samir-pathan-218b84239](https://www.linkedin.com/in/samir-pathan-218b84239)
