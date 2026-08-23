#!/bin/bash
# =============================================================
#   _   _ _______  ___   _ ____  ____   _    ____ _  _______ _____
#  | \ | | ____\ \/ / | | / ___||  _ \ / \  / ___| |/ / ____|_   _|
#  |  \| |  _|  \  /| | | \___ \| |_) / _ \| |   | ' /|  _|   | |
#  | |\  | |___ /  \| |_| |___) |  __/ ___ \ |___| . \| |___  | |
#  |_| \_|_____/_/\_\\___/|____/|_| /_/   \_\____|_|\_\_____| |_|
#
#              NEXUSPACKET — Multi-Tunnel VPN Setup
#         SSH over 80/443 + HAProxy TLS detection + CONNECT
#         + VLESS/REALITY (Xray-core) + Cloudflare auto SSL
#
#  Contact: https://t.me/NexusPacket
# =============================================================
set -euo pipefail

SCRIPT_NAME="NEXUSPACKET"
SCRIPT_CONTACT="https://t.me/NexusPacket"

# ---------- الألوان للطباعة ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

# ---------- المسارات والمتغيرات العامة ----------
BASE_DIR="/etc/multi-tunnel"
STATE_FILE="$BASE_DIR/install.state"     # لتتبع مراحل التثبيت (استئناف بعد انقطاع)
CONFIG_FILE="$BASE_DIR/config.env"
XRAY_DIR="/usr/local/etc/xray"
SSH_PORT_INTERNAL=444                    # SSH الحقيقي على بورت داخلي غير مباشر
TLS_PORT=443                             # البورت الظاهري (443) اللي يفرّق بين TLS/SSH عبر HAProxy
HTTP_PORT=80
MAX_CONN=300                             # الحد الأقصى للاتصالات المتزامنة
CF_CREDS_FILE="$BASE_DIR/cloudflare.ini"  # بيانات اعتماد Cloudflare API لتحدي DNS-01

# ---------- نظام إدارة المستخدمين ----------
XRAY_USERS_DIR="$BASE_DIR/xray_users"     # ملف JSON واحد لكل مستخدم Xray
SSH_LIMIT_DIR="$BASE_DIR/ssh_limits"      # حد الأجهزة لكل مستخدم SSH
XRAY_ACCESS_LOG="/var/log/xray/access.log"
VMESS_PORT=8444                           # V2Ray/VMess (بورت مباشر، خارج تمويه REALITY)
TROJAN_PORT=8445                          # Trojan (بورت مباشر، خارج تمويه REALITY)
SQUID_PORT=8080                           # بروكسي Squid (HTTP/HTTPS عادي، منفصل عن CONNECT tunnel)
TG_CONFIG_FILE="$BASE_DIR/telegram.env"   # توكن البوت + آيدي الأدمن
SSH_BANNER_FILE="$BASE_DIR/ssh_banner.txt"

mkdir -p "$XRAY_USERS_DIR" "$SSH_LIMIT_DIR"

mkdir -p "$BASE_DIR"

# ---------- فحص الصلاحيات ونظام التشغيل ----------
check_root() {
    [[ $EUID -eq 0 ]] || error "لازم تشغّل السكريبت بصلاحية root (sudo)."
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_VER="${VERSION_ID%%.*}"
    else
        error "تعذر اكتشاف نظام التشغيل. السكريبت يدعم Ubuntu/Debian فقط."
    fi
    case "$OS_ID" in
        ubuntu|debian) info "النظام المكتشف: $ID $VERSION_ID" ;;
        *) error "نظام غير مدعوم: $OS_ID (يدعم Ubuntu/Debian فقط)" ;;
    esac
}

# ---------- نظام تتبع الحالة (يكمل من حيث توقف) ----------
save_state() { echo "$1" >> "$STATE_FILE"; }
state_done()  { [[ -f "$STATE_FILE" ]] && grep -qx "$1" "$STATE_FILE"; }

run_step() {
    local step_name="$1"; local step_func="$2"
    if state_done "$step_name"; then
        info "تخطي: $step_name (منفذة مسبقاً)"
        return 0
    fi
    info "تنفيذ: $step_name ..."
    $step_func
    save_state "$step_name"
}

# =============================================================
#  1) تثبيت الحزم الأساسية
# =============================================================
install_dependencies() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y --no-install-recommends \
        dropbear-bin haproxy certbot python3-certbot-dns-cloudflare iptables-persistent \
        curl wget socat uuid-runtime jq ufw netcat-openbsd \
        squid apache2-utils python3
}

# =============================================================
#  2) SSH داخلي (dropbear) على بورت غير مباشر
#     + HAProxy على 443 يفرّق: TLS حقيقي <-> SSH عبر فحص ClientHello
# =============================================================
setup_dropbear() {
    cat > /etc/default/dropbear <<EOF
NO_START=0
DROPBEAR_PORT=$SSH_PORT_INTERNAL
DROPBEAR_EXTRA_ARGS="-w -g"   # -w: منع root، -g: منع كلمة مرور فارغة
DROPBEAR_BANNER=""
EOF
    systemctl enable dropbear
    systemctl restart dropbear
}

setup_haproxy() {
    # HAProxy يفحص أول بايتات TCP فعلياً عبر req.ssl_hello_type
    # لو الاتصال يبدأ بـ TLS ClientHello حقيقي -> Xray (VLESS/WS/TLS)
    # أي شيء غير ذلك (SSH handshake مثلاً) -> dropbear الداخلي
    # هذا أدق وأقوى تحكماً من sslh، ويفتح المجال لاحقاً لـ SNI routing متعدد الدومينات
    mkdir -p /etc/haproxy
    cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log local0
    maxconn $MAX_CONN
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    timeout connect 5s
    timeout client  1m
    timeout server  1m

frontend tls_sniffer
    bind *:$TLS_PORT
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }
    use_backend xray_backend if { req.ssl_hello_type 1 }
    default_backend ssh_backend

backend xray_backend
    server xray1 127.0.0.1:8443

backend ssh_backend
    server ssh1 127.0.0.1:$SSH_PORT_INTERNAL
EOF
    systemctl enable haproxy
    systemctl restart haproxy
}

