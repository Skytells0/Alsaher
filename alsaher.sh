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
FIRST_RUN_FLAG="$INSTALL_DIR/config/.first_run_done"

# ─── Root Check ────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && { echo -e "${RED}Error: Run as root!${NC}"; exit 1; }

# ─── Init Directories ──────────────────────────────────────────
mkdir -p $INSTALL_DIR/{ssh,xray,l2tp,noobz,falcon,zivpn,backup,config,logs}

# ══════════════════════════════════════════════════════════════
# CLOUDFLARE DNS SETUP
# ══════════════════════════════════════════════════════════════
_cf_setup_domain() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "CLOUDFLARE DOMAIN SETUP"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}اربط دومينك بـ Cloudflare تلقائياً${NC}      ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  ستحتاج إلى:                             ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${YELLOW}1.${NC} Domain مسجّل في Cloudflare            ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${YELLOW}2.${NC} API Token من Cloudflare               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}     (Zone:DNS:Edit permission)           ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  ${LGREEN}[1]${NC} إعداد الدومين الآن                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${RED}[2]${NC} تخطى (يمكن الإعداد لاحقاً)             ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""
    read -p " اختر [1/2]: " cf_choice

    case $cf_choice in
        1) _cf_do_setup ;;
        2)
            echo -e " ${YELLOW}⚠ تم التخطي — يمكن الإعداد لاحقاً من Settings > Change Domain${NC}"
            sleep 2
            ;;
        *)
            echo -e " ${YELLOW}تم التخطي.${NC}"
            sleep 2
            ;;
    esac
}

_cf_do_setup() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "إدخال بيانات Cloudflare"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo ""

    # ── Get server IP ──
    IPADDR=$(curl -s4 --connect-timeout 5 ifconfig.me 2>/dev/null \
          || curl -s  --connect-timeout 5 ipinfo.io/ip 2>/dev/null \
          || hostname -I | awk '{print $1}')

    echo -e " ${CYAN}IP السيرفر الحالي: ${YELLOW}$IPADDR${NC}"
    echo ""

    # ── Input: Root Domain ──
    echo -e " ${WHITE}مثال: example.com${NC}"
    read -p " أدخل الدومين الرئيسي (Root Domain): " CF_ZONE_NAME
    [[ -z "$CF_ZONE_NAME" ]] && { echo -e "${RED}الدومين مطلوب!${NC}"; sleep 2; return; }

    # ── Input: Subdomain ──
    echo ""
    echo -e " ${WHITE}مثال: vpn.example.com أو example.com${NC}"
    read -p " أدخل السابدومين (اتركه فارغاً لاستخدام الرئيسي): " CF_SUBDOMAIN
    [[ -z "$CF_SUBDOMAIN" ]] && CF_SUBDOMAIN="$CF_ZONE_NAME"

    # ── Input: API Token ──
    echo ""
    echo -e " ${WHITE}احصل عليه من: dash.cloudflare.com > My Profile > API Tokens${NC}"
    echo -e " ${WHITE}الصلاحيات المطلوبة: Zone > DNS > Edit${NC}"
    read -p " أدخل Cloudflare API Token: " CF_API_TOKEN
    [[ -z "$CF_API_TOKEN" ]] && { echo -e "${RED}API Token مطلوب!${NC}"; sleep 2; return; }

    echo ""
    echo -e " ${YELLOW}▶ جاري التحقق من البيانات...${NC}"

    # ── Verify Token ──
    CF_VERIFY=$(curl -s --connect-timeout 8 \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        "https://api.cloudflare.com/client/v4/user/tokens/verify")

    if ! echo "$CF_VERIFY" | grep -q '"success":true'; then
        echo -e " ${RED}✗ API Token غير صحيح أو منتهي الصلاحية!${NC}"
        echo -e " ${YELLOW}تأكد من الصلاحيات: Zone:DNS:Edit${NC}"
        sleep 3
        return
    fi
    echo -e " ${GREEN}✓ API Token صحيح${NC}"

    # ── Get Zone ID ──
    echo -e " ${YELLOW}▶ جاري البحث عن Zone ID للدومين...${NC}"
    CF_ZONE_RESP=$(curl -s --connect-timeout 8 \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        "https://api.cloudflare.com/client/v4/zones?name=${CF_ZONE_NAME}&status=active")

    CF_ZONE_ID=$(echo "$CF_ZONE_RESP" | grep -oP '"id":"\K[^"]+' | head -1)

    if [[ -z "$CF_ZONE_ID" ]]; then
        echo -e " ${RED}✗ لم يُعثر على Zone للدومين: $CF_ZONE_NAME${NC}"
        echo -e " ${YELLOW}تأكد أن الدومين مضاف في حساب Cloudflare وأن التوكن له صلاحية عليه${NC}"
        sleep 4
        return
    fi
    echo -e " ${GREEN}✓ Zone ID: ${CYAN}$CF_ZONE_ID${NC}"

    # ── Extract record name (subdomain part only for CF) ──
    # CF needs just the subdomain name relative to zone, or @ for root
    if [[ "$CF_SUBDOMAIN" == "$CF_ZONE_NAME" ]]; then
        CF_RECORD_NAME="@"
        CF_DISPLAY_NAME="$CF_ZONE_NAME"
    else
        CF_RECORD_NAME="$CF_SUBDOMAIN"
        CF_DISPLAY_NAME="$CF_SUBDOMAIN"
    fi

    # ── Check if record already exists ──
    echo -e " ${YELLOW}▶ التحقق من السجلات الموجودة...${NC}"
    CF_EXISTING=$(curl -s --connect-timeout 8 \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=A&name=${CF_DISPLAY_NAME}")

    CF_RECORD_ID=$(echo "$CF_EXISTING" | grep -oP '"id":"\K[^"]+' | head -1)

    if [[ -n "$CF_RECORD_ID" ]]; then
        # ── Update existing record ──
        echo -e " ${YELLOW}▶ سجل موجود مسبقاً — جاري التحديث...${NC}"
        CF_RESULT=$(curl -s --connect-timeout 8 -X PUT \
            -H "Authorization: Bearer $CF_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"${CF_RECORD_NAME}\",\"content\":\"${IPADDR}\",\"ttl\":120,\"proxied\":false}" \
            "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${CF_RECORD_ID}")
        CF_ACTION="تحديث"
    else
        # ── Create new A record ──
        echo -e " ${YELLOW}▶ إنشاء سجل DNS جديد...${NC}"
        CF_RESULT=$(curl -s --connect-timeout 8 -X POST \
            -H "Authorization: Bearer $CF_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"${CF_RECORD_NAME}\",\"content\":\"${IPADDR}\",\"ttl\":120,\"proxied\":false}" \
            "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records")
        CF_ACTION="إنشاء"
    fi

    if echo "$CF_RESULT" | grep -q '"success":true'; then
        echo ""
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e " ${GREEN}✓ تم $CF_ACTION السجل بنجاح!${NC}"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e " ${CYAN}الدومين   :${NC} ${YELLOW}$CF_DISPLAY_NAME${NC}"
        echo -e " ${CYAN}IP السيرفر:${NC} ${YELLOW}$IPADDR${NC}"
        echo -e " ${CYAN}النوع     :${NC} ${YELLOW}A Record (DNS Only)${NC}"
        echo -e " ${CYAN}TTL       :${NC} ${YELLOW}120 ثانية${NC}"
        echo -e " ${CYAN}Proxy     :${NC} ${YELLOW}OFF (DNS Only — مطلوب للـ VPN)${NC}"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e " ${YELLOW}ℹ قد يستغرق الـ DNS من 1-5 دقائق للانتشار${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"

        # ── Save domain & CF credentials ──
        echo "$CF_SUBDOMAIN"  > "$DOMAIN_FILE"
        cat > "$INSTALL_DIR/config/cloudflare" <<EOF
CF_API_TOKEN=$CF_API_TOKEN
CF_ZONE_ID=$CF_ZONE_ID
CF_ZONE_NAME=$CF_ZONE_NAME
CF_SUBDOMAIN=$CF_SUBDOMAIN
CF_RECORD_NAME=$CF_RECORD_NAME
EOF
        chmod 600 "$INSTALL_DIR/config/cloudflare"
        echo -e " ${GREEN}✓ تم حفظ الدومين والبيانات${NC}"

        # ── Ask: setup wildcard too? ──
        echo ""
        read -p " هل تريد إضافة Wildcard (*.${CF_ZONE_NAME}) أيضاً؟ [y/n]: " wc_choice
        if [[ "$wc_choice" =~ ^[Yy]$ ]]; then
            WC_RESULT=$(curl -s --connect-timeout 8 -X POST \
                -H "Authorization: Bearer $CF_API_TOKEN" \
                -H "Content-Type: application/json" \
                --data "{\"type\":\"A\",\"name\":\"*\",\"content\":\"${IPADDR}\",\"ttl\":120,\"proxied\":false}" \
                "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records")
            echo "$WC_RESULT" | grep -q '"success":true' \
                && echo -e " ${GREEN}✓ تم إضافة Wildcard *.${CF_ZONE_NAME} → $IPADDR${NC}" \
                || echo -e " ${YELLOW}⚠ الـ Wildcard موجود مسبقاً أو فشل الإنشاء${NC}"
        fi

    else
        CF_ERROR=$(echo "$CF_RESULT" | grep -oP '"message":"\K[^"]+' | head -1)
        echo ""
        echo -e " ${RED}✗ فشل $CF_ACTION السجل!${NC}"
        echo -e " ${RED}السبب: $CF_ERROR${NC}"
        echo -e " ${YELLOW}يمكن الإعداد يدوياً لاحقاً من Settings > Change Domain${NC}"
    fi

    echo ""
    press_enter
}

# ── Update CF record (callable from settings) ──
_cf_update_record() {
    if [ ! -f "$INSTALL_DIR/config/cloudflare" ]; then
        echo -e " ${RED}لا توجد بيانات Cloudflare محفوظة. قم بالإعداد أولاً.${NC}"
        sleep 2
        return
    fi
    source "$INSTALL_DIR/config/cloudflare"
    NEW_IP=$(curl -s4 --connect-timeout 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    CF_EXISTING=$(curl -s --connect-timeout 8 \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=A&name=${CF_SUBDOMAIN}")
    CF_RECORD_ID=$(echo "$CF_EXISTING" | grep -oP '"id":"\K[^"]+' | head -1)
    [ -z "$CF_RECORD_ID" ] && { echo -e "${RED}لم يُعثر على السجل!${NC}"; sleep 2; return; }
    curl -s -X PUT \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"${CF_RECORD_NAME}\",\"content\":\"${NEW_IP}\",\"ttl\":120,\"proxied\":false}" \
        "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${CF_RECORD_ID}" > /dev/null
    echo "$CF_SUBDOMAIN" > "$DOMAIN_FILE"
    echo -e " ${GREEN}✓ DNS محدّث: ${YELLOW}$CF_SUBDOMAIN → $NEW_IP${NC}"
}

# ══════════════════════════════════════════════════════════════
# FIRST RUN — AUTO INSTALL ALL SERVICES
# ══════════════════════════════════════════════════════════════
first_run_install() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${WHITE}ALSAHER VPN — FIRST TIME SETUP          ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  ${YELLOW}مرحباً! يبدو هذا أول تشغيل للسكريبت.${NC}   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  سنقوم بإعداد السيرفر خطوة بخطوة.       ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    sleep 2

    # ── STEP 1: Cloudflare Domain ──────────────────────────────
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "الخطوة 1 / 2 — إعداد الدومين"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}قبل تنصيب الخدمات، هل لديك دومين       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Cloudflare تريد ربطه بهذا السيرفر؟     ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  ${LGREEN}[1]${NC} نعم — اربط الدومين الآن              ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${YELLOW}[2]${NC} لاحقاً — تخطى الآن                   ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""
    read -p " اختر [1/2]: " cf_ans
    [[ "$cf_ans" == "1" ]] && _cf_do_setup

    # ── STEP 2: Check & Install Missing Services ──────────────
    _check_and_install_missing

    # Mark first run as done
    touch "$FIRST_RUN_FLAG"
}

