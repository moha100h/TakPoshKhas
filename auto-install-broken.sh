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
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
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
print_status "به‌روزرسانی سیستم..."
export DEBIAN_FRONTEND=noninteractive
apt update -y
apt upgrade -y

# Step 2: Install essential packages
print_status "نصب بسته‌های ضروری..."
apt install -y curl wget git build-essential software-properties-common gnupg2 lsb-release

# Step 3: Install Nginx
print_status "نصب Nginx..."
apt install -y nginx

# Step 4: Install Node.js 20
print_status "نصب Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x -o /tmp/node-setup.sh
chmod +x /tmp/node-setup.sh
bash /tmp/node-setup.sh
apt-get install -y nodejs

# Verify Node.js installation
node_version=$(node --version)
npm_version=$(npm --version)
print_status "Node.js نصب شد: $node_version"
print_status "npm نصب شد: $npm_version"

# Step 5: Install PM2
print_status "نصب PM2..."
npm install -g pm2

# Step 6: Install PostgreSQL
print_status "نصب PostgreSQL..."
apt install -y postgresql postgresql-contrib

# Start PostgreSQL service
systemctl start postgresql
systemctl enable postgresql

# Step 7: Configure PostgreSQL
print_status "تنظیم PostgreSQL..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS tekposhdb;"
sudo -u postgres psql -c "DROP USER IF EXISTS tekposh;"
sudo -u postgres psql -c "CREATE USER tekposh WITH PASSWORD 'TekPosh@2024';"
sudo -u postgres psql -c "CREATE DATABASE tekposhdb OWNER tekposh;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE tekposhdb TO tekposh;"
sudo -u postgres psql -c "ALTER USER tekposh CREATEDB;"

# Step 8: Setup application directory
APP_DIR="/var/www/tekposh"
print_status "ایجاد پوشه اپلیکیشن در $APP_DIR..."

# Remove existing directory if exists
if [ -d "$APP_DIR" ]; then
    print_warning "حذف نصب قبلی..."
    rm -rf $APP_DIR
fi

mkdir -p $APP_DIR
cd $APP_DIR

# Step 9: Clone repository
print_status "دانلود کد پروژه..."
git clone https://github.com/moha100h/TakPoshKhas.git .

# Step 10: Install dependencies
print_status "نصب وابستگی‌ها..."
npm install

# Step 11: Create environment file
print_status "ایجاد فایل تنظیمات..."
cat > .env << EOF
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://tekposh:TekPosh@2024@localhost:5432/tekposhdb
SESSION_SECRET=$(openssl rand -base64 32)
PGUSER=tekposh
PGPASSWORD=TekPosh@2024
PGDATABASE=tekposhdb
PGHOST=localhost
PGPORT=5432
EOF

# Step 12: Create uploads directory
print_status "ایجاد پوشه آپلود..."
mkdir -p public/uploads
chmod 755 public/uploads

# Step 13: Setup database
print_status "راه‌اندازی دیتابیس..."
npm run db:push || {
    print_warning "خطا در db:push، تلاش مجدد..."
    sleep 5
    npm run db:push
}

# Step 14: Create PM2 ecosystem file
print_status "ایجاد تنظیمات PM2..."
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'tekposh',
    script: 'npm',
    args: 'run dev',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log'
  }]
}
EOF

# Step 15: Create logs directory
mkdir -p logs

# Step 16: Set proper permissions
print_status "تنظیم مجوزها..."
chown -R www-data:www-data $APP_DIR
chmod -R 755 $APP_DIR
chmod -R 777 public/uploads
chmod -R 755 logs

# Step 17: Configure Nginx
print_status "تنظیم Nginx..."
cat > /etc/nginx/sites-available/tekposh << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name 88.198.124.200 _;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    location /uploads/ {
        alias /var/www/tekposh/public/uploads/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable Nginx site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/tekposh /etc/nginx/sites-enabled/

# Test Nginx configuration
nginx -t

# Step 18: Configure firewall
print_status "تنظیم فایروال..."
ufw --force reset
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Step 19: Start services
print_status "راه‌اندازی سرویس‌ها..."
systemctl restart nginx
systemctl enable nginx

# Step 20: Initialize default data
print_status "ایجاد داده‌های پیش‌فرض..."
cat > init-data.js << 'EOF'
const { storage } = require('./server/storage');
const bcrypt = require('bcrypt');

async function initializeData() {
  try {
    // Create admin user
    const hashedPassword = await bcrypt.hash('admin123', 10);
    await storage.createUser({
      username: 'admin',
      password: hashedPassword,
      role: 'admin'
    });
    console.log('✓ Admin user created');

    // Initialize brand settings
    await storage.updateBrandSettings({
      name: 'تک پوش خاص',
      slogan: 'طراحی منحصر به فرد که سبک شما را متفاوت می‌کند',
      description: 'برند پیشرو در طراحی تی‌شرت با کیفیت برتر'
    });
    console.log('✓ Brand settings initialized');

    // Initialize copyright settings
    await storage.updateCopyrightSettings({
      text: '© 1404 تک پوش خاص. تمامی حقوق محفوظ است.'
    });
    console.log('✓ Copyright settings initialized');

    console.log('✓ All data initialized successfully');
  } catch (error) {
    console.log('Warning:', error.message);
  }
  process.exit(0);
}

initializeData();
EOF

node init-data.js
rm init-data.js

# Step 21: Start application with PM2
print_status "راه‌اندازی اپلیکیشن..."
cd $APP_DIR
pm2 start ecosystem.config.js
pm2 save
pm2 startup systemd -u root --hp /root

# Step 22: Final status check
sleep 5
print_status "بررسی وضعیت نهایی..."

if pm2 show tekposh > /dev/null 2>&1; then
    print_status "✓ اپلیکیشن با موفقیت راه‌اندازی شد"
else
    print_error "✗ خطا در راه‌اندازی اپلیکیشن"
fi

if systemctl is-active --quiet nginx; then
    print_status "✓ Nginx فعال است"
else
    print_error "✗ خطا در Nginx"
fi

# Step 23: Display final information
echo ""
echo "================================="
print_status "🎉 نصب کامل شد!"
print_status "Installation completed successfully!"
echo "================================="
echo ""
print_info "🌐 آدرس سایت: http://88.198.124.200"
print_info "👤 ورود ادمین: admin / admin123"
echo ""
print_info "📋 دستورات مفید:"
print_info "   • وضعیت اپ: pm2 status"
print_info "   • مشاهده لاگ: pm2 logs tekposh"
print_info "   • ری‌استارت: pm2 restart tekposh"
print_info "   • توقف اپ: pm2 stop tekposh"
echo ""
print_info "🔧 تنظیمات:"
print_info "   • پورت اپ: 5000"
print_info "   • پروکسی Nginx: 80 → 5000"
print_info "   • دیتابیس: PostgreSQL"
echo ""
print_status "✅ سایت آماده استفاده است!"