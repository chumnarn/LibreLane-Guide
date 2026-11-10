# คู่มือติดตั้ง LibreLane จากศูนย์แบบ Step by Step

Windows 11 + WSL2 (Ubuntu 22.04) และ Ubuntu 22.04 ขึ้นไป • LibreLane 3.0.16 • IHP SG13G2

เมื่อจบคู่มือจะเปิด tool environment ได้ รัน smoke test ได้ และสร้าง GDSII ของวงจร counter ขนาด 8 บิตด้วย IHP SG13G2 ได้บนเครื่องที่ตั้งค่าครบ

## เลือกเทอร์มินัลก่อนคัดลอกคำสั่ง

| ป้ายกำกับ | เปิดจากที่ใด | ใช้ทำอะไร |
|---|---|---|
| PowerShell | Windows Terminal หรือ Start Menu | ติดตั้งและตรวจ WSL2 |
| Ubuntu Bash | แอป Ubuntu หรือ Terminal บน Ubuntu | ติดตั้ง Nix และ clone LibreLane |
| Nix shell | รัน `nix-shell` จาก root ของ repository | ตรวจเครื่องมือ รัน smoke test และสร้าง GDSII |

ทำทีละบล็อกและตรวจผลก่อนข้ามขั้น ผู้ใช้ Ubuntu ที่ติดตั้งโดยตรงเริ่มเตรียมเครื่องในขั้นที่ 1 แล้วข้ามส่วน Windows ในขั้นที่ 2 ได้

## 1. เตรียมเครื่อง

ใช้ RAM อย่างน้อย 8 GiB และแนะนำ 16 GiB เผื่อพื้นที่ดิสก์ประมาณ 30 GB สำหรับ Nix store, PDK และผลการรัน ตัวเลขนี้เป็นพื้นที่เผื่อสำหรับเริ่มต้นและขึ้นกับเครื่องมือที่ดาวน์โหลด ตรวจด้วย `free -h` และ `df -h ~ /` หลังเข้า Ubuntu

LibreLane เรียก Yosys สำหรับ synthesis, OpenROAD สำหรับ physical implementation และ KLayout สำหรับงาน layout ใน flow นี้ Nix จัดการเวอร์ชันเครื่องมือ ส่วน Ciel จัดการ PDK เป็นคนละชุดกัน

## 2. เปิด Ubuntu

### Windows 11

**2.1 · PowerShell แบบ Administrator** ตรวจรายชื่อและติดตั้ง Ubuntu หากมี Ubuntu อยู่แล้ว ให้ตรวจด้วย `wsl --list --verbose` และใช้ดิสทริบิวชันเดิมได้

```powershell
wsl --list --online
wsl --install -d Ubuntu-22.04
```

รีสตาร์ต Windows หากระบบร้องขอ เปิด Ubuntu 22.04 จาก Start Menu และสร้างบัญชี Linux จากนั้นตรวจใน PowerShell

```powershell
wsl --list --verbose
```

แถว Ubuntu-22.04 ต้องแสดง VERSION เป็น 2 ถ้ายังเป็น 1 ให้ใช้ `wsl --set-version Ubuntu-22.04 2` โดยใช้ชื่อดิสทริบิวชันตามที่แสดงจริง

**2.2 · Ubuntu Bash** ตรวจ PID 1

```bash
ps -p 1 -o comm=
```

หากยังไม่ได้ `systemd` ให้ใช้ `sudoedit /etc/wsl.conf` แล้วเพิ่มหรือแก้ในส่วน `[boot]` เดิม

```ini
[boot]
systemd=true
```

บันทึกงานใน WSL ก่อนสั่ง `wsl --shutdown` จาก PowerShell เพราะคำสั่งนี้หยุดทุกดิสทริบิวชัน จากนั้นเปิด Ubuntu ใหม่และตรวจ PID 1 อีกครั้ง เก็บ repository และโฟลเดอร์รันไว้ใต้ `~/` ในระบบไฟล์ Linux เพื่อให้การทำงานกับไฟล์จำนวนมากคล่องตัว

### Ubuntu ที่ติดตั้งโดยตรง

เปิด Terminal แล้วเริ่มที่ขั้นตอนถัดไป คำสั่ง Bash เหมือนกับ Ubuntu บน WSL2

## 3. ติดตั้ง Nix และเปิด binary cache

**3.1 · Ubuntu Bash** ติดตั้งเครื่องมือพื้นฐาน

```bash
sudo apt update
sudo apt install -y git curl ca-certificates
```

**3.2 · Ubuntu Bash** ตรวจ `command -v nix` ก่อน หากติดตั้ง Nix อยู่แล้วให้ข้าม installer และตรวจค่าด้านล่างใน `/etc/nix/nix.conf` โดยรักษาค่าเดิมที่ใช้งานอยู่ สำหรับเครื่องใหม่ใช้ installer ตามเอกสาร LibreLane