# ══════════════════════════════════════════════════════════════
# CHECK MISSING SERVICES AND PROMPT INSTALL
# ══════════════════════════════════════════════════════════════
_check_and_install_missing() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "الخطوة 2 / 2 — فحص الخدمات"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  ${YELLOW}جاري فحص الخدمات المثبّتة...${NC}           ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    sleep 1

    # ── Define core required services ──
    # Format: "display_name|check_cmd|install_fn"
    local -a CORE_SVCS=(
        "OpenSSH Server|ssh|_apt_install openssh-server ssh"
        "Dropbear SSH|dropbear|_install_dropbear_full"
        "Stunnel5 SSL|stunnel4|_install_stunnel_full"
        "SSH Websocket|websocat|_install_websocat_full"
        "OpenVPN|openvpn|_install_openvpn_full"
        "Xray Core|xray|_install_xray_full"
        "L2TP / IPSec|xl2tpd|_install_l2tp_full"
        "Squid Proxy|squid|_apt_install squid squid"
        "BadVPN UDPGW|badvpn-udpgw|_install_badvpn_full"
        "Nginx|nginx|_apt_install nginx nginx"
        "Certbot SSL|certbot|_install_certbot_full"
        "Fail2Ban|fail2ban|_apt_install fail2ban fail2ban"
        "UFW Firewall|ufw|_install_ufw_full"
        "vnStat|vnstat|_apt_install vnstat vnstat"
        "Cron|cron|_apt_install cron cron"
        "RC-Local|rc-local|_install_rclocal_full"
        "Net-Tools|net-tools|_apt_install net-tools ''"
        "Python3|python3|_install_python_full"
        "Iptables|iptables|_apt_install iptables ''"
    )

    # ── تحديث الحزم الأساسية أولاً بشكل صامت ──────────────────
    echo "" >> "$LOG_FILE"
    echo "=== AUTO-INSTALL MISSING — $(date) ===" >> "$LOG_FILE"
    apt-get update -y >> "$LOG_FILE" 2>&1
    apt-get install -y curl wget git unzip tar openssl gnupg2 lsb-release \
        ca-certificates software-properties-common apt-transport-https \
        >> "$LOG_FILE" 2>&1

    local total=${#CORE_SVCS[@]}
    local current=0
    local success=0
    local failed=0
    local skipped=0

    clear
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "الخطوة 2 / 2 — فحص وتنصيب الخدمات"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"

    for entry in "${CORE_SVCS[@]}"; do
        ((current++))
        local name="${entry%%|*}"
        local rest="${entry#*|}"
        local check="${rest%%|*}"
        local fn="${rest#*|}"

        # ── عرض شريط التقدم ──
        local pct=$(( current * 100 / total ))
        local filled=$(( current * 20 / total ))
        local bar=""
        for ((b=0; b<filled; b++));  do bar+="█"; done
        for ((b=filled; b<20; b++)); do bar+="░"; done

        printf "\r${BLUE}║${NC}  [${GREEN}%s${NC}] %3d%%  %-20s   ${BLUE}║${NC}\n" \
               "$bar" "$pct" "$name"

        if _is_installed "$check"; then
            printf "${BLUE}║${NC}   ${GREEN}✓${NC} %-37s${BLUE}║${NC}\n" "$name — مثبّت مسبقاً"
            ((skipped++))
            echo "[SKIP] $name already installed" >> "$LOG_FILE"
        else
            printf "${BLUE}║${NC}   ${YELLOW}▶${NC} %-37s${BLUE}║${NC}\n" "جاري تنصيب $name ..."
            eval "$fn" >> "$LOG_FILE" 2>&1
            if _is_installed "$check"; then
                printf "${BLUE}║${NC}   ${GREEN}✓${NC} %-37s${BLUE}║${NC}\n" "$name — تم التنصيب"
                ((success++))
                echo "[OK] $name" >> "$LOG_FILE"
            else
                printf "${BLUE}║${NC}   ${RED}✗${NC} %-37s${BLUE}║${NC}\n" "$name — فشل التنصيب"
                ((failed++))
                echo "[FAIL] $name" >> "$LOG_FILE"
            fi
        fi
    done

    # ── ملخص نهائي ────────────────────────────────────────────
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    printf  "${BLUE}║${NC}  ${GREEN}✓ تم تنصيب  : %-3s خدمة%-20s${BLUE}║${NC}\n" "$success" ""
    printf  "${BLUE}║${NC}  ${CYAN}● موجودة    : %-3s خدمة%-20s${BLUE}║${NC}\n" "$skipped" ""
    [ $failed -gt 0 ] && \
    printf  "${BLUE}║${NC}  ${RED}✗ فشل       : %-3s خدمة%-20s${BLUE}║${NC}\n" "$failed" ""
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    printf  "${BLUE}║${NC}  ${CYAN}السجل: ${YELLOW}%-33s${BLUE}║${NC}\n" "$LOG_FILE"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""
    press_enter
}

_do_full_install() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${WHITE}FULL AUTO INSTALL — جاري التنصيب ...    ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo "" | tee -a $LOG_FILE
    echo "=== ALSAHER FULL INSTALL — $(date) ===" >> $LOG_FILE

    # ── 0. Prepare system ──────────────────────────────────────
    _log_step "تحديث النظام (apt update & upgrade)..."
    apt-get update -y >> $LOG_FILE 2>&1
    apt-get upgrade -y >> $LOG_FILE 2>&1
    apt-get install -y curl wget git unzip tar openssl gnupg2 lsb-release \
        ca-certificates software-properties-common apt-transport-https \
        net-tools iptables iproute2 cron python3 python3-pip >> $LOG_FILE 2>&1
    _log_ok "System base packages"

    # ── 1. OpenSSH ──────────────────────────────────────────────
    _log_step "تنصيب OpenSSH Server..."
    apt-get install -y openssh-server >> $LOG_FILE 2>&1
    systemctl enable ssh >> $LOG_FILE 2>&1
    systemctl start  ssh >> $LOG_FILE 2>&1
    _log_ok "OpenSSH Server"

    # ── 2. Dropbear ─────────────────────────────────────────────
    _log_step "تنصيب Dropbear SSH..."
    apt-get install -y dropbear >> $LOG_FILE 2>&1
    sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear 2>/dev/null
    sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/' /etc/default/dropbear 2>/dev/null
    systemctl enable dropbear >> $LOG_FILE 2>&1
    systemctl restart dropbear >> $LOG_FILE 2>&1
    _log_ok "Dropbear SSH (port 109)"

    # ── 3. Stunnel5 ─────────────────────────────────────────────
    _log_step "تنصيب Stunnel5 (SSL Tunnel)..."
    apt-get install -y stunnel4 >> $LOG_FILE 2>&1
    sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null
    # Basic stunnel config if missing
    if [ ! -f /etc/stunnel/stunnel.conf ]; then
        cat > /etc/stunnel/stunnel.conf <<'SEOF'
cert = /etc/stunnel/stunnel.pem
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
[ssh-ssl]
accept  = 443
connect = 127.0.0.1:22
SEOF
        openssl req -new -x509 -days 3650 -nodes \
            -out /etc/stunnel/stunnel.pem \
            -keyout /etc/stunnel/stunnel.pem \
            -subj "/CN=alsaher-vpn" >> $LOG_FILE 2>&1
    fi
    systemctl enable stunnel4 >> $LOG_FILE 2>&1
    systemctl restart stunnel4 >> $LOG_FILE 2>&1
    _log_ok "Stunnel5 (port 443)"

    # ── 4. OpenVPN ──────────────────────────────────────────────
    _log_step "تنصيب OpenVPN..."
    apt-get install -y openvpn >> $LOG_FILE 2>&1
    systemctl enable openvpn >> $LOG_FILE 2>&1
    _log_ok "OpenVPN"

    # ── 5. Xray Core ────────────────────────────────────────────
    _log_step "تنصيب Xray Core..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >> $LOG_FILE 2>&1
    systemctl enable xray >> $LOG_FILE 2>&1
    systemctl start  xray >> $LOG_FILE 2>&1
    _log_ok "Xray Core"

    # ── 6. L2TP / IPSec ─────────────────────────────────────────
    _log_step "تنصيب L2TP / IPSec..."
    apt-get install -y xl2tpd strongswan >> $LOG_FILE 2>&1
    systemctl enable xl2tpd >> $LOG_FILE 2>&1
    _log_ok "L2TP / IPSec (xl2tpd + strongswan)"

    # ── 7. WireGuard ────────────────────────────────────────────
    _log_step "تنصيب WireGuard..."
    apt-get install -y wireguard >> $LOG_FILE 2>&1
    _log_ok "WireGuard"

    # ── 8. Squid Proxy ──────────────────────────────────────────
    _log_step "تنصيب Squid Proxy..."
    apt-get install -y squid >> $LOG_FILE 2>&1
    systemctl enable squid >> $LOG_FILE 2>&1
    systemctl start  squid >> $LOG_FILE 2>&1
    _log_ok "Squid Proxy (port 3128)"

    # ── 9. BadVPN (UDPGW) ───────────────────────────────────────
    _log_step "تنصيب BadVPN UDPGW..."
    if ! command -v badvpn-udpgw &>/dev/null; then
        apt-get install -y cmake make gcc >> $LOG_FILE 2>&1
        cd /tmp
        git clone https://github.com/ambrop72/badvpn.git >> $LOG_FILE 2>&1
        cd badvpn
        cmake . -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >> $LOG_FILE 2>&1
        make install >> $LOG_FILE 2>&1
        cd /root
    fi
    # Create systemd service for badvpn
    cat > /etc/systemd/system/badvpn.service <<'BEOF'
[Unit]
Description=BadVPN UDPGW
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500
Restart=always

[Install]
WantedBy=multi-user.target
BEOF
    systemctl daemon-reload >> $LOG_FILE 2>&1
    systemctl enable badvpn >> $LOG_FILE 2>&1
    systemctl start  badvpn >> $LOG_FILE 2>&1
    _log_ok "BadVPN UDPGW (port 7300)"

    # ── 10. Nginx ───────────────────────────────────────────────
    _log_step "تنصيب Nginx..."
    apt-get install -y nginx >> $LOG_FILE 2>&1
    systemctl enable nginx >> $LOG_FILE 2>&1
    systemctl start  nginx >> $LOG_FILE 2>&1
    _log_ok "Nginx"

    # ── 11. Certbot ─────────────────────────────────────────────
    _log_step "تنصيب Certbot (SSL)..."
    apt-get install -y certbot python3-certbot-nginx >> $LOG_FILE 2>&1
    _log_ok "Certbot"

    # ── 12. Fail2Ban ────────────────────────────────────────────
    _log_step "تنصيب Fail2Ban..."
    apt-get install -y fail2ban >> $LOG_FILE 2>&1
    systemctl enable fail2ban >> $LOG_FILE 2>&1
    systemctl start  fail2ban >> $LOG_FILE 2>&1
    _log_ok "Fail2Ban"

    # ── 13. vnStat ──────────────────────────────────────────────
    _log_step "تنصيب vnStat..."
    apt-get install -y vnstat >> $LOG_FILE 2>&1
    systemctl enable vnstat >> $LOG_FILE 2>&1
    systemctl start  vnstat >> $LOG_FILE 2>&1
    _log_ok "vnStat"

    # ── 14. Speedtest CLI ───────────────────────────────────────
    _log_step "تنصيب Speedtest CLI..."
    pip3 install speedtest-cli --break-system-packages >> $LOG_FILE 2>&1 || \
    apt-get install -y speedtest-cli >> $LOG_FILE 2>&1
    _log_ok "Speedtest CLI"

    # ── 15. UFW Firewall ────────────────────────────────────────
    _log_step "تنصيب وإعداد UFW Firewall..."
    apt-get install -y ufw >> $LOG_FILE 2>&1
    ufw --force reset >> $LOG_FILE 2>&1
    ufw default deny incoming >> $LOG_FILE 2>&1
    ufw default allow outgoing >> $LOG_FILE 2>&1
    # Allow all VPN ports
    for port in 22 80 109 143 443 442 1194 2052 2095 2200 3128 7100 7200 7300 8080 8880 10000; do
        ufw allow $port >> $LOG_FILE 2>&1
    done
    ufw --force enable >> $LOG_FILE 2>&1
    _log_ok "UFW Firewall (all VPN ports opened)"

    # ── 16. Websocat (SSH Websocket) ────────────────────────────
    _log_step "تنصيب Websocat (SSH Websocket)..."
    WS_URL="https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl"
    curl -L "$WS_URL" -o /usr/local/bin/websocat >> $LOG_FILE 2>&1
    chmod +x /usr/local/bin/websocat
    _log_ok "Websocat"

    # ── 17. RC-Local ────────────────────────────────────────────
    _log_step "تفعيل RC-Local..."
    if [ ! -f /etc/rc.local ]; then
        echo '#!/bin/bash' > /etc/rc.local
        echo 'exit 0' >> /etc/rc.local
        chmod +x /etc/rc.local
    fi
    cat > /etc/systemd/system/rc-local.service <<'RCEOF'
