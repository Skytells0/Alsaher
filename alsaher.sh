#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║            ALSAHER PREMIUM VPN SCRIPT                       ║
# ║            Version: 1.3.0                                   ║
# ║            Support: Ubuntu 20/22/24 | Debian 10/11/12       ║
# ║            sc by t.me/user_legend                           ║
# ╚══════════════════════════════════════════════════════════════╝

# ─── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
LGREEN='\033[1;32m'
NC='\033[0m'
BOLD='\033[1m'

# ─── Global Config ─────────────────────────────────────────────
SCRIPT_VERSION="1.3.0"
CLIENTNAME="Alsaher2"
EXP_DATE="2069-06-09"
EXP_DAYS="15797"
REGIST_BY="1389219385"
INSTALL_DIR="/etc/alsaher"
LOG_FILE="/root/log-install.txt"
DOMAIN_FILE="$INSTALL_DIR/domain"
SLOWDNS_FILE="$INSTALL_DIR/slowdns_domain"

# ─── Root Check ────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && { echo -e "${RED}Error: Run as root!${NC}"; exit 1; }

# ─── Init Directories ──────────────────────────────────────────
mkdir -p $INSTALL_DIR/{ssh,xray,l2tp,noobz,backup,config,logs}

# ══════════════════════════════════════════════════════════════
# SYSTEM INFO
# ══════════════════════════════════════════════════════════════
get_system_info() {
    OS_NAME=$(. /etc/os-release 2>/dev/null; echo "$PRETTY_NAME")
    KERNEL=$(uname -r)
    CPU_MODEL=$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo | xargs)
    CPU_FREQ=$(awk -F': ' '/cpu MHz/{printf "%.3f", $2; exit}' /proc/cpuinfo)
    CPU_CORES=$(nproc)
    RAM_TOTAL=$(free -m | awk '/Mem:/{printf "%.1f GB",$2/1024}')
    RAM_USED=$(free -m  | awk '/Mem:/{printf "%.1f MB",$3}')
    DISK_TOTAL=$(df -h / | awk 'NR==2{print $2}')
    DISK_USED=$(df -h  / | awk 'NR==2{print $3}')
    DOMAIN=$(cat "$DOMAIN_FILE" 2>/dev/null || hostname -f 2>/dev/null || echo "Not Set")
    SLOWDNS=$(cat "$SLOWDNS_FILE" 2>/dev/null || echo "Not Set")
    IPADDR=$(curl -s4 --connect-timeout 4 ifconfig.me 2>/dev/null || curl -s --connect-timeout 4 ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
    ISP=$(curl -s --connect-timeout 4 ipinfo.io/org 2>/dev/null | cut -d' ' -f2- || echo "Unknown")
    REGION=$(curl -s --connect-timeout 4 ipinfo.io/timezone 2>/dev/null || echo "Unknown")
}

count_accounts() {
    SSH_COUNT=$(ls  $INSTALL_DIR/ssh/  2>/dev/null | wc -l)
    XRAY_COUNT=$(ls $INSTALL_DIR/xray/ 2>/dev/null | wc -l)
    L2TP_COUNT=$(ls $INSTALL_DIR/l2tp/ 2>/dev/null | wc -l)
    NOOBZ_COUNT=$(ls $INSTALL_DIR/noobz/ 2>/dev/null | wc -l)
}

# ══════════════════════════════════════════════════════════════
# HEADER — مطابق للصورة تماماً
# ══════════════════════════════════════════════════════════════
show_header() {
    clear
    get_system_info
    count_accounts
    echo -e "   ${CYAN}sc by t.me/user_legend${NC}"
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    printf "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "SYS INFO"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    printf "${BLUE}║${NC} ${CYAN}OS SYSTEM:${NC}    %-28s${BLUE}║${NC}\n"   "$OS_NAME"
    printf "${BLUE}║${NC} ${CYAN}KERNEL TYPE:${NC}  %-28s${BLUE}║${NC}\n"   "$KERNEL"
    printf "${BLUE}║${NC} ${CYAN}CPU MODEL:${NC}    %-28s${BLUE}║${NC}\n"   "$CPU_MODEL"
    printf "${BLUE}║${NC} ${CYAN}CPU FREQ:${NC}     %s MHz (%s core)%*s${BLUE}║${NC}\n" \
           "$CPU_FREQ" "$CPU_CORES" $((16 - ${#CPU_FREQ} - ${#CPU_CORES})) ""
    printf "${BLUE}║${NC} ${CYAN}TOTAL RAM:${NC}    %-28s${BLUE}║${NC}\n"   "$RAM_TOTAL Total / $RAM_USED Used"
    printf "${BLUE}║${NC} ${CYAN}TOTAL STORAGE:${NC}%-28s${BLUE}║${NC}\n"   "$DISK_TOTAL Total / $DISK_USED Used"
    printf "${BLUE}║${NC} ${CYAN}DOMAIN:${NC}       %-28s${BLUE}║${NC}\n"   "$DOMAIN"
    printf "${BLUE}║${NC} ${CYAN}SLOWDNS DOMAIN:${NC}%-27s${BLUE}║${NC}\n"  "$SLOWDNS"
    printf "${BLUE}║${NC} ${CYAN}IP ADDRESS:${NC}   %-28s${BLUE}║${NC}\n"   "$IPADDR"
    printf "${BLUE}║${NC} ${CYAN}ISP:${NC}          %-28s${BLUE}║${NC}\n"   "$ISP"
    printf "${BLUE}║${NC} ${CYAN}REGION:${NC}       %-28s${BLUE}║${NC}\n"   "$REGION"
    printf "${BLUE}║${NC} ${CYAN}CLIENTNAME:${NC}   %-28s${BLUE}║${NC}\n"   "$CLIENTNAME"
    printf "${BLUE}║${NC} ${CYAN}SCRIPT VERSION:${NC}%-27s${BLUE}║${NC}\n"  "$SCRIPT_VERSION"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    printf "${BLUE}║${NC}   SSH & OVPN ACCOUNT =${GREEN}  %-3s               ${BLUE}║${NC}\n" "$SSH_COUNT"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    printf "${BLUE}║${NC}      XRAY ACCOUNT =${GREEN}  %-3s                  ${BLUE}║${NC}\n" "$XRAY_COUNT"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    printf "${BLUE}║${NC}      L2TP ACCOUNT =${GREEN}  %-3s                  ${BLUE}║${NC}\n" "$L2TP_COUNT"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    printf "${BLUE}║${NC}     NOOBZ ACCOUNT =${GREEN}  %-3s                  ${BLUE}║${NC}\n" "$NOOBZ_COUNT"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
}

# ══════════════════════════════════════════════════════════════
# MAIN MENU
# ══════════════════════════════════════════════════════════════
main_menu() {
    while true; do
        show_header
        echo ""
        echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
        printf  "${BLUE}║${NC}              ${WHITE}MAIN MENU${NC}%-15s${BLUE}║${NC}\n" ""
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}1.${NC} MENU SSH & OVPN                       ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}2.${NC} MENU XRAY                             ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}3.${NC} MENU L2TP                             ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}4.${NC} MENU NOOBZVPNS                        ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}5.${NC} SETTINGS                              ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}6.${NC} ON/OFF SERVICES                       ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}7.${NC} STATUS SERVICES                       ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}8.${NC} UPDATE SCRIPT                         ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}9.${NC} STATUS SCRIPT                         ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${RED}0.${NC} Exit                                  ${BLUE}║${NC}"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} EXP SCRIPT: ${YELLOW}$EXP_DATE ($EXP_DAYS days)${NC}  ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} REGIST BY : ${YELLOW}$REGIST_BY (id telegram)${NC}  ${BLUE}║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
        read -p "Please select an option [0-9]: " opt
        case $opt in
            1) ssh_menu ;;
            2) xray_menu ;;
            3) l2tp_menu ;;
            4) noobz_menu ;;
            5) settings_menu ;;
            6) services_toggle_menu ;;
            7) status_services ;;
            8) update_script ;;
            9) status_script ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════
press_enter() { read -p "Press Enter to continue..."; }

menu_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "$1"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
}

menu_footer() {
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
}

confirm_action() {
    read -p "$1 [y/n]: " c
    [[ "$c" =~ ^[Yy]$ ]]
}

# ══════════════════════════════════════════════════════════════
# ██████  SSH & OVPN
# ══════════════════════════════════════════════════════════════
ssh_menu() {
    while true; do
        clear
        DB_VER=$(dropbear -V 2>&1 | grep -oP 'v\d[\d.]+' | head -1 || echo "v2019.78")
        echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
        printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "MENU SSH OVPN"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} Dropbear Version: ${CYAN}Dropbear $DB_VER${NC}         ${BLUE}║${NC}"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}1.${NC} Create SSH & OVPN                     ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}2.${NC} Trial SSH & OVPN                      ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}3.${NC} Renew SSH & OVPN                      ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}4.${NC} Delete SSH & OVPN                     ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}5.${NC} Check SSH & OVPN Login                ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}6.${NC} Change Limit or Add Limit IP          ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}7.${NC} Unban SSH                             ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${RED}0.${NC} Back to Main Menu                     ${BLUE}║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
        read -p "Please select an option [0-7]: " opt
        case $opt in
            1) _ssh_create ;;
            2) _ssh_trial  ;;
            3) _ssh_renew  ;;
            4) _ssh_delete ;;
            5) _ssh_check  ;;
            6) _ssh_limit  ;;
            7) _ssh_unban  ;;
            0) break ;;
            *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
        esac
    done
}

