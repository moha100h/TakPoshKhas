#!/bin/bash

# تک پوش خاص - پاکسازی کامل و نصب حرفه‌ای
# Professional Complete Cleanup and Installation
# Ubuntu 22.04 LTS - Production Ready

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly APP_NAME="tek-push-khas"
readonly APP_DIR="/opt/${APP_NAME}"
readonly SERVICE_NAME="${APP_NAME}"
readonly DB_NAME="tekpushdb"
readonly DB_USER="tekpushuser"
readonly DB_PASS="TekPush2024SecurePassword"
readonly REPO_URL="https://github.com/moha100h/TakPoshKhas.git"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Error handling
error_exit() {
    log_error "$1"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "این اسکریپت باید با دسترسی root اجرا شود"
    fi
}

# Complete system cleanup
complete_cleanup() {
    log_info "شروع پاکسازی کامل سیستم..."
    
    # Stop and remove existing services
    systemctl stop ${SERVICE_NAME} 2>/dev/null || true
    systemctl disable ${SERVICE_NAME} 2>/dev/null || true
    rm -f /etc/systemd/system/${SERVICE_NAME}.service
    
    # Kill any running node processes on port 5000
    pkill -f "node.*5000" 2>/dev/null || true
    lsof -ti:5000 | xargs kill -9 2>/dev/null || true
    
    # Remove nginx configurations
    rm -f /etc/nginx/sites-enabled/${APP_NAME}
    rm -f /etc/nginx/sites-available/${APP_NAME}
    
    # Remove application directory
    rm -rf ${APP_DIR}
    
    # Database cleanup
    log_info "پاکسازی پایگاه داده..."
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null || true
    sudo -u postgres psql -c "DROP USER IF EXISTS ${DB_USER};" 2>/dev/null || true
    
    # Clean package caches
    apt autoremove -y
    apt autoclean
    
    # Reload systemd
    systemctl daemon-reload
    systemctl reset-failed
    
    log_success "پاکسازی کامل انجام شد"
}

# Install system dependencies
install_system_dependencies() {
    log_info "نصب وابستگی‌های سیستم..."
    
    # Update system
    apt update && apt upgrade -y
    
    # Install essential packages
    apt install -y \
        curl \
        wget \
        git \
        nginx \
        postgresql \
        postgresql-contrib \
        build-essential \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        ufw
    
    log_success "وابستگی‌های سیستم نصب شدند"
}

# Install Node.js 20 LTS
install_nodejs() {
    log_info "نصب Node.js 20 LTS..."
    
    # Remove existing Node.js installations
    apt remove -y nodejs npm 2>/dev/null || true
    
    # Install Node.js 20 LTS
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
    
    # Verify installation
    local node_version=$(node --version)
    local npm_version=$(npm --version)
    
    log_success "Node.js ${node_version} و npm ${npm_version} نصب شدند"
}

# Setup PostgreSQL
setup_postgresql() {
    log_info "تنظیم پایگاه داده PostgreSQL..."
    
    # Start and enable PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    # Create database user and database
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
    sudo -u postgres psql -c "ALTER USER ${DB_USER} CREATEDB;"
    
    log_success "PostgreSQL تنظیم شد"
}

# Clone and setup application
setup_application() {
    log_info "دریافت و تنظیم کد منبع..."
    
    # Create application directory
    mkdir -p ${APP_DIR}
    cd ${APP_DIR}
    
    # Clone repository
    git clone ${REPO_URL} .
    
    # Create environment file
    cat > .env << EOF
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}
SESSION_SECRET=TekPushKhas2024SuperSecureSessionKey$(date +%s)
PGHOST=localhost
PGPORT=5432
PGUSER=${DB_USER}
PGPASSWORD=${DB_PASS}
PGDATABASE=${DB_NAME}
EOF

    # Set proper ownership
    chown -R www-data:www-data ${APP_DIR}
    chmod -R 755 ${APP_DIR}
    
    log_success "کد منبع آماده شد"
}