```bash
curl --proto '=https' --tlsv1.2 -fsSL https://artifacts.nixos.org/nix-installer |
  sh -s -- install --extra-conf "
    extra-substituters = https://nix-cache.fossi-foundation.org
    extra-trusted-public-keys = nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs=
    extra-experimental-features = nix-command flakes
  "
```

หากแก้ค่า cache ใน Nix แบบหลายผู้ใช้ที่มีอยู่แล้ว ให้ใช้ `sudo systemctl restart nix-daemon.service` จากนั้นปิดและเปิด Terminal ใหม่

```bash
nix --version
nix-shell --version
nix show-config | grep -E '^(substituters|experimental-features) ='
```

ควรเห็น URL ของ FOSSi ในรายการ substituters และเห็น `nix-command` กับ `flakes` ใน experimental features

## 4. เปิด LibreLane ที่เวอร์ชันกำหนด

**4.1 · Ubuntu Bash** ดาวน์โหลดและตรวจแท็ก

คู่มือนี้ตรึงแท็ก `3.0.16` เพื่อให้ผู้เรียนใช้ baseline เดียวกัน หากรายวิชากำหนด `3.0.9` ให้ใช้แท็กนั้นตั้งแต่ตอน clone และเก็บแยกโฟลเดอร์

```bash
mkdir -p ~/eda
cd ~/eda
git clone --branch 3.0.16 https://github.com/librelane/librelane.git librelane-3.0.16
cd librelane-3.0.16
git describe --tags --exact-match
git rev-parse HEAD
```

จุดตรวจคือ `git describe --tags --exact-match` แสดง `3.0.16` หากคำสั่ง clone ล้มเหลว ให้แก้ก่อนเปิด shell

**4.2 · Ubuntu Bash** เปิด environment จาก root ของ repository

```bash
nix-shell
```

**4.3 · Nix shell** ตรวจเครื่องมือ

```bash
librelane --version
command -v librelane yosys openroad klayout
```

Nix จะดึงเครื่องมือเมื่อเปิด shell ครั้งแรก การเข้า shell ครั้งถัดไปใช้ `cd ~/eda/librelane-3.0.16 && nix-shell` และใช้ `exit` เพื่อออก คำสั่ง LibreLane ในขั้นตอนต่อไปให้รันจากภายใน shell นี้

## 5. รัน smoke test

**Nix shell** รันจาก repository ก่อนเริ่มแล็บ

```bash
librelane --smoke-test
echo "Smoke test exit status: $?"
```

อ่านผลท้าย log และยืนยันว่า exit status เป็น 0 ให้สั่ง `echo` ต่อจาก smoke test ทันทีเพื่ออ่านสถานะของคำสั่งนั้น Smoke test ตรวจการทำงานของตัวอย่างที่มากับ LibreLane ส่วนการตรวจ IHP SG13G2 โดยตรงอยู่ในแล็บถัดไป

## 6. แล็บแรกด้วย IHP SG13G2

**6.1 · Nix shell** สร้าง RTL และไฟล์ตั้งค่า ตัวอย่างเป็น synchronous counter 8 บิต มี enable และ synchronous reset ตั้งคาบนาฬิกา 20 ns สำหรับการทดลอง implementation

```bash
mkdir -p ~/asic-labs/ll-counter8/rtl
cd ~/asic-labs/ll-counter8

cat > rtl/counter8.v <<'VERILOG'
module counter8 (
    input  wire       clk,
    input  wire       rst,
    input  wire       en,
    output reg  [7:0] count
);
    always @(posedge clk) begin
        if (rst)
            count <= 8'd0;
        else if (en)
            count <= count + 8'd1;
    end
endmodule
VERILOG

cat > config.yaml <<'YAML'
DESIGN_NAME: counter8
VERILOG_FILES:
  - dir::rtl/counter8.v
CLOCK_PORT: clk
CLOCK_PERIOD: 20
YAML
```

`DESIGN_NAME` ตรงกับชื่อ top module ส่วน `dir::` อ้างตำแหน่งเทียบกับโฟลเดอร์ของ config ค่า `CLOCK_PORT` ตรงกับพอร์ตจริงและ `CLOCK_PERIOD` มีหน่วย ns

**6.2 · Nix shell** เรียก Classic flow และเก็บ log

```bash
run_tag="ihp-counter8-$(date +%Y%m%d-%H%M%S)"
set -o pipefail
librelane --pdk ihp-sg13g2 --run-tag "$run_tag" config.yaml |&
  tee "$run_tag.log"
flow_status=$?
printf 'Flow exit status: %s\n' "$flow_status"
```

ครั้งแรก Ciel จะดึง PDK ที่ flow ต้องการ จากนั้น Classic flow จะทำ synthesis, floorplan/PDN, placement, CTS, routing และตรวจผลตามขั้นตอนที่เปิดใช้

## 7. ตรวจผลและเปิด layout

