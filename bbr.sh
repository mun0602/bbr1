#!/bin/bash

# Script tối ưu mạng VPS với BBR và các tùy chọn khác
# Tạo bởi: Claude
# Chạy với quyền root: sudo bash script_name.sh

# Hiển thị màu trong terminal
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Hàm hiển thị thông báo
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Kiểm tra quyền root
if [ "$(id -u)" != "0" ]; then
   print_error "Script này cần chạy với quyền root!"
   echo "Vui lòng chạy lại với sudo: sudo bash $0"
   exit 1
fi

# Xác định hệ điều hành
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    print_error "Không thể xác định hệ điều hành."
    exit 1
fi

print_info "Phát hiện hệ điều hành: $OS $VERSION"

# Cập nhật hệ thống
update_system() {
    print_info "Đang cập nhật hệ thống..."
    
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt update -y && apt upgrade -y
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
        yum update -y
    else
        print_warning "Không hỗ trợ cập nhật tự động cho hệ điều hành này."
    fi
}

# Cài đặt các công cụ cần thiết
install_tools() {
    print_info "Đang cài đặt các công cụ cần thiết..."
    
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt install -y curl wget htop iftop iotop net-tools tcpdump ethtool
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
        yum install -y curl wget htop iftop iotop net-tools tcpdump ethtool
    else
        print_warning "Không hỗ trợ cài đặt tự động công cụ cho hệ điều hành này."
    fi
}

# Kích hoạt BBR
enable_bbr() {
    print_info "Đang kích hoạt BBR..."
    
    # Kiểm tra phiên bản kernel
    kernel_version=$(uname -r | cut -d. -f1,2)
    if (( $(echo "$kernel_version < 4.9" | bc -l) )); then
        print_warning "Phiên bản kernel ($kernel_version) quá cũ để hỗ trợ BBR."
        print_info "Đề xuất nâng cấp kernel lên phiên bản 4.9 trở lên."
        
        if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            read -p "Bạn có muốn nâng cấp kernel không? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                apt install -y linux-image-generic
                print_info "Đã cài đặt kernel mới. Vui lòng khởi động lại và chạy lại script này."
                exit 0
            fi
        else
            print_warning "Không hỗ trợ nâng cấp kernel tự động cho hệ điều hành này."
        fi
    else
        # Thêm cấu hình BBR vào sysctl
        if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
            echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        fi
        
        if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        fi
        
        # Áp dụng các thay đổi
        sysctl -p
        
        # Kiểm tra xem BBR đã được kích hoạt chưa
        tcp_congestion_control=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
        if [ "$tcp_congestion_control" == "bbr" ]; then
            print_info "BBR đã được kích hoạt thành công!"
        else
            print_error "Không thể kích hoạt BBR."
        fi
    fi
}

# Tối ưu hóa hạn chế tài nguyên hệ thống
optimize_limits() {
    print_info "Tối ưu hóa hạn chế tài nguyên hệ thống..."
    
    # Tăng giới hạn file mở
    if ! grep -q "fs.file-max" /etc/sysctl.conf; then
        echo "fs.file-max = 65535" >> /etc/sysctl.conf
    fi
    
    # Tăng giới hạn số lượng kết nối
    if ! grep -q "net.core.somaxconn" /etc/sysctl.conf; then
        echo "net.core.somaxconn = 65535" >> /etc/sysctl.conf
    fi
    
    # Tăng kích thước bộ đệm
    if ! grep -q "net.core.rmem_max" /etc/sysctl.conf; then
        echo "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
    fi
    
    if ! grep -q "net.core.wmem_max" /etc/sysctl.conf; then
        echo "net.core.wmem_max = 16777216" >> /etc/sysctl.conf
    fi
    
    # Tăng số lượng kết nối TCP đang chờ xử lý
    if ! grep -q "net.ipv4.tcp_max_syn_backlog" /etc/sysctl.conf; then
        echo "net.ipv4.tcp_max_syn_backlog = 65535" >> /etc/sysctl.conf
    fi
    
    # Tối ưu TCP keepalive
    if ! grep -q "net.ipv4.tcp_keepalive_time" /etc/sysctl.conf; then
        echo "net.ipv4.tcp_keepalive_time = 600" >> /etc/sysctl.conf
    fi
    
    if ! grep -q "net.ipv4.tcp_keepalive_intvl" /etc/sysctl.conf; then
        echo "net.ipv4.tcp_keepalive_intvl = 60" >> /etc/sysctl.conf
    fi
    
    if ! grep -q "net.ipv4.tcp_keepalive_probes" /etc/sysctl.conf; then
        echo "net.ipv4.tcp_keepalive_probes = 5" >> /etc/sysctl.conf
    fi
    
    # Áp dụng các thay đổi
    sysctl -p
    
    # Cập nhật giới hạn trong security limits
    if ! grep -q "* soft nofile 65535" /etc/security/limits.conf; then
        echo "* soft nofile 65535" >> /etc/security/limits.conf
        echo "* hard nofile 65535" >> /etc/security/limits.conf
    fi
    
    print_info "Đã tối ưu hạn chế tài nguyên hệ thống."
}

