#!/bin/bash
# Update system packages
yum update -y

# Install Apache web server
yum install -y httpd

# Start Apache and enable it to start on boot
systemctl start httpd
systemctl enable httpd

# Get Instance Metadata (for Availability Zone and Instance ID)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Create a custom HTML web page showing details
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>AWS High Availability App</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background-color: #f4f4f9; }
        .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0px 0px 10px rgba(0,0,0,0.1); display: inline-block; }
        h1 { color: #FF9900; }
        p { font-size: 18px; color: #333; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to AWS HA Architecture Project</h1>
        <p><b>Server Instance ID:</b> $INSTANCE_ID</p>
        <p><b>Availability Zone (AZ):</b> $AZ</p>
        <p><i>Traffic is successfully routed via Application Load Balancer!</i></p>
    </div>
</body>
</html>
EOF

# Restart Apache to apply changes
systemctl restart httpd
