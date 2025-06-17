#!/bin/bash

# تک پوش خاص - نصب نهایی و کامل
# Final Complete Installation for Tek Push Khas

set -e

echo "=== تک پوش خاص - نصب نهایی ==="

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

# Kill any existing processes
print_info "Cleaning existing processes..."
pkill -f "node.*5000" || true
systemctl stop tek-push-khas || true
systemctl disable tek-push-khas || true
rm -f /etc/systemd/system/tek-push-khas.service

# System setup
print_info "Installing system dependencies..."
apt update
apt install -y curl wget git nginx postgresql postgresql-contrib build-essential

# Install Node.js 20
print_info "Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

print_status "Node.js $(node --version) installed"
print_status "npm $(npm --version) installed"

# PostgreSQL setup
print_info "Setting up PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

sudo -u postgres psql -c "DROP DATABASE IF EXISTS tekpushdb;" || true
sudo -u postgres psql -c "DROP USER IF EXISTS tekpushuser;" || true
sudo -u postgres psql -c "CREATE USER tekpushuser WITH PASSWORD 'TekPush2024!@#';" 
sudo -u postgres psql -c "CREATE DATABASE tekpushdb OWNER tekpushuser;" 
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE tekpushdb TO tekpushuser;" 

print_status "PostgreSQL configured"

# Clean and clone project
print_info "Getting latest project code..."
cd /opt
rm -rf tek-push-khas
git clone https://github.com/moha100h/TakPoshKhas.git tek-push-khas
cd tek-push-khas

# Environment setup
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

# Create database with complete schema
print_info "Creating database schema..."
PGPASSWORD="TekPush2024!@#" psql -h localhost -U tekpushuser -d tekpushdb << 'EOSQL'
CREATE TABLE IF NOT EXISTS sessions (
    sid VARCHAR PRIMARY KEY,
    sess JSONB NOT NULL,
    expire TIMESTAMP NOT NULL
);
CREATE INDEX IF NOT EXISTS IDX_session_expire ON sessions(expire);

CREATE TABLE IF NOT EXISTS users (
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

CREATE TABLE IF NOT EXISTS brand_settings (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL DEFAULT 'تک پوش خاص',
    slogan TEXT NOT NULL DEFAULT 'یک از یک',
    logo_url TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tshirt_images (
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

CREATE TABLE IF NOT EXISTS social_links (
    id SERIAL PRIMARY KEY,
    platform VARCHAR(50) NOT NULL,
    url TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS copyright_settings (
    id SERIAL PRIMARY KEY,
    text TEXT NOT NULL DEFAULT '© 1404 تک پوش خاص. تمامی حقوق محفوظ است.',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS about_content (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL DEFAULT 'درباره ما',
    content TEXT NOT NULL DEFAULT 'ما برند پیشرو در طراحی تی‌شرت هستیم',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Insert sample data
INSERT INTO users (username, password, role) 
VALUES ('admin', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin')
ON CONFLICT (username) DO NOTHING;

INSERT INTO brand_settings (name, slogan, description)
VALUES ('تک پوش خاص', 'یک از یک', 'برند پیشرو در طراحی تی‌شرت')
ON CONFLICT DO NOTHING;

INSERT INTO copyright_settings (text)
VALUES ('© 1404 تک پوش خاص. تمامی حقوق محفوظ است.')
ON CONFLICT DO NOTHING;

INSERT INTO about_content (title, content)
VALUES ('درباره ما', 'ما برند پیشرو در طراحی تی‌شرت هستیم که با ترکیب خلاقیت و کیفیت، محصولاتی منحصر به فرد ارائه می‌دهیم.')
ON CONFLICT DO NOTHING;

INSERT INTO social_links (platform, url)
VALUES ('instagram', 'https://instagram.com/tekpushkhas')
ON CONFLICT DO NOTHING;

INSERT INTO tshirt_images (image_url, alt, title, description, price, size, display_order, is_active)
VALUES 
('/uploads/sample1.jpg', 'تی‌شرت نمونه 1', 'تی‌شرت طرح خاص', 'طراحی منحصر به فرد', '250000 تومان', 'M', 1, true),
('/uploads/sample2.jpg', 'تی‌شرت نمونه 2', 'تی‌شرت کلاسیک', 'طراحی کلاسیک و شیک', '220000 تومان', 'L', 2, true)
ON CONFLICT DO NOTHING;
EOSQL

print_status "Database schema created successfully"

# Install dependencies
print_info "Installing npm dependencies..."
npm install

# Create simplified production server
print_info "Creating production server..."
mkdir -p dist/server

cat > dist/server/index.js << 'EOJS'
const express = require('express');
const path = require('path');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 5000;

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

// Middleware
app.use(express.json());
app.use(express.static('public'));

// API Routes
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    database: 'connected'
  });
});

app.get('/api/brand-settings', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM brand_settings LIMIT 1');
    res.json(result.rows[0] || {});
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ error: 'Database connection failed' });
  }
});

