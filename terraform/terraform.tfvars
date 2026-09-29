# Copy this file to terraform.tfvars and fill in your own values.
# terraform.tfvars is gitignored on purpose — never commit real IPs/keys.

aws_region   = "ap-south-1"
project_name = "chaosops"

# Find yours with: curl -s https://checkip.amazonaws.com
my_ip_cidr = "your_ip/32"

worker_count          = 2
instance_type_master  = "t3.medium"
instance_type_worker  = "t3.medium"
