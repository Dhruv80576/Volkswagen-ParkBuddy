# EC2 Deployment Guide for Volkswagen Backend

## Prerequisites
- EC2 instance running (Amazon Linux 2 or Ubuntu)
- SSH access to your EC2 instance
- Security group configured to allow inbound traffic on port 8080

## Step 1: Configure EC2 Security Group

1. Go to AWS EC2 Console
2. Select your instance
3. Click on the Security Group
4. Add Inbound Rule:
   - Type: Custom TCP
   - Port: 8080
   - Source: 0.0.0.0/0 (or your specific IP range)
   - Description: Backend API

## Step 2: Connect to EC2 Instance

```bash
# Replace with your EC2 details
ssh -i "your-key.pem" ec2-user@your-ec2-public-ip
```

## Step 3: Transfer Backend Files to EC2

### Option A: Using SCP (from your local machine)

```bash
# Navigate to the Prototype_app directory on your local machine
cd c:\Users\agarw\Downloads\VOLKWAGEN-Hackathon\Prototype\Prototype_app

# Copy backend directory to EC2
scp -i "your-key.pem" -r backend ec2-user@your-ec2-public-ip:~/
```

### Option B: Using Git (recommended)

```bash
# On EC2 instance
cd ~
git clone https://github.com/Dhruv80576/Volkswagen-ParkBuddy.git
cd Volkswagen-ParkBuddy/Prototype/Prototype_app/backend
```

## Step 4: Run Deployment Script

```bash
# Make the script executable
chmod +x deploy.sh

# Run the deployment script
./deploy.sh
```

## Step 5: Verify Deployment

```bash
# Check if service is running
sudo systemctl status volkswagen-backend

# Test the API
curl http://localhost:8080/health

# Check from your local machine (replace with your EC2 public IP)
curl http://YOUR-EC2-PUBLIC-IP:8080/health
```

## Manual Deployment (Alternative)

If you prefer to run it manually without systemd:

```bash
# Install Go
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Navigate to backend
cd ~/backend

# Install dependencies
go mod download

# Build and run
go build -o volkswagen-backend .
./volkswagen-backend
```

## Running in Background (Manual Method)

```bash
# Using nohup
nohup ./volkswagen-backend > backend.log 2>&1 &

# Check if running
ps aux | grep volkswagen-backend

# View logs
tail -f backend.log
```

## Troubleshooting

### Port already in use
```bash
# Find process using port 8080
sudo lsof -i :8080
# or
sudo netstat -tulpn | grep 8080

# Kill the process
sudo kill -9 <PID>
```

### Service fails to start
```bash
# View detailed logs
sudo journalctl -u volkswagen-backend -n 50 --no-pager

# Check permissions
ls -la ~/backend/volkswagen-backend
```

### Cannot connect from outside
- Verify Security Group has port 8080 open
- Check EC2 instance firewall:
```bash
sudo iptables -L -n
```

## Environment Configuration

If you need to change the port or other settings:

1. Edit `main.go` and change the port in `r.Run(":8080")`
2. Rebuild: `go build -o volkswagen-backend .`
3. Restart service: `sudo systemctl restart volkswagen-backend`

## Updating the Backend

```bash
# Pull latest changes (if using Git)
git pull

# Rebuild
go build -o volkswagen-backend .

# Restart service
sudo systemctl restart volkswagen-backend
```

## API Endpoints

Once deployed, your backend will be accessible at:

- Health Check: `http://YOUR-EC2-PUBLIC-IP:8080/health`
- Location to H3: `POST http://YOUR-EC2-PUBLIC-IP:8080/api/location/h3`
- Nearby Cells: `POST http://YOUR-EC2-PUBLIC-IP:8080/api/location/nearby`
- And all other endpoints listed in the main README.md

## SSL/HTTPS (Optional but Recommended)

For production, consider setting up HTTPS:

1. Install Nginx as reverse proxy
2. Use Let's Encrypt for SSL certificate
3. Configure Nginx to proxy requests to localhost:8080

```bash
# Install Nginx
sudo yum install nginx -y  # Amazon Linux
# or
sudo apt-get install nginx -y  # Ubuntu

# Install Certbot
sudo yum install certbot python3-certbot-nginx -y
```

## Monitoring

```bash
# Real-time logs
sudo journalctl -u volkswagen-backend -f

# CPU and Memory usage
top
# or
htop

# Disk usage
df -h
```
