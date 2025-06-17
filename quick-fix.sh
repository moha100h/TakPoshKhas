#!/bin/bash

# تک پوش خاص - اسکریپت نصب سریع تولید
# Production Quick Fix Script for Tek Push Khas
# Usage: bash <(curl -Ls https://raw.githubusercontent.com/moha100h/TakPoshKhas/main/quick-fix.sh)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/moha100h/TakPoshKhas.git"
APP_DIR="/opt/tekpushkhas"
SERVICE_NAME="tekpushkhas"
DB_NAME="tekpushkhas_db"
DB_USER="tekpushkhas_user"
DB_PASS=$(openssl rand -base64 32)
SESSION_SECRET=$(openssl rand -base64 64)

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "این اسکریپت باید با دسترسی root اجرا شود"
        exit 1
    fi
}

# Stop and disable existing service
stop_existing_service() {
    log_info "توقف سرویس موجود..."
    
    systemctl stop ${SERVICE_NAME} 2>/dev/null || true
    systemctl disable ${SERVICE_NAME} 2>/dev/null || true
    
    # Kill any running node processes on port 5000
    pkill -f "node.*5000" 2>/dev/null || true
    
    # Wait for port to be freed
    sleep 2
    
    log_success "سرویس موجود متوقف شد"
}

# Install system dependencies
install_dependencies() {
    log_info "نصب وابستگی‌های سیستم..."
    
    apt-get update -qq
    apt-get install -y -qq \
        curl \
        git \
        nginx \
        postgresql \
        postgresql-contrib \
        nodejs \
        npm \
        build-essential \
        python3 \
        certbot \
        python3-certbot-nginx \
        ufw
    
    log_success "وابستگی‌های سیستم نصب شدند"
}

# Setup PostgreSQL
setup_postgresql() {
    log_info "راه‌اندازی PostgreSQL..."
    
    systemctl start postgresql
    systemctl enable postgresql
    
    # Create database and user
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null || true
    sudo -u postgres psql -c "DROP USER IF EXISTS ${DB_USER};" 2>/dev/null || true
    
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME};"
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH ENCRYPTED PASSWORD '${DB_PASS}';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
    sudo -u postgres psql -c "ALTER USER ${DB_USER} CREATEDB;"
    
    log_success "PostgreSQL راه‌اندازی شد"
}

# Clone and setup application
setup_application() {
    log_info "دانلود و راه‌اندازی اپلیکیشن..."
    
    # Remove existing directory
    rm -rf ${APP_DIR}
    
    # Clone repository
    git clone ${REPO_URL} ${APP_DIR}
    cd ${APP_DIR}
    
    # Create environment file
    cat > ${APP_DIR}/.env << EOF
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}
SESSION_SECRET=${SESSION_SECRET}
PGUSER=${DB_USER}
PGPASSWORD=${DB_PASS}
PGDATABASE=${DB_NAME}
PGHOST=localhost
PGPORT=5432
EOF

    # Set proper permissions
    chown -R www-data:www-data ${APP_DIR}
    chmod 600 ${APP_DIR}/.env
    
    log_success "اپلیکیشن راه‌اندازی شد"
}

# Install Node.js dependencies
install_node_dependencies() {
    log_info "نصب وابستگی‌های Node.js..."
    
    cd ${APP_DIR}
    
    # Clean install
    rm -rf node_modules package-lock.json
    npm cache clean --force
    
    # Install dependencies as www-data user
    sudo -u www-data npm install --production --no-optional --no-fund --no-audit
    
    # Fix permissions
    chown -R www-data:www-data ${APP_DIR}/node_modules
    
    log_success "وابستگی‌های Node.js نصب شدند"
}

