# deepseek-architecture
Terraform project that create an AWS Architecture by prompt Engineering

# To test the RDS postgres
- Create an EC2 instances
- Add this code to the User Data:
    #!/bin/bash
cd /tmp
sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
sudo dnf install -y postgresql15
    
- Add an Inbound rule in the SG of DB to enable conecctions from SG wheres EC2 resides
-  Command to coonet from shell:
psql -h <db-end-point> -U <user> -d <admin>




