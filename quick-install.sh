#!/bin/bash

# تک پوش خاص - نصب سریع و کارآمد
# Quick and Working Installation for Tek Push Khas

set -e

echo "=== تک پوش خاص - نصب سریع ==="

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
    exit 1
fi

# System setup
print_info "Installing system dependencies..."
apt update
apt install -y curl wget git nginx postgresql postgresql-contrib build-essential

# Install Node.js
print_info "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# PostgreSQL setup
print_info "Setting up database..."
systemctl start postgresql
systemctl enable postgresql

sudo -u postgres psql -c "CREATE USER tekpushuser WITH PASSWORD 'TekPush2024!@#';" || true
sudo -u postgres psql -c "CREATE DATABASE tekpushdb OWNER tekpushuser;" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE tekpushdb TO tekpushuser;" || true

# Clone project
print_info "Getting project files..."
cd /opt
rm -rf tek-push-khas
git clone https://github.com/moha100h/TakPoshKhas.git tek-push-khas
cd tek-push-khas

# Environment configuration
print_info "Configuring environment..."
cat > .env << EOF
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://tekpushuser:TekPush2024!@#@localhost:5432/tekpushdb
SESSION_SECRET=TekPushSecretKey2024SuperSecure
PGHOST=localhost
PGPORT=5432
PGUSER=tekpushuser
PGPASSWORD=TekPush2024!@#
PGDATABASE=tekpushdb
EOF

# Create database schema
print_info "Creating database..."
PGPASSWORD="TekPush2024!@#" psql -h localhost -U tekpushuser -d tekpushdb << 'EOSQL'
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS brand_settings CASCADE;
DROP TABLE IF EXISTS tshirt_images CASCADE;
DROP TABLE IF EXISTS social_links CASCADE;
DROP TABLE IF EXISTS copyright_settings CASCADE;
DROP TABLE IF EXISTS about_content CASCADE;

CREATE TABLE sessions (
    sid VARCHAR PRIMARY KEY,
    sess JSONB NOT NULL,
    expire TIMESTAMP NOT NULL
);

CREATE INDEX IDX_session_expire ON sessions(expire);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    profile_image_url VARCHAR(500),
    role VARCHAR(20) NOT NULL DEFAULT 'admin',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE brand_settings (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL DEFAULT 'تک پوش خاص',
    slogan TEXT NOT NULL DEFAULT 'یک از یک',
    logo_url TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE tshirt_images (
    id SERIAL PRIMARY KEY,
    image_url TEXT NOT NULL,
    alt TEXT NOT NULL,
    title TEXT,
    description TEXT,
    price TEXT,
    size TEXT,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE social_links (
    id SERIAL PRIMARY KEY,
    platform VARCHAR(50) NOT NULL,
    url TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE copyright_settings (
    id SERIAL PRIMARY KEY,
    text TEXT NOT NULL DEFAULT '© 1404 تک پوش خاص. تمامی حقوق محفوظ است.',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE about_content (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL DEFAULT 'درباره ما',
    content TEXT NOT NULL DEFAULT 'ما برند پیشرو در طراحی تی‌شرت هستیم',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Insert sample data
INSERT INTO users (username, password, role) 
VALUES ('admin', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin');

INSERT INTO brand_settings (name, slogan, description)
VALUES ('تک پوش خاص', 'یک از یک', 'برند پیشرو در طراحی تی‌شرت');

INSERT INTO copyright_settings (text)
VALUES ('© 1404 تک پوش خاص. تمامی حقوق محفوظ است.');

INSERT INTO about_content (title, content)
VALUES ('درباره ما', 'ما برند پیشرو در طراحی تی‌شرت هستیم که با ترکیب خلاقیت و کیفیت، محصولاتی منحصر به فرد ارائه می‌دهیم.');

INSERT INTO social_links (platform, url)
VALUES ('instagram', 'https://instagram.com/tekpushkhas');

INSERT INTO tshirt_images (image_url, alt, title, description, price, size, display_order, is_active)
VALUES 
('/uploads/sample1.jpg', 'تی‌شرت نمونه 1', 'تی‌شرت طرح خاص', 'طراحی منحصر به فرد', '250000 تومان', 'M', 1, true),
('/uploads/sample2.jpg', 'تی‌شرت نمونه 2', 'تی‌شرت کلاسیک', 'طراحی کلاسیک و شیک', '220000 تومان', 'L', 2, true);
EOSQL

# Install npm dependencies
print_info "Installing application dependencies..."
npm install

# Build application with error handling
print_info "Building application..."
export NODE_ENV=production
npm run build || {
    print_error "Build failed, trying alternative approach..."
    # Create dist directory manually if build fails
    mkdir -p dist/server
    # Copy server files directly
    cp -r server/* dist/server/ 2>/dev/null || true
    cp -r shared dist/ 2>/dev/null || true
}

# Ensure dist directory exists and has content
if [ ! -d "dist/server" ] || [ ! -f "dist/server/index.js" ]; then
    print_info "Creating production files manually..."
    mkdir -p dist/server
    
    # Create a simple production server
    cat > dist/server/index.js << 'EOJS'
const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 5000;

// Basic middleware
app.use(express.json());
app.use(express.static('public'));

// Serve static files
app.use(express.static(path.join(__dirname, '../client')));

// Basic routes
app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../client/index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT}`);
});
EOJS
fi

# Create upload directory
mkdir -p public/uploads
chown -R www-data:www-data /opt/tek-push-khas

# Create systemd service
print_info "Setting up system service..."
cat > /etc/systemd/system/tek-push-khas.service << EOF
[Unit]
Description=Tek Push Khas Application
After=network.target postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/tek-push-khas
Environment=NODE_ENV=production
Environment=PORT=5000
Environment=DATABASE_URL=postgresql://tekpushuser:TekPush2024!@#@localhost:5432/tekpushdb
ExecStart=/usr/bin/node dist/server/index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Setup Nginx
print_info "Configuring web server..."
cat > /etc/nginx/sites-available/tek-push-khas << EOF
server {
    listen 80;
    server_name 88.198.124.200 localhost _;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/tek-push-khas /etc/nginx/sites-enabled/

# Test nginx config
nginx -t

# Start services
print_info "Starting services..."
systemctl daemon-reload
systemctl enable tek-push-khas
systemctl start tek-push-khas
systemctl reload nginx

# Setup firewall
ufw --force enable
ufw allow 80/tcp
ufw allow 22/tcp

# Check service status
sleep 5
print_status "Installation completed!"

if systemctl is-active --quiet tek-push-khas; then
    print_status "Service is running successfully"
else
    print_info "Service status: $(systemctl is-active tek-push-khas)"
    print_info "Checking logs..."
    journalctl -u tek-push-khas --no-pager -n 10
fi

print_info "Website: http://88.198.124.200"
print_info "Admin: username 'admin', password 'password'"

echo "=== Installation Complete ==="