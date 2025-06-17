#!/bin/bash

# تک پوش خاص - اسکریپت تأیید نصب
# Deployment Verification Script for Tek Push Khas
# Usage: bash verify-deployment.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="tekpushkhas"
PORT=5000
HEALTH_ENDPOINT="http://localhost:${PORT}/api/health"

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

# Check system requirements
check_system() {
    log_info "بررسی سیستم..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "این اسکریپت باید با دسترسی root اجرا شود"
        exit 1
    fi
    
    # Check Ubuntu version
    if ! command -v lsb_release &> /dev/null; then
        log_warning "نسخه سیستم عامل قابل تشخیص نیست"
    else
        OS_VERSION=$(lsb_release -d | cut -f2)
        log_info "سیستم عامل: $OS_VERSION"
    fi
    
    # Check available memory
    MEMORY=$(free -h | awk '/^Mem:/ {print $2}')
    log_info "حافظه دردسترس: $MEMORY"
    
    # Check disk space
    DISK_SPACE=$(df -h / | awk 'NR==2 {print $4}')
    log_info "فضای دیسک دردسترس: $DISK_SPACE"
    
    log_success "بررسی سیستم تکمیل شد"
}

# Verify service status
check_service() {
    log_info "بررسی وضعیت سرویس..."
    
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        log_success "سرویس ${SERVICE_NAME} فعال است"
        
        # Get service uptime
        UPTIME=$(systemctl show ${SERVICE_NAME} --property=ActiveEnterTimestamp | cut -d= -f2)
        log_info "زمان شروع سرویس: $UPTIME"
        
        # Get service PID
        PID=$(systemctl show ${SERVICE_NAME} --property=MainPID | cut -d= -f2)
        log_info "شناسه فرآیند: $PID"
        
    else
        log_error "سرویس ${SERVICE_NAME} غیرفعال است"
        
        # Show service status
        log_info "وضعیت سرویس:"
        systemctl status ${SERVICE_NAME} --no-pager -l || true
        
        # Show recent logs
        log_info "آخرین لاگ‌ها:"
        journalctl -u ${SERVICE_NAME} --no-pager -n 20 || true
        
        return 1
    fi
}

# Check port availability
check_port() {
    log_info "بررسی پورت ${PORT}..."
    
    if netstat -tuln | grep -q ":${PORT} "; then
        log_success "پورت ${PORT} در حال استفاده است"
        
        # Show process using the port
        PROCESS=$(netstat -tulnp | grep ":${PORT} " | awk '{print $7}' | head -1)
        log_info "فرآیند استفاده‌کننده از پورت: $PROCESS"
        
    else
        log_error "پورت ${PORT} در دسترس نیست"
        return 1
    fi
}

# Test API health endpoint
test_api() {
    log_info "تست API..."
    
    # Test health endpoint
    if curl -f -s "${HEALTH_ENDPOINT}" > /dev/null; then
        log_success "API سالم است"
        
        # Get API response
        RESPONSE=$(curl -s "${HEALTH_ENDPOINT}")
        log_info "پاسخ API: $RESPONSE"
        
    else
        log_error "API پاسخ نمی‌دهد"
        
        # Try to get more details
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${HEALTH_ENDPOINT}" || echo "000")
        log_info "کد HTTP: $HTTP_CODE"
        
        return 1
    fi
}

# Check database connection
check_database() {
    log_info "بررسی اتصال پایگاه داده..."
    
    if systemctl is-active --quiet postgresql; then
        log_success "PostgreSQL فعال است"
        
        # Check database connection
        if sudo -u postgres psql -c "SELECT version();" > /dev/null 2>&1; then
            log_success "اتصال به پایگاه داده برقرار است"
        else
            log_error "خطا در اتصال به پایگاه داده"
            return 1
        fi
        
    else
        log_error "PostgreSQL غیرفعال است"
        return 1
    fi
}

# Check Nginx configuration
check_nginx() {
    log_info "بررسی Nginx..."
    
    if systemctl is-active --quiet nginx; then
        log_success "Nginx فعال است"
        
        # Test Nginx configuration
        if nginx -t > /dev/null 2>&1; then
            log_success "تنظیمات Nginx صحیح است"
        else
            log_error "خطا در تنظیمات Nginx"
            nginx -t
            return 1
        fi
        
    else
        log_error "Nginx غیرفعال است"
        return 1
    fi
}