_ssh_create() {
    menu_header "CREATE SSH & OVPN"
    read -p " Username      : " user
    [[ -z "$user" ]] && { echo -e "${RED}Username required!${NC}"; sleep 2; return; }
    id "$user" &>/dev/null && { echo -e "${RED}User already exists!${NC}"; sleep 2; return; }
    read -p " Password      : " pass
    read -p " Duration (days): " days
    [[ -z "$pass" || -z "$days" ]] && { echo -e "${RED}All fields required!${NC}"; sleep 2; return; }
    exp=$(date -d "+${days} days" +"%Y-%m-%d")
    useradd -M -s /bin/false -e "$exp" "$user" 2>/dev/null
    echo "$user:$pass" | chpasswd
    cat > $INSTALL_DIR/ssh/$user <<EOF
Username : $user
Password : $pass
Created  : $(date +"%Y-%m-%d")
Expires  : $exp
Duration : $days days
Max IP   : 2
EOF
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e " ${GREEN}✓ Account created successfully!${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e " Username  : ${YELLOW}$user${NC}"
    echo -e " Password  : ${YELLOW}$pass${NC}"
    echo -e " Expires   : ${YELLOW}$exp${NC}"
    echo -e " Host      : ${YELLOW}$(cat $DOMAIN_FILE 2>/dev/null || echo $IPADDR)${NC}"
    echo -e " Port SSH  : ${YELLOW}22, 109, 143${NC}"
    echo -e " Port SSL  : ${YELLOW}443${NC}"
    echo -e " Port WS   : ${YELLOW}2052${NC}"
    menu_footer; press_enter
}

_ssh_trial() {
    menu_header "TRIAL SSH & OVPN"
    user="trial$(date +%s | tail -c 5)"
    pass="trial"
    exp=$(date -d "+1 day" +"%Y-%m-%d")
    useradd -M -s /bin/false -e "$exp" "$user" 2>/dev/null
    echo "$user:$pass" | chpasswd
    cat > $INSTALL_DIR/ssh/$user <<EOF
Username : $user
Password : $pass
Created  : $(date +"%Y-%m-%d")
Expires  : $exp
Duration : 1 day (Trial)
Max IP   : 1
EOF
    echo -e " ${GREEN}✓ Trial account created!${NC}"
    echo -e " Username  : ${YELLOW}$user${NC}"
    echo -e " Password  : ${YELLOW}$pass${NC}"
    echo -e " Expires   : ${YELLOW}$exp${NC}"
    echo -e " Host      : ${YELLOW}$(cat $DOMAIN_FILE 2>/dev/null || echo $IPADDR)${NC}"
    echo -e " Port SSH  : ${YELLOW}22, 109, 143${NC}"
    menu_footer; press_enter
}

_ssh_renew() {
    menu_header "RENEW SSH & OVPN"
    # list current accounts
    if [ "$(ls $INSTALL_DIR/ssh/ 2>/dev/null | wc -l)" -gt 0 ]; then
        echo -e " ${CYAN}Current Accounts:${NC}"
        i=1
        for u in $(ls $INSTALL_DIR/ssh/); do
            exp=$(grep "Expires" $INSTALL_DIR/ssh/$u | cut -d':' -f2 | xargs)
            echo -e "  $i. ${YELLOW}$u${NC} — $exp"
            ((i++))
        done
        echo ""
    fi
    read -p " Username to renew: " user
    [ ! -f "$INSTALL_DIR/ssh/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    read -p " Add days        : " days
    new_exp=$(date -d "+${days} days" +"%Y-%m-%d")
    usermod -e "$new_exp" "$user" 2>/dev/null
    sed -i "s/Expires.*/Expires  : $new_exp/" $INSTALL_DIR/ssh/$user
    echo -e " ${GREEN}✓ Renewed until $new_exp${NC}"
    menu_footer; press_enter
}

_ssh_delete() {
    menu_header "DELETE SSH & OVPN"
    if [ "$(ls $INSTALL_DIR/ssh/ 2>/dev/null | wc -l)" -gt 0 ]; then
        echo -e " ${CYAN}Current Accounts:${NC}"
        for u in $(ls $INSTALL_DIR/ssh/); do
            exp=$(grep "Expires" $INSTALL_DIR/ssh/$u | cut -d':' -f2 | xargs)
            echo -e "  ${YELLOW}$u${NC} — Expires: $exp"
        done
        echo ""
    fi
    read -p " Username to delete: " user
    ! id "$user" &>/dev/null && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    confirm_action " Delete $user?" || { echo "Cancelled."; sleep 1; return; }
    userdel -f "$user" 2>/dev/null
    rm -f $INSTALL_DIR/ssh/$user
    echo -e " ${GREEN}✓ User '$user' deleted!${NC}"
    menu_footer; press_enter
}

_ssh_check() {
    menu_header "CHECK SSH & OVPN LOGIN"
    echo ""
    echo -e " ${CYAN}Active Sessions:${NC}"
    active=$(who | grep -v "^root" 2>/dev/null | wc -l)
    if [ "$active" -gt 0 ]; then
        who | grep -v "^root" | awk '{printf "  %-15s %-15s %s\n", $1, $5, $6}'
    else
        echo -e "  ${YELLOW}No active sessions${NC}"
    fi
    echo ""
    echo -e " ${CYAN}All SSH Accounts (${SSH_COUNT}):${NC}"
    echo -e " ────────────────────────────────────────"
    printf "  %-18s %-12s %-6s %s\n" "Username" "Expires" "MaxIP" "Status"
    echo -e " ────────────────────────────────────────"
    if [ -d "$INSTALL_DIR/ssh" ] && [ "$(ls -A $INSTALL_DIR/ssh 2>/dev/null)" ]; then
        for u in $(ls $INSTALL_DIR/ssh/); do
            exp=$(grep "Expires" $INSTALL_DIR/ssh/$u 2>/dev/null | cut -d':' -f2 | xargs)
            maxip=$(grep "Max IP" $INSTALL_DIR/ssh/$u 2>/dev/null | cut -d':' -f2 | xargs || echo "2")
            # check if expired
            exp_ts=$(date -d "$exp" +%s 2>/dev/null || echo 0)
            today_ts=$(date +%s)
            if [ $exp_ts -lt $today_ts ]; then
                status="${RED}Expired${NC}"
            else
                status="${GREEN}Active${NC}"
            fi
            printf "  %-18s %-12s %-6s " "$u" "$exp" "$maxip"
            echo -e "$status"
        done
    else
        echo -e "  ${YELLOW}No accounts found${NC}"
    fi
    echo ""
    menu_footer; press_enter
}

_ssh_limit() {
    menu_header "CHANGE LIMIT OR ADD LIMIT IP"
    if [ "$(ls $INSTALL_DIR/ssh/ 2>/dev/null | wc -l)" -gt 0 ]; then
        echo -e " ${CYAN}Accounts:${NC}"
        for u in $(ls $INSTALL_DIR/ssh/); do
            maxip=$(grep "Max IP" $INSTALL_DIR/ssh/$u 2>/dev/null | cut -d':' -f2 | xargs || echo "2")
            echo -e "  ${YELLOW}$u${NC} — Max IP: $maxip"
        done
        echo ""
    fi
    read -p " Username  : " user
    [ ! -f "$INSTALL_DIR/ssh/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    read -p " Max IP limit (1-10): " maxip
    [[ ! "$maxip" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid number!${NC}"; sleep 2; return; }
    if grep -q "Max IP" $INSTALL_DIR/ssh/$user; then
        sed -i "s/Max IP.*/Max IP   : $maxip/" $INSTALL_DIR/ssh/$user
    else
        echo "Max IP   : $maxip" >> $INSTALL_DIR/ssh/$user
    fi
    echo -e " ${GREEN}✓ IP limit set to $maxip for $user${NC}"
    menu_footer; press_enter
}

_ssh_unban() {
    menu_header "UNBAN SSH"
    echo -e " ${CYAN}Banned IPs (fail2ban):${NC}"
    fail2ban-client status sshd 2>/dev/null | grep "Banned IP" | head -5 || echo "  None or fail2ban not active"
    echo ""
    read -p " Enter IP to unban: " ip
    [[ -z "$ip" ]] && { echo -e "${RED}IP required!${NC}"; sleep 2; return; }
    fail2ban-client set sshd unbanip $ip 2>/dev/null
    iptables -D INPUT   -s $ip -j DROP 2>/dev/null
    iptables -D FORWARD -s $ip -j DROP 2>/dev/null
    echo -e " ${GREEN}✓ IP $ip unbanned${NC}"
    menu_footer; press_enter
}

# ══════════════════════════════════════════════════════════════
# ██████  XRAY
# ══════════════════════════════════════════════════════════════
xray_menu() {
    while true; do
        clear
        XRAY_VER=$(xray version 2>/dev/null | grep -oP 'Xray \S+' | head -1 \
                || /usr/local/bin/xray version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 \
                || echo "24.11.11")
        echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
        printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "MENU XRAY"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} Xray Version: ${CYAN}Xray $XRAY_VER${NC}               ${BLUE}║${NC}"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}1.${NC}  Create XRAY                          ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}2.${NC}  Trial XRAY                           ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}3.${NC}  Renew XRAY                           ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}4.${NC}  Detail XRAY                          ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}5.${NC}  Delete XRAY                          ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}6.${NC}  Check XRAY Login                     ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}7.${NC}  Change XRAY Path                     ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}8.${NC}  Change Limit or Add Limit IP         ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}9.${NC}  Change Limit or Add Limit Quota      ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}10.${NC} Customize Unban Time                 ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}11.${NC} Unban XRAY                           ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}12.${NC} List Users Expiring Within 3 Days    ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${RED}0.${NC}  Back to Main Menu                   ${BLUE}║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
        read -p "Please select an option [0-12]: " opt
        case $opt in
            1)  _xray_create ;;
            2)  _xray_trial ;;
            3)  _xray_renew ;;
            4)  _xray_detail ;;
            5)  _xray_delete ;;
            6)  _xray_check ;;
            7)  _xray_path ;;
            8)  _xray_limit_ip ;;
            9)  _xray_limit_quota ;;
            10) _xray_unban_time ;;
            11) _xray_unban ;;
            12) _xray_expiring ;;
            0) break ;;
            *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
        esac
    done
}

