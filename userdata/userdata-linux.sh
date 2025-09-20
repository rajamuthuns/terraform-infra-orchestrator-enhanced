#!/bin/bash
set -e
ENVIRONMENT="${environment}"
[ -z "$ENVIRONMENT" ] && ENVIRONMENT="dev"
HOSTNAME="${hostname}"
[ -z "$HOSTNAME" ] && HOSTNAME=$(hostname)
OS_TYPE="${os_type}"
[ -z "$OS_TYPE" ] && OS_TYPE="linux"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/userdata.log
}

log "Starting Linux EC2 initialization - $ENVIRONMENT"

# Update and install Apache
log "Installing Apache and dependencies"
yum update -y
yum install -y httpd curl wget awscli jq

# Start and enable Apache
log "Starting Apache service"
systemctl start httpd
systemctl enable httpd

# Configure Apache for ALB
log "Configuring Apache for ALB"
cat > /etc/httpd/conf.d/alb.conf << 'EOF'
ServerTokens Prod
LoadModule deflate_module modules/mod_deflate.so
SetOutputFilter DEFLATE
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
EOF

# Create main page
log "Creating web content"
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html><head><title>$ENVIRONMENT Linux Server</title>
<style>
body{font-family:Arial;margin:0;background:linear-gradient(135deg,#667eea,#764ba2);min-height:100vh;padding:20px}
.container{max-width:800px;margin:0 auto;background:rgba(255,255,255,0.95);border-radius:15px;box-shadow:0 10px 30px rgba(0,0,0,0.2);overflow:hidden}
.header{background:linear-gradient(135deg,#2c3e50,#34495e);color:white;padding:30px;text-align:center}
.content{padding:30px}
.status{background:linear-gradient(135deg,#27ae60,#2ecc71);color:white;padding:15px;border-radius:8px;margin-bottom:20px;text-align:center}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:20px}
.card{background:#f8f9fa;padding:20px;border-radius:10px;box-shadow:0 2px 10px rgba(0,0,0,0.1)}
.metric{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid #eee}
.links a{display:inline-block;margin:5px;padding:8px 16px;background:#3498db;color:white;text-decoration:none;border-radius:5px}
</style></head>
<body><div class="container">
<div class="header"><h1>Linux Web Server</h1><p>Environment: $ENVIRONMENT | Host: $HOSTNAME</p></div>
<div class="content"><div class="status">Apache Web Server Online - ALB Ready!</div>
<div class="grid"><div class="card"><h2>Instance Info</h2>
<div class="metric"><strong>Environment:</strong><span>$ENVIRONMENT</span></div>
<div class="metric"><strong>Hostname:</strong><span>$HOSTNAME</span></div>
<div class="metric"><strong>OS:</strong><span>Amazon Linux 2</span></div>
<div class="metric"><strong>Web Server:</strong><span>Apache HTTP Server</span></div>
<div class="metric"><strong>Status:</strong><span>Running</span></div></div>
<div class="card"><h2>Features</h2><ul style="list-style:none">
<li>✓ Apache Web Server</li><li>✓ ALB Health Checks</li><li>✓ HTTP Compression</li><li>✓ Security Headers</li><li>✓ Auto-scaling Ready</li></ul></div>
<div class="card" style="text-align:center"><h2>Links</h2>
<a href="/health">Health Check</a><a href="/status.html">Server Status</a></div></div></div></div></body></html>
EOF

# Create health check endpoint for ALB
log "Creating health check endpoint"
echo "OK" > /var/www/html/health

# Create status page
log "Creating status page"
cat > /var/www/html/status.html << EOF
<!DOCTYPE html><html><head><title>Linux Server Status</title>
<style>body{font-family:Arial;margin:40px;background:#f8f9fa}.container{max-width:600px;margin:0 auto;background:white;padding:20px;border-radius:10px}.metric{display:flex;justify-content:space-between;padding:10px;border-bottom:1px solid #eee}.ok{color:#27ae60;font-weight:bold}a{color:#3498db;text-decoration:none}</style>
</head><body><div class="container"><h1>Linux Server Status</h1>
<div class="metric"><strong>Apache Status:</strong><span class="ok">Running</span></div>
<div class="metric"><strong>Health Check:</strong><span class="ok">OK</span></div>
<div class="metric"><strong>ALB Integration:</strong><span class="ok">Ready</span></div>
<div class="metric"><strong>Environment:</strong><span>$ENVIRONMENT</span></div>
<div class="metric"><strong>Last Updated:</strong><span id="time"></span></div>
<p><a href="/">← Back to Home</a></p>
</div><script>document.getElementById('time').textContent=new Date().toLocaleString();</script></body></html>
EOF

# Set proper permissions
log "Setting file permissions"
chown -R apache:apache /var/www/html
chmod -R 644 /var/www/html/*

# Configure EBS volumes if present
log "Configuring additional volumes"
for device in /dev/xvdf /dev/xvdg /dev/nvme1n1 /dev/nvme2n1; do
    if [ -b "$device" ]; then
        log "Configuring volume: $device"
        if ! blkid $device; then 
            mkfs.ext4 $device
        fi
        mount_point="/data$(basename $device | tr -d 'a-z')"
        mkdir -p $mount_point
        mount $device $mount_point
        echo "$device $mount_point ext4 defaults,nofail 0 2" >> /etc/fstab
        chown ec2-user:ec2-user $mount_point
        log "Mounted $device to $mount_point"
    fi
done

# Create health monitoring script
log "Setting up health monitoring"
cat > /opt/health-monitor.sh << 'EOF'
#!/bin/bash
if curl -f -s http://localhost/health > /dev/null; then
    echo "$(date): ALB Health Check - OK" >> /var/log/health-monitor.log
    exit 0
else
    echo "$(date): ALB Health Check - FAILED" >> /var/log/health-monitor.log
    # Try to restart Apache if health check fails
    systemctl restart httpd
    exit 1
fi
EOF
chmod +x /opt/health-monitor.sh

# Set up cron job for health monitoring
echo "*/2 * * * * root /opt/health-monitor.sh" >> /etc/crontab

# Restart Apache to apply all configurations
log "Restarting Apache with new configuration"
systemctl restart httpd

# Verify Apache is running
if systemctl is-active --quiet httpd; then
    log "SUCCESS: Apache is running and ready"
else
    log "ERROR: Apache failed to start"
    systemctl status httpd
    exit 1
fi

# Test health endpoint
log "Testing health endpoint"
sleep 5
if curl -f -s http://localhost/health > /dev/null; then
    log "SUCCESS: Health endpoint is responding"
else
    log "WARNING: Health endpoint not responding yet"
fi

log "Linux web server initialization completed successfully"
log "Server is ready for ALB traffic on port 80"
log "Health check endpoint: /health"

# Create completion marker
echo "$(date): Linux userdata script completed successfully" > /var/log/userdata-complete