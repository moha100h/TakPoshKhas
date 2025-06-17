#!/bin/bash

# تک پوش خاص - اسکریپت نصب خودکار کامل
# Complete Auto Install Script for Tek Push Khas
# Server: 88.198.124.200 | Ubuntu 22.04 LTS

set -e

echo "=== تک پوش خاص - نصب خودکار کامل ==="
echo "Starting complete automated installation..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "لطفاً با دسترسی root اجرا کنید | Please run as root"
    exit 1
fi

# Cleanup function
cleanup() {
    print_info "پاکسازی فایل‌های موقت..."
    rm -f /tmp/node-setup.sh
}

trap cleanup EXIT

# Step 1: System Update
print_info "به‌روزرسانی سیستم..."
apt update && apt upgrade -y

# Step 2: Install Dependencies
print_info "نصب وابستگی‌های سیستم..."
apt install -y curl wget git nginx postgresql postgresql-contrib build-essential

# Step 3: Install Node.js 20
print_info "نصب Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Verify Node.js installation
node_version=$(node --version)
npm_version=$(npm --version)
print_status "Node.js $node_version و npm $npm_version نصب شد"

# Step 4: Setup PostgreSQL
print_info "تنظیم پایگاه داده PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# Create database and user
sudo -u postgres psql -c "CREATE USER tekpushuser WITH PASSWORD 'TekPush2024!@#';" || true
sudo -u postgres psql -c "CREATE DATABASE tekpushdb OWNER tekpushuser;" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE tekpushdb TO tekpushuser;" || true

print_status "پایگاه داده PostgreSQL آماده شد"

# Step 5: Clone Repository
print_info "دریافت کد منبع..."
cd /opt
if [ -d "tek-push-khas" ]; then
    rm -rf tek-push-khas
fi
git clone https://github.com/moha100h/TakPoshKhas.git tek-push-khas
cd tek-push-khas

# Step 6: Setup Environment
print_info "تنظیم متغیرهای محیطی..."
cat > .env << EOF
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://tekpushuser:TekPush2024!@#@localhost:5432/tekpushdb
SESSION_SECRET=TekPushSecretKey2024SuperSecure!@#$%^&*()
PGHOST=localhost
PGPORT=5432
PGUSER=tekpushuser
PGPASSWORD=TekPush2024!@#
PGDATABASE=tekpushdb
EOF

# Step 7: Install Dependencies
print_info "نصب وابستگی‌های پروژه..."
npm install

# Step 8: Create tsconfig.json for server if missing
print_info "ایجاد فایل‌های پیکربندی..."
mkdir -p server
cat > server/tsconfig.json << EOF
{
  "extends": "../tsconfig.json",
  "compilerOptions": {
    "outDir": "../dist/server",
    "rootDir": "../server",
    "module": "ESNext",
    "target": "ES2022",
    "moduleResolution": "node"
  },
  "include": ["../server/**/*"],
  "exclude": ["../node_modules", "../dist"]
}
EOF

# Create main tsconfig if missing
if [ ! -f "tsconfig.json" ]; then
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
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./client/src/*"],
      "@shared/*": ["./shared/*"],
      "@assets/*": ["./attached_assets/*"]
    }
  },
  "include": ["client/src", "shared", "server"],
  "references": [{ "path": "./server/tsconfig.json" }]
}
EOF
fi

# Step 9: Fix drizzle config
print_info "تنظیم Drizzle ORM..."
cat > drizzle.config.ts << EOF
import { defineConfig } from "drizzle-kit";

if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL environment variable is required");
}

export default defineConfig({
  dialect: "postgresql",
  schema: "./shared/schema.ts",
  out: "./migrations",
  dbCredentials: {
    url: process.env.DATABASE_URL,
  },
  verbose: true,
  strict: true,
});
EOF

# Step 10: Database Migration with proper schema
print_info "مهاجرت پایگاه داده..."

# Create database schema manually to avoid conflicts
PGPASSWORD="TekPush2024!@#" psql -h localhost -U tekpushuser -d tekpushdb << 'EOSQL'
-- Create sessions table
CREATE TABLE IF NOT EXISTS sessions (
    sid VARCHAR PRIMARY KEY,
    sess JSONB NOT NULL,
    expire TIMESTAMP NOT NULL
);

-- Create users table
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

-- Create brand_settings table
CREATE TABLE IF NOT EXISTS brand_settings (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL DEFAULT 'تک پوش خاص',
    slogan TEXT NOT NULL DEFAULT 'یک از یک',
    logo_url TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create tshirt_images table
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

-- Create social_links table
CREATE TABLE IF NOT EXISTS social_links (
    id SERIAL PRIMARY KEY,
    platform VARCHAR(50) NOT NULL,
    url TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create copyright_settings table
CREATE TABLE IF NOT EXISTS copyright_settings (
    id SERIAL PRIMARY KEY,
    text TEXT NOT NULL DEFAULT '© 1404 تک پوش خاص. تمامی حقوق محفوظ است.',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create about_content table
CREATE TABLE IF NOT EXISTS about_content (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL DEFAULT 'درباره ما',
    content TEXT NOT NULL DEFAULT 'ما برند پیشرو در طراحی تی‌شرت هستیم',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Insert default data
INSERT INTO users (username, password, role) 
VALUES ('admin', '$2b$10$rQZ4QJ5iKfY4QJ5iKfY4Q.J5iKfY4QJ5iKfY4QJ5iKfY4QJ5iKfY4QO', 'admin')
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

EOSQL

print_status "پایگاه داده با موفقیت ایجاد شد"

# Step 11: Build Application
print_info "ساخت اپلیکیشن..."
npm run build

print_status "فایل‌های استاتیک ایجاد شد"

# Step 12: Setup systemd service
print_info "تنظیم سرویس سیستم..."
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

# Step 13: Setup file permissions
print_info "تنظیم دسترسی‌ها..."
chown -R www-data:www-data /opt/tek-push-khas
chmod -R 755 /opt/tek-push-khas

# Step 14: Setup Nginx
print_info "تنظیم سرور وب..."
cat > /etc/nginx/sites-available/tek-push-khas << EOF
server {
    listen 80;
    server_name 88.198.124.200;
    
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

# Remove default nginx site and enable our site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/tek-push-khas /etc/nginx/sites-enabled/

# Test nginx configuration
nginx -t

# Step 15: Start Services
print_info "راه‌اندازی سرویس‌ها..."
systemctl daemon-reload
systemctl enable tek-push-khas
systemctl start tek-push-khas
systemctl reload nginx

# Step 16: Setup Firewall
print_info "تنظیم فایروال..."
ufw allow 80/tcp
ufw allow 22/tcp
ufw --force enable

# Step 17: Create upload directory
print_info "ایجاد پوشه آپلود..."
mkdir -p /opt/tek-push-khas/public/uploads
chown -R www-data:www-data /opt/tek-push-khas/public/uploads
chmod -R 755 /opt/tek-push-khas/public/uploads

print_status "نصب با موفقیت تکمیل شد!"
print_info "وب‌سایت در آدرس http://88.198.124.200 در دسترس است"
print_info "برای ورود از نام کاربری 'admin' و رمز عبور پیش‌فرض استفاده کنید"

# Check service status
if systemctl is-active --quiet tek-push-khas; then
    print_status "سرویس با موفقیت در حال اجرا است"
else
    print_warning "سرویس ممکن است نیاز به راه‌اندازی مجدد داشته باشد"
    print_info "برای بررسی وضعیت: systemctl status tek-push-khas"
fi

echo "=== نصب تکمیل شد ==="