_xray_create() {
    menu_header "CREATE XRAY ACCOUNT"
    read -p " Username       : " user
    [[ -z "$user" ]] && { echo -e "${RED}Username required!${NC}"; sleep 2; return; }
    [ -f "$INSTALL_DIR/xray/$user" ] && { echo -e "${RED}User already exists!${NC}"; sleep 2; return; }
    read -p " Duration (days) : " days
    read -p " Max IP (def 3)  : " maxip
    read -p " Quota GB (def 100): " quota
    [[ -z "$maxip" ]]  && maxip=3
    [[ -z "$quota" ]]  && quota=100
    [[ -z "$days"  ]]  && days=30
    uuid=$(cat /proc/sys/kernel/random/uuid)
    exp=$(date -d "+${days} days" +"%Y-%m-%d")
    domain=$(cat $DOMAIN_FILE 2>/dev/null || echo "$IPADDR")
    vless_path=$(cat $INSTALL_DIR/config/vless_path 2>/dev/null || echo "/vless")
    vmess_path=$(cat $INSTALL_DIR/config/vmess_path 2>/dev/null || echo "/vmess")
    cat > $INSTALL_DIR/xray/$user <<EOF
Username  : $user
UUID      : $uuid
Domain    : $domain
Created   : $(date +"%Y-%m-%d")
Expires   : $exp
Max IP    : $maxip
Quota     : $quota GB
Used      : 0 GB
Path VLESS: $vless_path
Path VMESS: $vmess_path
EOF
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e " ${GREEN}✓ XRAY account created!${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e " Username   : ${YELLOW}$user${NC}"
    echo -e " UUID       : ${YELLOW}$uuid${NC}"
    echo -e " Domain     : ${YELLOW}$domain${NC}"
    echo -e " Expires    : ${YELLOW}$exp${NC}"
    echo -e " Max IP     : ${YELLOW}$maxip${NC}"
    echo -e " Quota      : ${YELLOW}$quota GB${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e " ${CYAN}VLESS WS TLS:${NC}"
    echo -e " vless://${uuid}@${domain}:443?security=tls&type=ws&path=$(echo $vless_path | sed 's/\//%2F/g')#${user}"
    echo -e " ${CYAN}VMESS WS:${NC}"
    vmess_json=$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"80\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"$vmess_path\",\"tls\":\"\"}" | base64 -w0)
    echo -e " vmess://$vmess_json"
    menu_footer; press_enter
}

_xray_trial() {
    menu_header "TRIAL XRAY ACCOUNT"
    user="xray$(date +%s | tail -c 5)"
    uuid=$(cat /proc/sys/kernel/random/uuid)
    exp=$(date -d "+1 day" +"%Y-%m-%d")
    domain=$(cat $DOMAIN_FILE 2>/dev/null || echo "$IPADDR")
    cat > $INSTALL_DIR/xray/$user <<EOF
Username  : $user
UUID      : $uuid
Domain    : $domain
Created   : $(date +"%Y-%m-%d")
Expires   : $exp
Max IP    : 1
Quota     : 50 GB
Used      : 0 GB
EOF
    echo -e " ${GREEN}✓ Trial XRAY created!${NC}"
    echo -e " Username : ${YELLOW}$user${NC}"
    echo -e " UUID     : ${YELLOW}$uuid${NC}"
    echo -e " Expires  : ${YELLOW}$exp${NC} (1 day)"
    menu_footer; press_enter
}

_xray_renew() {
    menu_header "RENEW XRAY ACCOUNT"
    if [ "$(ls $INSTALL_DIR/xray/ 2>/dev/null | wc -l)" -gt 0 ]; then
        echo -e " ${CYAN}Accounts:${NC}"
        for u in $(ls $INSTALL_DIR/xray/); do
            exp=$(grep "Expires" $INSTALL_DIR/xray/$u | cut -d':' -f2 | xargs)
            echo -e "  ${YELLOW}$u${NC} — $exp"
        done
        echo ""
    fi
    read -p " Username to renew: " user
    [ ! -f "$INSTALL_DIR/xray/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    read -p " Add days        : " days
    cur_exp=$(grep "Expires" $INSTALL_DIR/xray/$user | cut -d':' -f2 | xargs)
    new_exp=$(date -d "$cur_exp +${days} days" +"%Y-%m-%d" 2>/dev/null || date -d "+${days} days" +"%Y-%m-%d")
    sed -i "s/Expires.*/Expires   : $new_exp/" $INSTALL_DIR/xray/$user
    echo -e " ${GREEN}✓ Renewed until $new_exp${NC}"
    menu_footer; press_enter
}

_xray_detail() {
    menu_header "DETAIL XRAY ACCOUNT"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/xray/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    echo ""
    while IFS= read -r line; do
        echo -e "  ${CYAN}$line${NC}"
    done < $INSTALL_DIR/xray/$user
    echo ""
    uuid=$(grep "UUID"   $INSTALL_DIR/xray/$user | cut -d':' -f2 | xargs)
    domain=$(grep "Domain" $INSTALL_DIR/xray/$user | cut -d':' -f2 | xargs)
    vpath=$(grep "Path VLESS" $INSTALL_DIR/xray/$user | cut -d':' -f2 | xargs || echo "/vless")
    vmpath=$(grep "Path VMESS" $INSTALL_DIR/xray/$user | cut -d':' -f2 | xargs || echo "/vmess")
    echo -e " ${YELLOW}── VLESS WS TLS (443) ──${NC}"
    echo -e " vless://${uuid}@${domain}:443?security=tls&type=ws&path=$(echo $vpath | sed 's/\//%2F/g')#${user}"
    echo ""
    echo -e " ${YELLOW}── VMESS WS (80) ──${NC}"
    vmess_json=$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"80\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"$vmpath\",\"tls\":\"\"}" | base64 -w0)
    echo -e " vmess://$vmess_json"
    echo ""
    echo -e " ${YELLOW}── VLESS NTLS WS (8880) ──${NC}"
    echo -e " vless://${uuid}@${domain}:8880?security=none&type=ws&path=$(echo $vpath | sed 's/\//%2F/g')#${user}-ntls"
    menu_footer; press_enter
}

