# ติดตั้ง LibreLane ด้วย AppImage แบบ Step by Step

**Windows 11 + WSL2 · Ubuntu 22.04 หรือ 24.04 · LibreLane 3.0.16**

AppImage เป็นไฟล์ Linux ที่รวม LibreLane และเครื่องมือ EDA ไว้ด้วยกัน ให้เปิดไฟล์จาก Ubuntu ใน WSL2 แล้วรันคำสั่ง `librelane` ภายใน environment ที่เปิดขึ้น เส้นทางนี้ใช้ AppImage โดยตรงโดยไม่ต้องติดตั้ง Nix หรือ Docker ส่วน PDK ที่ใช้ในแล็บจะดาวน์โหลดเมื่อเรียกใช้ครั้งแรก

| ช่วง | รันจาก |
|---|---|
| ติดตั้งและตรวจ WSL2 | Windows PowerShell |
| ดาวน์โหลดและเปิด AppImage | Ubuntu Bash |
| รัน smoke test และ RTL-to-GDSII | Shell ที่ AppImage เปิดขึ้น |

เอกสาร LibreLane ระบุ RAM ขั้นต่ำ 8 GiB และแนะนำ 16 GiB เตรียมพื้นที่ว่างสำหรับ AppImage, PDK และผลการรัน

## 1. ติดตั้ง Ubuntu บน WSL2

**PowerShell** ตรวจว่ามี Ubuntu อยู่แล้วหรือไม่

```powershell
wsl --list --verbose
```

ถ้ามี Ubuntu และคอลัมน์ `VERSION` เป็น `2` ให้เปิด Ubuntu แล้วไปขั้นที่ 2 ถ้ายังไม่มี ให้เปิด PowerShell แบบ Administrator แล้วรัน

```powershell
wsl --list --online
wsl --install -d Ubuntu-22.04
```

หาก Windows ขอให้รีสตาร์ต ให้รีสตาร์ตแล้วเปิด Ubuntu จาก Start Menu ตั้งชื่อผู้ใช้และรหัสผ่าน Linux ครั้งแรก จากนั้นกลับมาตรวจด้วย `wsl --list --verbose` หากพบ VERSION 1 ให้สั่ง `wsl --set-version Ubuntu-22.04 2` โดยใช้ชื่อดิสทริบิวชันตามที่แสดงจริง

**Ubuntu Bash** ตรวจสภาพแวดล้อม

```bash
cat /etc/os-release
uname -m
ps -p 1 -o comm=
df -h "$HOME"
```

จดผล `uname -m` สำหรับเลือกไฟล์ในขั้นถัดไป หาก WSL รุ่นเก่ายังไม่ใช้ `systemd` ให้เปิด `sudoedit /etc/wsl.conf` แล้วเพิ่มหรือแก้ `systemd=true` ภายใต้ส่วน `[boot]` บันทึกงานที่เปิดอยู่ใน WSL ก่อนใช้ `wsl --shutdown` ใน PowerShell แล้วเปิด Ubuntu ใหม่และตรวจ PID 1 อีกครั้ง

## 2. เลือกไฟล์ AppImage และดาวน์โหลด