# Check firewall settings
check_firewall() {
    log_info "بررسی فایروال..."
    
    if command -v ufw &> /dev/null; then
        UFW_STATUS=$(ufw status | head -1)
        log_info "وضعیت فایروال: $UFW_STATUS"
        
        if ufw status | grep -q "80/tcp"; then
            log_success "پورت 80 در فایروال باز است"
        else
            log_warning "پورت 80 در فایروال بسته است"
        fi
        
        if ufw status | grep -q "443/tcp"; then
            log_success "پورت 443 در فایروال باز است"
        else
            log_warning "پورت 443 در فایروال بسته است"
        fi
        
    else
        log_warning "UFW نصب نیست"
    fi
}

# Performance check
check_performance() {
    log_info "بررسی عملکرد..."
    
    # CPU usage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    log_info "استفاده از CPU: ${CPU_USAGE}%"
    
    # Memory usage
    MEMORY_USAGE=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
    log_info "استفاده از حافظه: ${MEMORY_USAGE}%"
    
    # Load average
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
    log_info "میانگین بار سیستم:$LOAD_AVG"
    
    # Check if service is using too much resources
    if [ -n "$PID" ] && [ "$PID" != "0" ]; then
        SERVICE_CPU=$(ps -p $PID -o %cpu= 2>/dev/null || echo "0")
        SERVICE_MEM=$(ps -p $PID -o %mem= 2>/dev/null || echo "0")
        log_info "استفاده سرویس از CPU: ${SERVICE_CPU}%"
        log_info "استفاده سرویس از حافظه: ${SERVICE_MEM}%"
    fi
}

# Generate report
generate_report() {
    log_info "تولید گزارش نهایی..."
    
    echo -e "\n${GREEN}=== گزارش وضعیت سرور تک پوش خاص ===${NC}"
    echo -e "📅 تاریخ: $(date)"
    echo -e "🌐 آدرس: http://$(curl -s ifconfig.me 2>/dev/null || echo 'نامشخص')"
    echo -e "⚡ پورت: $PORT"
    
    echo -e "\n${BLUE}=== وضعیت سرویس‌ها ===${NC}"
    echo -e "🔥 ${SERVICE_NAME}: $(systemctl is-active ${SERVICE_NAME})"
    echo -e "🗄️ PostgreSQL: $(systemctl is-active postgresql)"
    echo -e "🌐 Nginx: $(systemctl is-active nginx)"
    
    echo -e "\n${BLUE}=== منابع سیستم ===${NC}"
    echo -e "💾 حافظه: ${MEMORY_USAGE}% استفاده شده"
    echo -e "⚙️ CPU: ${CPU_USAGE}% استفاده شده"
    
    echo -e "\n${BLUE}=== دستورات مفید ===${NC}"
    echo -e "📋 وضعیت سرویس: systemctl status ${SERVICE_NAME}"
    echo -e "📋 لاگ‌های سرویس: journalctl -u ${SERVICE_NAME} -f"
    echo -e "🔄 راه‌اندازی مجدد: systemctl restart ${SERVICE_NAME}"
    echo -e "⏹️ توقف سرویس: systemctl stop ${SERVICE_NAME}"
    
    if [ $OVERALL_STATUS -eq 0 ]; then
        echo -e "\n${GREEN}✅ تمامی بررسی‌ها موفقیت‌آمیز بودند${NC}"
        echo -e "${GREEN}🎉 سرور آماده و در حال اجرا است${NC}"
    else
        echo -e "\n${RED}❌ برخی بررسی‌ها ناموفق بودند${NC}"
        echo -e "${YELLOW}⚠️ لطفاً مشکلات را بررسی و رفع کنید${NC}"
    fi
}

# Main execution
main() {
    log_info "شروع بررسی نصب تک پوش خاص..."
    
    OVERALL_STATUS=0
    
    check_system || OVERALL_STATUS=1
    check_service || OVERALL_STATUS=1
    check_port || OVERALL_STATUS=1
    test_api || OVERALL_STATUS=1
    check_database || OVERALL_STATUS=1
    check_nginx || OVERALL_STATUS=1
    check_firewall || OVERALL_STATUS=1
    check_performance || OVERALL_STATUS=1
    
    generate_report
    
    exit $OVERALL_STATUS
}

# Run main function
main "$@"