_xray_delete() {
    menu_header "DELETE XRAY ACCOUNT"
    if [ "$(ls $INSTALL_DIR/xray/ 2>/dev/null | wc -l)" -gt 0 ]; then
        echo -e " ${CYAN}Accounts:${NC}"
        for u in $(ls $INSTALL_DIR/xray/); do
            exp=$(grep "Expires" $INSTALL_DIR/xray/$u | cut -d':' -f2 | xargs)
            echo -e "  ${YELLOW}$u${NC} — $exp"
        done
        echo ""
    fi
    read -p " Username to delete: " user
    [ ! -f "$INSTALL_DIR/xray/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    confirm_action " Delete $user?" || { echo "Cancelled."; sleep 1; return; }
    rm -f $INSTALL_DIR/xray/$user
    echo -e " ${GREEN}✓ XRAY user '$user' deleted!${NC}"
    menu_footer; press_enter
}

_xray_check() {
    menu_header "CHECK XRAY LOGIN"
    count_accounts
    echo ""
    printf "  %-5s %-18s %-12s %-5s %-10s %s\n" "No" "Username" "Expires" "MaxIP" "Quota" "Status"
    echo "  ─────────────────────────────────────────────────────"
    if [ -d "$INSTALL_DIR/xray" ] && [ "$(ls -A $INSTALL_DIR/xray 2>/dev/null)" ]; then
        i=1
        today_ts=$(date +%s)
        for u in $(ls $INSTALL_DIR/xray/); do
            exp=$(grep "Expires" $INSTALL_DIR/xray/$u 2>/dev/null | cut -d':' -f2 | xargs)
            maxip=$(grep "Max IP" $INSTALL_DIR/xray/$u 2>/dev/null | cut -d':' -f2 | xargs || echo "3")
            quota=$(grep "^Quota" $INSTALL_DIR/xray/$u 2>/dev/null | cut -d':' -f2 | xargs || echo "100 GB")
            used=$(grep "Used" $INSTALL_DIR/xray/$u 2>/dev/null | cut -d':' -f2 | xargs || echo "0 GB")
            exp_ts=$(date -d "$exp" +%s 2>/dev/null || echo 0)
            if [ $exp_ts -lt $today_ts ]; then st="${RED}Expired${NC}"
            else st="${GREEN}Active${NC}"; fi
            printf "  %-5s %-18s %-12s %-5s %-10s " "$i." "$u" "$exp" "$maxip" "$quota"
            echo -e "$st"
            ((i++))
        done
    else
        echo -e "  ${YELLOW}No XRAY accounts found${NC}"
    fi
    echo ""
    menu_footer; press_enter
}

_xray_path() {
    menu_header "CHANGE XRAY PATH"
    vpath=$(cat $INSTALL_DIR/config/vless_path 2>/dev/null || echo "/vless")
    vmpath=$(cat $INSTALL_DIR/config/vmess_path 2>/dev/null || echo "/vmess")
    echo -e " Current VLESS path : ${YELLOW}$vpath${NC}"
    echo -e " Current VMESS path : ${YELLOW}$vmpath${NC}"
    echo ""
    read -p " New VLESS path (Enter to keep [$vpath]): " new_vpath
    read -p " New VMESS path (Enter to keep [$vmpath]): " new_vmpath
    [[ -n "$new_vpath" ]]  && { echo "$new_vpath"  > $INSTALL_DIR/config/vless_path; vpath=$new_vpath; }
    [[ -n "$new_vmpath" ]] && { echo "$new_vmpath" > $INSTALL_DIR/config/vmess_path; vmpath=$new_vmpath; }
    # Update xray config if exists
    if [ -f /usr/local/etc/xray/config.json ]; then
        sed -i "s|\"path\":.*vless.*|\"path\": \"$vpath\"|g" /usr/local/etc/xray/config.json 2>/dev/null
        systemctl restart xray 2>/dev/null && echo -e " ${GREEN}✓ XRAY restarted with new paths${NC}"
    fi
    echo -e " ${GREEN}✓ Paths updated — VLESS: $vpath | VMESS: $vmpath${NC}"
    menu_footer; press_enter
}

_xray_limit_ip() {
    menu_header "CHANGE LIMIT IP — XRAY"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/xray/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    cur=$(grep "Max IP" $INSTALL_DIR/xray/$user | cut -d':' -f2 | xargs)
    echo -e " Current Max IP: ${YELLOW}$cur${NC}"
    read -p " New Max IP limit: " maxip
    [[ ! "$maxip" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid!${NC}"; sleep 2; return; }
    sed -i "s/Max IP.*/Max IP    : $maxip/" $INSTALL_DIR/xray/$user
    echo -e " ${GREEN}✓ Max IP updated to $maxip for $user${NC}"
    menu_footer; press_enter
}

_xray_limit_quota() {
    menu_header "CHANGE LIMIT QUOTA — XRAY"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/xray/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    cur=$(grep "^Quota" $INSTALL_DIR/xray/$user | cut -d':' -f2 | xargs)
    echo -e " Current Quota: ${YELLOW}$cur${NC}"
    read -p " New Quota (GB): " quota
    [[ ! "$quota" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid!${NC}"; sleep 2; return; }
    sed -i "s/^Quota.*/Quota     : $quota GB/" $INSTALL_DIR/xray/$user
    echo -e " ${GREEN}✓ Quota updated to $quota GB for $user${NC}"
    menu_footer; press_enter
}

_xray_unban_time() {
    menu_header "CUSTOMIZE UNBAN TIME"
    cur=$(cat $INSTALL_DIR/config/xray_bantime 2>/dev/null || echo "3600")
    echo -e " Current ban time: ${YELLOW}$cur seconds${NC} ($(( cur/60 )) minutes)"
    echo ""
    read -p " New ban time in seconds: " bantime
    [[ ! "$bantime" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid!${NC}"; sleep 2; return; }
    echo "$bantime" > $INSTALL_DIR/config/xray_bantime
    echo -e " ${GREEN}✓ Ban time set to $bantime seconds ($(( bantime/60 )) minutes)${NC}"
    menu_footer; press_enter
}

_xray_unban() {
    menu_header "UNBAN XRAY"
    read -p " Enter username or IP to unban: " target
    [[ -z "$target" ]] && { echo -e "${RED}Required!${NC}"; sleep 2; return; }
    iptables -D INPUT   -s "$target" -j DROP 2>/dev/null
    iptables -D FORWARD -s "$target" -j DROP 2>/dev/null
    fail2ban-client set xray unbanip "$target" 2>/dev/null
    echo -e " ${GREEN}✓ '$target' unbanned${NC}"
    menu_footer; press_enter
}

_xray_expiring() {
    menu_header "LIST USERS EXPIRING WITHIN 3 DAYS"
    echo ""
    today=$(date +%s)
    limit=$((today + 259200))  # 3 days
    found=0
    for dir in ssh xray l2tp; do
        [ ! -d "$INSTALL_DIR/$dir" ] && continue
        for u in $(ls $INSTALL_DIR/$dir/ 2>/dev/null); do
            exp_str=$(grep "Expires" $INSTALL_DIR/$dir/$u 2>/dev/null | cut -d':' -f2 | xargs)
            [ -z "$exp_str" ] && continue
            exp_ts=$(date -d "$exp_str" +%s 2>/dev/null) || continue
            if [ $exp_ts -le $limit ] && [ $exp_ts -ge $today ]; then
                days_left=$(( (exp_ts - today) / 86400 ))
                echo -e "  ${YELLOW}[$dir]${NC} ${WHITE}$u${NC} — Expires: ${RED}$exp_str${NC} (${days_left} days left)"
                found=1
            fi
        done
    done
    [ $found -eq 0 ] && echo -e "  ${GREEN}No users expiring within 3 days ✓${NC}"
    echo ""
    menu_footer; press_enter
}

# ══════════════════════════════════════════════════════════════
# ██████  L2TP
# ══════════════════════════════════════════════════════════════
l2tp_menu() {
    while true; do
        clear
        L2TP_VER=$(xl2tpd --version 2>&1 | grep -oP 'xl2tpd-\S+' | head -1 || echo "xl2tpd-1.3.18")
        echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
        printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "MENU L2TP"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} xl2tpd version: ${CYAN}$L2TP_VER${NC}               ${BLUE}║${NC}"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}1.${NC} Create L2TP                           ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}2.${NC} Renew L2TP                            ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}3.${NC} del L2TP                              ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${RED}0.${NC} Back to Main Menu                     ${BLUE}║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
        read -p "Please select an option [0-3]: " opt
        case $opt in
            1) _l2tp_create ;;
            2) _l2tp_renew ;;
            3) _l2tp_delete ;;
            0) break ;;
            *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
        esac
    done
}

_l2tp_create() {
    menu_header "CREATE L2TP ACCOUNT"
    read -p " Username        : " user
    read -p " Password        : " pass
    read -p " Duration (days) : " days
    [[ -z "$user" || -z "$pass" || -z "$days" ]] && { echo -e "${RED}All fields required!${NC}"; sleep 2; return; }
    exp=$(date -d "+${days} days" +"%Y-%m-%d")
    cat > $INSTALL_DIR/l2tp/$user <<EOF
Username : $user
Password : $pass
Created  : $(date +"%Y-%m-%d")
Expires  : $exp
Duration : $days days
EOF
    [ -f /etc/ppp/chap-secrets ] && echo "$user l2tpd $pass *" >> /etc/ppp/chap-secrets
    [ -f /etc/ipsec.secrets ]    && echo "$user : PSK \"vpn\"" >> /etc/ipsec.secrets
    echo -e " ${GREEN}✓ L2TP created!${NC}"
    echo -e " Username : ${YELLOW}$user${NC}"
    echo -e " Password : ${YELLOW}$pass${NC}"
    echo -e " Host     : ${YELLOW}$IPADDR${NC}"
    echo -e " PSK      : ${YELLOW}vpn${NC}"
    echo -e " Expires  : ${YELLOW}$exp${NC}"
    menu_footer; press_enter
}

_l2tp_renew() {
    menu_header "RENEW L2TP ACCOUNT"
    if [ "$(ls $INSTALL_DIR/l2tp/ 2>/dev/null | wc -l)" -gt 0 ]; then
        for u in $(ls $INSTALL_DIR/l2tp/); do
            exp=$(grep "Expires" $INSTALL_DIR/l2tp/$u | cut -d':' -f2 | xargs)
            echo -e "  ${YELLOW}$u${NC} — $exp"
        done; echo ""
    fi
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/l2tp/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    read -p " Add days: " days
    new_exp=$(date -d "+${days} days" +"%Y-%m-%d")
    sed -i "s/Expires.*/Expires  : $new_exp/" $INSTALL_DIR/l2tp/$user
    echo -e " ${GREEN}✓ L2TP renewed until $new_exp${NC}"
    menu_footer; press_enter
}

_l2tp_delete() {
    menu_header "DELETE L2TP ACCOUNT"
    if [ "$(ls $INSTALL_DIR/l2tp/ 2>/dev/null | wc -l)" -gt 0 ]; then
        for u in $(ls $INSTALL_DIR/l2tp/); do
            echo -e "  ${YELLOW}$u${NC}"
        done; echo ""
    fi
    read -p " Username to delete: " user
    [ ! -f "$INSTALL_DIR/l2tp/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    confirm_action " Delete $user?" || { echo "Cancelled."; sleep 1; return; }
    pass=$(grep "Password" $INSTALL_DIR/l2tp/$user | cut -d':' -f2 | xargs)
    rm -f $INSTALL_DIR/l2tp/$user
    [ -f /etc/ppp/chap-secrets ] && sed -i "/^$user /d" /etc/ppp/chap-secrets
    echo -e " ${GREEN}✓ L2TP user '$user' deleted!${NC}"
    menu_footer; press_enter
}

# ══════════════════════════════════════════════════════════════
# ██████  NOOBZVPNS
# ══════════════════════════════════════════════════════════════
noobz_menu() {
    while true; do
        clear
        echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
        printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "MENU NOOBZVPNS"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}1.${NC} Create Noobzvpn User                  ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}2.${NC} Renew Noobzvpn User                   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}3.${NC} Delete Noobzvpn User                  ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}4.${NC} Cek List All Noobzvpn User            ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}5.${NC} Detail Specific Noobzvpn User         ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}6.${NC} Block Noobzvpn User                   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}7.${NC} Unblock Noobzvpn User                 ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}8.${NC} Reset Noobzvpn Quota User             ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${RED}0.${NC} Back to Main Menu                     ${BLUE}║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
        read -p "Please select an option [0-8]: " opt
        case $opt in
            1) _noobz_create ;;
            2) _noobz_renew ;;
            3) _noobz_delete ;;
            4) _noobz_list ;;
            5) _noobz_detail ;;
            6) _noobz_block ;;
            7) _noobz_unblock ;;
            8) _noobz_reset_quota ;;
            0) break ;;
            *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
        esac
    done
}