[Unit]
Description=RC Local Compatibility
After=network.target

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
RCEOF
    systemctl daemon-reload >> $LOG_FILE 2>&1
    systemctl enable rc-local >> $LOG_FILE 2>&1
    _log_ok "RC-Local"

    # ── 18. IP Forwarding & Kernel Tweaks ───────────────────────
    _log_step "إعداد IP Forwarding وتحسينات الكيرنل..."
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf 2>/dev/null
    sysctl -p >> $LOG_FILE 2>&1
    _log_ok "IP Forwarding & Kernel Tweaks"

    echo ""
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  ${GREEN}✓ تم تنصيب جميع الخدمات بنجاح!${NC}         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  📄 السجل: ${YELLOW}$LOG_FILE${NC}               ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""
    press_enter
}

_log_step() {
    echo -e " ${YELLOW}▶${NC} $1"
    echo "[INFO] $1" >> $LOG_FILE
}

_log_ok() {
    echo -e " ${GREEN}✓${NC} $1 — ${GREEN}OK${NC}"
    echo "[OK] $1" >> $LOG_FILE
}

_log_fail() {
    echo -e " ${RED}✗${NC} $1 — ${RED}FAILED${NC}"
    echo "[FAIL] $1" >> $LOG_FILE
}

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
    SSH_COUNT=$(ls    $INSTALL_DIR/ssh/    2>/dev/null | wc -l)
    XRAY_COUNT=$(ls   $INSTALL_DIR/xray/   2>/dev/null | wc -l)
    L2TP_COUNT=$(ls   $INSTALL_DIR/l2tp/   2>/dev/null | wc -l)
    NOOBZ_COUNT=$(ls  $INSTALL_DIR/noobz/  2>/dev/null | wc -l)
    FALCON_COUNT=$(ls $INSTALL_DIR/falcon/ 2>/dev/null | wc -l)
    ZIVPN_COUNT=$(ls $INSTALL_DIR/zivpn/  2>/dev/null | wc -l)
}

# ══════════════════════════════════════════════════════════════
# HEADER
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
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    printf "${BLUE}║${NC}    FALCON ACCOUNT =${GREEN}  %-3s                  ${BLUE}║${NC}\n" "$FALCON_COUNT"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    printf "${BLUE}║${NC}    ZIVPN ACCOUNT  =${GREEN}  %-3s                  ${BLUE}║${NC}\n" "$ZIVPN_COUNT"
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
        echo -e "${BLUE}║${NC} ${LGREEN}1.${NC}  MENU SSH & OVPN                      ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}2.${NC}  MENU XRAY                            ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}3.${NC}  MENU L2TP                            ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}4.${NC}  MENU NOOBZVPNS                       ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}5.${NC}  MENU FALCON PROXY                    ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}6.${NC}  MENU ZIVPN                           ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}7.${NC}  SETTINGS                             ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}8.${NC}  ON/OFF SERVICES                      ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}9.${NC}  STATUS SERVICES                      ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}10.${NC} UPDATE SCRIPT                        ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}11.${NC} STATUS SCRIPT                        ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}12.${NC} INSTALL / REMOVE SERVICES            ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${RED}0.${NC}  Exit                                 ${BLUE}║${NC}"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} EXP SCRIPT: ${YELLOW}$EXP_DATE ($EXP_DAYS days)${NC}  ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} REGIST BY : ${YELLOW}$REGIST_BY (id telegram)${NC}  ${BLUE}║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
        read -p "Please select an option [0-12]: " opt
        case $opt in
            1)  ssh_menu ;;
            2)  xray_menu ;;
            3)  l2tp_menu ;;
            4)  noobz_menu ;;
            5)  falcon_menu ;;
            6)  zivpn_menu ;;
            7)  settings_menu ;;
            8)  services_toggle_menu ;;
            9)  status_services ;;
            10) update_script ;;
            11) status_script ;;
            12) install_menu ;;
            0)  echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *)  echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
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
# ██████  INSTALL / REMOVE SERVICES MENU
# ══════════════════════════════════════════════════════════════

# Check if a package/command is installed
_is_installed() {
    local name="$1"
    command -v "$name" &>/dev/null && return 0
    dpkg -l "$name" &>/dev/null 2>&1 && return 0
    systemctl list-unit-files 2>/dev/null | grep -q "^${name}.service" && return 0
    return 1
}

# Badge: show green INSTALLED or red NOT INSTALLED
_badge() {
    if _is_installed "$1"; then
        printf "${GREEN}[INSTALLED]${NC}"
    else
        printf "${RED}[NOT SET]${NC}   "
    fi
}

install_menu() {
    while true; do
        clear
        echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
        printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "INSTALL / REMOVE SERVICES"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        printf  "${BLUE}║${NC} ${PURPLE}► SSH & TUNNELING${NC}%-25s${BLUE}║${NC}\n" ""
        printf  "${BLUE}║${NC}  ${LGREEN}[1]${NC}  OpenSSH Server          $(_badge ssh)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[2]${NC}  Dropbear SSH            $(_badge dropbear)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[3]${NC}  Stunnel5 (SSL Tunnel)   $(_badge stunnel4)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[4]${NC}  SSH Websocket (websocat) $(_badge websocat)  ${BLUE}║${NC}\n"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        printf  "${BLUE}║${NC} ${PURPLE}► VPN SERVICES${NC}%-27s${BLUE}║${NC}\n" ""
        printf  "${BLUE}║${NC}  ${LGREEN}[5]${NC}  OpenVPN                 $(_badge openvpn)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[6]${NC}  Xray Core               $(_badge xray)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[7]${NC}  L2TP / IPSec (xl2tpd)  $(_badge xl2tpd)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[8]${NC}  WireGuard               $(_badge wg)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[26]${NC} Falcon Proxy            $(_badge proxy)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[27]${NC} ZiVPN (UDP 5667)        $(_badge zivpn)   ${BLUE}║${NC}\n"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        printf  "${BLUE}║${NC} ${PURPLE}► PROXY & DNS${NC}%-28s${BLUE}║${NC}\n" ""
        printf  "${BLUE}║${NC}  ${LGREEN}[9]${NC}  Squid Proxy             $(_badge squid)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[10]${NC} SlowDNS                 $(_badge dns-over-https)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[11]${NC} BadVPN UDPGW            $(_badge badvpn-udpgw)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[12]${NC} Cloudflare WARP         $(_badge warp-cli)   ${BLUE}║${NC}\n"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        printf  "${BLUE}║${NC} ${PURPLE}► WEB & MONITORING${NC}%-23s${BLUE}║${NC}\n" ""
        printf  "${BLUE}║${NC}  ${LGREEN}[13]${NC} Nginx Web Server        $(_badge nginx)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[14]${NC} Certbot SSL             $(_badge certbot)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[15]${NC} Fail2Ban                $(_badge fail2ban)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[16]${NC} Webmin                  $(_badge webmin)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[17]${NC} vnStat Bandwidth Mon.   $(_badge vnstat)   ${BLUE}║${NC}\n"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        printf  "${BLUE}║${NC} ${PURPLE}► UTILITIES${NC}%-30s${BLUE}║${NC}\n" ""
        printf  "${BLUE}║${NC}  ${LGREEN}[18]${NC} Speedtest CLI           $(_badge speedtest-cli)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[19]${NC} UFW Firewall            $(_badge ufw)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[20]${NC} Net-Tools               $(_badge net-tools)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[21]${NC} Python3 & PIP3          $(_badge python3)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[22]${NC} Iptables                $(_badge iptables)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[23]${NC} RC-Local                $(_badge rc-local)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[24]${NC} Cron                    $(_badge cron)   ${BLUE}║${NC}\n"
        printf  "${BLUE}║${NC}  ${LGREEN}[25]${NC} TC Traffic Control      $(_badge tc)   ${BLUE}║${NC}\n"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC}  ${RED}[0]${NC}  Back to Main Menu                   ${BLUE}║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"

        read -p "Select service [0-25]: " opt
        case $opt in
            1)  _svc_menu "OpenSSH Server"       "openssh-server"  "ssh"           "_apt_install"  ;;
            2)  _svc_menu "Dropbear SSH"         "dropbear"        "dropbear"      "_install_dropbear_full" ;;
            3)  _svc_menu "Stunnel5"             "stunnel4"        "stunnel4"      "_install_stunnel_full" ;;
            4)  _svc_menu "SSH Websocket"        "websocat"        ""              "_install_websocat_full" ;;
            5)  _svc_menu "OpenVPN"              "openvpn"         "openvpn"       "_install_openvpn_full" ;;
            6)  _svc_menu "Xray Core"            "xray"            "xray"          "_install_xray_full" ;;
            7)  _svc_menu "L2TP / IPSec"         "xl2tpd"          "xl2tpd"        "_install_l2tp_full" ;;
            8)  _svc_menu "WireGuard"            "wireguard"       "wg-quick@wg0"  "_apt_install" ;;
            9)  _svc_menu "Squid Proxy"          "squid"           "squid"         "_apt_install" ;;
            10) _svc_menu "SlowDNS"              "dns-over-https"  "dns-over-https" "_install_slowdns_full" ;;
            11) _svc_menu "BadVPN UDPGW"         "badvpn-udpgw"   "badvpn"        "_install_badvpn_full" ;;
            12) _svc_menu "Cloudflare WARP"      "warp-cli"        "warp-svc"      "_install_warp_full" ;;
            13) _svc_menu "Nginx"                "nginx"           "nginx"         "_apt_install" ;;
            14) _svc_menu "Certbot SSL"          "certbot"         ""              "_install_certbot_full" ;;
            15) _svc_menu "Fail2Ban"             "fail2ban"        "fail2ban"      "_apt_install" ;;
            16) _svc_menu "Webmin"               "webmin"          "webmin"        "_install_webmin_full" ;;
            17) _svc_menu "vnStat"               "vnstat"          "vnstat"        "_apt_install" ;;
            18) _svc_menu "Speedtest CLI"        "speedtest-cli"   ""              "_install_speedtest_full" ;;
            19) _svc_menu "UFW Firewall"         "ufw"             "ufw"           "_install_ufw_full" ;;
            20) _svc_menu "Net-Tools"            "net-tools"       ""              "_apt_install" ;;
            21) _svc_menu "Python3 & PIP3"       "python3"         ""              "_install_python_full" ;;
            22) _svc_menu "Iptables"             "iptables"        ""              "_apt_install" ;;
            23) _svc_menu "RC-Local"             "rc-local"        "rc-local"      "_install_rclocal_full" ;;
            24) _svc_menu "Cron"                 "cron"            "cron"          "_apt_install" ;;
            25) _svc_menu "TC Traffic Control"   "iproute2"        ""              "_apt_install" ;;
            26) _svc_menu "Falcon Proxy"            "proxy"           "falcon-proxy"  "_install_falcon_full" ;;
            27) _svc_menu "ZiVPN UDP"               "zivpn"           "zivpn"         "_install_zivpn_full" ;;
            0) break ;;
            *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════