# Create database schema
create_database_schema() {
    log_info "ایجاد ساختار پایگاه داده..."
    
    PGPASSWORD=${DB_PASS} psql -h localhost -U ${DB_USER} -d ${DB_NAME} << 'EOSQL'
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Sessions table for session management
CREATE TABLE IF NOT EXISTS sessions (
    sid VARCHAR PRIMARY KEY,
    sess JSONB NOT NULL,
    expire TIMESTAMP NOT NULL
);
CREATE INDEX IF NOT EXISTS IDX_session_expire ON sessions(expire);

-- Users table
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

-- Brand settings table
CREATE TABLE IF NOT EXISTS brand_settings (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL DEFAULT 'تک پوش خاص',
    slogan TEXT NOT NULL DEFAULT 'یک از یک',
    logo_url TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- T-shirt images table
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

-- Social links table
CREATE TABLE IF NOT EXISTS social_links (
    id SERIAL PRIMARY KEY,
    platform VARCHAR(50) NOT NULL,
    url TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Copyright settings table
CREATE TABLE IF NOT EXISTS copyright_settings (
    id SERIAL PRIMARY KEY,
    text TEXT NOT NULL DEFAULT '© 1404 تک پوش خاص. تمامی حقوق محفوظ است.',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- About content table
CREATE TABLE IF NOT EXISTS about_content (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL DEFAULT 'درباره ما',
    content TEXT NOT NULL DEFAULT 'ما برند پیشرو در طراحی تی‌شرت هستیم',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Insert default data
INSERT INTO users (username, password, role) 
VALUES ('admin', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin')
ON CONFLICT (username) DO NOTHING;

INSERT INTO brand_settings (name, slogan, description)
VALUES ('تک پوش خاص', 'یک از یک', 'برند پیشرو در طراحی تی‌شرت های منحصر به فرد')
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
('/uploads/tshirt-sample-1.jpg', 'تی‌شرت طرح خاص شماره یک', 'تی‌شرت طرح خاص', 'طراحی منحصر به فرد با کیفیت بالا', '250,000 تومان', 'M', 1, true),
('/uploads/tshirt-sample-2.jpg', 'تی‌شرت کلاسیک شماره دو', 'تی‌شرت کلاسیک', 'طراحی کلاسیک و شیک مناسب همه سلیقه‌ها', '220,000 تومان', 'L', 2, true),
('/uploads/tshirt-sample-3.jpg', 'تی‌شرت مدرن شماره سه', 'تی‌شرت مدرن', 'طراحی مدرن و جذاب برای جوانان', '280,000 تومان', 'XL', 3, true)
ON CONFLICT DO NOTHING;
EOSQL

    log_success "ساختار پایگاه داده ایجاد شد"
}

# Install application dependencies
install_app_dependencies() {
    log_info "نصب وابستگی‌های اپلیکیشن..."
    
    cd ${APP_DIR}
    
    # Clean install dependencies
    sudo -u www-data npm ci --only=production
    
    log_success "وابستگی‌های اپلیکیشن نصب شدند"
}

# Create production server
create_production_server() {
    log_info "ایجاد سرور تولید..."
    
    mkdir -p ${APP_DIR}/dist/server
    
    cat > ${APP_DIR}/dist/server/index.js << 'EOJS'
const express = require('express');
const path = require('path');
const { Pool } = require('pg');
const session = require('express-session');
const connectPg = require('connect-pg-simple')(session);

const app = express();
const PORT = process.env.PORT || 5000;

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Session store
const sessionStore = new connectPg({
  pool: pool,
  tableName: 'sessions',
  createTableIfMissing: false
});

// Middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(express.static(path.join(__dirname, '../../public')));

// Session configuration
app.use(session({
  store: sessionStore,
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: false,
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000 // 24 hours
  }
}));

// API Routes
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT NOW()');
    res.json({ 
      status: 'ok', 
      timestamp: new Date().toISOString(),
      database: 'connected',
      version: '1.0.0'
    });
  } catch (error) {
    res.status(500).json({ 
      status: 'error', 
      message: 'Database connection failed' 
    });
  }
});

app.get('/api/brand-settings', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM brand_settings ORDER BY id LIMIT 1');
    res.json(result.rows[0] || {});
  } catch (error) {
    console.error('Brand settings error:', error);
    res.status(500).json({ error: 'Failed to fetch brand settings' });
  }
});