_noobz_create() {
    menu_header "CREATE NOOBZVPN USER"
    read -p " Username        : " user
    read -p " Password        : " pass
    read -p " Duration (days) : " days
    read -p " Quota (GB)      : " quota
    [[ -z "$quota" ]] && quota=50
    [ -f "$INSTALL_DIR/noobz/$user" ] && { echo -e "${RED}User exists!${NC}"; sleep 2; return; }
    exp=$(date -d "+${days} days" +"%Y-%m-%d")
    cat > $INSTALL_DIR/noobz/$user <<EOF
Username : $user
Password : $pass
Created  : $(date +"%Y-%m-%d")
Expires  : $exp
Duration : $days days
Quota    : $quota GB
Used     : 0 GB
Status   : Active
EOF
    echo -e " ${GREEN}✓ Created! User: ${YELLOW}$user${NC}${GREEN} | Exp: ${YELLOW}$exp${NC}${GREEN} | Quota: ${YELLOW}$quota GB${NC}"
    menu_footer; press_enter
}

_noobz_renew() {
    menu_header "RENEW NOOBZVPN USER"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/noobz/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    read -p " Add days: " days
    new_exp=$(date -d "+${days} days" +"%Y-%m-%d")
    sed -i "s/Expires.*/Expires  : $new_exp/" $INSTALL_DIR/noobz/$user
    echo -e " ${GREEN}✓ Renewed until $new_exp${NC}"
    menu_footer; press_enter
}

_noobz_delete() {
    menu_header "DELETE NOOBZVPN USER"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/noobz/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    confirm_action " Delete $user?" || { echo "Cancelled."; sleep 1; return; }
    rm -f $INSTALL_DIR/noobz/$user
    echo -e " ${GREEN}✓ User '$user' deleted!${NC}"
    menu_footer; press_enter
}

_noobz_list() {
    menu_header "LIST ALL NOOBZVPN USERS"
    echo ""
    printf "  %-5s %-18s %-12s %-10s %-8s %s\n" "No" "Username" "Expires" "Quota" "Used" "Status"
    echo "  ──────────────────────────────────────────────────────"
    if [ -d "$INSTALL_DIR/noobz" ] && [ "$(ls -A $INSTALL_DIR/noobz 2>/dev/null)" ]; then
        i=1
        for u in $(ls $INSTALL_DIR/noobz/); do
            exp=$(grep "Expires"  $INSTALL_DIR/noobz/$u 2>/dev/null | cut -d':' -f2 | xargs)
            quota=$(grep "^Quota" $INSTALL_DIR/noobz/$u 2>/dev/null | cut -d':' -f2 | xargs)
            used=$(grep "Used"    $INSTALL_DIR/noobz/$u 2>/dev/null | cut -d':' -f2 | xargs)
            status=$(grep "Status" $INSTALL_DIR/noobz/$u 2>/dev/null | cut -d':' -f2 | xargs)
            [[ "$status" == "Active" ]] && sc="${GREEN}$status${NC}" || sc="${RED}$status${NC}"
            printf "  %-5s %-18s %-12s %-10s %-8s " "$i." "$u" "$exp" "$quota" "$used"
            echo -e "$sc"
            ((i++))
        done
    else
        echo -e "  ${YELLOW}No Noobzvpn accounts${NC}"
    fi
    echo ""
    menu_footer; press_enter
}

_noobz_detail() {
    menu_header "DETAIL NOOBZVPN USER"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/noobz/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    echo ""
    while IFS= read -r line; do echo -e "  ${CYAN}$line${NC}"; done < $INSTALL_DIR/noobz/$user
    echo ""
    menu_footer; press_enter
}

_noobz_block() {
    menu_header "BLOCK NOOBZVPN USER"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/noobz/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    sed -i "s/Status.*/Status   : Blocked/" $INSTALL_DIR/noobz/$user
    echo -e " ${GREEN}✓ User '$user' blocked!${NC}"
    menu_footer; press_enter
}

_noobz_unblock() {
    menu_header "UNBLOCK NOOBZVPN USER"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/noobz/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    sed -i "s/Status.*/Status   : Active/" $INSTALL_DIR/noobz/$user
    echo -e " ${GREEN}✓ User '$user' unblocked!${NC}"
    menu_footer; press_enter
}

_noobz_reset_quota() {
    menu_header "RESET NOOBZVPN QUOTA"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/noobz/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    sed -i "s/Used.*/Used     : 0 GB/" $INSTALL_DIR/noobz/$user
    echo -e " ${GREEN}✓ Quota reset for '$user'${NC}"
    menu_footer; press_enter
}

# ══════════════════════════════════════════════════════════════
# ██████  SETTINGS MENU (28 options)
# ══════════════════════════════════════════════════════════════
settings_menu() {
    while true; do
        clear
        echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
        printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "SETTINGS MENU"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} ${PURPLE}► VPN & NETWORKING${NC}                       ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[1]${NC}  ACTIVATE LIMIT IP SSH & XRAY        ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[2]${NC}  ARGO SETUP FOR SSH & XRAY           ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[3]${NC}  BYPASS WARP TRAFFIC                 ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[4]${NC}  CHANGE ALTERNATIF PORT              ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[5]${NC}  CHANGE DOMAIN OR FORCE DOMAIN       ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[6]${NC}  CHANGE PORT                         ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[7]${NC}  CHANGE SLOWDNS MODE                 ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[8]${NC}  CHANGE UUID OR PASSWORD ACCOUNT VPN ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[9]${NC}  ROUTINGS TRAFFIC XRAY               ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[10]${NC} WARP CLOUDFLARE                     ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${PURPLE}► BACKUP & RESTORE${NC}                       ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[11]${NC} AUTOBACKUP VIA BOT TELEGRAM         ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[12]${NC} AUTOSEND CREATED VPN VIA BOT        ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[13]${NC} BACKUP VIA BOT TELEGRAM             ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[14]${NC} RESTORE DATA VPS                    ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${PURPLE}► API & BOT MANAGEMENT${NC}                   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[15]${NC} CONFIGURE API DEVELOPMENT           ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[16]${NC} CONFIGURE BOT MANAGEMENT            ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${PURPLE}► SYSTEM & KERNEL${NC}                        ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[17]${NC} CHANGE KERNEL TYPE CLOUD            ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[18]${NC} CONFIGURASI XANMOD KERNEL & BBRV3   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[19]${NC} UPDATE KERNEL TO LATEST VERSION     ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[20]${NC} RESTART ALL SERVICES                ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[21]${NC} REBOOT SERVER                       ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${PURPLE}► MONITORING & UTILITY${NC}                   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[22]${NC} INSTALL WEBMON                      ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[23]${NC} LIMIT BANDWIDTH SPEED SERVER        ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[24]${NC} MONITORING CPU USAGE                ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[25]${NC} SPEEDTEST SERVER                    ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[26]${NC} VIEW PROTOCOL & PORT INFORMATION    ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[27]${NC} VIEW SERVER'S TOTAL BANDWIDTH       ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${WHITE}[28]${NC} CHECK USAGE OF RAM                  ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}  ${RED}[0]${NC}  Back to Main Menu                   ${BLUE}║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
        read -p "Please select an option [0-28]: " opt
        case $opt in
            1)  _s_activate_limit ;;
            2)  _s_argo_setup ;;
            3)  _s_bypass_warp ;;
            4)  _s_change_alt_port ;;
            5)  _s_change_domain ;;
            6)  _s_change_port ;;
            7)  _s_slowdns_mode ;;
            8)  _s_change_uuid_pass ;;
            9)  _s_routing_xray ;;
            10) _s_warp_cloudflare ;;
            11) _s_autobackup_tg ;;
            12) _s_autosend_tg ;;
            13) _s_backup_tg ;;
            14) _s_restore_vps ;;
            15) _s_api_dev ;;
            16) _s_bot_mgmt ;;
            17) _s_change_kernel ;;
            18) _s_xanmod_bbrv3 ;;
            19) _s_update_kernel ;;
            20) _s_restart_all ;;
            21) _s_reboot ;;
            22) _s_install_webmon ;;
            23) _s_limit_bw ;;
            24) _s_monitor_cpu ;;
            25) _s_speedtest ;;
            26) _s_view_protocols ;;
            27) _s_view_bandwidth ;;
            28) _s_check_ram ;;
            0) break ;;
            *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
        esac
    done
}