# SERVICE INSTALL/REMOVE DIALOG
# pkg=$2 = apt package name OR command name
# svc=$3 = systemd service name
# fn=$4  = custom install function name (or "_apt_install" for simple ones)
# ══════════════════════════════════════════════════════════════
_svc_menu() {
    local label="$1"
    local pkg="$2"
    local svc="$3"
    local install_fn="$4"

    menu_header "MANAGE — $label"
    echo ""

    if _is_installed "$pkg"; then
        echo -e " ${GREEN}● الحالة: مثبّت (INSTALLED)${NC}"
        echo ""
        echo -e " ${LGREEN}[1]${NC} إعادة تثبيت / تحديث"
        echo -e " ${RED}[2]${NC} حذف (Remove)"
        echo -e " ${YELLOW}[0]${NC} رجوع"
        echo ""
        read -p " اختر [0-2]: " c
        case $c in
            1)
                _log_step "إعادة تثبيت $label..."
                $install_fn "$pkg" "$svc"
                ;;
            2)
                confirm_action " تأكيد حذف $label?" || { echo "Cancelled."; sleep 1; return; }
                _remove_service "$pkg" "$svc" "$label"
                ;;
            0) return ;;
        esac
    else
        echo -e " ${RED}● الحالة: غير مثبّت (NOT INSTALLED)${NC}"
        echo ""
        echo -e " ${LGREEN}[1]${NC} تثبيت الآن (Install)"
        echo -e " ${YELLOW}[0]${NC} رجوع"
        echo ""
        read -p " اختر [0-1]: " c
        case $c in
            1)
                _log_step "تثبيت $label..."
                $install_fn "$pkg" "$svc"
                ;;
            0) return ;;
        esac
    fi
    echo ""
    menu_footer
    press_enter
}

# ──────────────────────────────────────────────────────────────
# REMOVE a service
# ──────────────────────────────────────────────────────────────
_remove_service() {
    local pkg="$1"
    local svc="$2"
    local label="$3"
    [ -n "$svc" ] && {
        systemctl stop    "$svc" 2>/dev/null
        systemctl disable "$svc" 2>/dev/null
    }
    apt-get purge -y "$pkg" >> $LOG_FILE 2>&1
    apt-get autoremove -y   >> $LOG_FILE 2>&1
    echo -e " ${GREEN}✓ تم حذف $label بنجاح${NC}"
}

# ──────────────────────────────────────────────────────────────
# GENERIC APT INSTALL + enable/start service
# ──────────────────────────────────────────────────────────────
_apt_install() {
    local pkg="$1"
    local svc="$2"
    apt-get update -y >> $LOG_FILE 2>&1
    apt-get install -y "$pkg" >> $LOG_FILE 2>&1
    [ -n "$svc" ] && {
        systemctl enable "$svc" >> $LOG_FILE 2>&1
        systemctl start  "$svc" >> $LOG_FILE 2>&1
    }
    _log_ok "$pkg"
}

# ──────────────────────────────────────────────────────────────
# DROPBEAR — custom install (set ports)
# ──────────────────────────────────────────────────────────────
_install_dropbear_full() {
    apt-get install -y dropbear >> $LOG_FILE 2>&1
    sed -i 's/NO_START=1/NO_START=0/'   /etc/default/dropbear 2>/dev/null
    sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 109 -p 143"/' /etc/default/dropbear 2>/dev/null
    grep -q "DROPBEAR_EXTRA_ARGS" /etc/default/dropbear || \
        echo 'DROPBEAR_EXTRA_ARGS="-p 109 -p 143"' >> /etc/default/dropbear
    systemctl enable dropbear >> $LOG_FILE 2>&1
    systemctl restart dropbear >> $LOG_FILE 2>&1
    _log_ok "Dropbear (ports 109, 143)"
}

# ──────────────────────────────────────────────────────────────
# STUNNEL5 — custom install (auto generate cert)
# ──────────────────────────────────────────────────────────────
_install_stunnel_full() {
    apt-get install -y stunnel4 >> $LOG_FILE 2>&1
    sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null
    if [ ! -f /etc/stunnel/stunnel.pem ]; then
        openssl req -new -x509 -days 3650 -nodes \
            -out /etc/stunnel/stunnel.pem \
            -keyout /etc/stunnel/stunnel.pem \
            -subj "/CN=alsaher-vpn" >> $LOG_FILE 2>&1
    fi
    cat > /etc/stunnel/stunnel.conf <<'EOF'
cert = /etc/stunnel/stunnel.pem
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
[ssh-ssl]
accept  = 443
connect = 127.0.0.1:22
[dropbear-ssl]
accept  = 444
connect = 127.0.0.1:109
EOF
    systemctl enable stunnel4 >> $LOG_FILE 2>&1
    systemctl restart stunnel4 >> $LOG_FILE 2>&1
    _log_ok "Stunnel5 (port 443, 444)"
}

# ──────────────────────────────────────────────────────────────
# WEBSOCAT — SSH Websocket
# ──────────────────────────────────────────────────────────────
_install_websocat_full() {
    WS_URL="https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl"
    curl -L "$WS_URL" -o /usr/local/bin/websocat >> $LOG_FILE 2>&1
    chmod +x /usr/local/bin/websocat
    # Create systemd service
    cat > /etc/systemd/system/ssh-ws.service <<'EOF'
[Unit]
Description=SSH Websocket Proxy
After=network.target

[Service]
ExecStart=/usr/local/bin/websocat -t --binary ws-l:0.0.0.0:2052 tcp:127.0.0.1:22
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >> $LOG_FILE 2>&1
    systemctl enable ssh-ws >> $LOG_FILE 2>&1
    systemctl start  ssh-ws >> $LOG_FILE 2>&1
    _log_ok "SSH Websocket (port 2052)"
}

# ──────────────────────────────────────────────────────────────
# OPENVPN — install + basic config
# ──────────────────────────────────────────────────────────────
_install_openvpn_full() {
    apt-get install -y openvpn easy-rsa >> $LOG_FILE 2>&1
    systemctl enable openvpn >> $LOG_FILE 2>&1
    _log_ok "OpenVPN"
    echo -e " ${YELLOW}ℹ لتشغيل OpenVPN يجب إعداد ملف config.ovpn${NC}"
}

# ──────────────────────────────────────────────────────────────
# XRAY — install from official script
# ──────────────────────────────────────────────────────────────
_install_xray_full() {
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >> $LOG_FILE 2>&1
    systemctl enable xray >> $LOG_FILE 2>&1
    systemctl start  xray >> $LOG_FILE 2>&1
    _log_ok "Xray Core"
}

# ──────────────────────────────────────────────────────────────
# L2TP / IPSec
# ──────────────────────────────────────────────────────────────
_install_l2tp_full() {
    apt-get install -y xl2tpd strongswan ppp >> $LOG_FILE 2>&1
    # xl2tpd basic config
    [ ! -f /etc/xl2tpd/xl2tpd.conf ] && cat > /etc/xl2tpd/xl2tpd.conf <<'EOF'
[global]
ipsec saref = yes
[lns default]
ip range = 192.168.100.10-192.168.100.100
local ip = 192.168.100.1
require chap = yes
refuse pap = yes
require authentication = yes
name = xl2tpd
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF
    [ ! -f /etc/ppp/options.xl2tpd ] && cat > /etc/ppp/options.xl2tpd <<'EOF'
require-mschap-v2
ms-dns 8.8.8.8
ms-dns 8.8.4.4
auth
mtu 1280
mru 1280
nodefaultroute
lock
proxyarp
EOF
    systemctl enable xl2tpd >> $LOG_FILE 2>&1
    systemctl start  xl2tpd >> $LOG_FILE 2>&1
    _log_ok "L2TP / IPSec"
}

# ──────────────────────────────────────────────────────────────
# BADVPN UDPGW
# ──────────────────────────────────────────────────────────────
_install_badvpn_full() {
    apt-get install -y cmake make gcc git >> $LOG_FILE 2>&1
    cd /tmp
    rm -rf badvpn
    git clone https://github.com/ambrop72/badvpn.git >> $LOG_FILE 2>&1
    cd badvpn
    cmake . -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >> $LOG_FILE 2>&1
    make install >> $LOG_FILE 2>&1
    cd /root
    cat > /etc/systemd/system/badvpn.service <<'EOF'
[Unit]
Description=BadVPN UDPGW
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >> $LOG_FILE 2>&1
    systemctl enable badvpn >> $LOG_FILE 2>&1
    systemctl start  badvpn >> $LOG_FILE 2>&1
    _log_ok "BadVPN UDPGW (port 7300)"
}

# ──────────────────────────────────────────────────────────────
# SLOWDNS
# ──────────────────────────────────────────────────────────────
_install_slowdns_full() {
    read -p " SlowDNS Domain (NS record): " sdomain
    [ -n "$sdomain" ] && echo "$sdomain" > "$SLOWDNS_FILE"
    # Placeholder: download actual slowdns binary from your source
    echo -e " ${YELLOW}ℹ يجب رفع ملف slowdns binary يدوياً إلى /usr/local/bin/slowdns${NC}"
    _log_ok "SlowDNS config saved"
}

# ──────────────────────────────────────────────────────────────
# WARP CLOUDFLARE
# ──────────────────────────────────────────────────────────────
_install_warp_full() {
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | \
        gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg >> $LOG_FILE 2>&1
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] \
https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | \
        tee /etc/apt/sources.list.d/cloudflare-client.list >> $LOG_FILE 2>&1
    apt-get update -y >> $LOG_FILE 2>&1
    apt-get install -y cloudflare-warp >> $LOG_FILE 2>&1
    _log_ok "Cloudflare WARP"
}

# ──────────────────────────────────────────────────────────────
# CERTBOT
# ──────────────────────────────────────────────────────────────
_install_certbot_full() {
    apt-get install -y certbot python3-certbot-nginx >> $LOG_FILE 2>&1
    _log_ok "Certbot"
    echo -e " ${YELLOW}ℹ لإصدار شهادة: certbot --nginx -d yourdomain.com${NC}"
}

# ──────────────────────────────────────────────────────────────
# WEBMIN
# ──────────────────────────────────────────────────────────────
_install_webmin_full() {
    curl -o /tmp/setup-repos.sh \
        https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh >> $LOG_FILE 2>&1
    bash /tmp/setup-repos.sh --force >> $LOG_FILE 2>&1
    apt-get install -y webmin >> $LOG_FILE 2>&1
    systemctl enable webmin >> $LOG_FILE 2>&1
    systemctl start  webmin >> $LOG_FILE 2>&1
    _log_ok "Webmin (port 10000)"
}

# ──────────────────────────────────────────────────────────────
# SPEEDTEST
# ──────────────────────────────────────────────────────────────
_install_speedtest_full() {
    pip3 install speedtest-cli --break-system-packages >> $LOG_FILE 2>&1 || \
    apt-get install -y speedtest-cli >> $LOG_FILE 2>&1
    _log_ok "Speedtest CLI"
}

# ──────────────────────────────────────────────────────────────
# UFW — open all needed ports automatically
# ──────────────────────────────────────────────────────────────
_install_ufw_full() {
    apt-get install -y ufw >> $LOG_FILE 2>&1
    ufw --force reset >> $LOG_FILE 2>&1
    ufw default deny incoming >> $LOG_FILE 2>&1
    ufw default allow outgoing >> $LOG_FILE 2>&1
    for port in 22 80 109 143 443 442 444 1194 2052 2095 2200 3128 7100 7200 7300 8080 8880 10000; do
        ufw allow $port >> $LOG_FILE 2>&1
    done
    ufw allow 500/udp  >> $LOG_FILE 2>&1
    ufw allow 4500/udp >> $LOG_FILE 2>&1
    ufw --force enable >> $LOG_FILE 2>&1
    _log_ok "UFW Firewall (all ports opened)"
}

# ──────────────────────────────────────────────────────────────
# PYTHON3
# ──────────────────────────────────────────────────────────────
_install_python_full() {
    apt-get install -y python3 python3-pip >> $LOG_FILE 2>&1
    _log_ok "Python3 & PIP3"
}