# Tối ưu cấu hình mạng
optimize_network() {
    print_info "Tối ưu cấu hình mạng..."
    
    # Tắt IPv6 nếu không cần thiết
    if ! grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf; then
        echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
        echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
    fi
    
    # Tối ưu TIME_WAIT
    if ! grep -q "net.ipv4.tcp_tw_reuse" /etc/sysctl.conf; then
        echo "net.ipv4.tcp_tw_reuse = 1" >> /etc/sysctl.conf
    fi
    
    # Tăng kích thước bảng theo dõi kết nối
    if ! grep -q "net.netfilter.nf_conntrack_max" /etc/sysctl.conf; then
        echo "net.netfilter.nf_conntrack_max = 1048576" >> /etc/sysctl.conf
    fi
    
    # Tối ưu bảo mật mạng
    if ! grep -q "net.ipv4.conf.all.rp_filter" /etc/sysctl.conf; then
        echo "net.ipv4.conf.all.rp_filter = 1" >> /etc/sysctl.conf
    fi
    
    if ! grep -q "net.ipv4.conf.default.rp_filter" /etc/sysctl.conf; then
        echo "net.ipv4.conf.default.rp_filter = 1" >> /etc/sysctl.conf
    fi
    
    # Tắt ICMP Redirect
    if ! grep -q "net.ipv4.conf.all.accept_redirects" /etc/sysctl.conf; then
        echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.conf
        echo "net.ipv4.conf.default.accept_redirects = 0" >> /etc/sysctl.conf
    fi
    
    # Áp dụng các thay đổi
    sysctl -p
    
    print_info "Đã tối ưu cấu hình mạng."
}

# Thiết lập lịch định thời gian CPU (CPU Scheduler)
optimize_cpu_scheduler() {
    print_info "Tối ưu lịch định thời gian CPU..."
    
    # Kiểm tra xem cpufrequtils đã được cài đặt chưa
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt install -y cpufrequtils
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
        yum install -y cpufrequtils
    fi
    
    # Thiết lập governor thành performance
    if command -v cpufreq-set &> /dev/null; then
        for cpu in $(ls /sys/devices/system/cpu/ | grep -E '^cpu[0-9]+$'); do
            cpufreq-set -c ${cpu#cpu} -g performance
        done
        print_info "Đã thiết lập CPU governor thành performance."
    else
        print_warning "Không thể thiết lập CPU governor."
    fi
}

# Tạo báo cáo hệ thống
generate_report() {
    print_info "Đang tạo báo cáo hệ thống..."
    
    REPORT_FILE="/root/network_optimization_report.txt"
    
    echo "=== BÁO CÁO TỐI ƯU MẠNG VPS ===" > $REPORT_FILE
    echo "Ngày tạo: $(date)" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    
    echo "=== THÔNG TIN HỆ THỐNG ===" >> $REPORT_FILE
    echo "Hệ điều hành: $OS $VERSION" >> $REPORT_FILE
    echo "Kernel: $(uname -r)" >> $REPORT_FILE
    echo "CPU: $(grep -c processor /proc/cpuinfo) cores" >> $REPORT_FILE
    echo "RAM: $(free -h | grep Mem | awk '{print $2}')" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    
    echo "=== CẤU HÌNH BBR ===" >> $REPORT_FILE
    echo "TCP Congestion Control: $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')" >> $REPORT_FILE
    echo "Default Qdisc: $(sysctl net.core.default_qdisc | awk '{print $3}')" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    
    echo "=== CẤU HÌNH MẠNG ===" >> $REPORT_FILE
    echo "IP Addresses:" >> $REPORT_FILE
    ip addr | grep inet | grep -v "127.0.0.1" | grep -v "::1" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    echo "Bandwidth Test:" >> $REPORT_FILE
    echo "Để kiểm tra băng thông, hãy chạy: speedtest-cli" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    
    echo "=== CÁC THIẾT LẬP TỐI ƯU ===" >> $REPORT_FILE
    grep -E 'net\.' /etc/sysctl.conf >> $REPORT_FILE
    
    print_info "Đã tạo báo cáo tại: $REPORT_FILE"
}

# Chức năng chính
main() {
    print_info "Bắt đầu tối ưu hóa mạng VPS..."
    
    update_system
    install_tools
    enable_bbr
    optimize_limits
    optimize_network
    optimize_cpu_scheduler
    generate_report
    
    print_info "Tối ưu hóa mạng VPS hoàn tất!"
    print_info "Bạn nên khởi động lại hệ thống để áp dụng tất cả các thay đổi."
    read -p "Bạn có muốn khởi động lại ngay không? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Đang khởi động lại hệ thống..."
        reboot
    else
        print_info "Hãy khởi động lại hệ thống khi thuận tiện."
    fi
}

# Chạy chương trình
main
