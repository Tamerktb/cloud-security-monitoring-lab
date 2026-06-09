# Attack Simulation Guide

Test your security monitoring lab by simulating real attack scenarios.

## Prerequisites

- Running Wazuh server (see `scripts/install-wazuh-server.sh`)
- At least one Wazuh agent deployed on a target (see `scripts/setup-wazuh-agent.sh`)
- Attack tools: `nmap`, `hydra`, `aws-cli`

```bash
# Install tools
sudo apt-get install -y nmap hydra awscli
```

---

## Scenario 1: SSH Brute Force

Simulates an attacker trying to guess SSH credentials.

```bash
# From an attacker machine (can be your local machine)
hydra -l ubuntu -P /usr/share/wordlists/rockyou.txt <TARGET_IP> ssh -t 4
```

**What to check in Wazuh:**
- Dashboard → Security Events → Filter by rule ID 5710
- Verify alert severity: High (level 10)
- Check the source IP, username, and attempt count in alert details

---

## Scenario 2: Port Scan

Simulates reconnaissance via nmap port scan.

```bash
nmap -sS -sV -p- <TARGET_IP> -T4
```

**What to check in Wazuh:**
- Dashboard → Security Events → look for port scan alerts
- Wazuh should detect the connection attempts as suspicious activity

---

## Scenario 3: S3 Bucket Enumeration

Simulates an attacker probing for publicly accessible S3 buckets.

```bash
# Try to list a bucket without authentication
aws s3 ls s3://example-bucket/ --no-sign-request

# Try common bucket names
for bucket in test dev backup logs data; do
  aws s3 ls "s3://${bucket}-target/" --no-sign-request 2>/dev/null
done
```

**What to check in Wazuh:**
- CloudTrail integration should pick up the denied requests
- Rule ID 5720 should trigger on anonymous access attempts

---

## Scenario 4: Suspicious API Calls

Simulates an attacker with compromised credentials probing for privileges.

```bash
# Attempt to list IAM users (requires privileges)
aws iam list-users

# Attempt to create an admin user
aws iam create-user --user-name backdoor

# Attempt to access a restricted S3 bucket
aws s3 ls s3://restricted-bucket/
```

**What to check in Wazuh:**
- Rule ID 5730 should trigger on AccessDenied errors
- Verify the user identity ARN and event name in alert details

---

## Expected Results

| Scenario | Rule ID | Severity | Expected Alert |
|---|---|---|---|
| SSH Brute Force | 5710 | High (10) | Alert with source IP and attempt count |
| Port Scan | Built-in | Medium (7) | Nmap scan detection |
| S3 Anonymous Access | 5720 | Critical (12) | Alert with bucket name and IP |
| Unauthorized API | 5730 | Medium (8) | Alert with user ARN and event name |

## Cleanup

After testing, terminate AWS resources to avoid charges:

```bash
cd terraform
terraform destroy
```
