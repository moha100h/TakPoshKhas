#!/bin/bash

# تک پوش خاص - بررسی و تأیید استقرار
# Deployment Verification Script

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly APP_NAME="tek-push-khas"
readonly SERVICE_NAME="${APP_NAME}"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check system services
check_services() {
    log_info "بررسی وضعیت سرویس‌ها..."
    
    local all_good=true
    
    # Check PostgreSQL
    if systemctl is-active --quiet postgresql; then
        log_success "✓ PostgreSQL فعال است"
    else
        log_error "✗ PostgreSQL غیرفعال است"
        all_good=false
    fi
    
    # Check Nginx
    if systemctl is-active --quiet nginx; then
        log_success "✓ Nginx فعال است"
    else
        log_error "✗ Nginx غیرفعال است"
        all_good=false
    fi
    
    # Check Application Service
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        log_success "✓ سرویس اپلیکیشن فعال است"
    else
        log_error "✗ سرویس اپلیکیشن غیرفعال است"
        all_good=false
    fi
    
    return $($all_good && echo 0 || echo 1)
}

# Check API endpoints
check_endpoints() {
    log_info "بررسی API endpoints..."
    
    local base_url="http://localhost"
    local all_good=true
    
    # Health check
    if curl -f "${base_url}/api/health" > /dev/null 2>&1; then
        log_success "✓ Health endpoint پاسخگو است"
    else
        log_error "✗ Health endpoint پاسخگو نیست"
        all_good=false
    fi
    
    # Brand settings
    if curl -f "${base_url}/api/brand-settings" > /dev/null 2>&1; then
        log_success "✓ Brand settings endpoint پاسخگو است"
    else
        log_error "✗ Brand settings endpoint پاسخگو نیست"
        all_good=false
    fi
    
    # T-shirt images
    if curl -f "${base_url}/api/tshirt-images" > /dev/null 2>&1; then
        log_success "✓ T-shirt images endpoint پاسخگو است"
    else
        log_error "✗ T-shirt images endpoint پاسخگو نیست"
        all_good=false
    fi
    
    # Social links
    if curl -f "${base_url}/api/social-links" > /dev/null 2>&1; then
        log_success "✓ Social links endpoint پاسخگو است"
    else
        log_error "✗ Social links endpoint پاسخگو نیست"
        all_good=false
    fi
    
    # Copyright settings
    if curl -f "${base_url}/api/copyright-settings" > /dev/null 2>&1; then
        log_success "✓ Copyright settings endpoint پاسخگو است"
    else
        log_error "✗ Copyright settings endpoint پاسخگو نیست"
        all_good=false
    fi
    
    return $($all_good && echo 0 || echo 1)
}

# Check database connectivity
check_database() {
    log_info "بررسی اتصال پایگاه داده..."
    
    # Try to connect as application user
    if sudo -u postgres psql -d tekpushdb -c "SELECT COUNT(*) FROM users;" > /dev/null 2>&1; then
        log_success "✓ اتصال پایگاه داده موفق است"
        return 0
    else
        log_error "✗ اتصال پایگاه داده ناموفق است"
        return 1
    fi
}

# Check file permissions
check_permissions() {
    log_info "بررسی دسترسی فایل‌ها..."
    
    local app_dir="/opt/${APP_NAME}"
    
    if [ -d "${app_dir}" ]; then
        local owner=$(stat -c '%U' "${app_dir}")
        if [ "$owner" = "www-data" ]; then
            log_success "✓ دسترسی فایل‌ها صحیح است"
            return 0
        else
            log_error "✗ دسترسی فایل‌ها نادرست است (مالک: $owner)"
            return 1
        fi
    else
        log_error "✗ پوشه اپلیکیشن یافت نشد"
        return 1
    fi
}

# Check port availability
check_ports() {
    log_info "بررسی پورت‌ها..."
    
    # Check if port 80 is listening
    if netstat -tuln | grep ":80 " > /dev/null 2>&1; then
        log_success "✓ پورت 80 در حال گوش دادن است"
    else
        log_error "✗ پورت 80 در حال گوش دادن نیست"
        return 1
    fi
    
    # Check if port 5000 is listening
    if netstat -tuln | grep ":5000 " > /dev/null 2>&1; then
        log_success "✓ پورت 5000 در حال گوش دادن است"
    else
        log_error "✗ پورت 5000 در حال گوش دادن نیست"
        return 1
    fi
    
    return 0
}

# Performance test
performance_test() {
    log_info "تست عملکرد..."
    
    local base_url="http://localhost"
    
    # Simple response time test
    local response_time=$(curl -o /dev/null -s -w '%{time_total}' "${base_url}/api/health")
    
    if (( $(echo "${response_time} < 1.0" | bc -l) )); then
        log_success "✓ زمان پاسخ مناسب است (${response_time}s)"
    else
        log_warning "⚠ زمان پاسخ کند است (${response_time}s)"
    fi
}

# Show system resources
show_resources() {
    log_info "منابع سیستم:"
    
    # Memory usage
    local mem_total=$(free -h | awk '/^Mem:/ {print $2}')
    local mem_used=$(free -h | awk '/^Mem:/ {print $3}')
    echo "  RAM: ${mem_used} / ${mem_total}"
    
    # Disk usage
    local disk_usage=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
    echo "  Disk: ${disk_usage}"
    
    # CPU load
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}')
    echo "  Load:${cpu_load}"
}

# Show application logs
show_logs() {
    log_info "آخرین لاگ‌های اپلیکیشن:"
    echo "----------------------------------------"
    journalctl -u ${SERVICE_NAME} -n 10 --no-pager
    echo "----------------------------------------"
}

# Main verification function
main() {
    echo "========================================"
    echo "     تک پوش خاص - بررسی استقرار"
    echo "   Deployment Verification System"
    echo "========================================"
    echo
    
    local overall_status=true
    
    # Run all checks
    check_services || overall_status=false
    echo
    check_database || overall_status=false
    echo
    check_permissions || overall_status=false
    echo
    check_ports || overall_status=false
    echo
    check_endpoints || overall_status=false
    echo
    performance_test
    echo
    show_resources
    echo
    
    # Final result
    if [ "$overall_status" = true ]; then
        echo
        log_success "🎉 استقرار کاملاً موفق است!"
        echo
        echo -e "${GREEN}📋 اطلاعات دسترسی:${NC}"
        echo -e "${BLUE}🌐 وب‌سایت: ${NC}http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR-SERVER-IP')"
        echo -e "${BLUE}👤 ادمین: ${NC}username: admin, password: password"
        echo -e "${BLUE}📊 مانیتورینگ: ${NC}systemctl status ${SERVICE_NAME}"
        echo -e "${BLUE}📋 لاگ‌ها: ${NC}journalctl -u ${SERVICE_NAME} -f"
        echo
        echo -e "${GREEN}✅ همه بررسی‌ها موفق بودند${NC}"
    else
        echo
        log_error "❌ مشکلاتی در استقرار وجود دارد"
        echo
        echo -e "${YELLOW}📋 برای عیب‌یابی:${NC}"
        echo -e "${BLUE}🔍 وضعیت سرویس‌ها: ${NC}systemctl status ${SERVICE_NAME} postgresql nginx"
        echo -e "${BLUE}📋 لاگ‌های مفصل: ${NC}journalctl -u ${SERVICE_NAME} -f"
        echo -e "${BLUE}🔧 راه‌اندازی مجدد: ${NC}systemctl restart ${SERVICE_NAME}"
        echo
        show_logs
    fi
}

# Run verification
main "$@"