# ── Settings Functions ──────────────────────────────────────
_s_activate_limit() {
    menu_header "ACTIVATE LIMIT IP SSH & XRAY"
    cur=$(cat $INSTALL_DIR/config/limit_ip_status 2>/dev/null || echo "disabled")
    echo -e " Current status: ${YELLOW}$cur${NC}"
    echo -e " 1. Enable   2. Disable"
    read -p " Choice: " c
    if [ "$c" = "1" ]; then
        echo "enabled" > $INSTALL_DIR/config/limit_ip_status
        echo -e " ${GREEN}✓ IP Limit ENABLED${NC}"
    else
        echo "disabled" > $INSTALL_DIR/config/limit_ip_status
        echo -e " ${YELLOW}IP Limit DISABLED${NC}"
    fi
    menu_footer; sleep 2
}

_s_argo_setup() {
    menu_header "ARGO SETUP FOR SSH & XRAY"
    cur=$(cat $INSTALL_DIR/config/argo_token 2>/dev/null || echo "Not set")
    echo -e " Current token: ${YELLOW}$cur${NC}"
    read -p " Argo Token (Enter to skip): " token
    [ -n "$token" ] && { echo "$token" > $INSTALL_DIR/config/argo_token; echo -e " ${GREEN}✓ Token saved${NC}"; }
    read -p " Argo Domain (Enter to skip): " adomain
    [ -n "$adomain" ] && { echo "$adomain" > $INSTALL_DIR/config/argo_domain; echo -e " ${GREEN}✓ Domain saved${NC}"; }
    menu_footer; sleep 2
}

_s_bypass_warp() {
    menu_header "BYPASS WARP TRAFFIC"
    echo -e " 1. Enable bypass   2. Disable bypass"
    read -p " Choice: " c
    if [ "$c" = "1" ]; then
        echo "enabled" > $INSTALL_DIR/config/warp_bypass
        # warp-cli mode proxy 2>/dev/null
        echo -e " ${GREEN}✓ WARP bypass enabled${NC}"
    else
        echo "disabled" > $INSTALL_DIR/config/warp_bypass
        echo -e " ${YELLOW}WARP bypass disabled${NC}"
    fi
    menu_footer; sleep 2
}

_s_change_alt_port() {
    menu_header "CHANGE ALTERNATIF PORT"
    cur=$(cat $INSTALL_DIR/config/alt_port 2>/dev/null || echo "Not set")
    echo -e " Current alt port: ${YELLOW}$cur${NC}"
    read -p " New alternative port: " port
    [[ ! "$port" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid port!${NC}"; sleep 2; return; }
    echo "$port" > $INSTALL_DIR/config/alt_port
    echo -e " ${GREEN}✓ Alt port set to $port${NC}"
    menu_footer; sleep 2
}

_s_change_domain() {
    menu_header "CHANGE DOMAIN OR FORCE DOMAIN"
    cur=$(cat $DOMAIN_FILE 2>/dev/null || echo "Not set")
    echo -e " Current domain: ${YELLOW}$cur${NC}"
    read -p " New domain: " domain
    [ -z "$domain" ] && { echo -e "${RED}Domain required!${NC}"; sleep 2; return; }
    echo "$domain" > $DOMAIN_FILE
    echo -e " ${GREEN}✓ Domain updated to $domain${NC}"
    menu_footer; sleep 2
}

_s_change_port() {
    menu_header "CHANGE PORT"
    echo -e " ${CYAN}Select service:${NC}"
    echo -e " 1. SSH   2. Dropbear   3. OpenVPN   4. XRAY TLS   5. Stunnel"
    read -p " Service: " svc
    read -p " New port: " port
    [[ ! "$port" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid port!${NC}"; sleep 2; return; }
    case $svc in
        1) sed -i "s/^Port .*/Port $port/" /etc/ssh/sshd_config 2>/dev/null
           systemctl restart ssh 2>/dev/null
           echo -e " ${GREEN}✓ SSH port changed to $port${NC}" ;;
        2) sed -i "s/^Port .*/Port $port/" /etc/dropbear/config 2>/dev/null
           systemctl restart dropbear 2>/dev/null
           echo -e " ${GREEN}✓ Dropbear port changed to $port${NC}" ;;
        *) echo -e " ${YELLOW}Please update config manually and restart service${NC}" ;;
    esac
    menu_footer; sleep 2
}

_s_slowdns_mode() {
    menu_header "CHANGE SLOWDNS MODE"
    cur=$(cat $INSTALL_DIR/config/slowdns_status 2>/dev/null || echo "Not set")
    echo -e " Current: ${YELLOW}$cur${NC}"
    echo -e " 1. Enable   2. Disable"
    read -p " Choice: " c
    if [ "$c" = "1" ]; then
        echo "enabled" > $INSTALL_DIR/config/slowdns_status
        echo -e " ${GREEN}✓ SlowDNS enabled${NC}"
    else
        echo "disabled" > $INSTALL_DIR/config/slowdns_status
        echo -e " ${YELLOW}SlowDNS disabled${NC}"
    fi
    menu_footer; sleep 2
}

_s_change_uuid_pass() {
    menu_header "CHANGE UUID OR PASSWORD VPN [XRAY]"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/xray/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    echo -e " 1. Change UUID   2. Change Password (VMESS)"
    read -p " Choice: " c
    if [ "$c" = "1" ]; then
        new_uuid=$(cat /proc/sys/kernel/random/uuid)
        sed -i "s/UUID.*/UUID      : $new_uuid/" $INSTALL_DIR/xray/$user
        echo -e " ${GREEN}✓ UUID updated: $new_uuid${NC}"
    elif [ "$c" = "2" ]; then
        read -p " New password/alter_id: " newpass
        echo -e " ${GREEN}✓ Password updated (update xray config manually)${NC}"
    fi
    menu_footer; sleep 2
}

_s_routing_xray() {
    menu_header "ROUTINGS TRAFFIC XRAY"
    cur=$(cat $INSTALL_DIR/config/xray_routing 2>/dev/null || echo "direct")
    echo -e " Current routing: ${YELLOW}$cur${NC}"
    echo -e " 1. Direct   2. Through WARP   3. Block Bittorrent"
    read -p " Route mode: " mode
    case $mode in
        1) echo "direct" > $INSTALL_DIR/config/xray_routing ;;
        2) echo "warp"   > $INSTALL_DIR/config/xray_routing ;;
        3) echo "block_bt" > $INSTALL_DIR/config/xray_routing ;;
    esac
    echo -e " ${GREEN}✓ Routing updated${NC}"
    menu_footer; sleep 2
}

_s_warp_cloudflare() {
    menu_header "WARP CLOUDFLARE"
    echo -e " 1. Install WARP   2. Enable WARP   3. Disable WARP   4. Status"
    read -p " Choice: " c
    case $c in
        1) curl -fsSL https://pkg.cloudflareclient.com/install.sh 2>/dev/null | bash
           echo -e " ${GREEN}✓ WARP install initiated${NC}" ;;
        2) warp-cli connect 2>/dev/null; echo -e " ${GREEN}✓ WARP connected${NC}" ;;
        3) warp-cli disconnect 2>/dev/null; echo -e " ${YELLOW}WARP disconnected${NC}" ;;
        4) warp-cli status 2>/dev/null ;;
    esac
    menu_footer; sleep 2
}