เปิด [LibreLane Release 3.0.16](https://github.com/librelane/librelane/releases/tag/3.0.16) แล้วเลือกไฟล์จาก **Assets** ตามผลของ `uname -m` คู่มือนี้ตรึงเวอร์ชันเพื่อให้ผู้เรียนได้สภาพแวดล้อมเดียวกัน

| ผลจาก Ubuntu | ชื่อไฟล์ที่เลือก |
|---|---|
| `x86_64` | `librelane-devshell-x86_64.AppImage` |
| `aarch64` | `librelane-devshell-aarch64.AppImage` |

ถ้าดาวน์โหลดด้วยเบราว์เซอร์ Windows ให้ใช้ **Ubuntu Bash** คัดลอกไฟล์เข้า Linux home โดยแทน `YOUR_WINDOWS_USER` ด้วยชื่อโฟลเดอร์จริงใต้ `/mnt/c/Users/` และปรับตำแหน่งถ้าเบราว์เซอร์ใช้โฟลเดอร์ดาวน์โหลดอื่น

```bash
app_dir="$HOME/eda/librelane-appimage/3.0.16"
asset="librelane-devshell-$(uname -m).AppImage"
mkdir -p "$app_dir"
cp -i -- "/mnt/c/Users/YOUR_WINDOWS_USER/Downloads/$asset" "$app_dir/$asset"
ls -lh -- "$app_dir/$asset"
```

จุดตรวจคือ `ls` แสดงไฟล์ใน Linux home หากไฟล์หาไม่พบ ให้ตรวจชื่อจริงใน Downloads รวมถึงชื่อที่เบราว์เซอร์เติมต่อท้ายเมื่อดาวน์โหลดซ้ำ เก็บโครงการและผลรันใต้ `~/` เพื่อให้การทำงานกับไฟล์จำนวนมากอยู่ในระบบไฟล์ Linux

## 3. ให้สิทธิ์ execute และเปิด environment

**Ubuntu Bash** ตั้งสิทธิ์และเปิดไฟล์ด้วยบัญชีผู้ใช้ปกติ

```bash
app="$HOME/eda/librelane-appimage/3.0.16/librelane-devshell-$(uname -m).AppImage"
chmod u+x -- "$app"
ls -l -- "$app"
"$app"
```

เมื่อเปิดสำเร็จจะได้ shell ใหม่พร้อมใช้เครื่องมือ Prompt อาจขึ้นว่า `[nix-shell:~]$` เพราะเป็นรูปแบบ prompt ของ environment ที่บรรจุมากับ AppImage จากนี้ให้รันคำสั่งใน shell ดังกล่าว ใช้ `exit` เมื่อจะกลับไป Ubuntu Bash

## 4. ตรวจเวอร์ชันและรัน smoke test

**Shell ของ AppImage**

```bash
librelane --version
command -v librelane yosys openroad klayout
```

ผลที่ควรเห็นคือเวอร์ชัน `3.0.16` และ path ของเครื่องมือที่ตรวจ จากนั้นรันทดสอบตัวอย่างที่มากับ LibreLane

```bash
librelane --smoke-test
smoke_status=$?
printf 'Smoke test exit status: %s\n' "$smoke_status"
```

ผ่านเมื่อสถานะเป็น `0` หากมีการดาวน์โหลด PDK ให้รอจนจบก่อนตรวจสถานะ หากล้มเหลวให้เริ่มจากข้อความ error แรก Smoke test ตรวจ flow ของตัวอย่างที่มากับ LibreLane ส่วนขั้นต่อไปตรวจเส้นทาง IHP SG13G2 โดยตรง

## 5. แล็บแรกด้วย IHP SG13G2

**Shell ของ AppImage** สร้างโครงการตัวอย่างใน Linux home

```bash
mkdir -p "$HOME/asic-labs/appimage-counter8/rtl"
cd "$HOME/asic-labs/appimage-counter8"

cat > rtl/counter8.v <<'VERILOG'
module counter8 (
    input wire clk,
    input wire rst,
    input wire en,
    output reg [7:0] count
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

วงจรนับเมื่อ `en=1` และรีเซตแบบ synchronous ค่า `CLOCK_PERIOD: 20` กำหนดคาบ 20 ns ส่วน `dir::` อ้าง path เทียบกับโฟลเดอร์ของ `config.yaml`

```bash
run_tag="ihp-appimage-$(date +%Y%m%d-%H%M%S)"
set -o pipefail
librelane --pdk ihp-sg13g2 --run-tag "$run_tag" config.yaml 2>&1 |
  tee "$run_tag.log"
flow_status=$?
printf 'Flow exit status: %s\n' "$flow_status"
```

Ciel จะดึง PDK เมื่อยังไม่มี revision ที่ต้องใช้ แล้ว Classic flow จึงทำ synthesis, floorplan, placement, CTS และ routing ตรวจว่า exit status เป็น `0` ก่อนทำขั้นที่ 6 ถ้าล้มเหลวให้เปิด `$run_tag.log` และ log ของ step ที่ล้มเหลวใน `runs/$run_tag/`

## 6. ตรวจ GDSII และเปิด KLayout

**Shell ของ AppImage ในเทอร์มินัลเดิม**

```bash
find "runs/$run_tag/final" -type f -name '*.gds'
librelane --pdk ihp-sg13g2 --run-tag "$run_tag" --flow openinklayout config.yaml
```

ตรวจว่าพบไฟล์ GDSII และ KLayout แสดง top cell `counter8` หากเปิด shell ใหม่ ให้กลับเข้าโฟลเดอร์โครงการและกำหนด `run_tag` ตามชื่อโฟลเดอร์ใต้ `runs/` ใช้ `--last-run` แทน `--run-tag` ได้เมื่อต้องการเปิดรันล่าสุด

GDSII นี้เป็นผลของแล็บ hardening ระดับ core อ่านรายงาน STA และผล DRC/LVS ของรันประกอบก่อนสรุปคุณภาพ implementation

## 7. แก้ปัญหาตามข้อความที่พบ

| อาการ | วิธีตรวจและแก้ |
|---|---|
| `No such file or directory` ตอนคัดลอก | ตรวจชื่อโฟลเดอร์บัญชี Windows และชื่อไฟล์จริงใน Downloads |
| `Permission denied` ตอนเปิด | ยืนยันว่าไฟล์อยู่ใต้ Linux home แล้วรัน `chmod u+x -- "$app"` |
| `Exec format error` | ตรวจ `uname -m` ให้ตรงกับไฟล์ และตรวจว่าดาวน์โหลด AppImage ครบ |
| `libfuse.so.2` หาย | Ubuntu 22.04 ใช้ `sudo apt update && sudo apt install libfuse2` ส่วน Ubuntu 24.04 ใช้ `sudo apt update && sudo apt install libfuse2t64` แล้วลองเปิดใหม่ |
| FUSE mount ไม่ได้ | ตรวจ WSL2 และลองโหมด extract-and-run ตามบล็อกด้านล่าง |
| `librelane: command not found` | เปิด AppImage ก่อน แล้วใช้ `command -v librelane` ภายใน shell ที่ได้ |
| ดาวน์โหลด PDK ล้มเหลว | ตรวจข้อความจาก Ciel, พื้นที่ว่าง และการเชื่อมต่อเครือข่าย แล้วรันซ้ำ |
| KLayout เปิดหน้าต่างไม่ได้ | ตรวจ WSLg ด้วย `printenv DISPLAY WAYLAND_DISPLAY` และอัปเดต WSL ด้วย `wsl --update` ใน PowerShell หรือใช้ KLayout บน Windows เปิด GDSII ที่สร้างแล้ว |

หาก runtime ของ AppImage รองรับ extract-and-run ให้ลองจาก **Ubuntu Bash** โดยกำหนดตัวแปร `app` ตามขั้นที่ 3 โหมดนี้ใช้พื้นที่ชั่วคราวเพื่อแตกไฟล์ก่อนรัน

```bash
"$app" --appimage-extract-and-run
```

## เปิดใช้งานครั้งถัดไป

เปิด Ubuntu แล้วเรียกไฟล์เดิม เมื่อเข้า shell ของ AppImage แล้วจึงเปลี่ยนไปยังโฟลเดอร์โครงการ

```bash
"$HOME/eda/librelane-appimage/3.0.16/librelane-devshell-$(uname -m).AppImage"
```

## เอกสารอ้างอิง

- [LibreLane AppImage สำหรับ Windows และ WSL2](https://librelane.readthedocs.io/en/latest/installation/appimage_installation/installation_win.html)
- [LibreLane 3.0.16 Release](https://github.com/librelane/librelane/releases/tag/3.0.16)
- [IHP SG13G2 Setup Guide](https://ihp-open-pdk-docs.readthedocs.io/en/latest/digital/librelane_setup.html)
- [LibreLane Newcomers’ Tutorial](https://librelane.readthedocs.io/en/latest/getting_started/newcomers/index.html)
- [AppImage FUSE Troubleshooting](https://docs.appimage.org/user-guide/troubleshooting/fuse.html)
