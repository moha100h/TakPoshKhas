#!/bin/bash

# تک پوش خاص - نصب کامل یک مرحله‌ای
# One-Command Complete Installation for Tek Push Khas

set -e

echo "=== تک پوش خاص - نصب خودکار ==="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
    exit 1
fi

# System update
print_info "Updating system..."
apt update && apt upgrade -y

# Install dependencies
print_info "Installing dependencies..."
apt install -y curl wget git nginx postgresql postgresql-contrib build-essential

# Install Node.js 20
print_info "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Setup PostgreSQL
print_info "Setting up PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

sudo -u postgres psql -c "CREATE USER tekpushuser WITH PASSWORD 'TekPush2024!@#';" || true
sudo -u postgres psql -c "CREATE DATABASE tekpushdb OWNER tekpushuser;" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE tekpushdb TO tekpushuser;" || true

# Clone and setup project
print_info "Cloning project..."
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

# Fix TypeScript configuration
print_info "Setting up build configuration..."
cat > tsconfig.json << EOF
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2023"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./client/src/*"],
      "@shared/*": ["./shared/*"],
      "@assets/*": ["./attached_assets/*"]
    }
  },
  "include": ["client/src", "shared", "server"],
  "exclude": ["node_modules", "dist"]
}
EOF

mkdir -p server
cat > server/tsconfig.json << EOF
{
  "extends": "../tsconfig.json",
  "compilerOptions": {
    "outDir": "../dist/server",
    "rootDir": "../server",
    "module": "CommonJS",
    "target": "ES2022",
    "moduleResolution": "node",
    "noEmit": false
  },
  "include": ["../server/**/*"],
  "exclude": ["../node_modules", "../dist"]
}
EOF

# Install dependencies
print_info "Installing npm packages..."
npm install

# Create database schema directly
print_info "Creating database schema..."
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

# Build application
print_info "Building application..."
npm run build

# Setup permissions
print_info "Setting up permissions..."
chown -R www-data:www-data /opt/tek-push-khas
chmod -R 755 /opt/tek-push-khas

# Create systemd service
print_info "Creating system service..."
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
ExecStart=/usr/bin/node dist/server/index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Setup Nginx
print_info "Configuring web server..."
cat > /etc/nginx/sites-available/tek-push-khas << EOF
server {
    listen 80;
    server_name 88.198.124.200 localhost;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/tek-push-khas /etc/nginx/sites-enabled/

# Test nginx configuration
nginx -t

# Create upload directory
mkdir -p /opt/tek-push-khas/public/uploads
chown -R www-data:www-data /opt/tek-push-khas/public/uploads

# Start services
print_info "Starting services..."
systemctl daemon-reload
systemctl enable tek-push-khas
systemctl start tek-push-khas
systemctl reload nginx

# Setup firewall
ufw allow 80/tcp
ufw allow 22/tcp
ufw --force enable

print_status "Installation completed successfully!"
print_info "Website available at: http://88.198.124.200"
print_info "Admin login: username 'admin', password 'password'"

# Check service status
sleep 3
if systemctl is-active --quiet tek-push-khas; then
    print_status "Service is running successfully"
else
    print_info "Service status: $(systemctl is-active tek-push-khas)"
    print_info "Check logs with: journalctl -u tek-push-khas -f"
fi

echo "=== Installation Complete ==="