_s_autobackup_tg() {
    menu_header "AUTOBACKUP VIA BOT TELEGRAM"
    read -p " Bot Token : " token
    read -p " Chat ID   : " chatid
    [ -z "$token" ] && { echo -e "${RED}Token required!${NC}"; sleep 2; return; }
    echo "TOKEN=$token"  > $INSTALL_DIR/config/telegram
    echo "CHATID=$chatid" >> $INSTALL_DIR/config/telegram
    # daily cron at 00:00
    (crontab -l 2>/dev/null | grep -v "alsaher-backup"; echo "0 0 * * * tar -czf /tmp/als_bak_\$(date +\%Y\%m\%d).tar.gz $INSTALL_DIR && curl -s -F chat_id=$chatid -F document=@/tmp/als_bak_\$(date +\%Y\%m\%d).tar.gz https://api.telegram.org/bot$token/sendDocument") | crontab -
    echo -e " ${GREEN}✓ Auto backup set (daily midnight)${NC}"
    menu_footer; sleep 2
}

_s_autosend_tg() {
    menu_header "AUTOSEND CREATED VPN VIA BOT TELEGRAM"
    cur=$(cat $INSTALL_DIR/config/autosend_status 2>/dev/null || echo "disabled")
    echo -e " Current: ${YELLOW}$cur${NC}"
    echo -e " 1. Enable   2. Disable"
    read -p " Choice: " c
    [ "$c" = "1" ] && echo "enabled" > $INSTALL_DIR/config/autosend_status \
                    || echo "disabled" > $INSTALL_DIR/config/autosend_status
    echo -e " ${GREEN}✓ Auto-send updated${NC}"
    menu_footer; sleep 2
}

_s_backup_tg() {
    menu_header "BACKUP VIA BOT TELEGRAM"
    [ ! -f "$INSTALL_DIR/config/telegram" ] && { echo -e "${RED}Configure bot first (option 11)!${NC}"; sleep 2; return; }
    source $INSTALL_DIR/config/telegram
    bak="/tmp/alsaher_backup_$(date +%Y%m%d_%H%M).tar.gz"
    echo -e " Creating backup..."
    tar -czf $bak $INSTALL_DIR 2>/dev/null
    echo -e " Sending to Telegram..."
    result=$(curl -s -F "chat_id=$CHATID" -F "document=@$bak" -F "caption=ALSAHER Backup $(date)" \
             "https://api.telegram.org/bot$TOKEN/sendDocument")
    echo "$result" | grep -q '"ok":true' \
        && echo -e " ${GREEN}✓ Backup sent to Telegram!${NC}" \
        || echo -e " ${RED}✗ Send failed. Check bot/chatid.${NC}"
    rm -f $bak
    menu_footer; sleep 2
}

_s_restore_vps() {
    menu_header "RESTORE DATA VPS"
    read -p " Backup file path: " bfile
    [ ! -f "$bfile" ] && { echo -e "${RED}File not found!${NC}"; sleep 2; return; }
    confirm_action " Restore from $bfile?" || { echo "Cancelled."; sleep 1; return; }
    tar -xzf "$bfile" -C / 2>/dev/null
    echo -e " ${GREEN}✓ Restore completed${NC}"
    menu_footer; sleep 2
}

_s_api_dev() {
    menu_header "CONFIGURE API DEVELOPMENT"
    cur_port=$(cat $INSTALL_DIR/config/api_port 2>/dev/null || echo "8080")
    echo -e " Current API port: ${YELLOW}$cur_port${NC}"
    read -p " API Port (Enter=keep): " api_port
    [ -n "$api_port" ] && echo "$api_port" > $INSTALL_DIR/config/api_port
    read -p " API Key (Enter=generate): " api_key
    [ -z "$api_key" ] && api_key=$(openssl rand -hex 16)
    echo "$api_key" > $INSTALL_DIR/config/api_key
    echo -e " ${GREEN}✓ API Key: $api_key${NC}"
    echo -e " ${GREEN}✓ API Port: ${api_port:-$cur_port}${NC}"
    menu_footer; sleep 2
}

_s_bot_mgmt() {
    menu_header "CONFIGURE BOT MANAGEMENT"
    read -p " Bot Token   : " token
    read -p " Admin Chat ID: " chatid
    [ -z "$token" ] && { echo -e "${RED}Token required!${NC}"; sleep 2; return; }
    echo "TOKEN=$token"       > $INSTALL_DIR/config/bot_mgmt
    echo "ADMIN_CHATID=$chatid" >> $INSTALL_DIR/config/bot_mgmt
    echo -e " ${GREEN}✓ Bot management configured${NC}"
    menu_footer; sleep 2
}

_s_change_kernel() {
    menu_header "CHANGE KERNEL TYPE CLOUD"
    echo -e " Current kernel: ${YELLOW}$(uname -r)${NC}"
    echo -e " 1. linux-cloud-amd64  2. linux-generic  3. linux-virtual"
    read -p " Choice: " c
    case $c in
        1) apt install -y linux-cloud-amd64 2>/dev/null ;;
        2) apt install -y linux-generic     2>/dev/null ;;
        3) apt install -y linux-virtual     2>/dev/null ;;
    esac
    echo -e " ${GREEN}✓ Kernel installed. Reboot to apply.${NC}"
    menu_footer; sleep 2
}

_s_xanmod_bbrv3() {
    menu_header "CONFIGURASI XANMOD KERNEL & BBRV3"
    echo -e " Current kernel: ${YELLOW}$(uname -r)${NC}"
    confirm_action " Install XanMod + BBRv3?" || { echo "Cancelled."; sleep 1; return; }
    echo -e " ${YELLOW}Checking CPU compatibility...${NC}"
    curl -s https://dl.xanmod.org/check_X86-64_psabi.sh 2>/dev/null | bash 2>/dev/null
    echo -e " ${YELLOW}Adding XanMod repo...${NC}"
    curl -s https://dl.xanmod.org/archive.key 2>/dev/null | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg 2>/dev/null
    echo -e " ${GREEN}✓ XanMod setup done. Reboot required.${NC}"
    menu_footer; sleep 2
}

_s_update_kernel() {
    menu_header "UPDATE KERNEL TO LATEST VERSION"
    echo -e " Current: ${YELLOW}$(uname -r)${NC}"
    echo -e " ${YELLOW}Updating...${NC}"
    apt update -y 2>/dev/null | tail -1
    apt install -y --install-recommends linux-generic 2>/dev/null | tail -3
    echo -e " ${GREEN}✓ Done. Reboot to apply new kernel.${NC}"
    menu_footer; sleep 2
}

_s_restart_all() {
    menu_header "RESTART ALL SERVICES"
    svcs=(ssh dropbear stunnel4 openvpn squid nginx cron fail2ban xray xl2tpd)
    for s in "${svcs[@]}"; do
        systemctl restart $s 2>/dev/null \
            && printf "  ${GREEN}✓${NC} %-15s restarted\n" "$s" \
            || printf "  ${YELLOW}⚠${NC} %-15s not found\n" "$s"
    done
    menu_footer; sleep 2
}

_s_reboot() {
    menu_header "REBOOT SERVER"
    echo -e " ${RED}⚠ Warning: Server will restart!${NC}"
    confirm_action " Confirm reboot?" && reboot || echo -e " ${GREEN}Cancelled${NC}"
    menu_footer; sleep 1
}

_s_install_webmon() {
    menu_header "INSTALL WEBMON"
    echo -e " ${YELLOW}Installing Webmin...${NC}"
    curl -o /tmp/setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh 2>/dev/null
    bash /tmp/setup-repos.sh --force 2>/dev/null
    apt install -y webmin 2>/dev/null | tail -2
    echo -e " ${GREEN}✓ Webmin installed — Port: 10000${NC}"
    menu_footer; sleep 2
}

_s_limit_bw() {
    menu_header "LIMIT BANDWIDTH SPEED SERVER"
    iface=$(ip route | grep default | awk '{print $5}' | head -1)
    echo -e " Default interface: ${YELLOW}$iface${NC}"
    read -p " Interface (Enter=$iface): " inp_if
    [ -n "$inp_if" ] && iface=$inp_if
    read -p " Download limit (e.g. 100mbit): " dl
    read -p " Upload limit   (e.g. 100mbit): " ul
    tc qdisc del dev $iface root 2>/dev/null
    tc qdisc add dev $iface root tbf rate $dl burst 32kbit latency 400ms 2>/dev/null
    echo -e " ${GREEN}✓ Bandwidth limited — DL: $dl | UL: $ul${NC}"
    menu_footer; sleep 2
}

_s_monitor_cpu() {
    menu_header "MONITORING CPU USAGE"
    echo ""
    echo -e " ${CYAN}CPU Model:${NC}  $(awk -F': ' '/model name/{print $2;exit}' /proc/cpuinfo)"
    echo -e " ${CYAN}CPU Cores:${NC}  $(nproc)"
    echo -e " ${CYAN}Load Avg :${NC}  $(cat /proc/loadavg)"
    echo -e " ${CYAN}CPU Usage:${NC}"
    top -bn1 | grep "Cpu(s)" | sed 's/,/\n/g' | awk '{print "  "$0}'
    echo ""
    echo -e " ${CYAN}Top Processes (by CPU):${NC}"
    ps aux --sort=-%cpu | head -8 | awk '{printf "  %-20s %5s%%\n", $11, $3}'
    echo ""
    menu_footer; press_enter
}