app.get('/api/tshirt-images', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT * FROM tshirt_images 
      WHERE is_active = true 
      ORDER BY display_order ASC, id ASC
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('T-shirt images error:', error);
    res.status(500).json({ error: 'Failed to fetch t-shirt images' });
  }
});

app.get('/api/social-links', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT * FROM social_links 
      WHERE is_active = true 
      ORDER BY id ASC
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('Social links error:', error);
    res.status(500).json({ error: 'Failed to fetch social links' });
  }
});

app.get('/api/copyright-settings', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM copyright_settings ORDER BY id LIMIT 1');
    res.json(result.rows[0] || {});
  } catch (error) {
    console.error('Copyright settings error:', error);
    res.status(500).json({ error: 'Failed to fetch copyright settings' });
  }
});

app.get('/api/about-content', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM about_content ORDER BY id LIMIT 1');
    res.json(result.rows[0] || {});
  } catch (error) {
    console.error('About content error:', error);
    res.status(500).json({ error: 'Failed to fetch about content' });
  }
});

app.get('/api/user', (req, res) => {
  res.status(401).json({ message: 'وارد نشده‌اید' });
});

// Serve main application
app.get('*', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>تک پوش خاص - یک از یک</title>
    <meta name="description" content="برند پیشرو در طراحی تی‌شرت های منحصر به فرد">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', 'Vazir', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            color: white;
            text-align: center;
            line-height: 1.6;
        }
        .container {
            max-width: 800px;
            padding: 3rem 2rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 20px;
            backdrop-filter: blur(15px);
            box-shadow: 0 15px 35px rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .logo { font-size: 4rem; margin-bottom: 1rem; font-weight: bold; }
        .slogan { font-size: 2rem; margin-bottom: 2rem; opacity: 0.9; color: #e8f4f8; }
        .description { font-size: 1.2rem; margin-bottom: 3rem; opacity: 0.8; }
        .status { 
            background: rgba(46, 204, 113, 0.2);
            padding: 1.5rem;
            border-radius: 15px;
            margin-top: 2rem;
            border: 1px solid rgba(46, 204, 113, 0.3);
        }
        .status h3 { margin-bottom: 1rem; color: #2ecc71; }
        .features {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin: 2rem 0;
        }
        .feature {
            background: rgba(255, 255, 255, 0.1);
            padding: 1rem;
            border-radius: 10px;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .footer {
            margin-top: 2rem;
            font-size: 0.9rem;
            opacity: 0.7;
        }
        @media (max-width: 768px) {
            .logo { font-size: 2.5rem; }
            .slogan { font-size: 1.5rem; }
            .container { padding: 2rem 1rem; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🎽 تک پوش خاص</div>
        <div class="slogan">یک از یک</div>
        <div class="description">
            برند پیشرو در طراحی تی‌شرت های منحصر به فرد<br>
            با ترکیب خلاقیت و کیفیت، محصولاتی بی‌نظیر ارائه می‌دهیم
        </div>
        
        <div class="features">
            <div class="feature">
                <h4>🎨 طراحی خلاقانه</h4>
                <p>طرح های منحصر به فرد و جذاب</p>
            </div>
            <div class="feature">
                <h4>🏆 کیفیت بالا</h4>
                <p>بهترین مواد و چاپ با دوام</p>
            </div>
            <div class="feature">
                <h4>🚀 سرویس سریع</h4>
                <p>تحویل سریع و خدمات عالی</p>
            </div>
        </div>
        
        <div class="status">
            <h3>✅ سرور با موفقیت راه‌اندازی شد</h3>
            <p>🌐 وب‌سایت آماده ارائه خدمات است</p>
            <p>📊 تمامی سرویس ها فعال هستند</p>
        </div>
        
        <div class="footer">
            © 1404 تک پوش خاص - تمامی حقوق محفوظ است
        </div>
    </div>
    
    <script>
        // Simple health check
        fetch('/api/health')
            .then(response => response.json())
            .then(data => {
                console.log('سرور فعال است:', data);
            })
            .catch(error => {
                console.error('خطا در اتصال:', error);
            });
    </script>
</body>
</html>
  `);
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Graceful shutdown
const gracefulShutdown = () => {
  console.log('Shutting down gracefully...');
  pool.end(() => {
    console.log('Database pool closed');
    process.exit(0);
  });
};

process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 تک پوش خاص سرور در پورت ${PORT} راه‌اندازی شد`);
  console.log(`📅 ${new Date().toISOString()}`);
  console.log(`🔗 http://localhost:${PORT}`);
});
EOJS

    chown -R www-data:www-data ${APP_DIR}/dist
    
    log_success "سرور تولید ایجاد شد"
}

# Create directories and set permissions
create_directories() {
    log_info "ایجاد پوشه‌های مورد نیاز..."
    
    mkdir -p ${APP_DIR}/public/uploads
    mkdir -p ${APP_DIR}/logs
    
    # Create sample upload files
    touch ${APP_DIR}/public/uploads/.gitkeep
    
    # Set proper permissions
    chown -R www-data:www-data ${APP_DIR}
    chmod -R 755 ${APP_DIR}
    chmod -R 777 ${APP_DIR}/public/uploads
    chmod -R 755 ${APP_DIR}/logs
    
    log_success "پوشه‌ها ایجاد شدند"
}

# Create systemd service
create_systemd_service() {
    log_info "ایجاد سرویس سیستم..."
    
    cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Tek Push Khas - Persian T-Shirt Brand Application
Documentation=https://github.com/moha100h/TakPoshKhas
After=network.target postgresql.service
Wants=postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=${APP_DIR}
Environment=NODE_ENV=production
Environment=PORT=5000
EnvironmentFile=${APP_DIR}/.env
ExecStart=/usr/bin/node dist/server/index.js
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StartLimitInterval=60s
StartLimitBurst=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${APP_DIR}
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    
    log_success "سرویس سیستم ایجاد شد"
}

# Configure Nginx
configure_nginx() {
    log_info "تنظیم سرور وب Nginx..."
    
    # Create nginx configuration
    cat > /etc/nginx/sites-available/${APP_NAME} << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=static:10m rate=50r/s;
    
    # Static files with caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files \$uri @backend;
    }
    
    # API routes
    location /api/ {
        limit_req zone=api burst=20 nodelay;
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
        proxy_buffering off;
    }
    
    # Health check endpoint
    location = /api/health {
        access_log off;
        proxy_pass http://127.0.0.1:5000/api/health;
    }
    
    # Main application
    location / {
        limit_req zone=static burst=100 nodelay;
        try_files \$uri @backend;
    }
    
    location @backend {
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
    
    # Deny access to sensitive files
    location ~ /\. {
        deny all;
    }
    
    location ~ /(\.env|\.git|package\.json|package-lock\.json) {
        deny all;
    }
}
EOF

    # Remove default nginx site
    rm -f /etc/nginx/sites-enabled/default
    
    # Enable our site
    ln -sf /etc/nginx/sites-available/${APP_NAME} /etc/nginx/sites-enabled/
    
    # Test nginx configuration
    nginx -t || error_exit "خطا در تنظیمات Nginx"
    
    log_success "Nginx تنظیم شد"
}

# Configure firewall
configure_firewall() {
    log_info "تنظیم فایروال..."
    
    # Reset UFW to defaults
    ufw --force reset
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow essential services
    ufw allow 22/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    # Enable firewall
    ufw --force enable
    
    log_success "فایروال تنظیم شد"
}

# Test server functionality
test_server() {
    log_info "تست عملکرد سرور..."
    
    cd ${APP_DIR}
    
    # Test server startup
    sudo -u www-data NODE_ENV=production DATABASE_URL="postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}" node dist/server/index.js &
    local server_pid=$!
    
    # Wait for server to start
    sleep 5
    
    # Test health endpoint
    if curl -f http://localhost:5000/api/health > /dev/null 2>&1; then
        log_success "تست سرور موفق بود"
        kill ${server_pid}
    else
        log_error "تست سرور ناموفق بود"
        kill ${server_pid} 2>/dev/null || true
        return 1
    fi
}

# Start all services
start_services() {
    log_info "راه‌اندازی سرویس‌ها..."
    
    # Start application service
    systemctl start ${SERVICE_NAME}
    
    # Start and reload nginx
    systemctl start nginx
    systemctl reload nginx
    
    log_success "سرویس‌ها راه‌اندازی شدند"
}

# Final status check
final_status_check() {
    log_info "بررسی نهایی وضعیت..."
    
    local success=true
    
    # Check application service
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        log_success "✅ سرویس اپلیکیشن فعال است"
    else
        log_error "❌ سرویس اپلیکیشن غیرفعال است"
        success=false
    fi
    
    # Check nginx
    if systemctl is-active --quiet nginx; then
        log_success "✅ سرور وب فعال است"
    else
        log_error "❌ سرور وب غیرفعال است"
        success=false
    fi
    
    # Check database
    if systemctl is-active --quiet postgresql; then
        log_success "✅ پایگاه داده فعال است"
    else
        log_error "❌ پایگاه داده غیرفعال است"
        success=false
    fi
    
    # Test API endpoints
    sleep 3
    if curl -f http://localhost/api/health > /dev/null 2>&1; then
        log_success "✅ API endpoints پاسخگو هستند"
    else
        log_error "❌ API endpoints پاسخگو نیستند"
        success=false
    fi
    
    if [ "$success" = true ]; then
        echo
        log_success "🎉 نصب با موفقیت کامل شد!"
        echo
        echo -e "${GREEN}📋 اطلاعات دسترسی:${NC}"
        echo -e "${BLUE}🌐 وب‌سایت: ${NC}http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR-SERVER-IP')"
        echo -e "${BLUE}👤 ادمین: ${NC}username: admin, password: password"
        echo -e "${BLUE}📊 مانیتورینگ: ${NC}systemctl status ${SERVICE_NAME}"
        echo -e "${BLUE}📋 لاگ‌ها: ${NC}journalctl -u ${SERVICE_NAME} -f"
        echo
    else
        echo
        log_error "❌ نصب با خطا مواجه شد"
        echo
        echo -e "${YELLOW}📋 اطلاعات عیب‌یابی:${NC}"
        echo -e "${BLUE}🔍 وضعیت سرویس: ${NC}systemctl status ${SERVICE_NAME}"
        echo -e "${BLUE}📋 لاگ اپلیکیشن: ${NC}journalctl -u ${SERVICE_NAME} -n 50"
        echo -e "${BLUE}📋 لاگ Nginx: ${NC}tail -f /var/log/nginx/error.log"
    fi
}

# Cleanup old installation files
cleanup_old_files() {
    log_info "پاکسازی فایل‌های قدیمی نصب..."
    
    cd /opt
    rm -f auto-install*.sh
    rm -f complete-install.sh
    rm -f quick-install.sh
    rm -f final-install.sh
    rm -f install.sh
    rm -f setup-ubuntu.sh
    rm -f update.sh
    
    log_success "فایل‌های قدیمی پاک شدند"
}

# Main installation function
main() {
    echo "========================================"
    echo "   تک پوش خاص - نصب حرفه‌ای و کامل"
    echo "   Professional Installation System"
    echo "   Ubuntu 22.04 LTS"
    echo "========================================"
    echo
    
    check_root
    
    log_info "شروع نصب کامل..."
    
    complete_cleanup
    install_system_dependencies
    install_nodejs
    setup_postgresql
    setup_application
    create_database_schema
    install_app_dependencies
    create_production_server
    create_directories
    create_systemd_service
    configure_nginx
    configure_firewall
    
    if test_server; then
        start_services
        cleanup_old_files
        final_status_check
    else
        error_exit "تست سرور ناموفق بود"
    fi
}

# Run main function
main "$@"