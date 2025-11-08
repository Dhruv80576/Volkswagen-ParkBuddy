#!/bin/bash

# Volkswagen H3 Backend Deployment Script
# This script sets up and runs the Go backend on an EC2 instance

echo "🚀 Starting Volkswagen H3 Backend Deployment..."

# Update system packages
echo "📦 Updating system packages..."
sudo yum update -y || sudo apt-get update -y

# Install Go if not already installed
if ! command -v go &> /dev/null
then
    echo "📥 Installing Go..."
    cd /tmp
    wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
    
    # Add Go to PATH
    echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
    
    echo "✅ Go installed successfully!"
    go version
else
    echo "✅ Go is already installed"
    go version
fi

# Navigate to backend directory
cd ~/backend || cd ~/Prototype_app/backend || cd /home/ec2-user/backend

echo "📦 Installing Go dependencies..."
go mod download

echo "🔨 Building the application..."
go build -o volkswagen-backend .

echo "🌐 Setting up the service to run in background..."

# Create systemd service file
sudo tee /etc/systemd/system/volkswagen-backend.service > /dev/null <<EOF
[Unit]
Description=Volkswagen H3 Backend Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/volkswagen-backend
Restart=always
RestartSec=10
Environment="GIN_MODE=release"

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable volkswagen-backend
sudo systemctl start volkswagen-backend

echo "✅ Backend service started!"
echo "📊 Checking service status..."
sudo systemctl status volkswagen-backend --no-pager

echo ""
echo "🎉 Deployment Complete!"
echo "Backend is running on http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo ""
echo "📝 Useful commands:"
echo "  - Check status: sudo systemctl status volkswagen-backend"
echo "  - View logs: sudo journalctl -u volkswagen-backend -f"
echo "  - Restart: sudo systemctl restart volkswagen-backend"
echo "  - Stop: sudo systemctl stop volkswagen-backend"
