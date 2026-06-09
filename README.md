# Cloud Security Monitoring Lab

Deploy a complete cloud security monitoring environment on AWS with SIEM, threat detection, and automated incident response.

## Overview

This project provisions a full security operations center (SOC) lab in AWS including:

- **Infrastructure as Code** — Terraform deploys VPC, EC2 instances, S3 buckets, CloudTrail, VPC Flow Logs
- **SIEM** — Wazuh server for log aggregation, alerting, and threat detection
- **Detection Rules** — Custom rules for SSH brute force, S3 anonymous access, and unauthorized API calls
- **Honeypot** — Cowrie SSH honeypot to capture attacker activity
- **Attack Simulation** — Scripts to test detection capabilities

## Architecture

```
Internet
    |
    ├── Monitoring Instance (Wazuh Server) :443
    │       └── Ingest: agent logs, CloudTrail, VPC Flow Logs
    │
    ├── Honeypot (Cowrie) :22
    │       └── Captures attacker SSH interactions
    │
    ├── CloudTrail → S3 → Wazuh
    └── VPC Flow Logs → CloudWatch → Wazuh
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- An [AWS key pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) for EC2 SSH access

## Quick Start

### 1. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan -var="key_name=YOUR_KEY_PAIR_NAME"
terraform apply -var="key_name=YOUR_KEY_PAIR_NAME" -auto-approve
```

Save the output IPs:
```
monitoring_instance_ip = 54.xxx.xxx.xxx
honeypot_instance_ip   = 55.xxx.xxx.xxx
cloudtrail_bucket      = secops-lab-cloudtrail-logs-xxxx
```

### 2. Install Wazuh Server

SSH to the monitoring instance and run:

```bash
chmod +x scripts/install-wazuh-server.sh
sudo ./scripts/install-wazuh-server.sh
```

Access the Wazuh dashboard at `https://<MONITORING_IP>:443` with credentials printed at the end of the script.

### 3. Configure Cloud Integrations

Forward CloudTrail and VPC Flow Logs to Wazuh:

```bash
# On the Wazuh server, edit /var/ossec/etc/ossec.conf
# Add the S3 bucket integration block (see config/ossec-agent.conf)
# Restart Wazuh:
systemctl restart wazuh-manager
```

### 4. Deploy Honeypot

If Terraform deployed it, the honeypot is already running on the second EC2 instance with Cowrie containerized on port 22.

### 5. Test Detection

Run attack simulations from a separate machine:

```bash
chmod +x scripts/simulate-attack.sh
./scripts/simulate-attack.sh <HONEYPOT_IP>
```

Select scenario 4 ("All of the above") to generate alerts across all detection rules.

## Detection Rules

| Rule | ID | Severity | Description |
|---|---|---|---|
| SSH Brute Force | 5710 | High (10) | 5+ failed SSH attempts in 5 minutes |
| S3 Anonymous Access | 5720 | Critical (12) | Anonymous S3 bucket enumeration |
| Unauthorized API | 5730 | Medium (8) | 3+ AccessDenied API calls in 5 minutes |

Rules are in `detection-rules/`. Add them to Wazuh at `/var/ossec/etc/rules/custom/`.

## Project Structure

```
cloud-security-monitoring-lab/
├── terraform/              # AWS infrastructure as code
│   ├── main.tf             # Core resources: VPC, EC2, S3, CloudTrail
│   ├── variables.tf        # Configuration variables
│   ├── outputs.tf          # Output values
│   └── providers.tf        # Terraform/AWS provider config
├── scripts/
│   ├── install-wazuh-server.sh
│   ├── setup-wazuh-agent.sh
│   ├── configure-vpc-flow-logs.sh
│   └── simulate-attack.sh
├── detection-rules/
│   ├── ssh-brute-force.yml
│   ├── s3-public-access.yml
│   └── cloudtrail-unauthorized-api.yml
├── config/
│   └── ossec-agent.conf    # Wazuh agent configuration template
├── examples/
│   └── attack-simulation.md
└── README.md
```

## Cost Estimates

Runs on AWS Free Tier eligible resources:

| Resource | Type | Monthly Cost |
|---|---|---|
| Monitoring EC2 | t3.medium | ~$30 (not free tier) |
| Honeypot EC2 | t2.micro | Free tier eligible |
| S3/CloudTrail | Small volume | < $5 |
| VPC Flow Logs | CloudWatch | < $5 |

**Stop instances when not in use** to minimize costs:
```bash
terraform destroy
```

## What This Demonstrates

- Infrastructure as Code (Terraform)
- Cloud security architecture (VPC, security groups, IAM)
- SIEM deployment and configuration (Wazuh)
- Detection engineering (custom rules, correlation)
- Threat simulation and testing
- Incident response automation
- AWS security services (CloudTrail, VPC Flow Logs)
- Containerization (Docker/honeypot deployment)
- Linux system administration
- Shell scripting and automation

## License

MIT