# =============================================================
#  3) بروكسي CONNECT على بورت 80 (وضع البروكسي لتطبيقات البايلود)
#     أي طلب HTTP CONNECT يوجَّه إلى نفق SSH الداخلي
# =============================================================
setup_connect_proxy() {
    cat > "$BASE_DIR/connect_proxy.py" <<'PYEOF'
#!/usr/bin/env python3
# بروكسي CONNECT بسيط: يفتح نفق TCP خام بين العميل والوجهة الداخلية
# يُستخدم من تطبيقات البايلود (HTTP Injector/Custom) بإرسال CONNECT
import socket, threading, sys

LISTEN_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 80
TARGET_HOST = "127.0.0.1"
TARGET_PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 444
MAX_CONN = int(sys.argv[3]) if len(sys.argv) > 3 else 300

active = threading.Semaphore(MAX_CONN)

def relay(a, b):
    try:
        while True:
            data = a.recv(8192)
            if not data:
                break
            b.sendall(data)
    except Exception:
        pass
    finally:
        a.close(); b.close()

def handle(client):
    with active:
        try:
            req = client.recv(4096)
            if not req:
                client.close(); return
            # نتجاهل تفاصيل الطلب: أي CONNECT أو حتى بيانات WebSocket
            # نرد بأي استجابة HTTP 200/101 حسب توقع تطبيق البايلود ثم نفتح النفق
            if b"CONNECT" in req.split(b"\r\n")[0]:
                client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            else:
                client.sendall(b"HTTP/1.1 101 Switching Protocols\r\n"
                                b"Upgrade: websocket\r\nConnection: Upgrade\r\n\r\n")
            upstream = socket.create_connection((TARGET_HOST, TARGET_PORT))
            t1 = threading.Thread(target=relay, args=(client, upstream), daemon=True)
            t2 = threading.Thread(target=relay, args=(upstream, client), daemon=True)
            t1.start(); t2.start(); t1.join(); t2.join()
        except Exception:
            try: client.close()
            except Exception: pass

def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", LISTEN_PORT))
    srv.listen(200)
    print(f"CONNECT proxy listening on {LISTEN_PORT} -> {TARGET_HOST}:{TARGET_PORT}")
    while True:
        client, _ = srv.accept()
        threading.Thread(target=handle, args=(client,), daemon=True).start()

if __name__ == "__main__":
    main()
PYEOF
    chmod +x "$BASE_DIR/connect_proxy.py"
}

# =============================================================
#  4) شهادات SSL تلقائية عبر certbot (standalone على بورت مؤقت)
# =============================================================
setup_ssl_cert() {
    [[ -z "${DOMAIN:-}" ]] && error "لازم تحدد الدومين أولاً (متغير DOMAIN)."

    # DNS-01 عبر Cloudflare: لا يحتاج بورت 80/443 إطلاقاً، فلا يوجد أي تعارض
    # مع HAProxy أو بروكسي CONNECT، والتجديد يصير بالخلفية بدون أي downtime
    if [[ ! -f "$CF_CREDS_FILE" ]]; then
        [[ -z "${CF_API_TOKEN:-}" ]] && \
            read -rsp "أدخل Cloudflare API Token (Zone.DNS edit permission): " CF_API_TOKEN
        echo
        cat > "$CF_CREDS_FILE" <<EOF
dns_cloudflare_api_token = $CF_API_TOKEN
EOF
        chmod 600 "$CF_CREDS_FILE"
    fi

    certbot certonly --non-interactive --agree-tos \
        -m "admin@alsaherhost.com" -d "$DOMAIN" \
        --dns-cloudflare \
        --dns-cloudflare-credentials "$CF_CREDS_FILE" \
        --dns-cloudflare-propagation-seconds 30 \
        || warn "فشل استخراج الشهادة، تأكد إن الـ API Token صحيح وإن الدومين مُدار عبر Cloudflare."

    # تجديد تلقائي عبر systemd timer -- بدون إيقاف أي خدمة لأنه DNS-01
    systemctl enable certbot.timer 2>/dev/null || true
}

# =============================================================
#  5) Xray-core: VLESS + WebSocket + TLS
# =============================================================
install_xray() {
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
}

setup_xray_vless() {
    mkdir -p "$XRAY_DIR"

    # موقع الغطاء: نستخدم TLS handshake حقيقي منه، فبصمة TLS تطابق زيارة
    # فعلية لهذا الموقع (مو بس المحتوى مشفر، حتى الـ fingerprint نفسه يتطابق)
    local dest="${REALITY_DEST:-www.microsoft.com}"

    # توليد زوج مفاتيح x25519 مرة واحدة فقط (يبقى ثابت لكل المستخدمين القادمين)
    if [[ ! -f "$BASE_DIR/reality_private_key.txt" ]]; then
        local short_id; short_id=$(openssl rand -hex 8)
        local keys; keys=$(xray x25519)
        local priv_key; priv_key=$(echo "$keys" | grep -i "Private" | awk '{print $NF}')
        local pub_key;  pub_key=$(echo "$keys"  | grep -i "Public"  | awk '{print $NF}')
        echo "$priv_key"  > "$BASE_DIR/reality_private_key.txt"; chmod 600 "$BASE_DIR/reality_private_key.txt"
        echo "$pub_key"   > "$BASE_DIR/reality_public_key.txt"
        echo "$short_id"  > "$BASE_DIR/reality_short_id.txt"
    fi
    echo "$dest" > "$BASE_DIR/reality_dest.txt"

    generate_xray_config
    systemctl enable xray
}