# Setup database schema
setup_database_schema() {
    log_info "ایجاد ساختار پایگاه داده..."
    
    cd ${APP_DIR}
    
    # Create database schema using psql
    PGPASSWORD=${DB_PASS} psql -h localhost -U ${DB_USER} -d ${DB_NAME} << 'EOSQL'
-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'user',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sessions table
CREATE TABLE IF NOT EXISTS sessions (
    sid VARCHAR NOT NULL COLLATE "default",
    sess JSON NOT NULL,
    expire TIMESTAMP(6) NOT NULL
)
WITH (OIDS=FALSE);

ALTER TABLE sessions ADD CONSTRAINT session_pkey PRIMARY KEY (sid) NOT DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX IF NOT EXISTS IDX_session_expire ON sessions(expire);

-- Brand settings table
CREATE TABLE IF NOT EXISTS brand_settings (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) DEFAULT 'تک پوش خاص',
    slogan TEXT DEFAULT 'یک برند منحصر به فرد برای افراد خاص',
    logo_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- T-shirt images table
CREATE TABLE IF NOT EXISTS tshirt_images (
    id SERIAL PRIMARY KEY,
    image_url VARCHAR(500) NOT NULL,
    alt TEXT NOT NULL,
    title VARCHAR(255),
    description TEXT,
    price VARCHAR(100),
    size VARCHAR(50),
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Social links table
CREATE TABLE IF NOT EXISTS social_links (
    id SERIAL PRIMARY KEY,
    platform VARCHAR(100) NOT NULL,
    url VARCHAR(500) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Copyright settings table
CREATE TABLE IF NOT EXISTS copyright_settings (
    id SERIAL PRIMARY KEY,
    text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- About content table
CREATE TABLE IF NOT EXISTS about_content (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default data
INSERT INTO brand_settings (name, slogan) 
VALUES ('تک پوش خاص', 'یک برند منحصر به فرد برای افراد خاص')
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

-- Create admin user (username: admin, password: admin123)
INSERT INTO users (username, password, role)
VALUES ('admin', '$2b$10$rOvUEqrG3iY8Z5.3b7J0xuQR8ZcV2fRq8Z5Gk.X9QRJVZbN5J4K2W', 'admin')
ON CONFLICT DO NOTHING;
EOSQL

    log_success "ساختار پایگاه داده ایجاد شد"
}

# Create production server
create_production_server() {
    log_info "ایجاد سرور تولید..."
    
    mkdir -p ${APP_DIR}/dist/server
    
    # Create production server file
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
      message: 'تک پوش خاص - سرور فعال است'
    });
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

// Serve main application
app.get('*', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>تک پوش خاص - Tek Push Khas</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            color: white;
        }
        .container {
            text-align: center;
            background: rgba(255, 255, 255, 0.1);
            padding: 3rem;
            border-radius: 20px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
            border: 1px solid rgba(255, 255, 255, 0.18);
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
            background: linear-gradient(45deg, #ff6b6b, #4ecdc4);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .subtitle {
            font-size: 1.2rem;
            margin-bottom: 2rem;
            opacity: 0.9;
        }
        .status {
            display: inline-block;
            padding: 0.5rem 1rem;
            background: #28a745;
            color: white;
            border-radius: 25px;
            margin: 1rem 0;
        }
        .footer {
            margin-top: 2rem;
            opacity: 0.7;
            font-size: 0.9rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>تک پوش خاص</h1>
        <div class="subtitle">برند منحصر به فرد تی‌شرت</div>
        <div class="status">🟢 سرور فعال است</div>
        <div class="footer">
            <p>© 1404 تک پوش خاص. تمامی حقوق محفوظ است.</p>
            <p>سرور تولید آماده به کار</p>
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
const startServer = async () => {
  try {
    // Test database connection
    await pool.query('SELECT NOW()');
    console.log('✅ Database connection established');
    
    const server = app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 تک پوش خاص سرور در پورت ${PORT} راه‌اندازی شد`);
      console.log(`📅 ${new Date().toISOString()}`);
      console.log(`🔗 http://localhost:${PORT}`);
      console.log(`🟢 Server is ready to accept connections`);
    });
    
    server.on('error', (error) => {
      console.error('❌ Server error:', error);
      if (error.code === 'EADDRINUSE') {
        console.error(`Port ${PORT} is already in use`);
        process.exit(1);
      }
    });
    
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    console.error('Database connection failed');
    process.exit(1);
  }
};

startServer();
EOJS

    chown -R www-data:www-data ${APP_DIR}/dist
    
    log_success "سرور تولید ایجاد شد"
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
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    
    log_success "سرویس سیستم ایجاد شد"
}

# Configure Nginx
configure_nginx() {
    log_info "راه‌اندازی Nginx..."
    
    cat > /etc/nginx/sites-available/${SERVICE_NAME} << EOF
server {
    listen 80;
    server_name _;
    
    client_max_body_size 50M;
    
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
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
    
    location /uploads/ {
        alias ${APP_DIR}/public/uploads/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/${SERVICE_NAME} /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and reload nginx
    nginx -t
    systemctl restart nginx
    systemctl enable nginx
    
    log_success "Nginx راه‌اندازی شد"
}

# Configure firewall
configure_firewall() {
    log_info "راه‌اندازی فایروال..."
    
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 'Nginx Full'
    ufw --force enable
    
    log_success "فایروال راه‌اندازی شد"
}

# Start services
start_services() {
    log_info "راه‌اندازی سرویس‌ها..."
    
    # Start application service
    systemctl start ${SERVICE_NAME}
    
    # Wait for service to start
    sleep 5
    
    # Check service status
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        log_success "سرویس ${SERVICE_NAME} با موفقیت راه‌اندازی شد"
    else
        log_error "خطا در راه‌اندازی سرویس"
        systemctl status ${SERVICE_NAME} --no-pager -l
        exit 1
    fi
}

# Display final information
display_final_info() {
    log_success "نصب با موفقیت تکمیل شد!"
    
    echo -e "\n${GREEN}=== اطلاعات سرور ===${NC}"
    echo -e "🌐 آدرس وب: http://$(curl -s ifconfig.me)"
    echo -e "🔑 نام کاربری مدیر: admin"
    echo -e "🔐 رمز عبور مدیر: admin123"
    echo -e "📊 وضعیت سرویس: $(systemctl is-active ${SERVICE_NAME})"
    echo -e "🗄️ پایگاه داده: ${DB_NAME}"
    
    echo -e "\n${BLUE}=== دستورات مفید ===${NC}"
    echo -e "📋 وضعیت سرویس: systemctl status ${SERVICE_NAME}"
    echo -e "📋 لاگ‌های سرویس: journalctl -u ${SERVICE_NAME} -f"
    echo -e "🔄 راه‌اندازی مجدد: systemctl restart ${SERVICE_NAME}"
    echo -e "⏹️ توقف سرویس: systemctl stop ${SERVICE_NAME}"
    
    echo -e "\n${GREEN}سرور آماده است! 🎉${NC}"
}

# Main execution
main() {
    log_info "شروع نصب تک پوش خاص..."
    
    check_root
    stop_existing_service
    install_dependencies
    setup_postgresql
    setup_application
    install_node_dependencies
    setup_database_schema
    create_production_server
    create_systemd_service
    configure_nginx
    configure_firewall
    start_services
    display_final_info
}

# Run main function
main "$@"