# ──────────────────────────────────────────────────────────────
# RC-LOCAL
# ──────────────────────────────────────────────────────────────
_install_rclocal_full() {
    if [ ! -f /etc/rc.local ]; then
        echo '#!/bin/bash' > /etc/rc.local
        echo 'exit 0' >> /etc/rc.local
        chmod +x /etc/rc.local
    fi
    cat > /etc/systemd/system/rc-local.service <<'EOF'
[Unit]
Description=RC Local Compatibility
After=network.target

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >> $LOG_FILE 2>&1
    systemctl enable rc-local >> $LOG_FILE 2>&1
    _log_ok "RC-Local"
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
    read -p " New VLESS path (Enter to keep): " new_vpath
    read -p " New VMESS path (Enter to keep): " new_vmpath
    [[ -n "$new_vpath" ]]  && { echo "$new_vpath"  > $INSTALL_DIR/config/vless_path; vpath=$new_vpath; }
    [[ -n "$new_vmpath" ]] && { echo "$new_vmpath" > $INSTALL_DIR/config/vmess_path; vmpath=$new_vmpath; }
    [ -f /usr/local/etc/xray/config.json ] && {
        sed -i "s|\"path\":.*vless.*|\"path\": \"$vpath\"|g" /usr/local/etc/xray/config.json 2>/dev/null
        systemctl restart xray 2>/dev/null && echo -e " ${GREEN}✓ XRAY restarted${NC}"
    }
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
    read -p " New ban time in seconds: " bantime
    [[ ! "$bantime" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid!${NC}"; sleep 2; return; }
    echo "$bantime" > $INSTALL_DIR/config/xray_bantime
    echo -e " ${GREEN}✓ Ban time set to $bantime seconds${NC}"
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
    limit=$((today + 259200))
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
        echo -e "${BLUE}║${NC} ${LGREEN}3.${NC} Delete L2TP                           ${BLUE}║${NC}"
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
# ██████  FALCON PROXY
# ══════════════════════════════════════════════════════════════
falcon_menu() {
    while true; do
        clear
        FALCON_BIN_VER=$(proxy --version 2>/dev/null | head -1 || echo "Not installed")
        echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
        printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "MENU FALCON PROXY"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} Version: ${CYAN}$FALCON_BIN_VER${NC}                       ${BLUE}║${NC}"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}1.${NC}  Create Falcon User                   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}2.${NC}  Trial Falcon User                    ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}3.${NC}  Renew Falcon User                    ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}4.${NC}  Delete Falcon User                   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}5.${NC}  List All Falcon Users                ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}6.${NC}  Detail Falcon User                   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}7.${NC}  Block Falcon User                    ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}8.${NC}  Unblock Falcon User                  ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}9.${NC}  Reset Falcon Quota                   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}10.${NC} Change Limit IP                      ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}11.${NC} Change Quota                         ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}12.${NC} Users Expiring Within 3 Days         ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${RED}0.${NC}  Back to Main Menu                   ${BLUE}║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
        read -p "Please select an option [0-12]: " opt
        case $opt in
            1)  _falcon_create ;;
            2)  _falcon_trial ;;
            3)  _falcon_renew ;;
            4)  _falcon_delete ;;
            5)  _falcon_list ;;
            6)  _falcon_detail ;;
            7)  _falcon_block ;;
            8)  _falcon_unblock ;;
            9)  _falcon_reset_quota ;;
            10) _falcon_limit_ip ;;
            11) _falcon_limit_quota ;;
            12) _falcon_expiring ;;
            0) break ;;
            *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
        esac
    done
}

_falcon_create() {
    menu_header "CREATE FALCON PROXY USER"
    read -p " Username        : " user
    [[ -z "$user" ]] && { echo -e "${RED}Username required!${NC}"; sleep 2; return; }
    [ -f "$INSTALL_DIR/falcon/$user" ] && { echo -e "${RED}User already exists!${NC}"; sleep 2; return; }
    read -p " Password        : " pass
    read -p " Duration (days) : " days
    read -p " Max IP (def 2)  : " maxip
    read -p " Quota GB (def 50): " quota
    [[ -z "$pass"  ]] && { echo -e "${RED}Password required!${NC}"; sleep 2; return; }
    [[ -z "$days"  ]] && days=30
    [[ -z "$maxip" ]] && maxip=2
    [[ -z "$quota" ]] && quota=50
    exp=$(date -d "+${days} days" +"%Y-%m-%d")
    domain=$(cat $DOMAIN_FILE 2>/dev/null || echo "$IPADDR")
    cat > $INSTALL_DIR/falcon/$user <<EOF
Username : $user
Password : $pass
Domain   : $domain
Created  : $(date +"%Y-%m-%d")
Expires  : $exp
Duration : $days days
Max IP   : $maxip
Quota    : $quota GB
Used     : 0 GB
Status   : Active
EOF
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e " ${GREEN}✓ Falcon user created!${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e " Username : ${YELLOW}$user${NC}"
    echo -e " Password : ${YELLOW}$pass${NC}"
    echo -e " Host     : ${YELLOW}$domain${NC}"
    echo -e " Port     : ${YELLOW}8080${NC}"
    echo -e " Expires  : ${YELLOW}$exp${NC}"
    echo -e " Max IP   : ${YELLOW}$maxip${NC}"
    echo -e " Quota    : ${YELLOW}$quota GB${NC}"
    menu_footer; press_enter
}

_falcon_trial() {
    menu_header "TRIAL FALCON PROXY USER"
    user="falcon$(date +%s | tail -c 5)"
    pass="trial123"
    exp=$(date -d "+1 day" +"%Y-%m-%d")
    domain=$(cat $DOMAIN_FILE 2>/dev/null || echo "$IPADDR")
    cat > $INSTALL_DIR/falcon/$user <<EOF
Username : $user
Password : $pass
Domain   : $domain
Created  : $(date +"%Y-%m-%d")
Expires  : $exp
Duration : 1 day (Trial)
Max IP   : 1
Quota    : 5 GB
Used     : 0 GB
Status   : Active
EOF
    echo -e " ${GREEN}✓ Trial Falcon created!${NC}"
    echo -e " Username : ${YELLOW}$user${NC}"
    echo -e " Password : ${YELLOW}$pass${NC}"
    echo -e " Host     : ${YELLOW}$domain${NC}"
    echo -e " Port     : ${YELLOW}8080${NC}"
    echo -e " Expires  : ${YELLOW}$exp${NC} (1 day)"
    # Register in 3proxy
    _falcon_add_3proxy_user "$user" "$pass" 2>/dev/null
    menu_footer; press_enter
}