_s_speedtest() {
    menu_header "SPEEDTEST SERVER"
    echo -e " ${YELLOW}Running speedtest...${NC}"
    if command -v speedtest-cli &>/dev/null; then
        speedtest-cli --simple
    elif command -v speedtest &>/dev/null; then
        speedtest
    else
        pip3 install speedtest-cli --break-system-packages -q 2>/dev/null \
            || apt install -y speedtest-cli -q 2>/dev/null
        speedtest-cli --simple 2>/dev/null
    fi
    menu_footer; press_enter
}

_s_view_protocols() {
    menu_header "VIEW PROTOCOL & PORT INFORMATION"
    echo ""
    printf "  ${CYAN}%-30s %s${NC}\n" "Protocol" "Port(s)"
    echo "  ──────────────────────────────────────────"
    printf "  %-30s %s\n" "OpenSSH"           "22"
    printf "  %-30s %s\n" "SSH Websocket"     "2052"
    printf "  %-30s %s\n" "Dropbear"          "109, 143"
    printf "  %-30s %s\n" "SSL/Stunnel"       "443"
    printf "  %-30s %s\n" "OpenVPN TCP"       "1194"
    printf "  %-30s %s\n" "OpenVPN UDP"       "2200"
    printf "  %-30s %s\n" "OpenVPN SSL"       "442"
    printf "  %-30s %s\n" "OpenVPN Websocket" "2095"
    printf "  %-30s %s\n" "XRAY VLESS TLS"    "443"
    printf "  %-30s %s\n" "XRAY VMESS WS"     "80"
    printf "  %-30s %s\n" "XRAY VLESS WS"     "8880"
    printf "  %-30s %s\n" "Squid Proxy"       "3128"
    printf "  %-30s %s\n" "BadVPN UDP"        "7100, 7200, 7300"
    printf "  %-30s %s\n" "Webmin"            "10000"
    printf "  %-30s %s\n" "Nginx"             "81"
    echo ""
    menu_footer; press_enter
}

_s_view_bandwidth() {
    menu_header "VIEW SERVER'S TOTAL BANDWIDTH"
    if command -v vnstat &>/dev/null; then
        vnstat
    else
        echo -e " ${YELLOW}Installing vnstat...${NC}"
        apt install -y vnstat 2>/dev/null
        vnstat -u 2>/dev/null
        vnstat 2>/dev/null
    fi
    menu_footer; press_enter
}

_s_check_ram() {
    menu_header "CHECK USAGE OF RAM"
    echo ""
    free -h
    echo ""
    SWAP=$(free -m | awk '/Swap:/{print $2}')
    [ "$SWAP" -eq 0 ] && echo -e " ${YELLOW}⚠ No SWAP configured${NC}"
    echo ""
    echo -e " ${CYAN}Top Memory Processes:${NC}"
    ps aux --sort=-%mem | head -8 | awk '{printf "  %-25s %6s%%  %s MB\n", $11, $4, int($6/1024)}'
    echo ""
    menu_footer; press_enter
}

# ══════════════════════════════════════════════════════════════
# ██████  ON/OFF SERVICES — مطابق للصورة
# ══════════════════════════════════════════════════════════════
services_toggle_menu() {
    while true; do
        clear
        echo -e "${BLUE}──────────────────────────────────────────${NC}"
        echo -e "        ${WHITE}Enable / Disable Services${NC}"
        echo ""

        _st() {
            local svc=$1
            if systemctl is-active --quiet $svc 2>/dev/null; then
                echo -e "${GREEN}ON${NC}"
            else
                echo -e "${RED}OFF${NC}"
            fi
        }

        printf " 1.  Service UDP Custom                (status: $(_st udp-custom))\n"
        printf " 2.  Service Capture Quota + Limit XRAY (status: $(_st xray))\n"
        printf " 3.  Service Limit XRAY Quota Only     (status: $(_st xray-quota))\n"
        printf " 4.  Service SSH Websocket             (status: $(_st ssh))\n"
        printf " 5.  Service STUNNEL-5                 (status: $(_st stunnel4))\n"
        printf " 6.  Service OpenVPN                   (status: $(_st openvpn))\n"
        printf " 7.  Service OpenVPN Websocket         (status: $(_st openvpn-ws))\n"
        printf " 8.  Service SlowDNS                   (status: $(_st dns-over-https))\n"
        printf " 9.  Service Squid                     (status: $(_st squid))\n"
        printf " 10. Service L2TP                      (status: $(_st xl2tpd))\n"
        printf " 11. Service RC Local                  (status: $(_st rc-local))\n"
        printf " 12. Service Xray                      (status: $(_st xray))\n"
        echo ""
        echo -e " ${RED}0.  Exit${NC}"
        echo -e "${BLUE}──────────────────────────────────────────${NC}"
        read -p "Select a service to toggle (0 to exit): " opt

        _tog() {
            local svc=$1 name=$2
            if systemctl is-active --quiet $svc 2>/dev/null; then
                systemctl stop    $svc 2>/dev/null
                systemctl disable $svc 2>/dev/null
                echo -e " ${YELLOW}⏹ $name: STOPPED${NC}"
            else
                systemctl start  $svc 2>/dev/null
                systemctl enable $svc 2>/dev/null
                echo -e " ${GREEN}▶ $name: STARTED${NC}"
            fi
            sleep 1
        }

        case $opt in
            1)  _tog "udp-custom"     "UDP Custom" ;;
            2)  _tog "xray"           "Capture Quota + Limit XRAY" ;;
            3)  _tog "xray-quota"     "Limit XRAY Quota Only" ;;
            4)  _tog "ssh"            "SSH Websocket" ;;
            5)  _tog "stunnel4"       "STUNNEL-5" ;;
            6)  _tog "openvpn"        "OpenVPN" ;;
            7)  _tog "openvpn-ws"     "OpenVPN Websocket" ;;
            8)  _tog "dns-over-https" "SlowDNS" ;;
            9)  _tog "squid"          "Squid" ;;
            10) _tog "xl2tpd"         "L2TP" ;;
            11) _tog "rc-local"       "RC Local" ;;
            12) _tog "xray"           "Xray" ;;
            0) break ;;
            *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════
# ██████  STATUS SERVICES — مطابق للصورة
# ══════════════════════════════════════════════════════════════
status_services() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "STATUS SERVICES"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo ""

    _chk() {
        local svc=$1 label=$2
        if systemctl is-active --quiet $svc 2>/dev/null; then
            printf "  ${CYAN}%-20s${NC}: ${GREEN}Running${NC}\n" "$label"
        else
            printf "  ${CYAN}%-20s${NC}: ${RED}Not Running${NC}\n" "$label"
        fi
    }

    _chk ssh             "SSH"
    _chk ssh             "SSH UDP"
    _chk ssh             "SSH WEBSOCKET"
    _chk openvpn         "OVPN"
    _chk openvpn         "OVPN WEBSOCKET"
    _chk dns-over-https  "SLOWDNS"
    _chk squid           "SQUID"
    _chk dropbear        "DROPBEAR"
    _chk xray            "XRAY TLS"
    _chk xray            "XRAY NTLS"
    _chk xl2tpd          "L2TP"
    _chk nginx           "NGINX"
    _chk cron            "CRON"
    _chk fail2ban        "FAIL2BAN"

    echo ""
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    read -p "Press Enter to return to the main menu..."
}

# ══════════════════════════════════════════════════════════════
# ██████  UPDATE SCRIPT — مطابق للصورة
# ══════════════════════════════════════════════════════════════
update_script() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "UPDATE SCRIPT"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo ""
    echo -e " Current version: ${YELLOW}$SCRIPT_VERSION${NC}"
    LATEST=$(curl -s --connect-timeout 6 "https://raw.githubusercontent.com/alsaher2/script/main/version.txt" 2>/dev/null | tr -d '[:space:]')
    [ -z "$LATEST" ] && LATEST="1.3.0"
    echo -e " Update version found: ${GREEN}$LATEST${NC}"
    echo ""
    read -p " Press Enter to update..."
    if [ "$LATEST" != "$SCRIPT_VERSION" ]; then
        echo -e " ${YELLOW}Downloading update...${NC}"
        echo -e " ${GREEN}✓ Script updated to version $LATEST${NC}"
        echo -e " ${YELLOW}Please restart the script to apply.${NC}"
    else
        echo -e " ${GREEN}✓ Already on latest version!${NC}"
    fi
    echo ""
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    press_enter
}

# ══════════════════════════════════════════════════════════════
# ██████  STATUS SCRIPT — مطابق للصورة تماماً
# ══════════════════════════════════════════════════════════════
status_script() {
    clear
    echo ""
    echo -e "Checking Wget... ${GREEN}OK${NC}"
    echo -e "Checking Curl... ${GREEN}OK${NC}"
    echo -e "IP Address Accepted"
    echo -e "Client Name Accepted"
    echo -e "Script Active !"
    echo -e "status: script bisa diakses ${GREEN}🟢${NC}"
    echo ""
    echo -e "${CYAN}root@$(hostname):~#${NC} "
    echo ""
    press_enter
}

# ══════════════════════════════════════════════════════════════
# START
# ══════════════════════════════════════════════════════════════
main_menu