# =============================================================
#  توليد config.json من قاعدة بيانات المستخدمين (يُستدعى عند أي
#  إضافة/حذف/حظر/تجديد مستخدم، وأيضاً عند التثبيت الأولي)
# =============================================================
generate_xray_config() {
    local priv_key short_id dest
    priv_key=$(cat "$BASE_DIR/reality_private_key.txt")
    short_id=$(cat "$BASE_DIR/reality_short_id.txt")
    dest=$(cat "$BASE_DIR/reality_dest.txt")

    # جمع عملاء كل بروتوكول من ملفات JSON للمستخدمين (يتجاهل المحظور/المنتهي)
    local vless_clients="[]" vmess_clients="[]" trojan_clients="[]"
    if compgen -G "$XRAY_USERS_DIR/*.json" > /dev/null; then
        vless_clients=$(jq -s '[.[] | select(.protocol=="vless" and .banned==false and (.expiry|tonumber) > now)
            | {id: .uuid, flow: "xtls-rprx-vision", email: .username}]' "$XRAY_USERS_DIR"/*.json)
        vmess_clients=$(jq -s '[.[] | select(.protocol=="vmess" and .banned==false and (.expiry|tonumber) > now)
            | {id: .uuid, email: .username}]' "$XRAY_USERS_DIR"/*.json)
        trojan_clients=$(jq -s '[.[] | select(.protocol=="trojan" and .banned==false and (.expiry|tonumber) > now)
            | {password: .uuid, email: .username}]' "$XRAY_USERS_DIR"/*.json)
    fi

    local extra_inbounds="[]"
    if [[ -f "$BASE_DIR/extra_protocols.enabled" ]]; then
        local domain; domain=$(cat "$BASE_DIR/extra_domain.txt" 2>/dev/null || echo "")
        extra_inbounds=$(jq -n \
            --argjson vmess "$vmess_clients" --argjson trojan "$trojan_clients" \
            --arg cert "/etc/letsencrypt/live/$domain/fullchain.pem" \
            --arg key "/etc/letsencrypt/live/$domain/privkey.pem" \
            --argjson vmess_port "$VMESS_PORT" --argjson trojan_port "$TROJAN_PORT" '
        [
          { listen: "0.0.0.0", port: $vmess_port, protocol: "vmess",
            settings: { clients: $vmess },
            streamSettings: { network: "ws", security: "tls",
              wsSettings: { path: "/vmess" },
              tlsSettings: { certificates: [ { certificateFile: $cert, keyFile: $key } ] } } },
          { listen: "0.0.0.0", port: $trojan_port, protocol: "trojan",
            settings: { clients: $trojan },
            streamSettings: { network: "tcp", security: "tls",
              tlsSettings: { certificates: [ { certificateFile: $cert, keyFile: $key } ] } } }
        ]')
    fi

    jq -n \
        --argjson vless "$vless_clients" --argjson extra "$extra_inbounds" \
        --arg priv "$priv_key" --arg sid "$short_id" --arg dest "$dest" '
    {
      log: { loglevel: "warning", access: "/var/log/xray/access.log" },
      stats: {},
      api: { tag: "api", services: ["HandlerService", "StatsService"] },
      policy: {
        levels: { "0": { statsUserUplink: true, statsUserDownlink: true } },
        system: { statsInboundUplink: true, statsInboundDownlink: true }
      },
      inbounds: ([
        { listen: "127.0.0.1", port: 8443, protocol: "vless",
          settings: { clients: $vless, decryption: "none" },
          streamSettings: { network: "tcp", security: "reality",
            realitySettings: { show: false, dest: ($dest + ":443"), xver: 0,
              serverNames: [$dest], privateKey: $priv, shortIds: [$sid] } } },
        { listen: "127.0.0.1", port: 10085, protocol: "dokodemo-door",
          settings: { address: "127.0.0.1" }, tag: "api" }
      ] + $extra),
      routing: { rules: [ { type: "field", inboundTag: ["api"], outboundTag: "api" } ] },
      outbounds: [ { protocol: "freedom" }, { protocol: "freedom", tag: "api" } ]
    }' > "$XRAY_DIR/config.json"

    mkdir -p /var/log/xray
    systemctl restart xray 2>/dev/null || true
}

# =============================================================
#  إدارة مستخدمي SSH
# =============================================================
ssh_add_user_impl() {
    local username="$1" password="$2" days="$3" devlimit="$4" quota_gb="${5:-0}"
    id "$username" &>/dev/null && { warn "المستخدم موجود مسبقاً."; return 1; }
    local expiry_date; expiry_date=$(date -d "+${days} days" +%Y-%m-%d)
    useradd -M -N -s /usr/sbin/nologin -e "$expiry_date" "$username"
    echo "${username}:${password}" | chpasswd
    echo "$devlimit" > "$SSH_LIMIT_DIR/$username"
    echo "$quota_gb" > "$SSH_LIMIT_DIR/$username.quota"

    # مزامنة نفس الحساب على بروكسي Squid (نفس اسم المستخدم/كلمة المرور)
    squid_sync_user "$username" "$password"

    # عداد استهلاك بيانات هذا المستخدم عبر iptables (owner match)
    iptables -N "quota_$username" 2>/dev/null || true
    iptables -A OUTPUT -m owner --uid-owner "$username" -j "quota_$username" 2>/dev/null || true

    info "تمت إضافة $username — ينتهي $expiry_date — حد أجهزة: $devlimit — حصة: ${quota_gb}GB"
}
ssh_add_user() {
    read -rp "اسم المستخدم: " username
    read -rsp "كلمة المرور: " password; echo
    read -rp "المدة بالأيام (مثال 30): " days
    read -rp "عدد الأجهزة المسموح بها: " devlimit
    read -rp "حصة البيانات بالجيجا (0 = بلا حد): " quota_gb
    ssh_add_user_impl "$username" "$password" "$days" "$devlimit" "$quota_gb"
}

ssh_list_users() {
    printf "%-16s %-13s %-6s %-8s %-10s\n" "المستخدم" "الانتهاء" "الحد" "متصل" "المستخدم/الحصة"
    for f in "$SSH_LIMIT_DIR"/*; do
        [[ -e "$f" && "$f" != *.quota ]] || continue
        local u; u=$(basename "$f")
        local limit; limit=$(cat "$f")
        local quota; quota=$(cat "$SSH_LIMIT_DIR/$u.quota" 2>/dev/null || echo 0)
        local exp; exp=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
        local active; active=$(pgrep -c -u "$u" 2>/dev/null || echo 0)
        local used_gb; used_gb=$(ssh_get_usage_gb "$u")
        printf "%-16s %-13s %-6s %-8s %-10s\n" "$u" "${exp:-غير محدد}" "$limit" "$active" "${used_gb}/${quota}GB"
    done
}

ssh_get_usage_gb() {
    local username="$1"
    local bytes; bytes=$(iptables -L "quota_$username" -v -x -n 2>/dev/null | awk 'NR==3{print $2}')
    [[ -z "$bytes" ]] && bytes=0
    awk -v b="$bytes" 'BEGIN{printf "%.2f", b/1024/1024/1024}'
}

ssh_ban_user_impl() {
    usermod -L "$1" 2>/dev/null && pkill -u "$1" 2>/dev/null
    squid_lock_user "$1"
}
ssh_ban_user() { read -rp "اسم المستخدم المراد حظره: " u; ssh_ban_user_impl "$u" && info "تم حظر $u."; }

ssh_unban_user_impl() { usermod -U "$1"; squid_unlock_user "$1"; }
ssh_unban_user() { read -rp "اسم المستخدم المراد رفع الحظر عنه: " u; ssh_unban_user_impl "$u" && info "تم رفع الحظر عن $u."; }

ssh_delete_user_impl() {
    pkill -u "$1" 2>/dev/null || true
    userdel "$1" 2>/dev/null
    rm -f "$SSH_LIMIT_DIR/$1" "$SSH_LIMIT_DIR/$1.quota"
    iptables -F "quota_$1" 2>/dev/null || true
    iptables -X "quota_$1" 2>/dev/null || true
    squid_delete_user "$1"
}
ssh_delete_user() { read -rp "اسم المستخدم المراد حذفه: " u; ssh_delete_user_impl "$u" && info "تم حذف $u."; }

ssh_renew_user_impl() {
    local expiry_date; expiry_date=$(date -d "+${2} days" +%Y-%m-%d)
    chage -E "$expiry_date" "$1"
    usermod -U "$1" 2>/dev/null || true   # رفع الحظر تلقائياً عند التجديد لو كان محظوراً بسبب الحصة/الانتهاء
    squid_unlock_user "$1"
    echo "$expiry_date"
}
ssh_renew_user() {
    read -rp "اسم المستخدم: " u; read -rp "أيام إضافية من اليوم: " d
    local exp; exp=$(ssh_renew_user_impl "$u" "$d") && info "تم تجديد $u حتى $exp."
}

# تطبيق حد الأجهزة + حد البيانات + انتهاء الاشتراك: يُشغَّل عبر cron كل دقيقة
# ملاحظة: عدّ الأجهزة تقريب شائع (عمليات dropbear المملوكة للمستخدم)،
# وحد البيانات دقيق فعلياً (بايتات حقيقية عبر iptables) لكنه على مستوى
# UPLOAD فقط من السيرفر (اتجاه واحد)، وهو الشائع في هذا النوع من البانلات.
ssh_enforce_limits() {
    for f in "$SSH_LIMIT_DIR"/*; do
        [[ -e "$f" && "$f" != *.quota ]] || continue
        local u; u=$(basename "$f")
        local limit; limit=$(cat "$f")
        local pids; pids=$(pgrep -u "$u" | sort -n)
        local count; count=$(echo "$pids" | grep -c . || true)
        if (( count > limit )); then
            local excess=$(( count - limit ))
            echo "$pids" | head -n "$excess" | xargs -r kill -9
        fi
        local quota; quota=$(cat "$SSH_LIMIT_DIR/$u.quota" 2>/dev/null || echo 0)
        if [[ "$quota" != "0" ]]; then
            local used; used=$(ssh_get_usage_gb "$u")
            if awk -v u="$used" -v q="$quota" 'BEGIN{exit !(u>=q)}'; then
                ssh_ban_user_impl "$u"
                notify_telegram "🚫 تم حظر $u تلقائياً — تجاوز حصة البيانات (${used}/${quota}GB)"
            fi
        fi
    done
    ssh_check_expiring_soon
}

ssh_check_connected() {
    echo "المستخدم              PID     مدة التشغيل"
    for f in "$SSH_LIMIT_DIR"/*; do
        [[ -e "$f" && "$f" != *.quota ]] || continue
        local u; u=$(basename "$f")
        ps -u "$u" -o user=,pid=,etime= 2>/dev/null
    done
}

# تنبيه انتهاء الاشتراك (يوم واحد قبل الانتهاء) عبر تيليجرام
ssh_check_expiring_soon() {
    for f in "$SSH_LIMIT_DIR"/*; do
        [[ -e "$f" && "$f" != *.quota ]] || continue
        local u; u=$(basename "$f")
        local exp_epoch; exp_epoch=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs -I{} date -d "{}" +%s 2>/dev/null)
        [[ -z "$exp_epoch" ]] && continue
        local days_left=$(( (exp_epoch - $(date +%s)) / 86400 ))
        local flag="$SSH_LIMIT_DIR/$u.notified"
        if (( days_left <= 1 && days_left >= 0 )) && [[ ! -f "$flag" ]]; then
            notify_telegram "⏰ اشتراك $u (SSH) ينتهي خلال يوم أو أقل."
            touch "$flag"
        elif (( days_left > 1 )); then
            rm -f "$flag"
        fi
    done
}

# =============================================================
#  إدارة مستخدمي Xray (VLESS+REALITY / VMess / Trojan)
# =============================================================
xray_add_user_impl() {
    local username="$1" protocol="$2" days="$3" devlimit="$4" quota_gb="${5:-0}"
    [[ -f "$XRAY_USERS_DIR/$username.json" ]] && { warn "المستخدم موجود مسبقاً."; return 1; }
    local uuid; uuid=$(uuidgen)
    local expiry_epoch; expiry_epoch=$(date -d "+${days} days" +%s)
    jq -n --arg u "$username" --arg p "$protocol" --arg id "$uuid" \
        --arg exp "$expiry_epoch" --arg dl "$devlimit" --arg q "$quota_gb" --arg created "$(date +%s)" \
        '{username:$u, protocol:$p, uuid:$id, expiry:$exp, device_limit:$dl, quota_gb:$q, banned:false, created:$created}' \
        > "$XRAY_USERS_DIR/$username.json"
    generate_xray_config
    echo "$uuid"
}
xray_add_user() {
    read -rp "اسم المستخدم: " username
    echo "اختر البروتوكول: 1) VLESS+REALITY (تمويه كامل)  2) VMess  3) Trojan"
    read -rp "> " proto_choice
    local protocol
    case "$proto_choice" in
        1) protocol="vless" ;;
        2) protocol="vmess"
           [[ ! -f "$BASE_DIR/extra_protocols.enabled" ]] && \
               warn "تنبيه: VMess/Trojan تحتاج تفعيل أولاً (دومين + شهادة SSL)." ;;
        3) protocol="trojan" ;;
        *) error "اختيار غير صحيح." ;;
    esac
    read -rp "المدة بالأيام: " days
    read -rp "عدد الأجهزة (توثيقي فقط): " devlimit
    read -rp "حصة البيانات بالجيجا (0 = بلا حد، تحتاج تفعيل Xray API): " quota_gb
    local uuid; uuid=$(xray_add_user_impl "$username" "$protocol" "$days" "$devlimit" "$quota_gb") \
        && info "تمت الإضافة — UUID/Password: $uuid" \
        && xray_print_link "$username"
}

xray_list_users() {
    printf "%-16s %-9s %-13s %-8s %-8s\n" "المستخدم" "البروتوكول" "الانتهاء" "محظور" "الاستهلاك"
    for f in "$XRAY_USERS_DIR"/*.json; do
        [[ -e "$f" ]] || continue
        local u; u=$(jq -r .username "$f")
        local used; used=$(xray_get_usage_gb "$u")
        jq -r --arg used "$used" '[.username, .protocol, (.expiry|tonumber|strftime("%Y-%m-%d")), (.banned|tostring), ($used+"GB")] | @tsv' "$f" | \
            awk -F'\t' '{printf "%-16s %-9s %-13s %-8s %-8s\n", $1, $2, $3, $4, $5}'
    done
}

xray_ban_user_impl() {
    local f="$XRAY_USERS_DIR/$1.json"; [[ -f "$f" ]] || return 1
    jq '.banned = true' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    generate_xray_config
}
xray_ban_user() { read -rp "اسم المستخدم المراد حظره: " u; xray_ban_user_impl "$u" && info "تم حظر $u."; }

xray_unban_user_impl() {
    local f="$XRAY_USERS_DIR/$1.json"; [[ -f "$f" ]] || return 1
    jq '.banned = false' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    generate_xray_config
}
xray_unban_user() { read -rp "اسم المستخدم المراد رفع الحظر عنه: " u; xray_unban_user_impl "$u" && info "تم رفع الحظر عن $u."; }

xray_delete_user_impl() { rm -f "$XRAY_USERS_DIR/$1.json"; generate_xray_config; }
xray_delete_user() { read -rp "اسم المستخدم المراد حذفه: " u; xray_delete_user_impl "$u" && info "تم حذف $u."; }

xray_renew_user_impl() {
    local f="$XRAY_USERS_DIR/$1.json"; [[ -f "$f" ]] || return 1
    local new_exp; new_exp=$(date -d "+${2} days" +%s)
    jq --arg e "$new_exp" '.expiry = $e | .banned = false' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    generate_xray_config
    date -d "@$new_exp" +%Y-%m-%d
}
xray_renew_user() {
    read -rp "اسم المستخدم: " u; read -rp "أيام إضافية من اليوم: " d
    local exp; exp=$(xray_renew_user_impl "$u" "$d") && info "تم تجديد $u حتى $exp."
}

# استهلاك بيانات Xray الفعلي عبر Xray Stats API (uplink+downlink الحقيقيين،
# وليس تخميناً من السجل النصي — هذا مسار Xray الرسمي والصحيح لهذا الغرض)
xray_get_usage_gb() {
    local username="$1"
    local up down
    up=$(xray api statsquery --server=127.0.0.1:10085 -pattern "user>>>${username}>>>traffic>>>uplink" 2>/dev/null \
        | jq -r '.stat[0].value // 0')
    down=$(xray api statsquery --server=127.0.0.1:10085 -pattern "user>>>${username}>>>traffic>>>downlink" 2>/dev/null \
        | jq -r '.stat[0].value // 0')
    awk -v u="${up:-0}" -v d="${down:-0}" 'BEGIN{printf "%.2f", (u+d)/1024/1024/1024}'
}

# فحص/فرض حصة بيانات وانتهاء اشتراك Xray (يُشغَّل مع نفس cron الدقيقة الواحدة)
xray_enforce_limits() {
    for f in "$XRAY_USERS_DIR"/*.json; do
        [[ -e "$f" ]] || continue
        local u q banned exp
        u=$(jq -r .username "$f"); q=$(jq -r .quota_gb "$f"); banned=$(jq -r .banned "$f"); exp=$(jq -r .expiry "$f")
        if [[ "$banned" == "false" && "$q" != "0" && "$q" != "null" ]]; then
            local used; used=$(xray_get_usage_gb "$u")
            if awk -v u="$used" -v qq="$q" 'BEGIN{exit !(u>=qq)}'; then
                xray_ban_user_impl "$u"
                notify_telegram "🚫 تم حظر $u (Xray) تلقائياً — تجاوز حصة البيانات (${used}/${q}GB)"
            fi
        fi
        local days_left=$(( (exp - $(date +%s)) / 86400 ))
        local flag="$XRAY_USERS_DIR/$u.notified"
        if (( days_left <= 1 && days_left >= 0 )) && [[ ! -f "$flag" ]]; then
            notify_telegram "⏰ اشتراك $u (Xray) ينتهي خلال يوم أو أقل."
            touch "$flag"
        elif (( days_left > 1 )); then
            rm -f "$flag"
        fi
    done
}

# فحص/تنبيه اتصالات Xray الحالية (تقريبي عبر access.log) — وليس فرضاً حقيقياً
# لحد الأجهزة؛ Xray-core لا يوفر آلية أصلية لقطع عميل بعينه عند تجاوز العدد.
xray_check_connected() {
    [[ -f "$XRAY_ACCESS_LOG" ]] || { warn "لا يوجد سجل اتصالات بعد."; return; }
    echo "آخر عناوين IP فريدة متصلة لكل مستخدم (آخر 5 دقائق):"
    local since; since=$(date -d "-5 minutes" "+%Y/%m/%d %H:%M:%S")
    awk -v since="$since" '$0 > since' "$XRAY_ACCESS_LOG" 2>/dev/null | \
        grep -oP 'email:\s*\K\S+|from\s+\K[0-9.]+' | \
        paste - - 2>/dev/null | sort -u || warn "تعذر تحليل السجل."
}

# رابط استيراد مباشر (vless://) يقدر العميل يلصقه في v2rayNG/NekoRay مباشرة
xray_print_link() {
    local username="$1"
    local f="$XRAY_USERS_DIR/$username.json"; [[ -f "$f" ]] || { warn "المستخدم غير موجود."; return; }
    local uuid protocol; uuid=$(jq -r .uuid "$f"); protocol=$(jq -r .protocol "$f")
    local pub sid dest; pub=$(cat "$BASE_DIR/reality_public_key.txt"); sid=$(cat "$BASE_DIR/reality_short_id.txt"); dest=$(cat "$BASE_DIR/reality_dest.txt")
    local server_ip; server_ip=$(curl -s -4 ifconfig.me 2>/dev/null || echo "SERVER_IP")
    case "$protocol" in
        vless)
            echo "vless://${uuid}@${server_ip}:443?security=reality&encryption=none&pbk=${pub}&fp=chrome&sni=${dest}&sid=${sid}&flow=xtls-rprx-vision&type=tcp#${username}-NEXUSPACKET" ;;
        trojan)
            local domain; domain=$(cat "$BASE_DIR/extra_domain.txt" 2>/dev/null)
            echo "trojan://${uuid}@${domain}:${TROJAN_PORT}?security=tls#${username}-NEXUSPACKET" ;;
        vmess)
            local domain; domain=$(cat "$BASE_DIR/extra_domain.txt" 2>/dev/null)
            local vmess_json; vmess_json=$(jq -n --arg id "$uuid" --arg add "$domain" --arg port "$VMESS_PORT" \
                --arg ps "${username}-NEXUSPACKET" '{v:"2",ps:$ps,add:$add,port:$port,id:$id,aid:"0",net:"ws",path:"/vmess",tls:"tls"}')
            echo "vmess://$(echo -n "$vmess_json" | base64 -w0)" ;;
    esac
}

# =============================================================
#  تفعيل VMess/Trojan (اختياري) — يحتاج دومين حقيقي + شهادة SSL
#  (لا يستخدمان REALITY، فهما خارج نطاق التمويه الكامل عمداً)
# =============================================================
enable_extra_protocols() {
    if [[ -f "$BASE_DIR/extra_protocols.enabled" ]]; then
        info "VMess/Trojan مفعّلة مسبقاً."
        return
    fi
    read -rp "أدخل الدومين المخصص لـ VMess/Trojan (يجب أن يشير لهذا السيرفر عبر Cloudflare): " DOMAIN
    export DOMAIN
    echo "$DOMAIN" > "$BASE_DIR/extra_domain.txt"
    setup_ssl_cert
    touch "$BASE_DIR/extra_protocols.enabled"
    generate_xray_config
    info "تم تفعيل VMess (بورت $VMESS_PORT) وTrojan (بورت $TROJAN_PORT) على $DOMAIN."
    warn "هذان البروتوكولان يستخدمان شهادة SSL حقيقية على بورت منفصل، وليسا جزءاً من تمويه REALITY."
}

# جدولة فرض حد أجهزة SSH كل دقيقة عبر cron
setup_limit_cron() {
    local cron_line="* * * * * bash $BASE_DIR/nexuspacket.sh --enforce-limits >/dev/null 2>&1"
    ( crontab -l 2>/dev/null | grep -v "enforce-limits" ; echo "$cron_line" ) | crontab -
    cp "$0" "$BASE_DIR/nexuspacket.sh" 2>/dev/null || true
    chmod +x "$BASE_DIR/nexuspacket.sh"
}

# =============================================================
#  بروكسي Squid على بورت 8080 (HTTP/HTTPS عادي بمصادقة)
#  نفس مستخدمي SSH يقدرون يستخدمونه بنفس الباسوورد (مزامنة تلقائية)
# =============================================================
setup_squid() {
    touch /etc/squid/squid_users.htpasswd
    cat > /etc/squid/squid.conf <<EOF
http_port $SQUID_PORT
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/squid_users.htpasswd
auth_param basic realm NEXUSPACKET Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all
access_log /var/log/squid/access.log
EOF
    systemctl enable squid
    systemctl restart squid
}

squid_sync_user() {
    local username="$1" password="$2"
    command -v htpasswd &>/dev/null || return 0
    htpasswd -b /etc/squid/squid_users.htpasswd "$username" "$password" 2>/dev/null
    systemctl reload squid 2>/dev/null || true
}
squid_lock_user() {
    sed -i "/^${1}:/d" /etc/squid/squid_users.htpasswd 2>/dev/null
    systemctl reload squid 2>/dev/null || true
}
squid_unlock_user() { :; }  # يحتاج كلمة المرور الأصلية لإعادتها؛ استخدم renew لإعادة تعيينها عند الحاجة
squid_delete_user() { squid_lock_user "$1"; }

# =============================================================
#  بانر SSH احترافي (يظهر في لوق تطبيقات HTTP Injector/HTTP Custom
#  فوراً عند الاتصال، قبل حتى إدخال بيانات الحساب)
# =============================================================
setup_ssh_banner() {
    cat > "$SSH_BANNER_FILE" <<'EOF'
=====================================
        NEXUSPACKET
   Powered by Al-Saher Host
   Telegram: https://t.me/NexusPacket
=====================================
EOF
    sed -i '/^DROPBEAR_BANNER=/d' /etc/default/dropbear
    echo "DROPBEAR_BANNER=\"$SSH_BANNER_FILE\"" >> /etc/default/dropbear
    systemctl restart dropbear
}

# =============================================================
#  تنبيهات تيليجرام (تجديد/انتهاء/حظر تلقائي) — يحتاج توكن + آيدي أدمن
# =============================================================
notify_telegram() {
    [[ -f "$TG_CONFIG_FILE" ]] || return 0
    . "$TG_CONFIG_FILE"
    [[ -z "${TG_BOT_TOKEN:-}" || -z "${TG_ADMIN_ID:-}" ]] && return 0
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d chat_id="$TG_ADMIN_ID" -d text="$1" >/dev/null 2>&1 || true
}

setup_telegram_bot() {
    read -rp "أدخل توكن البوت (من BotFather): " token
    read -rp "أدخل آيدي حسابك في تيليجرام (Admin Chat ID): " admin_id
    cat > "$TG_CONFIG_FILE" <<EOF
TG_BOT_TOKEN="$token"
TG_ADMIN_ID="$admin_id"
EOF
    chmod 600 "$TG_CONFIG_FILE"

    write_telegram_bot_script

    cat > /etc/systemd/system/nexuspacket-bot.service <<EOF
[Unit]
Description=NEXUSPACKET Telegram Bot
After=network.target

[Service]
ExecStart=/usr/bin/python3 $BASE_DIR/telegram_bot.py
Restart=always
RestartSec=5
WorkingDirectory=$BASE_DIR

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable nexuspacket-bot
    systemctl restart nexuspacket-bot
    notify_telegram "✅ NEXUSPACKET Bot متصل وجاهز."
    info "تم تفعيل بوت تيليجرام."
}

# البوت مضمّن هنا (heredoc) عشان السكريبت يبقى ملف واحد قائم بذاته
write_telegram_bot_script() {
cat > "$BASE_DIR/telegram_bot.py" <<'PYEOF'
#!/usr/bin/env python3
# NEXUSPACKET Telegram Bot -- إدارة كاملة عن بعد (SSH + Xray)
# Contact: https://t.me/NexusPacket -- بدون أي مكتبات خارجية
import json, re, subprocess, time, urllib.request, urllib.parse

CONFIG_PATH = "/etc/multi-tunnel/telegram.env"
SCRIPT_PATH = "/etc/multi-tunnel/nexuspacket.sh"

def load_config():
    cfg = {}
    with open(CONFIG_PATH) as f:
        for line in f:
            m = re.match(r'^\s*([A-Z_]+)\s*=\s*"?([^"\n]*)"?\s*$', line)
            if m: cfg[m.group(1)] = m.group(2)
    return cfg

def run_cli(*args):
    try:
        r = subprocess.run(["bash", SCRIPT_PATH, *args], capture_output=True, text=True, timeout=60)
        out = (r.stdout or "") + (r.stderr or "")
        return out.strip() or "تم التنفيذ (بدون مخرجات)."
    except Exception as e:
        return f"خطأ أثناء التنفيذ: {e}"

HELP_TEXT = """NEXUSPACKET Bot -- الأوامر المتاحة:

SSH:
/addssh user pass days devlimit [quota_gb]
/listssh
/banssh user
/unbanssh user
/delssh user
/renewssh user days

XRAY (vless/vmess/trojan):
/addxray user protocol days devlimit [quota_gb]
/listxray
/banxray user
/unbanxray user
/delxray user
/renewxray user days
/link user

عام:
/backup
/help

التواصل: https://t.me/NexusPacket
"""

COMMANDS = {
    "/addssh":    lambda a: run_cli("--ssh-add", *a),
    "/listssh":   lambda a: run_cli("--ssh-list"),
    "/banssh":    lambda a: run_cli("--ssh-ban", *a),
    "/unbanssh":  lambda a: run_cli("--ssh-unban", *a),
    "/delssh":    lambda a: run_cli("--ssh-delete", *a),
    "/renewssh":  lambda a: run_cli("--ssh-renew", *a),
    "/addxray":   lambda a: run_cli("--xray-add", *a),
    "/listxray":  lambda a: run_cli("--xray-list"),
    "/banxray":   lambda a: run_cli("--xray-ban", *a),
    "/unbanxray": lambda a: run_cli("--xray-unban", *a),
    "/delxray":   lambda a: run_cli("--xray-delete", *a),
    "/renewxray": lambda a: run_cli("--xray-renew", *a),
    "/link":      lambda a: run_cli("--xray-link", *a),
    "/backup":    lambda a: run_cli("--backup"),
}

def api_call(token, method, params=None):
    url = f"https://api.telegram.org/bot{token}/{method}"
    data = urllib.parse.urlencode(params or {}).encode()
    with urllib.request.urlopen(url, data=data, timeout=35) as resp:
        return json.loads(resp.read().decode())

def send_message(token, chat_id, text):
    try:
        api_call(token, "sendMessage", {"chat_id": chat_id, "text": text})
    except Exception as e:
        print(f"[!] فشل إرسال الرسالة: {e}")

def main():
    cfg = load_config()
    token = cfg.get("TG_BOT_TOKEN")
    admin_id = str(cfg.get("TG_ADMIN_ID", ""))
    if not token or not admin_id:
        print("[x] التوكن أو آيدي الأدمن غير مضبوط في telegram.env")
        return

    print("[+] NEXUSPACKET Bot يعمل الآن (long polling)...")
    offset = 0
    while True:
        try:
            updates = api_call(token, "getUpdates", {"offset": offset, "timeout": 30})
            for upd in updates.get("result", []):
                offset = upd["update_id"] + 1
                msg = upd.get("message", {})
                chat_id = str(msg.get("chat", {}).get("id", ""))
                text = msg.get("text", "").strip()
                if not text:
                    continue
                if chat_id != admin_id:
                    continue  # فقط الأدمن المحدد -- أي حد ثاني يُتجاهل تماماً
                parts = text.split()
                cmd = parts[0].lower()
                args = parts[1:]
                if cmd in ("/start", "/help"):
                    send_message(token, chat_id, HELP_TEXT)
                elif cmd in COMMANDS:
                    send_message(token, chat_id, COMMANDS[cmd](args)[:4000])
                else:
                    send_message(token, chat_id, "أمر غير معروف. أرسل /help لعرض الأوامر.")
        except Exception as e:
            print(f"[!] خطأ بحلقة الاستقبال: {e}")
            time.sleep(5)

if __name__ == "__main__":
    main()
PYEOF
}

# =============================================================
#  نسخ احتياطي / استرجاع لكامل بيانات المستخدمين والإعدادات
# =============================================================
backup_all() {
    local out="/root/nexuspacket-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$out" \
        "$BASE_DIR" \
        /etc/letsencrypt 2>/dev/null \
        /etc/squid/squid_users.htpasswd 2>/dev/null \
        --ignore-failed-read
    # نسخ بيانات مستخدمي SSH النظاميين (لا يمكن استرجاعهم إلا بإعادة تنفيذ useradd)
    getent passwd | awk -F: '$3>=1000{print $1}' > "$BASE_DIR/.ssh_users_snapshot"
    info "تم إنشاء نسخة احتياطية: $out"
    echo "$out"
}

restore_all() {
    read -rp "مسار ملف النسخة الاحتياطية (.tar.gz): " backup_path
    [[ -f "$backup_path" ]] || { error "الملف غير موجود."; }
    tar -xzf "$backup_path" -C /
    generate_xray_config
    systemctl restart dropbear haproxy xray squid connect-proxy 2>/dev/null || true
    info "تم الاسترجاع. ملاحظة: حسابات SSH النظامية (useradd) تحتاج إعادة إنشاء يدوية إذا لم تكن موجودة أصلاً على هذا السيرفر."
}

# =============================================================
#  6) تحديد الاتصالات المتزامنة (حماية من الحمل الزائد)
# =============================================================
setup_conn_limit() {
    # يحدد عدد الاتصالات المتزامنة الكلي على البورتات المستخدمة
    iptables -I INPUT -p tcp --dport "$TLS_PORT" -m connlimit \
        --connlimit-above "$MAX_CONN" --connlimit-mask 0 -j REJECT
    iptables -I INPUT -p tcp --dport "$HTTP_PORT" -m connlimit \
        --connlimit-above "$MAX_CONN" --connlimit-mask 0 -j REJECT
    netfilter-persistent save 2>/dev/null || true
}

# =============================================================
#  7) خدمة systemd لبروكسي CONNECT + إبقاء كل الخدمات حية تلقائياً
# =============================================================
setup_systemd_services() {
    cat > /etc/systemd/system/connect-proxy.service <<EOF
[Unit]
Description=HTTP CONNECT / WebSocket Proxy Tunnel
After=network.target dropbear.service

[Service]
ExecStart=/usr/bin/python3 $BASE_DIR/connect_proxy.py $HTTP_PORT $SSH_PORT_INTERNAL $MAX_CONN
Restart=always
RestartSec=2
User=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable connect-proxy
    systemctl restart connect-proxy

    # التأكد إن dropbear و haproxy و xray كلها Restart=always (بقاء تلقائي)
    for svc in dropbear haproxy xray squid; do
        mkdir -p "/etc/systemd/system/${svc}.service.d"
        cat > "/etc/systemd/system/${svc}.service.d/override.conf" <<EOF
[Service]
Restart=always
RestartSec=3
EOF
    done
    systemctl daemon-reload
}

# =============================================================
#  8) عرض معلومات الاتصال بعد التثبيت
# =============================================================
show_info() {
    local pub_key short_id dest
    pub_key=$(cat "$BASE_DIR/reality_public_key.txt" 2>/dev/null || echo "غير متوفر")
    short_id=$(cat "$BASE_DIR/reality_short_id.txt" 2>/dev/null || echo "غير متوفر")
    dest=$(cat "$BASE_DIR/reality_dest.txt" 2>/dev/null || echo "غير متوفر")
    echo "-----------------------------------------------"
    echo " SSH (عبر 443):      يفرزه HAProxy تلقائياً حسب نوع الاتصال"
    echo " SSH/بايلود (80):    CONNECT proxy -> بورت 80"
    echo " Flow:               xtls-rprx-vision"
    echo " REALITY Dest:       $dest"
    echo " REALITY Public Key: $pub_key"
    echo " REALITY Short ID:   $short_id"
    if [[ -f "$BASE_DIR/extra_protocols.enabled" ]]; then
        echo " VMess/Trojan:       مفعّلة على $(cat "$BASE_DIR/extra_domain.txt") (بورت $VMESS_PORT / $TROJAN_PORT)"
    else
        echo " VMess/Trojan:       غير مفعّلة"
    fi
    echo " حد الاتصالات العام: $MAX_CONN اتصال متزامن"
    echo " (استخدم قائمة إدارة المستخدمين لعرض UUID/كلمات مرور كل مستخدم على حدة)"
    echo "-----------------------------------------------"
    echo " $SCRIPT_NAME | $SCRIPT_CONTACT"
    echo "-----------------------------------------------"
}

# =============================================================
#  التسلسل الكامل للتثبيت
# =============================================================
full_install() {
    read -rp "أدخل موقع الغطاء لانتحال بصمة TLS (اضغط Enter للافتراضي www.microsoft.com): " user_dest
    export REALITY_DEST="${user_dest:-www.microsoft.com}"

    run_step "check_root"        check_root
    run_step "detect_os"         detect_os
    run_step "install_deps"      install_dependencies
    run_step "setup_dropbear"    setup_dropbear
    run_step "setup_ssh_banner"  setup_ssh_banner
    run_step "install_xray"      install_xray
    run_step "setup_xray_vless"  setup_xray_vless
    run_step "setup_haproxy"     setup_haproxy
    run_step "setup_connect"     setup_connect_proxy
    run_step "setup_squid"       setup_squid
    run_step "setup_systemd"     setup_systemd_services
    run_step "setup_connlimit"   setup_conn_limit
    run_step "setup_limit_cron"  setup_limit_cron

    info "التثبيت اكتمل بنجاح."
    show_info
}

# =============================================================
#  القائمة الرئيسية
# =============================================================
show_banner() {
    echo -e "${GREEN}"
    echo "  _   _ _______  ___   _ ____  ____   _    ____ _  _______ _____"
    echo " | \\ | | ____\\ \\/ / | | / ___||  _ \\ / \\  / ___| |/ / ____|_   _|"
    echo " |  \\| |  _|  \\  /| | | \\___ \\| |_) / _ \\| |   | ' /|  _|   | |"
    echo " | |\\  | |___ /  \\| |_| |___) |  __/ ___ \\ |___| . \\| |___  | |"
    echo " |_| \\_|_____/_/\\_\\\\___/|____/|_| /_/   \\_\\____|_|\\_\\_____| |_|"
    echo -e "${NC}"
    echo "                 $SCRIPT_NAME — Multi-Tunnel VPN Setup"
    echo "                 التواصل: $SCRIPT_CONTACT"
    echo "============================================="
}

ssh_menu() {
    echo "----------- إدارة مستخدمي SSH -----------"
    echo " 1) إضافة مستخدم"
    echo " 2) قائمة المستخدمين"
    echo " 3) حظر مستخدم"
    echo " 4) رفع الحظر عن مستخدم"
    echo " 5) حذف مستخدم"
    echo " 6) تجديد مدة مستخدم"
    echo " 7) فحص المتصلين الآن"
    echo " 8) رجوع"
    read -rp "اختر رقم: " c
    case "$c" in
        1) ssh_add_user ;; 2) ssh_list_users ;; 3) ssh_ban_user ;;
        4) ssh_unban_user ;; 5) ssh_delete_user ;; 6) ssh_renew_user ;;
        7) ssh_check_connected ;; 8) return ;; *) warn "اختيار غير صحيح." ;;
    esac
}

xray_menu() {
    echo "----------- إدارة مستخدمي XRAY (VLESS/VMess/Trojan) -----------"
    echo " 1) إضافة مستخدم"
    echo " 2) قائمة المستخدمين"
    echo " 3) حظر مستخدم"
    echo " 4) رفع الحظر عن مستخدم"
    echo " 5) حذف مستخدم"
    echo " 6) تجديد مدة مستخدم"
    echo " 7) فحص المتصلين الآن (تقريبي)"
    echo " 8) تفعيل VMess/Trojan (يحتاج دومين)"
    echo " 9) عرض رابط استيراد مستخدم"
    echo " 10) رجوع"
    read -rp "اختر رقم: " c
    case "$c" in
        1) xray_add_user ;; 2) xray_list_users ;; 3) xray_ban_user ;;
        4) xray_unban_user ;; 5) xray_delete_user ;; 6) xray_renew_user ;;
        7) xray_check_connected ;; 8) enable_extra_protocols ;;
        9) read -rp "اسم المستخدم: " u; xray_print_link "$u" ;;
        10) return ;;
        *) warn "اختيار غير صحيح." ;;
    esac
}

main_menu() {
    while true; do
        show_banner
        echo " 1) تثبيت كامل (كل المزايا)"
        echo " 2) إدارة مستخدمي SSH"
        echo " 3) إدارة مستخدمي XRAY (VLESS/VMess/Trojan)"
        echo " 4) عرض معلومات السيرفر"
        echo " 5) إعادة تشغيل كل الخدمات"
        echo " 6) تفعيل/إعداد بوت تيليجرام"
        echo " 7) نسخ احتياطي"
        echo " 8) استرجاع نسخة احتياطية"
        echo " 9) خروج"
        read -rp "اختر رقم: " choice
        case "$choice" in
            1) full_install ;;
            2) ssh_menu ;;
            3) xray_menu ;;
            4) show_info ;;
            5) systemctl restart dropbear haproxy xray squid connect-proxy && info "تم إعادة التشغيل." ;;
            6) setup_telegram_bot ;;
            7) backup_all ;;
            8) restore_all ;;
            9) exit 0 ;;
            *) warn "اختيار غير صحيح." ;;
        esac
        echo; read -rp "اضغط Enter للمتابعة..." _
    done
}

# ---------- نقطة الدخول: أوامر غير تفاعلية (يستخدمها بوت تيليجرام) ----------
case "${1:-}" in
    --enforce-limits) check_root; ssh_enforce_limits; xray_enforce_limits; exit 0 ;;
    --ssh-add)    check_root; ssh_add_user_impl "$2" "$3" "$4" "$5" "${6:-0}"; exit 0 ;;
    --ssh-list)   check_root; ssh_list_users; exit 0 ;;
    --ssh-ban)    check_root; ssh_ban_user_impl "$2"; exit 0 ;;
    --ssh-unban)  check_root; ssh_unban_user_impl "$2"; exit 0 ;;
    --ssh-delete) check_root; ssh_delete_user_impl "$2"; exit 0 ;;
    --ssh-renew)  check_root; ssh_renew_user_impl "$2" "$3"; exit 0 ;;
    --xray-add)   check_root; xray_add_user_impl "$2" "$3" "$4" "$5" "${6:-0}"; exit 0 ;;
    --xray-list)  check_root; xray_list_users; exit 0 ;;
    --xray-ban)   check_root; xray_ban_user_impl "$2"; exit 0 ;;
    --xray-unban) check_root; xray_unban_user_impl "$2"; exit 0 ;;
    --xray-delete) check_root; xray_delete_user_impl "$2"; exit 0 ;;
    --xray-renew) check_root; xray_renew_user_impl "$2" "$3"; exit 0 ;;
    --xray-link)  check_root; xray_print_link "$2"; exit 0 ;;
    --backup)     check_root; backup_all; exit 0 ;;
esac

check_root
main_menu
