# KR260 + Vivado Remote Workflow
 
## Setup
- KR260 running Ubuntu on PS (ARM), connected via Tailscale
- Goal: program & debug PL (FPGA fabric) remotely
 
## Key Concept: PS vs PL
- KR260 is Zynq UltraScale+ — PS (ARM/Ubuntu) and PL (FPGA fabric) are separate domains on same chip
- Reprogramming PL **does not affect Ubuntu**
 
## Programming the Fabric (Already Works)
- Build bitstream in Vivado on PC → `scp` to KR260 over Tailscale → load with `fpgautil`
- No extra tools needed
 
## ILA Debugging
- ILA = logic analyzer embedded in FPGA fabric — lets you watch internal signals as waveforms in Vivado
- Requires Vivado Hardware Manager connected to the PL via JTAG or equivalent
- `fpgautil` = deploy only, ILA = debug running design
 
## hw_server
- JTAG daemon that exposes a JTAG connection over the network to Vivado
- Normally needs physical USB/JTAG cable
- On KR260, PS has internal DAP access to PL — so `hw_server -I` can reach PL without a cable
 
## Best Path: hw_server on KR260 CPU
1. Install Vivado Lab Edition (~2GB) on KR260
2. Run `hw_server -I` on KR260
3. In Vivado on PC: Hardware Manager → Remote Server → KR260 Tailscale IP, port 3121
- Full ILA debugging over Tailscale, no extra hardware
 
---
 
## KR260 Setup Walkthrough
 
### 1. Install Vivado Lab Edition on KR260
On your PC, download the Vivado Lab Edition installer from AMD's website (match your Vivado version — 2025.x). Transfer to KR260:
```bash
scp Xilinx_Vivado_Lab_Lin_2025.x.tar.gz ubuntu@<kr260-tailscale-ip>:~/
```
On the KR260:
```bash
tar -xf Xilinx_Vivado_Lab_Lin_2025.x.tar.gz
cd Xilinx_Vivado_Lab_Lin_2025.x/
sudo ./xsetup --agree XilinxEULA,3rdPartyEULA \
  --batch Install \
  --edition "Vivado Lab Edition (Standalone)" \
  --location "/tools/Xilinx"
```
 
### 2. Source the Environment
```bash
source /tools/Xilinx/Vivado_Lab/2025.x/settings64.sh
```
Add this to `~/.bashrc` so it persists across reboots:
```bash
echo "source /tools/Xilinx/Vivado_Lab/2025.x/settings64.sh" >> ~/.bashrc
```
 
### 3. Start hw_server
```bash
hw_server -I -s tcp::3121
```
- `-I` = use internal DAP (no physical JTAG cable needed)
- `-s tcp::3121` = listen on port 3121
 
To run persistently in the background:
```bash
nohup hw_server -I -s tcp::3121 &
```
Or create a systemd service so it starts on boot:
```bash
sudo nano /etc/systemd/system/hw_server.service
```
```ini
[Unit]
Description=Xilinx hw_server
After=network.target
 
[Service]
ExecStart=/tools/Xilinx/Vivado_Lab/2025.x/bin/hw_server -I -s tcp::3121
Restart=always
User=ubuntu
 
[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl enable hw_server
sudo systemctl start hw_server
```
 
### 4. Verify It's Running
```bash
sudo systemctl status hw_server
# or
ss -tlnp | grep 3121
```
 
---
 
## Connecting from Vivado 2025 on Your PC
 
### Program the Fabric (fpgautil — no ILA)
Build your bitstream in Vivado, then:
```bash
scp your_design.bit ubuntu@<kr260-tailscale-ip>:~/
ssh ubuntu@<kr260-tailscale-ip>
sudo fpgautil -b ~/your_design.bit
```
 
### Connect Hardware Manager for ILA Debugging
1. Open Vivado 2025 on your PC
2. Click **Open Hardware Manager** (bottom of Flow Navigator)
3. Click **Open Target → Open New Target…**
4. Click **Next**
5. Set **Connect to: Remote Server**
6. **Host:** `<KR260 Tailscale IP>`
7. **Port:** `3121`
8. Click **Next** — Vivado will enumerate the PL and show the Zynq device
9. Click **Next → Finish**
 
You now have full Hardware Manager access — program bitstreams, arm ILA triggers, capture waveforms — all over Tailscale.
 
### Program Bitstream via Hardware Manager (alternative to fpgautil)
Once connected:
1. Right-click the device in Hardware panel → **Program Device**
2. Browse to your `.bit` file
3. Click **Program**
 
---
 
## Raspberry Pi 5 Alternative (if above is flaky)
- Pi + FT2232H USB JTAG adapter → wired to KR260 JTAG header → run `hw_server` on Pi
- Vivado connects to Pi's Tailscale IP instead
- GPIO bit-bang XVC not ideal on Pi 5 due to changed GPIO hardware