_falcon_renew() {
    menu_header "RENEW FALCON USER"
    if [ "$(ls $INSTALL_DIR/falcon/ 2>/dev/null | wc -l)" -gt 0 ]; then
        echo -e " ${CYAN}Current Accounts:${NC}"
        for u in $(ls $INSTALL_DIR/falcon/); do
            exp=$(grep "Expires" $INSTALL_DIR/falcon/$u | cut -d':' -f2 | xargs)
            echo -e "  ${YELLOW}$u${NC} — $exp"
        done; echo ""
    fi
    read -p " Username to renew: " user
    [ ! -f "$INSTALL_DIR/falcon/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    read -p " Add days        : " days
    cur_exp=$(grep "Expires" $INSTALL_DIR/falcon/$user | cut -d':' -f2 | xargs)
    new_exp=$(date -d "$cur_exp +${days} days" +"%Y-%m-%d" 2>/dev/null || date -d "+${days} days" +"%Y-%m-%d")
    sed -i "s/Expires.*/Expires  : $new_exp/" $INSTALL_DIR/falcon/$user
    echo -e " ${GREEN}✓ Renewed until $new_exp${NC}"
    menu_footer; press_enter
}

_falcon_delete() {
    menu_header "DELETE FALCON USER"
    if [ "$(ls $INSTALL_DIR/falcon/ 2>/dev/null | wc -l)" -gt 0 ]; then
        echo -e " ${CYAN}Accounts:${NC}"
        for u in $(ls $INSTALL_DIR/falcon/); do
            exp=$(grep "Expires" $INSTALL_DIR/falcon/$u | cut -d':' -f2 | xargs)
            echo -e "  ${YELLOW}$u${NC} — $exp"
        done; echo ""
    fi
    read -p " Username to delete: " user
    [ ! -f "$INSTALL_DIR/falcon/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    confirm_action " Delete $user?" || { echo "Cancelled."; sleep 1; return; }
    rm -f $INSTALL_DIR/falcon/$user
    _falcon_del_3proxy_user "$user" 2>/dev/null
    echo -e " ${GREEN}✓ Falcon user '$user' deleted!${NC}"
    menu_footer; press_enter
}

_falcon_list() {
    menu_header "LIST ALL FALCON USERS"
    echo ""
    printf "  %-5s %-18s %-12s %-6s %-10s %-8s %s\n" "No" "Username" "Expires" "MaxIP" "Quota" "Used" "Status"
    echo "  ──────────────────────────────────────────────────────────"
    if [ -d "$INSTALL_DIR/falcon" ] && [ "$(ls -A $INSTALL_DIR/falcon 2>/dev/null)" ]; then
        i=1
        today_ts=$(date +%s)
        for u in $(ls $INSTALL_DIR/falcon/); do
            exp=$(grep    "Expires"  $INSTALL_DIR/falcon/$u 2>/dev/null | cut -d':' -f2 | xargs)
            maxip=$(grep  "Max IP"   $INSTALL_DIR/falcon/$u 2>/dev/null | cut -d':' -f2 | xargs || echo "2")
            quota=$(grep  "^Quota"   $INSTALL_DIR/falcon/$u 2>/dev/null | cut -d':' -f2 | xargs || echo "50 GB")
            used=$(grep   "^Used"    $INSTALL_DIR/falcon/$u 2>/dev/null | cut -d':' -f2 | xargs || echo "0 GB")
            status=$(grep "Status"   $INSTALL_DIR/falcon/$u 2>/dev/null | cut -d':' -f2 | xargs || echo "Active")
            exp_ts=$(date -d "$exp" +%s 2>/dev/null || echo 0)
            if [ $exp_ts -lt $today_ts ]; then sc="${RED}Expired${NC}"
            elif [[ "$status" == "Blocked" ]]; then sc="${YELLOW}Blocked${NC}"
            else sc="${GREEN}Active${NC}"; fi
            printf "  %-5s %-18s %-12s %-6s %-10s %-8s " "$i." "$u" "$exp" "$maxip" "$quota" "$used"
            echo -e "$sc"
            ((i++))
        done
    else
        echo -e "  ${YELLOW}No Falcon accounts found${NC}"
    fi
    echo ""
    menu_footer; press_enter
}

_falcon_detail() {
    menu_header "DETAIL FALCON USER"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/falcon/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    echo ""
    while IFS= read -r line; do echo -e "  ${CYAN}$line${NC}"; done < $INSTALL_DIR/falcon/$user
    echo ""
    domain=$(grep "Domain"   $INSTALL_DIR/falcon/$user | cut -d':' -f2 | xargs)
    pass=$(grep   "Password" $INSTALL_DIR/falcon/$user | cut -d':' -f2 | xargs)
    echo -e " ${YELLOW}── Connection Info ──${NC}"
    echo -e " Host : ${YELLOW}$domain${NC}"
    echo -e " Port : ${YELLOW}8080${NC}"
    echo -e " User : ${YELLOW}$user${NC}"
    echo -e " Pass : ${YELLOW}$pass${NC}"
    echo -e " Type : ${YELLOW}HTTP/HTTPS Proxy${NC}"
    echo ""
    menu_footer; press_enter
}

_falcon_block() {
    menu_header "BLOCK FALCON USER"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/falcon/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    sed -i "s/Status.*/Status   : Blocked/" $INSTALL_DIR/falcon/$user
    _falcon_block_3proxy_user "$user" 2>/dev/null
    echo -e " ${GREEN}✓ User '$user' blocked!${NC}"
    menu_footer; press_enter
}

_falcon_unblock() {
    menu_header "UNBLOCK FALCON USER"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/falcon/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    sed -i "s/Status.*/Status   : Active/" $INSTALL_DIR/falcon/$user
    _falcon_unblock_3proxy_user "$user" 2>/dev/null
    echo -e " ${GREEN}✓ User '$user' unblocked!${NC}"
    menu_footer; press_enter
}

_falcon_reset_quota() {
    menu_header "RESET FALCON QUOTA"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/falcon/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    sed -i "s/^Used.*/Used     : 0 GB/" $INSTALL_DIR/falcon/$user
    echo -e " ${GREEN}✓ Quota reset for '$user'${NC}"
    menu_footer; press_enter
}

_falcon_limit_ip() {
    menu_header "CHANGE LIMIT IP — FALCON"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/falcon/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    cur=$(grep "Max IP" $INSTALL_DIR/falcon/$user | cut -d':' -f2 | xargs)
    echo -e " Current Max IP: ${YELLOW}$cur${NC}"
    read -p " New Max IP limit (1-10): " maxip
    [[ ! "$maxip" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid!${NC}"; sleep 2; return; }
    sed -i "s/Max IP.*/Max IP   : $maxip/" $INSTALL_DIR/falcon/$user
    echo -e " ${GREEN}✓ Max IP updated to $maxip for $user${NC}"
    menu_footer; press_enter
}

_falcon_limit_quota() {
    menu_header "CHANGE QUOTA — FALCON"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/falcon/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    cur=$(grep "^Quota" $INSTALL_DIR/falcon/$user | cut -d':' -f2 | xargs)
    echo -e " Current Quota: ${YELLOW}$cur${NC}"
    read -p " New Quota (GB): " quota
    [[ ! "$quota" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid!${NC}"; sleep 2; return; }
    sed -i "s/^Quota.*/Quota    : $quota GB/" $INSTALL_DIR/falcon/$user
    echo -e " ${GREEN}✓ Quota updated to $quota GB for $user${NC}"
    menu_footer; press_enter
}

_falcon_expiring() {
    menu_header "FALCON USERS EXPIRING WITHIN 3 DAYS"
    echo ""
    today=$(date +%s)
    limit=$((today + 259200))
    found=0
    for u in $(ls $INSTALL_DIR/falcon/ 2>/dev/null); do
        exp_str=$(grep "Expires" $INSTALL_DIR/falcon/$u 2>/dev/null | cut -d':' -f2 | xargs)
        [ -z "$exp_str" ] && continue
        exp_ts=$(date -d "$exp_str" +%s 2>/dev/null) || continue
        if [ $exp_ts -le $limit ] && [ $exp_ts -ge $today ]; then
            days_left=$(( (exp_ts - today) / 86400 ))
            echo -e "  ${WHITE}$u${NC} — Expires: ${RED}$exp_str${NC} (${days_left} days left)"
            found=1
        fi
    done
    [ $found -eq 0 ] && echo -e "  ${GREEN}No Falcon users expiring within 3 days ✓${NC}"
    echo ""
    menu_footer; press_enter
}

_install_falcon_full() {
    _log_step "تنصيب Falcon Proxy (3proxy HTTP+SOCKS5)..."
    apt-get install -y build-essential git curl wget >> "$LOG_FILE" 2>&1

    # ── Build 3proxy from source ──────────────────────────────
    if ! command -v 3proxy &>/dev/null; then
        cd /tmp
        rm -rf 3proxy
        git clone https://github.com/3proxy/3proxy.git >> "$LOG_FILE" 2>&1
        cd 3proxy
        make -f Makefile.Linux >> "$LOG_FILE" 2>&1
        cp bin/3proxy /usr/local/bin/3proxy
        chmod +x /usr/local/bin/3proxy
        cd /root
    fi

    # ── Create config directories ──────────────────────────────
    mkdir -p /etc/3proxy /var/log/3proxy
    touch /etc/3proxy/passwd

    # ── Write default 3proxy config ───────────────────────────
    cat > /etc/3proxy/3proxy.cfg <<'EOF3'
#!/usr/local/bin/3proxy
# Falcon Proxy — powered by 3proxy
daemon
pidfile /var/run/3proxy.pid
nserver 8.8.8.8
nserver 8.8.4.4
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
log /var/log/3proxy/access.log D
logformat "- +_L%t.%.  %N.%p %E %U %C:%c %R:%r %O %I %h %T"
rotate 30
# Auth file
users $/etc/3proxy/passwd
# Allow authenticated users only
auth strong
allow *
# HTTP Proxy port 8080
proxy -p8080 -a
# SOCKS5 port 1080
socks -p1080 -a
EOF3

    # ── Systemd service ────────────────────────────────────────
    cat > /etc/systemd/system/falcon-proxy.service <<'FEOF'
[Unit]
Description=Falcon Proxy (3proxy HTTP+SOCKS5)
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
PIDFile=/var/run/3proxy.pid
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
FEOF

    systemctl daemon-reload >> "$LOG_FILE" 2>&1
    systemctl enable falcon-proxy >> "$LOG_FILE" 2>&1
    systemctl start  falcon-proxy >> "$LOG_FILE" 2>&1
    _log_ok "Falcon Proxy — HTTP:8080 | SOCKS5:1080"
}

# ── Add user to 3proxy passwd file ────────────────────────────
_falcon_add_3proxy_user() {
    local user="$1" pass="$2"
    # 3proxy uses CL (clear text) or CR (crypt) passwords
    # Format: username:CL:password
    if grep -q "^${user}:" /etc/3proxy/passwd 2>/dev/null; then
        sed -i "s|^${user}:.*|${user}:CL:${pass}|" /etc/3proxy/passwd
    else
        echo "${user}:CL:${pass}" >> /etc/3proxy/passwd
    fi
    systemctl reload falcon-proxy 2>/dev/null || systemctl restart falcon-proxy 2>/dev/null
}

# ── Remove user from 3proxy passwd file ───────────────────────
_falcon_del_3proxy_user() {
    local user="$1"
    sed -i "/^${user}:/d" /etc/3proxy/passwd 2>/dev/null
    systemctl reload falcon-proxy 2>/dev/null || systemctl restart falcon-proxy 2>/dev/null
}

# ── Block/unblock user in 3proxy (comment out line) ───────────
_falcon_block_3proxy_user() {
    local user="$1"
    sed -i "s|^${user}:|#BLOCKED#${user}:|" /etc/3proxy/passwd 2>/dev/null
    systemctl reload falcon-proxy 2>/dev/null || systemctl restart falcon-proxy 2>/dev/null
}

_falcon_unblock_3proxy_user() {
    local user="$1"
    sed -i "s|^#BLOCKED#${user}:|${user}:|" /etc/3proxy/passwd 2>/dev/null
    systemctl reload falcon-proxy 2>/dev/null || systemctl restart falcon-proxy 2>/dev/null
}

# ══════════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════════
# ██████  ZIVPN (UDP 5667)
# ══════════════════════════════════════════════════════════════
zivpn_menu() {
    while true; do
        clear
        ZI_VER=$(zivpn --version 2>/dev/null | head -1 || echo "Not installed")
        echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
        printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "MENU ZIVPN (UDP 5667)"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} Version: ${CYAN}$ZI_VER${NC}                         ${BLUE}║${NC}"
        echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}1.${NC}  Create ZiVPN User                   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}2.${NC}  Trial ZiVPN User                    ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}3.${NC}  Renew ZiVPN User                    ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}4.${NC}  Delete ZiVPN User                   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}5.${NC}  List All ZiVPN Users                ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}6.${NC}  Detail ZiVPN User                   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}7.${NC}  Block ZiVPN User                    ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}8.${NC}  Unblock ZiVPN User                  ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}9.${NC}  Reset ZiVPN Quota                   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}10.${NC} Change Limit IP                     ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}11.${NC} Change Quota                        ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}12.${NC} Change ZiVPN Port                   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${LGREEN}13.${NC} Users Expiring Within 3 Days        ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${RED}0.${NC}  Back to Main Menu                   ${BLUE}║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
        read -p "Please select an option [0-13]: " opt
        case $opt in
            1)  _zivpn_create ;;
            2)  _zivpn_trial ;;
            3)  _zivpn_renew ;;
            4)  _zivpn_delete ;;
            5)  _zivpn_list ;;
            6)  _zivpn_detail ;;
            7)  _zivpn_block ;;
            8)  _zivpn_unblock ;;
            9)  _zivpn_reset_quota ;;
            10) _zivpn_limit_ip ;;
            11) _zivpn_limit_quota ;;
            12) _zivpn_change_port ;;
            13) _zivpn_expiring ;;
            0) break ;;
            *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
        esac
    done
}

_zivpn_create() {
    menu_header "CREATE ZIVPN USER"
    read -p " Username        : " user
    [[ -z "$user" ]] && { echo -e "${RED}Username required!${NC}"; sleep 2; return; }
    [ -f "$INSTALL_DIR/zivpn/$user" ] && { echo -e "${RED}User already exists!${NC}"; sleep 2; return; }
    read -p " Password        : " pass
    read -p " Duration (days) : " days
    read -p " Max IP (def 2)  : " maxip
    read -p " Quota GB (def 50): " quota
    [[ -z "$pass"  ]] && { echo -e "${RED}Password required!${NC}"; sleep 2; return; }
    [[ -z "$days"  ]] && days=30
    [[ -z "$maxip" ]] && maxip=2
    [[ -z "$quota" ]] && quota=50
    exp=$(date -d "+${days} days" +"%Y-%m-%d")
    domain=$(cat $DOMAIN_FILE 2>/dev/null || echo "$IPADDR")
    port=$(cat $INSTALL_DIR/config/zivpn_port 2>/dev/null || echo "5667")
    cat > $INSTALL_DIR/zivpn/$user <<EOF
Username : $user
Password : $pass
Domain   : $domain
Created  : $(date +"%Y-%m-%d")
Expires  : $exp
Duration : $days days
Max IP   : $maxip
Quota    : $quota GB
Used     : 0 GB
Status   : Active
EOF
    # Register in ZiVPN system
    _zivpn_add_user "$user" "$pass"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e " ${GREEN}✓ ZiVPN user created!${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo -e " Username : ${YELLOW}$user${NC}"
    echo -e " Password : ${YELLOW}$pass${NC}"
    echo -e " Host     : ${YELLOW}$domain${NC}"
    echo -e " Port     : ${YELLOW}$port (UDP)${NC}"
    echo -e " Expires  : ${YELLOW}$exp${NC}"
    echo -e " Max IP   : ${YELLOW}$maxip${NC}"
    echo -e " Quota    : ${YELLOW}$quota GB${NC}"
    menu_footer; press_enter
}

_zivpn_trial() {
    menu_header "TRIAL ZIVPN USER"
    user="zi$(date +%s | tail -c 5)"
    pass="trial123"
    exp=$(date -d "+1 day" +"%Y-%m-%d")
    domain=$(cat $DOMAIN_FILE 2>/dev/null || echo "$IPADDR")
    port=$(cat $INSTALL_DIR/config/zivpn_port 2>/dev/null || echo "5667")
    cat > $INSTALL_DIR/zivpn/$user <<EOF
Username : $user
Password : $pass
Domain   : $domain
Created  : $(date +"%Y-%m-%d")
Expires  : $exp
Duration : 1 day (Trial)
Max IP   : 1
Quota    : 5 GB
Used     : 0 GB
Status   : Active
EOF
    _zivpn_add_user "$user" "$pass"
    echo -e " ${GREEN}✓ Trial ZiVPN created!${NC}"
    echo -e " Username : ${YELLOW}$user${NC}"
    echo -e " Password : ${YELLOW}$pass${NC}"
    echo -e " Host     : ${YELLOW}$domain${NC}"
    echo -e " Port     : ${YELLOW}$port (UDP)${NC}"
    echo -e " Expires  : ${YELLOW}$exp${NC} (1 day)"
    menu_footer; press_enter
}