**7.1 · Nix shell** ทำขั้นนี้เมื่อ Flow exit status เป็น 0 คำสั่งใช้ `run_tag` จากเทอร์มินัลเดิม หากเปิดเทอร์มินัลใหม่ให้เข้า Nix shell กลับมายังโฟลเดอร์แล็บ แล้วตั้ง `run_tag` ให้ตรงกับชื่อโฟลเดอร์ใน `runs/`

```bash
find "runs/$run_tag/final" -type f | sort
find "runs/$run_tag/final" -type f -name '*.gds' | sort
```

**7.2 · Nix shell** เปิด layout ของรันที่เพิ่งตรวจ

```bash
librelane --pdk ihp-sg13g2 --run-tag "$run_tag" --flow openinklayout config.yaml
```

| สิ่งที่ตรวจ | หลักฐาน |
|---|---|
| Flow สำเร็จ | ข้อความท้าย log และ exit status 0 |
| GDSII ของวงจร | ไฟล์ GDS ใต้ `runs/<run-tag>/final/` และ top cell `counter8` ใน KLayout |
| Timing | รายงาน STA หลัง routing ตรวจ setup และ hold slack พร้อมดู constraint coverage |
| Physical verification | รายงาน DRC/LVS จาก step ที่เปิดใช้ ตรวจจำนวน violation และผลการเทียบ netlist |

`--last-run` เปิดรันล่าสุด ให้ใช้ `--run-tag "$run_tag"` แทนเมื่อต้องการเจาะจงรัน และเลือกเพียงหนึ่งตัวเลือกต่อคำสั่ง

ตัวอย่างนี้ทำ hardening ระดับ core ด้วย constraint ขั้นต้น สำหรับนำไปส่งผลิตต้องมี top-level integration, ข้อกำหนด I/O และการตรวจ sign-off ตาม PDK และ foundry ที่เลือก

## 8. แก้ปัญหาตามอาการ

| อาการ | วิธีตรวจและแก้ |
|---|---|
| `nix: command not found` | เปิด Terminal ใหม่ ตรวจผล installer และตรวจ `systemctl status nix-daemon.service` หากติดตั้งแบบหลายผู้ใช้ |
| `nix-shell` หา `<nixpkgs>` ไม่เจอ | ตรวจ `pwd` และ `git describe --tags` ก่อน ให้รันจาก root ของ LibreLane checkout หากเกิดเฉพาะใน shell ของแล็บ ให้ตรวจว่ามี `import <nixpkgs>` ที่ต้องอาศัย `NIX_PATH` หรือไม่ |
| Nix พยายาม build เครื่องมือจำนวนมาก | ตรวจ URL และ public key ของ FOSSi cache รวมถึงสถาปัตยกรรมและแท็กที่ checkout |
| `librelane: command not found` | เข้า `nix-shell` จาก root ของ LibreLane แล้วตรวจ `command -v librelane` |
| Ciel ดาวน์โหลด PDK ไม่สำเร็จ | ตรวจ error ของ download, proxy/TLS และพื้นที่ดิสก์ แล้วรันซ้ำเมื่อแก้ต้นเหตุ |
| Flow หยุดกลางทาง | เริ่มจาก error แรกใน log หลัก เปิด log ของ step ที่ล้มใน `runs/<run-tag>/` และตรวจ `DESIGN_NAME`, ชื่อ clock และ PDK ที่ resolve |
| KLayout เปิด GUI ไม่ขึ้น | ตรวจ `DISPLAY` หรือ `WAYLAND_DISPLAY` และอัปเดต WSL ด้วย `wsl --update` จาก PowerShell หรือเปิด GDS ที่สร้างแล้วด้วย KLayout บน Windows |

### ใช้ IHP PDK ที่เตรียมไว้เอง

ใช้เมื่อมี PDK checkout ที่ตรงกับ workflow หรือเมื่อจำเป็นต้องคุม revision เอง ให้ `--pdk-root` ชี้โฟลเดอร์แม่ที่มี `ihp-sg13g2/` และบันทึก commit ของ PDK คู่กับ LibreLane

```bash
librelane --pdk ihp-sg13g2 --pdk-root "$HOME/eda/IHP-Open-PDK" \
  --manual-pdk config.yaml
```

ก่อนแชร์ผลกับผู้เรียนหรือผู้ร่วมงาน ให้เก็บ LibreLane tag/commit, PDK revision, `config.yaml`, RTL และ run log ไว้ด้วยกัน

## เอกสารอ้างอิง

- [LibreLane สำหรับ Windows/WSL2](https://librelane.readthedocs.io/en/latest/installation/nix_installation/installation_win.html)
- [LibreLane สำหรับ Ubuntu/Linux](https://librelane.readthedocs.io/en/stable/installation/nix_installation/installation_linux.html)
- [LibreLane Releases](https://github.com/librelane/librelane/releases)
- [Newcomers’ Tutorial](https://librelane.readthedocs.io/en/latest/getting_started/newcomers/index.html)
- [IHP SG13G2 Setup Guide](https://ihp-open-pdk-docs.readthedocs.io/en/latest/digital/librelane_setup.html)