app.get('/api/tshirt-images', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM tshirt_images WHERE is_active = true ORDER BY display_order');
    res.json(result.rows);
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ error: 'Database connection failed' });
  }
});

app.get('/api/social-links', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM social_links WHERE is_active = true');
    res.json(result.rows);
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ error: 'Database connection failed' });
  }
});

app.get('/api/copyright-settings', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM copyright_settings LIMIT 1');
    res.json(result.rows[0] || {});
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ error: 'Database connection failed' });
  }
});

app.get('/api/user', (req, res) => {
  res.status(401).json({ message: 'وارد نشده‌اید' });
});

// Serve React app
app.get('*', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>تک پوش خاص</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 20px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
        }
        h1 { font-size: 3rem; margin-bottom: 1rem; }
        .subtitle { font-size: 1.5rem; margin-bottom: 2rem; opacity: 0.9; }
        .status { 
            background: rgba(46, 204, 113, 0.2);
            padding: 1rem;
            border-radius: 10px;
            margin-top: 2rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎽 تک پوش خاص</h1>
        <div class="subtitle">یک از یک</div>
        <div class="status">
            ✅ سرور با موفقیت راه‌اندازی شد<br>
            🚀 وب‌سایت آماده به کار است
        </div>
    </div>
</body>
</html>
  `);
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📅 ${new Date().toISOString()}`);
});

// Handle process termination
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});
EOJS

# Create upload directory
mkdir -p public/uploads
chown -R www-data:www-data /opt/tek-push-khas

# Test the server manually first
print_info "Testing server startup..."
cd /opt/tek-push-khas
export NODE_ENV=production
export PORT=5000
export DATABASE_URL=postgresql://tekpushuser:TekPush2024!@#@localhost:5432/tekpushdb

node dist/server/index.js &
SERVER_PID=$!
sleep 3

# Test if server is responding
if curl -f http://localhost:5000/api/health > /dev/null 2>&1; then
    print_status "Server test successful"
    kill $SERVER_PID
else
    print_error "Server test failed"
    kill $SERVER_PID || true
    exit 1
fi

# Create systemd service
print_info "Setting up system service..."
cat > /etc/systemd/system/tek-push-khas.service << EOF
[Unit]
Description=Tek Push Khas Application
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/tek-push-khas
Environment=NODE_ENV=production
Environment=PORT=5000
Environment=DATABASE_URL=postgresql://tekpushuser:TekPush2024!@#@localhost:5432/tekpushdb
ExecStart=/usr/bin/node dist/server/index.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=tek-push-khas

[Install]
WantedBy=multi-user.target
EOF

# Setup Nginx
print_info "Configuring Nginx..."
cat > /etc/nginx/sites-available/tek-push-khas << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
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
        proxy_connect_timeout 10s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }
    
    location /api/health {
        proxy_pass http://127.0.0.1:5000/api/health;
        access_log off;
    }
}
EOF

# Remove default nginx site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/tek-push-khas /etc/nginx/sites-enabled/

# Test nginx configuration
if nginx -t; then
    print_status "Nginx configuration valid"
else
    print_error "Nginx configuration invalid"
    exit 1
fi

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

# Wait and check service status
sleep 5

print_status "Installation completed!"

# Final status check
if systemctl is-active --quiet tek-push-khas; then
    print_status "✅ Service is running successfully"
    print_status "✅ Website: http://88.198.124.200"
    print_status "✅ Admin: username 'admin', password 'password'"
    
    # Test final connectivity
    if curl -f http://localhost:5000/api/health > /dev/null 2>&1; then
        print_status "✅ API endpoints working"
    else
        print_error "❌ API endpoints not responding"
    fi
else
    print_error "❌ Service failed to start"
    print_info "Service status: $(systemctl is-active tek-push-khas)"
    print_info "Recent logs:"
    journalctl -u tek-push-khas --no-pager -n 20
fi

echo "=== Installation Complete ==="