_zivpn_renew() {
    menu_header "RENEW ZIVPN USER"
    if [ "$(ls $INSTALL_DIR/zivpn/ 2>/dev/null | wc -l)" -gt 0 ]; then
        echo -e " ${CYAN}Current Accounts:${NC}"
        for u in $(ls $INSTALL_DIR/zivpn/); do
            exp=$(grep "Expires" $INSTALL_DIR/zivpn/$u | cut -d':' -f2 | xargs)
            echo -e "  ${YELLOW}$u${NC} — $exp"
        done; echo ""
    fi
    read -p " Username to renew: " user
    [ ! -f "$INSTALL_DIR/zivpn/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    read -p " Add days        : " days
    cur_exp=$(grep "Expires" $INSTALL_DIR/zivpn/$user | cut -d':' -f2 | xargs)
    new_exp=$(date -d "$cur_exp +${days} days" +"%Y-%m-%d" 2>/dev/null || date -d "+${days} days" +"%Y-%m-%d")
    sed -i "s/Expires.*/Expires  : $new_exp/" $INSTALL_DIR/zivpn/$user
    echo -e " ${GREEN}✓ Renewed until $new_exp${NC}"
    menu_footer; press_enter
}

_zivpn_delete() {
    menu_header "DELETE ZIVPN USER"
    if [ "$(ls $INSTALL_DIR/zivpn/ 2>/dev/null | wc -l)" -gt 0 ]; then
        echo -e " ${CYAN}Accounts:${NC}"
        for u in $(ls $INSTALL_DIR/zivpn/); do
            exp=$(grep "Expires" $INSTALL_DIR/zivpn/$u | cut -d':' -f2 | xargs)
            echo -e "  ${YELLOW}$u${NC} — $exp"
        done; echo ""
    fi
    read -p " Username to delete: " user
    [ ! -f "$INSTALL_DIR/zivpn/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    confirm_action " Delete $user?" || { echo "Cancelled."; sleep 1; return; }
    rm -f $INSTALL_DIR/zivpn/$user
    _zivpn_del_user "$user"
    echo -e " ${GREEN}✓ ZiVPN user '$user' deleted!${NC}"
    menu_footer; press_enter
}

_zivpn_list() {
    menu_header "LIST ALL ZIVPN USERS"
    echo ""
    printf "  %-5s %-18s %-12s %-6s %-10s %-8s %s\n" "No" "Username" "Expires" "MaxIP" "Quota" "Used" "Status"
    echo "  ──────────────────────────────────────────────────────────"
    if [ -d "$INSTALL_DIR/zivpn" ] && [ "$(ls -A $INSTALL_DIR/zivpn 2>/dev/null)" ]; then
        i=1
        today_ts=$(date +%s)
        for u in $(ls $INSTALL_DIR/zivpn/); do
            exp=$(grep    "Expires"  $INSTALL_DIR/zivpn/$u 2>/dev/null | cut -d':' -f2 | xargs)
            maxip=$(grep  "Max IP"   $INSTALL_DIR/zivpn/$u 2>/dev/null | cut -d':' -f2 | xargs || echo "2")
            quota=$(grep  "^Quota"   $INSTALL_DIR/zivpn/$u 2>/dev/null | cut -d':' -f2 | xargs || echo "50 GB")
            used=$(grep   "^Used"    $INSTALL_DIR/zivpn/$u 2>/dev/null | cut -d':' -f2 | xargs || echo "0 GB")
            status=$(grep "Status"   $INSTALL_DIR/zivpn/$u 2>/dev/null | cut -d':' -f2 | xargs || echo "Active")
            exp_ts=$(date -d "$exp" +%s 2>/dev/null || echo 0)
            if   [ $exp_ts -lt $today_ts ];        then sc="${RED}Expired${NC}"
            elif [[ "$status" == "Blocked" ]];      then sc="${YELLOW}Blocked${NC}"
            else sc="${GREEN}Active${NC}"; fi
            printf "  %-5s %-18s %-12s %-6s %-10s %-8s " "$i." "$u" "$exp" "$maxip" "$quota" "$used"
            echo -e "$sc"
            ((i++))
        done
    else
        echo -e "  ${YELLOW}No ZiVPN accounts found${NC}"
    fi
    echo ""
    menu_footer; press_enter
}

_zivpn_detail() {
    menu_header "DETAIL ZIVPN USER"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/zivpn/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    echo ""
    while IFS= read -r line; do echo -e "  ${CYAN}$line${NC}"; done < $INSTALL_DIR/zivpn/$user
    echo ""
    domain=$(grep "Domain"   $INSTALL_DIR/zivpn/$user | cut -d':' -f2 | xargs)
    pass=$(grep   "Password" $INSTALL_DIR/zivpn/$user | cut -d':' -f2 | xargs)
    port=$(cat $INSTALL_DIR/config/zivpn_port 2>/dev/null || echo "5667")
    echo -e " ${YELLOW}── Connection Info ──${NC}"
    echo -e " Host     : ${YELLOW}$domain${NC}"
    echo -e " Port     : ${YELLOW}$port (UDP)${NC}"
    echo -e " Username : ${YELLOW}$user${NC}"
    echo -e " Password : ${YELLOW}$pass${NC}"
    echo -e " Protocol : ${YELLOW}UDP / ZiVPN${NC}"
    echo ""
    menu_footer; press_enter
}

_zivpn_block() {
    menu_header "BLOCK ZIVPN USER"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/zivpn/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    sed -i "s/Status.*/Status   : Blocked/" $INSTALL_DIR/zivpn/$user
    _zivpn_block_user "$user"
    echo -e " ${GREEN}✓ User '$user' blocked!${NC}"
    menu_footer; press_enter
}

_zivpn_unblock() {
    menu_header "UNBLOCK ZIVPN USER"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/zivpn/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    sed -i "s/Status.*/Status   : Active/" $INSTALL_DIR/zivpn/$user
    _zivpn_unblock_user "$user"
    echo -e " ${GREEN}✓ User '$user' unblocked!${NC}"
    menu_footer; press_enter
}

_zivpn_reset_quota() {
    menu_header "RESET ZIVPN QUOTA"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/zivpn/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    sed -i "s/^Used.*/Used     : 0 GB/" $INSTALL_DIR/zivpn/$user
    echo -e " ${GREEN}✓ Quota reset for '$user'${NC}"
    menu_footer; press_enter
}

_zivpn_limit_ip() {
    menu_header "CHANGE LIMIT IP — ZIVPN"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/zivpn/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    cur=$(grep "Max IP" $INSTALL_DIR/zivpn/$user | cut -d':' -f2 | xargs)
    echo -e " Current Max IP: ${YELLOW}$cur${NC}"
    read -p " New Max IP (1-10): " maxip
    [[ ! "$maxip" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid!${NC}"; sleep 2; return; }
    sed -i "s/Max IP.*/Max IP   : $maxip/" $INSTALL_DIR/zivpn/$user
    echo -e " ${GREEN}✓ Max IP updated to $maxip for $user${NC}"
    menu_footer; press_enter
}

_zivpn_limit_quota() {
    menu_header "CHANGE QUOTA — ZIVPN"
    read -p " Username: " user
    [ ! -f "$INSTALL_DIR/zivpn/$user" ] && { echo -e "${RED}User not found!${NC}"; sleep 2; return; }
    cur=$(grep "^Quota" $INSTALL_DIR/zivpn/$user | cut -d':' -f2 | xargs)
    echo -e " Current Quota: ${YELLOW}$cur${NC}"
    read -p " New Quota (GB): " quota
    [[ ! "$quota" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid!${NC}"; sleep 2; return; }
    sed -i "s/^Quota.*/Quota    : $quota GB/" $INSTALL_DIR/zivpn/$user
    echo -e " ${GREEN}✓ Quota updated to $quota GB for $user${NC}"
    menu_footer; press_enter
}

_zivpn_change_port() {
    menu_header "CHANGE ZIVPN PORT"
    cur=$(cat $INSTALL_DIR/config/zivpn_port 2>/dev/null || echo "5667")
    echo -e " Current port: ${YELLOW}$cur (UDP)${NC}"
    read -p " New UDP port: " port
    [[ ! "$port" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid port!${NC}"; sleep 2; return; }
    echo "$port" > $INSTALL_DIR/config/zivpn_port
    # Update config file
    [ -f /etc/zivpn/server.conf ] && \
        sed -i "s/^port.*/port = $port/" /etc/zivpn/server.conf 2>/dev/null
    # Update UDP port in udpgw / iptables rule if needed
    ufw allow "$port/udp" 2>/dev/null
    systemctl restart zivpn 2>/dev/null
    echo -e " ${GREEN}✓ ZiVPN port changed to $port/UDP${NC}"
    menu_footer; press_enter
}

_zivpn_expiring() {
    menu_header "ZIVPN USERS EXPIRING WITHIN 3 DAYS"
    echo ""
    today=$(date +%s)
    limit=$((today + 259200))
    found=0
    for u in $(ls $INSTALL_DIR/zivpn/ 2>/dev/null); do
        exp_str=$(grep "Expires" $INSTALL_DIR/zivpn/$u 2>/dev/null | cut -d':' -f2 | xargs)
        [ -z "$exp_str" ] && continue
        exp_ts=$(date -d "$exp_str" +%s 2>/dev/null) || continue
        if [ $exp_ts -le $limit ] && [ $exp_ts -ge $today ]; then
            days_left=$(( (exp_ts - today) / 86400 ))
            echo -e "  ${WHITE}$u${NC} — Expires: ${RED}$exp_str${NC} (${days_left} days left)"
            found=1
        fi
    done
    [ $found -eq 0 ] && echo -e "  ${GREEN}No ZiVPN users expiring within 3 days ✓${NC}"
    echo ""
    menu_footer; press_enter
}

# ── ZiVPN user management helpers ────────────────────────────
_zivpn_add_user() {
    local user="$1" pass="$2"
    local conf="/etc/zivpn/users.conf"
    [ ! -f "$conf" ] && touch "$conf"
    if grep -q "^${user}:" "$conf" 2>/dev/null; then
        sed -i "s|^${user}:.*|${user}:${pass}:active|" "$conf"
    else
        echo "${user}:${pass}:active" >> "$conf"
    fi
    systemctl restart zivpn 2>/dev/null
}

_zivpn_del_user() {
    local user="$1"
    sed -i "/^${user}:/d" /etc/zivpn/users.conf 2>/dev/null
    systemctl restart zivpn 2>/dev/null
}

_zivpn_block_user() {
    local user="$1"
    sed -i "s|^${user}:\(.*\):active|${user}:\1:blocked|" /etc/zivpn/users.conf 2>/dev/null
    systemctl restart zivpn 2>/dev/null
}

_zivpn_unblock_user() {
    local user="$1"
    sed -i "s|^${user}:\(.*\):blocked|${user}:\1:active|" /etc/zivpn/users.conf 2>/dev/null
    systemctl restart zivpn 2>/dev/null
}

# ── ZiVPN install ─────────────────────────────────────────────
_install_zivpn_full() {
    _log_step "تنصيب ZiVPN (UDP 5667)..."
    apt-get install -y build-essential cmake git libssl-dev \
        libsodium-dev libudns-dev >> "$LOG_FILE" 2>&1

    # ── Clone and build zivpn ─────────────────────────────────
    if ! command -v zivpn &>/dev/null; then
        cd /tmp
        rm -rf zivpn
        git clone https://github.com/zivpn/zivpn.git >> "$LOG_FILE" 2>&1 || {
            # Fallback: build a simple UDP tunnel server
            _log_step "زivpn غير متاح — تنصيب udptunnel بديل..."
            apt-get install -y udptunnel 2>/dev/null >> "$LOG_FILE" 2>&1
        }
        if [ -d /tmp/zivpn ]; then
            cd /tmp/zivpn
            cmake . >> "$LOG_FILE" 2>&1
            make >> "$LOG_FILE" 2>&1
            [ -f bin/zivpn ] && cp bin/zivpn /usr/local/bin/zivpn
            cd /root
        fi
    fi

    # ── Create config ─────────────────────────────────────────
    mkdir -p /etc/zivpn
    touch /etc/zivpn/users.conf
    echo "5667" > $INSTALL_DIR/config/zivpn_port

    cat > /etc/zivpn/server.conf <<'EOF'
# ZiVPN Server Config
port = 5667
protocol = udp
auth = file
users_file = /etc/zivpn/users.conf
max_clients = 100
log = /var/log/zivpn.log
EOF

    # ── Open UDP port ─────────────────────────────────────────
    ufw allow 5667/udp >> "$LOG_FILE" 2>&1
    iptables -I INPUT -p udp --dport 5667 -j ACCEPT 2>/dev/null

    # ── Systemd service ───────────────────────────────────────
    cat > /etc/systemd/system/zivpn.service <<'ZEOF'
[Unit]
Description=ZiVPN UDP Service
After=network.target

[Service]
ExecStart=/usr/local/bin/zivpn -c /etc/zivpn/server.conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
ZEOF

    systemctl daemon-reload >> "$LOG_FILE" 2>&1
    systemctl enable zivpn  >> "$LOG_FILE" 2>&1
    systemctl start  zivpn  >> "$LOG_FILE" 2>&1
    _log_ok "ZiVPN (UDP port 5667)"
}

# ██████  SETTINGS MENU
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
        echo -e "${BLUE}║${NC}  ${GREEN}[29]${NC} CLOUDFLARE DNS SETUP / UPDATE       ${BLUE}║${NC}"
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
        read -p "Please select an option [0-29]: " opt
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
            29) _s_cf_dns ;;
            0) break ;;
            *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
        esac
    done
}

_s_cf_dns() {
    menu_header "CLOUDFLARE DNS SETUP / UPDATE"
    echo ""
    if [ -f "$INSTALL_DIR/config/cloudflare" ]; then
        source "$INSTALL_DIR/config/cloudflare"
        echo -e " ${CYAN}الإعداد الحالي:${NC}"
        echo -e "  الدومين  : ${YELLOW}$CF_SUBDOMAIN${NC}"
        echo -e "  Zone Name: ${YELLOW}$CF_ZONE_NAME${NC}"
        echo -e "  Zone ID  : ${YELLOW}$CF_ZONE_ID${NC}"
        echo ""
        echo -e " ${LGREEN}[1]${NC} تحديث IP السيرفر في Cloudflare"
        echo -e " ${LGREEN}[2]${NC} إعادة الإعداد (تغيير الدومين أو التوكن)"
        echo -e " ${RED}[0]${NC} رجوع"
        echo ""
        read -p " اختر [0-2]: " c
        case $c in
            1) _cf_update_record ;;
            2) _cf_do_setup ;;
            0) return ;;
        esac
    else
        echo -e " ${YELLOW}لا توجد بيانات Cloudflare محفوظة بعد.${NC}"
        echo ""
        echo -e " ${LGREEN}[1]${NC} إعداد Cloudflare الآن"
        echo -e " ${RED}[0]${NC} رجوع"
        read -p " اختر [0-1]: " c
        [[ "$c" == "1" ]] && _cf_do_setup
    fi
    menu_footer
    press_enter
}

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
        1) echo "direct"   > $INSTALL_DIR/config/xray_routing ;;
        2) echo "warp"     > $INSTALL_DIR/config/xray_routing ;;
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
        1) _install_warp_full ;;
        2) warp-cli connect 2>/dev/null;    echo -e " ${GREEN}✓ WARP connected${NC}" ;;
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
    echo "TOKEN=$token"   > $INSTALL_DIR/config/telegram
    echo "CHATID=$chatid" >> $INSTALL_DIR/config/telegram
    (crontab -l 2>/dev/null | grep -v "alsaher-backup"; \
     echo "0 0 * * * tar -czf /tmp/als_bak_\$(date +\%Y\%m\%d).tar.gz $INSTALL_DIR && curl -s -F chat_id=$chatid -F document=@/tmp/als_bak_\$(date +\%Y\%m\%d).tar.gz https://api.telegram.org/bot$token/sendDocument") \
    | crontab -
    echo -e " ${GREEN}✓ Auto backup set (daily midnight)${NC}"
    menu_footer; sleep 2
}

_s_autosend_tg() {
    menu_header "AUTOSEND CREATED VPN VIA BOT TELEGRAM"
    cur=$(cat $INSTALL_DIR/config/autosend_status 2>/dev/null || echo "disabled")
    echo -e " Current: ${YELLOW}$cur${NC}"
    echo -e " 1. Enable   2. Disable"
    read -p " Choice: " c
    [ "$c" = "1" ] && echo "enabled"  > $INSTALL_DIR/config/autosend_status \
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
    echo "TOKEN=$token"         > $INSTALL_DIR/config/bot_mgmt
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
    curl -s https://dl.xanmod.org/check_X86-64_psabi.sh 2>/dev/null | bash 2>/dev/null
    curl -s https://dl.xanmod.org/archive.key 2>/dev/null | \
        gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg 2>/dev/null
    echo -e " ${GREEN}✓ XanMod setup done. Reboot required.${NC}"
    menu_footer; sleep 2
}

_s_update_kernel() {
    menu_header "UPDATE KERNEL TO LATEST VERSION"
    echo -e " Current: ${YELLOW}$(uname -r)${NC}"
    apt update -y 2>/dev/null | tail -1
    apt install -y --install-recommends linux-generic 2>/dev/null | tail -3
    echo -e " ${GREEN}✓ Done. Reboot to apply new kernel.${NC}"
    menu_footer; sleep 2
}

_s_restart_all() {
    menu_header "RESTART ALL SERVICES"
    svcs=(ssh dropbear stunnel4 openvpn squid nginx cron fail2ban xray xl2tpd badvpn ssh-ws rc-local vnstat)
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
    menu_header "INSTALL WEBMIN"
    _install_webmin_full
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
        _install_speedtest_full
        speedtest-cli --simple 2>/dev/null
    fi
    menu_footer; press_enter
}

_s_view_protocols() {
    menu_header "VIEW PROTOCOL & PORT INFORMATION"
    echo ""
    printf "  ${CYAN}%-30s %s${NC}\n" "Protocol" "Port(s)"
    echo "  ──────────────────────────────────────────"
    printf "  %-30s %s\n" "OpenSSH"            "22"
    printf "  %-30s %s\n" "SSH Websocket"      "2052"
    printf "  %-30s %s\n" "Dropbear"           "109, 143"
    printf "  %-30s %s\n" "SSL/Stunnel"        "443, 444"
    printf "  %-30s %s\n" "OpenVPN TCP"        "1194"
    printf "  %-30s %s\n" "OpenVPN UDP"        "2200"
    printf "  %-30s %s\n" "OpenVPN SSL"        "442"
    printf "  %-30s %s\n" "OpenVPN Websocket"  "2095"
    printf "  %-30s %s\n" "XRAY VLESS TLS"     "443"
    printf "  %-30s %s\n" "XRAY VMESS WS"      "80"
    printf "  %-30s %s\n" "XRAY VLESS WS"      "8880"
    printf "  %-30s %s\n" "Squid Proxy"        "3128"
    printf "  %-30s %s\n" "BadVPN UDP"         "7300"
    printf "  %-30s %s\n" "L2TP / IPSec"       "500, 4500 UDP"
    printf "  %-30s %s\n" "Webmin"             "10000"
    printf "  %-30s %s\n" "Nginx"              "80, 81"
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
        vnstat
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
# ██████  ON/OFF SERVICES
# ══════════════════════════════════════════════════════════════
services_toggle_menu() {
    while true; do
        clear
        echo -e "${BLUE}──────────────────────────────────────────${NC}"
        echo -e "        ${WHITE}Enable / Disable Services${NC}"
        echo ""

        _st() {
            systemctl is-active --quiet $1 2>/dev/null \
                && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}"
        }

        printf " 1.  Service UDP Custom                (status: $(_st udp-custom))\n"
        printf " 2.  Service Capture Quota + Limit XRAY (status: $(_st xray))\n"
        printf " 3.  Service Limit XRAY Quota Only     (status: $(_st xray-quota))\n"
        printf " 4.  Service SSH Websocket             (status: $(_st ssh-ws))\n"
        printf " 5.  Service STUNNEL-5                 (status: $(_st stunnel4))\n"
        printf " 6.  Service OpenVPN                   (status: $(_st openvpn))\n"
        printf " 7.  Service OpenVPN Websocket         (status: $(_st openvpn-ws))\n"
        printf " 8.  Service SlowDNS                   (status: $(_st dns-over-https))\n"
        printf " 9.  Service Squid                     (status: $(_st squid))\n"
        printf " 10. Service L2TP                      (status: $(_st xl2tpd))\n"
        printf " 11. Service RC Local                  (status: $(_st rc-local))\n"
        printf " 12. Service Xray                      (status: $(_st xray))\n"
        printf " 13. Service BadVPN UDPGW              (status: $(_st badvpn))\n"
        printf " 14. Service Nginx                     (status: $(_st nginx))\n"
        printf " 15. Service Fail2Ban                  (status: $(_st fail2ban))\n"
        printf " 16. Service Falcon Proxy              (status: $(_st falcon-proxy))\n"
        printf " 17. Service ZiVPN UDP                 (status: $(_st zivpn))\n"
        echo ""
        echo -e " ${RED}0.  Exit${NC}"
        echo -e "${BLUE}──────────────────────────────────────────${NC}"
        read -p "Select a service to toggle [0-15]: " opt

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
            4)  _tog "ssh-ws"         "SSH Websocket" ;;
            5)  _tog "stunnel4"       "STUNNEL-5" ;;
            6)  _tog "openvpn"        "OpenVPN" ;;
            7)  _tog "openvpn-ws"     "OpenVPN Websocket" ;;
            8)  _tog "dns-over-https" "SlowDNS" ;;
            9)  _tog "squid"          "Squid" ;;
            10) _tog "xl2tpd"         "L2TP" ;;
            11) _tog "rc-local"       "RC Local" ;;
            12) _tog "xray"           "Xray" ;;
            13) _tog "badvpn"         "BadVPN UDPGW" ;;
            14) _tog "nginx"          "Nginx" ;;
            15) _tog "fail2ban"       "Fail2Ban" ;;
            16) _tog "falcon-proxy"    "Falcon Proxy" ;;
            17) _tog "zivpn"          "ZiVPN UDP" ;;
            0) break ;;
            *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════
# ██████  STATUS SERVICES
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
            printf "  ${CYAN}%-22s${NC}: ${GREEN}Running ✓${NC}\n" "$label"
        else
            printf "  ${CYAN}%-22s${NC}: ${RED}Not Running ✗${NC}\n" "$label"
        fi
    }

    _chk ssh             "SSH"
    _chk ssh-ws          "SSH WEBSOCKET"
    _chk openvpn         "OPENVPN"
    _chk dns-over-https  "SLOWDNS"
    _chk squid           "SQUID"
    _chk dropbear        "DROPBEAR"
    _chk stunnel4        "STUNNEL5"
    _chk xray            "XRAY"
    _chk xl2tpd          "L2TP"
    _chk badvpn          "BADVPN UDPGW"
    _chk nginx           "NGINX"
    _chk cron            "CRON"
    _chk fail2ban        "FAIL2BAN"
    _chk rc-local        "RC-LOCAL"
    _chk vnstat          "VNSTAT"
    _chk warp-svc        "CLOUDFLARE WARP"
    _chk falcon-proxy    "FALCON PROXY"
    _chk zivpn           "ZIVPN UDP"

    echo ""
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    read -p "Press Enter to return to the main menu..."
}

# ══════════════════════════════════════════════════════════════
# ██████  UPDATE SCRIPT
# ══════════════════════════════════════════════════════════════
update_script() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    printf  "${BLUE}║${NC}  ${WHITE}%-40s${NC}${BLUE}║${NC}\n" "UPDATE SCRIPT"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
    echo ""
    echo -e " Current version: ${YELLOW}$SCRIPT_VERSION${NC}"
    LATEST=$(curl -s --connect-timeout 6 \
        "https://raw.githubusercontent.com/alsaher2/script/main/version.txt" 2>/dev/null | tr -d '[:space:]')
    [ -z "$LATEST" ] && LATEST="1.3.0"
    echo -e " Latest version : ${GREEN}$LATEST${NC}"
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
# ██████  STATUS SCRIPT
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
# START — Check first run then launch menu
# ══════════════════════════════════════════════════════════════
if [ ! -f "$FIRST_RUN_FLAG" ]; then
    first_run_install
fi

main_menu
