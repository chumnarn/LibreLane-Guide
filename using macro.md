# คู่มือ LibreLane 3.x: Using Macros พร้อม Lab แบบ Step-by-Step

> คู่มือนี้อ้างอิง LibreLane Documentation: **Using Macros** (stable) และออกแบบสำหรับ LibreLane 3.x โดยใช้ `config.yaml`

## 1. วัตถุประสงค์การเรียนรู้

เมื่อจบ Lab ผู้เรียนจะสามารถ:

1. อธิบายความแตกต่างระหว่าง RTL module, standard cell และ hardened macro
2. ระบุ physical/timing views ที่ LibreLane ต้องใช้
3. ประกาศ macro และ instance ในตัวแปร `MACROS` ของ `config.yaml`
4. harden block ระดับล่าง แล้วนำ LEF/GDS/netlist/liberty ไปใช้ใน top-level
5. กำหนดตำแหน่ง orientation, halo และการต่อ power/ground ของ macro
6. ตรวจสอบ synthesis hierarchy, floorplan, PDN, routing, STA, DRC และ LVS
7. วิเคราะห์และแก้ข้อผิดพลาด macro integration ที่พบบ่อย

---

## 2. Macro คืออะไร

Macro คือ block ที่ผ่าน physical implementation มาแล้ว เช่น SRAM, ROM, PLL, analog IP, accelerator หรือ CPU core เมื่อวางใน top-level เครื่องมือจะไม่ place standard cells ภายใน macro ใหม่ แต่ใช้ abstract physical view เพื่อวางและเดินสายรอบ block

ประโยชน์หลักคือ:

- ลดเวลารัน PnR ของ top-level
- reuse block ที่ผ่านการตรวจสอบแล้ว
- แยกการพัฒนาและ timing closure เป็นลำดับชั้น
- รองรับ third-party IP โดยไม่เปิดเผย RTL ภายใน

ข้อควรจำ: **ชื่อ key ชั้นแรกของ `MACROS` คือชื่อ module/cell ของ macro ส่วนชื่อใน `instances` คือชื่อ instance ที่ปรากฏใน synthesized netlist**

---

## 3. Views ของ Macro

| View | จำเป็น | หน้าที่ |
|---|---:|---|
| `.lef` | ใช่ | ขนาด ขอบเขต pin และ routing obstruction สำหรับ PnR |
| `.gds` / `.gds.gz` | ใช่ | geometry ฉบับเต็มสำหรับ stream-out และ signoff |
| `.vh` | แนะนำ | Verilog header/black-box declaration สำหรับ lint และ synthesis |
| `.nl.v` / `.gl.v` | แนะนำ | gate-level netlist; ใช้ synthesis fallback และอาจใช้ร่วมกับ SPEF ใน STA |
| `.pnl.v` | ทางเลือก | powered gate-level netlist |
| `.lib` | แนะนำมาก | timing arcs, delay, constraints และ power ของ macro |
| `.spef` | ทางเลือก | parasitic RC; ใช้ร่วมกับ netlist สำหรับ hierarchical STA |
| `.spice` | ทางเลือก | transistor/netlist view สำหรับ physical verification ในบาง flow |
| `.sdf` | ทางเลือก | timing annotation; LibreLane ยังไม่ใช้โดยตรงใน flow ปกติ |
| Yosys JSON header | ทางเลือก | powered header ในรูปแบบที่โปรแกรมอ่านได้ |

LibreLane จะปฏิเสธ macro definition ที่ไม่มี `lef` หรือ `gds` อย่างน้อยหนึ่งไฟล์

### 3.1 ลำดับการเลือกข้อมูลสำหรับ STA

- `STA_MACRO_PRIORITIZE_NL: true` — ให้ความสำคัญ `.nl.v + .spef`, fallback ไป `.lib`, แล้วจึง black-box
- `STA_MACRO_PRIORITIZE_NL: false` — ให้ความสำคัญ `.lib`, fallback ไป `.nl.v + .spef`, แล้วจึง black-box

ถ้าไม่มี timing view จะตรวจ STA แบบ black-box ซึ่งอาจซ่อน setup/hold violation ที่ boundary ของ macro

---

## 4. รูปแบบ `MACROS` ใน `config.yaml`

```yaml
MACROS:
  alu_macro:                         # ชื่อ macro/module ไม่ใช่ชื่อ instance
    instances:
      u_alu:                         # ต้องตรงกับ synthesized instance name
        location: [100.0, 120.0]     # หน่วยไมครอน
        orientation: N
    lef:
      - dir::macros/alu_macro/lef/alu_macro.lef
    gds:
      - dir::macros/alu_macro/gds/alu_macro.gds
    vh:
      - dir::macros/alu_macro/verilog/alu_macro.vh
    nl:
      - dir::macros/alu_macro/verilog/alu_macro.nl.v
    lib:
      "*_tt_025C_1v20":
        - dir::macros/alu_macro/lib/alu_macro.lib
    spef: {}
    spice: []
    sdf: {}
```

`dir::` อ้าง path สัมพันธ์กับ directory ของ config file จึงช่วยให้ repository เคลื่อนย้ายได้

### 4.1 Orientation ที่ใช้บ่อย

| ค่า | ความหมายโดยย่อ |
|---|---|
| `N` | ไม่หมุน |
| `S` | หมุน 180° |
| `E` / `W` | หมุน 90° / 270° |
| `FN` / `FS` | mirror แล้ววางแนว N/S |
| `FE` / `FW` | mirror แล้วหมุน |

ต้องตรวจว่า pin access, power stripe และ legal orientation ของ macro รองรับค่าที่เลือก

---

# Lab — Harden และ Integrate ALU Macro

## 5. ภาพรวม Lab

Lab นี้มีสองรอบของ LibreLane:

1. **Macro hardening:** แปลง `alu_macro` จาก RTL เป็น LEF/GDS/netlist/liberty
2. **Top-level integration:** ใช้ผลลัพธ์เป็น fixed macro ภายใน `macro_user_top`

> ตัวอย่างใช้ชื่อ PDK `ihp-sg13g2` ให้เปลี่ยนเฉพาะ `PDK` และ timing-corner mapping หากใช้ PDK อื่น ตรวจชื่อ PDK ที่ติดตั้งด้วย `librelane --list-pdks`

## 6. โครงสร้าง Project

```text
macro-lab/
├── Makefile
├── macro/
│   ├── config.yaml
│   └── rtl/alu_macro.sv
├── top/
│   ├── config.yaml
│   ├── constraints.sdc
│   └── rtl/
│       ├── alu_macro.vh
│       └── macro_user_top.sv
└── macros/alu_macro/
    ├── gds/
    ├── lef/
    ├── lib/
    └── verilog/
```

## 7. RTL ของ Macro

ไฟล์ `macro/rtl/alu_macro.sv`

```systemverilog
`default_nettype none
module alu_macro (
`ifdef USE_POWER_PINS
    inout wire VDD,
    inout wire VSS,
`endif
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [1:0]  op,
    output reg  [31:0] y
);
    wire [31:0] result = (op == 2'b00) ? (a + b) :
                         (op == 2'b01) ? (a - b) :
                         (op == 2'b10) ? (a & b) : (a ^ b);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) y <= 32'b0;
        else        y <= result;
    end
endmodule
`default_nettype wire
```

Power pins อยู่ใต้ guard `USE_POWER_PINS`; ชื่อ define นี้ต้องสอดคล้องกับ `VERILOG_POWER_DEFINE`

## 8. Config สำหรับ Harden Macro

ไฟล์ `macro/config.yaml`

```yaml
meta:
  version: 2

DESIGN_NAME: alu_macro
VERILOG_FILES:
  - dir::rtl/alu_macro.sv

CLOCK_PORT: clk
CLOCK_PERIOD: 10.0
VERILOG_POWER_DEFINE: USE_POWER_PINS

DIE_AREA: [0, 0, 360, 300]
CORE_AREA: [20, 20, 340, 280]
FP_SIZING: absolute
PL_TARGET_DENSITY_PCT: 45

VDD_NETS: [VDD]
GND_NETS: [VSS]
```

หมายเหตุ: LibreLane/PDK revision บางรุ่นใช้ชื่อ density variable ต่างกัน ให้ตรวจ resolved config และ warning; ใน LibreLane 3.x รุ่นที่ติดตั้งจริงอาจต้องใช้ `PL_TARGET_DENSITY` เป็นอัตราส่วนแทนเปอร์เซ็นต์

## 9. รัน Macro Hardening

```bash
cd macro-lab
librelane --pdk ihp-sg13g2 --run-tag alu_macro_v1 macro/config.yaml
```

ตรวจสอบผลลัพธ์ก่อนนำไปใช้:

```bash
find macro/runs/alu_macro_v1/final -maxdepth 2 -type f | sort
```

ควรพบอย่างน้อย LEF และ GDS และควรเก็บ netlist/liberty ที่ flow สร้างได้ อย่าคาดเดาชื่อ path ของ artifact; ให้ตรวจ `final/` ของ run จริงก่อน copy

ตัวอย่าง copy:

```bash
mkdir -p macros/alu_macro/{gds,lef,lib,verilog}
cp macro/runs/alu_macro_v1/final/gds/alu_macro.gds macros/alu_macro/gds/
cp macro/runs/alu_macro_v1/final/lef/alu_macro.lef macros/alu_macro/lef/
cp macro/runs/alu_macro_v1/final/nl/alu_macro.nl.v macros/alu_macro/verilog/
cp macro/runs/alu_macro_v1/final/lib/nom_*/alu_macro.lib macros/alu_macro/lib/alu_macro.lib
```

หากชื่อ directory ของ netlist/liberty ต่างออกไป ให้ใช้ผลจาก `find` เป็นแหล่งจริง

## 10. Verilog Header ของ Macro

ไฟล์ `top/rtl/alu_macro.vh`

```systemverilog
`ifndef ALU_MACRO_VH
`define ALU_MACRO_VH
(* blackbox *)
module alu_macro (
`ifdef USE_POWER_PINS
    inout wire VDD,
    inout wire VSS,
`endif
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [1:0]  op,
    output wire [31:0] y
);
endmodule
`endif
```

ต้องตรวจ port name, width และ direction ให้ตรงกับ macro netlist/LEF ทุกจุด

## 11. Top-level RTL

ไฟล์ `top/rtl/macro_user_top.sv`

```systemverilog
`default_nettype none
module macro_user_top (
`ifdef USE_POWER_PINS
    inout wire VDD,
    inout wire VSS,
`endif
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [1:0]  op,
    output wire [31:0] y
);
    alu_macro u_alu (
`ifdef USE_POWER_PINS
        .VDD(VDD),
        .VSS(VSS),
`endif
        .clk(clk), .rst_n(rst_n), .a(a), .b(b), .op(op), .y(y)
    );
endmodule
`default_nettype wire
```

## 12. SDC ของ Top-level

ไฟล์ `top/constraints.sdc`

```tcl
create_clock -name core_clk -period 10.000 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks core_clk]
set_input_delay 2.0 -clock core_clk [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]
set_output_delay 4.0 -clock core_clk [all_outputs]
set_false_path -from [get_ports rst_n]
```

## 13. Config สำหรับ Integrate Macro

ไฟล์ `top/config.yaml`

```yaml
meta:
  version: 2

DESIGN_NAME: macro_user_top
VERILOG_FILES:
  - dir::rtl/macro_user_top.sv

CLOCK_PORT: clk
CLOCK_PERIOD: 10.0
PNR_SDC_FILE: dir::constraints.sdc
SIGNOFF_SDC_FILE: dir::constraints.sdc
VERILOG_POWER_DEFINE: USE_POWER_PINS

DIE_AREA: [0, 0, 700, 600]
CORE_AREA: [30, 30, 670, 570]
FP_SIZING: absolute
PL_TARGET_DENSITY_PCT: 40

VDD_NETS: [VDD]
GND_NETS: [VSS]

FP_MACRO_HORIZONTAL_HALO: 15
FP_MACRO_VERTICAL_HALO: 15

STA_MACRO_PRIORITIZE_NL: false

MACROS:
  alu_macro:
    instances:
      u_alu:
        location: [170.0, 150.0]
        orientation: N
    lef:
      - dir::../macros/alu_macro/lef/alu_macro.lef
    gds:
      - dir::../macros/alu_macro/gds/alu_macro.gds
    vh:
      - dir::rtl/alu_macro.vh
    nl:
      - dir::../macros/alu_macro/verilog/alu_macro.nl.v
    lib:
      "*":
        - dir::../macros/alu_macro/lib/alu_macro.lib
    spef: {}
    spice: []
    sdf: {}
```

การใช้ wildcard `"*"` เหมาะสำหรับ Lab ที่มี liberty เดียว แต่ project tape-out ควร map liberty ให้ตรงกับ timing corners ของ PDK อย่างเจาะจง

## 14. รัน Top-level

```bash
librelane --pdk ihp-sg13g2 --run-tag macro_top_v1 top/config.yaml
```

LibreLane 3.x ไม่ใช้ `--interactive` หรือ `--override`; เปลี่ยนค่าผ่าน `config.yaml` หรือสร้าง config variant แล้วรันด้วย `--run-tag`

---

## 15. จุดตรวจรับผล Lab

### 15.1 ก่อนรัน

```bash
test -s macros/alu_macro/lef/alu_macro.lef
test -s macros/alu_macro/gds/alu_macro.gds
grep -n "MACRO alu_macro" macros/alu_macro/lef/alu_macro.lef
grep -n "module alu_macro" top/rtl/alu_macro.vh
grep -n "alu_macro u_alu" top/rtl/macro_user_top.sv
```

### 15.2 หลัง synthesis

- `u_alu` ยังเป็น macro instance และไม่ถูกสังเคราะห์เป็น logic ภายใน
- ไม่มี `module not found`, `unknown module` หรือ port mismatch
- หาก macro อยู่ใต้ hierarchy ที่ถูก flatten ชื่ออาจเป็น `u_subsystem.u_alu`

ค้นชื่อจริงจาก synthesized netlist:

```bash
rg -n "alu_macro|u_alu" top/runs/macro_top_v1
```

### 15.3 หลัง floorplan

- macro อยู่ที่พิกัดและ orientation ที่กำหนด
- macro ไม่ทับ die/core boundary, IO, macro อื่น หรือ PDN ring
- standard-cell rows ถูกตัดรอบ macro และมี halo
- signal pins ของ macro เข้าถึง routing layer ได้

### 15.4 หลัง PDN

- VDD/VSS ของ macro เชื่อมกับ top-level power domains
- power stripe/ring แตะ macro power pins หรือ macro grid ตาม intended topology
- ไม่มี critical disconnected pin

ถ้าไม่ต้องการต่อ power pins ใน RTL สามารถพิจารณา `PDN_MACRO_CONNECTIONS` แต่ต้องใช้ syntax ที่ตรงกับ LibreLane/PDK revision และชื่อ instance/net/pin จริง การต่อแบบ explicit ใน RTL มักตรวจสอบง่ายกว่า

### 15.5 หลัง routing และ signoff

- congestion และ DRC รอบ macro boundary เป็นศูนย์หรืออยู่ในเกณฑ์ที่ยอมรับได้
- setup/hold slack ผ่านทุก corner ที่กำหนด
- LVS ยืนยันว่า macro instance และ connections ตรงกัน
- GDS stream-out มี macro geometry ครบ ไม่ใช่กล่องว่าง

---

## 16. หลาย Instance และ Hierarchy

ตัวอย่าง macro type เดียวสอง instance:

```yaml
MACROS:
  alu_macro:
    instances:
      u_bank0.u_alu:
        location: [100, 150]
        orientation: N
      u_bank1.u_alu:
        location: [420, 150]
        orientation: FN
    lef: [dir::../macros/alu_macro/lef/alu_macro.lef]
    gds: [dir::../macros/alu_macro/gds/alu_macro.gds]
    vh:  [dir::rtl/alu_macro.vh]
```

เมื่อ synthesis flatten hierarchy ซึ่งเป็นแนวทางปกติ ชื่อ nested instance ใช้ dot notation เช่น `u_bank0.u_alu` ไม่ใช่ชื่อ module และไม่ใส่ escape character

สำหรับ array instance เช่น `spm_inst[0]` ให้เขียนชื่อจริง `spm_inst[0]` ไม่ใช่ `spm_inst\\[0\\]` หลีกเลี่ยงการสร้าง escaped identifier ที่มี `/`, `[]` หรือ `:` เพราะอาจทำให้ flow ตีความ hierarchy ผิด

---

## 17. การเปลี่ยน RTL Block เดิมให้เป็น Macro

parameter ของ RTL จะถูก bake ลงใน hardened macro แล้ว จึงไม่ควรส่ง parameter เดิมให้ black-box ระหว่าง PnR ใช้ preprocessor แยกระหว่าง simulation และ implementation:

```systemverilog
`ifdef __pnr__
  BarrelShifter u_shift (.A(a), .O(y), .shamt(shamt));
`else
  BarrelShifter #(.WIDTH(16)) u_shift (.A(a), .O(y), .shamt(shamt));
`endif
```

LibreLane กำหนด `__pnr__` ระหว่าง lint/synthesis ทำให้ simulation ยังใช้ parameterized RTL แต่ implementation ใช้ hardened interface

---

## 18. Troubleshooting Matrix

| อาการ | สาเหตุที่เป็นไปได้ | วิธีตรวจ/แก้ |
|---|---|---|
| Macro instance not found | ชื่อใน `instances` ไม่ตรง synthesized netlist | ค้น netlist หลัง synthesis; ใช้ dot notation หลัง flatten |
| Missing LEF/GDS | path ผิดหรือ artifact ไม่ถูก copy | `test -s`, ตรวจ `dir::` และชื่อไฟล์จริง |
| Module not found | ไม่มี `vh`/`nl` หรือ header ไม่อยู่ใน macro definition | เพิ่ม `vh` ที่ถูกต้อง; ตรวจชื่อ module |
| Port mismatch | header, RTL, netlist และ LEF pin ไม่ตรงกัน | เปรียบเทียบชื่อ/width/direction แบบ case-sensitive |
| Macro ถูก synthesize เป็น gates | ใส่ RTL implementation ของ macroใน top flow | เอา implementation RTL ออกจาก top; ใช้ header/netlist ผ่าน `MACROS` |
| PDN disconnected | power pin/net name ไม่ตรง หรือ stripe ไม่แตะ pin | ตรวจ LEF `PIN`, RTL power ports, VDD/GND nets และ PDN report |
| Routing congestion รอบ macro | halo/ช่องทางเดินสายไม่พอ หรือ pin หันผิดด้าน | เพิ่ม core area/halo, ย้ายหรือกลับ orientation |
| LVS missing/extra cell | GDS/netlist macro view คนละ revision | package views จาก run เดียวกันและบันทึก checksum/version |
| STA ผ่านง่ายผิดปกติ | STA ทำ black-box | เพิ่ม `.lib` หรือ `.nl.v + .spef`; อ่าน STA log ว่าเลือก view ใด |
| Hold fail ที่ boundary | macro/top constraints ไม่สอดคล้องหรือ placement ทำ skew สูง | ใช้ accurate timing view, ตรวจ boundary paths และ clock skew |
| GDS มีช่องว่างแทน macro | ไม่มี/อ่าน GDS macro ไม่ได้ | ตรวจ `gds` path และ stream-out log |

---

## 19. แบบฝึกหัด

### Exercise A — Placement Experiment

รันอย่างน้อยสามค่า location/orientation บันทึก wirelength, congestion, setup WNS และ hold WNS แล้วอธิบายว่าทำไมตำแหน่งที่ใกล้ datapath จึงอาจไม่ได้ดีที่สุดหาก power/pin access ไม่เหมาะสม

### Exercise B — Black-box STA

1. รันด้วย `.lib`
2. เอา `.lib` ออกจาก macro definition ชั่วคราว
3. เปรียบเทียบจำนวน timing arcs, WNS/TNS และข้อความใน STA log

ห้ามใช้ผล black-box เป็นหลักฐาน timing signoff

### Exercise C — Two Macros

สร้าง `u_alu0` และ `u_alu1`, ต่อเป็น pipeline สอง stage, วางคนละ orientation และยืนยันว่าทั้งสอง instance อยู่ใน DEF/GDS

### Exercise D — SRAM Extension

แทน `alu_macro` ด้วย IHP SRAM โดยทำตามลำดับ:

1. ตรวจชื่อ module และ ports จาก Verilog model
2. ตรวจ `MACRO`, `SIZE`, signal pins และ power pins จาก LEF
3. เตรียม black-box header ที่ไม่มี behavioral implementation
4. map LEF/GDS/liberty ครบชุดจาก PDK revision เดียวกัน
5. instantiate SRAM wrapper เพื่อแปลง protocol/polarity โดยไม่เปลี่ยน macro interface
6. กำหนด fixed placement, halo และ PDN
7. รัน functional simulation ด้วย behavioral model แยกจาก PnR header
8. ตรวจ post-synthesis macro count, PDN, STA, LVS และ GDS

---

## 20. Rubric ประเมินผล 100 คะแนน

| หัวข้อ | คะแนน |
|---|---:|
| RTL/header และ interface consistency | 15 |
| Macro hardening สำเร็จและ views ครบ | 20 |
| `MACROS`/instance naming ถูกต้อง | 15 |
| Floorplan, placement, halo และ routability | 15 |
| Power/ground integration | 15 |
| STA และ physical verification | 15 |
| รายงานผล/การทดลองเปรียบเทียบ | 5 |

## 21. Checklist ก่อน Tape-out

- [ ] LEF/GDS/netlist/liberty เป็น macro revision เดียวกัน
- [ ] บันทึก source commit, PDK version และ LibreLane version
- [ ] instance names ตรงกับ synthesized netlist ทุกตัว
- [ ] macro pins และ bus ordering ตรงทุก view
- [ ] macro placement legal และมีช่อง routing/PDN เพียงพอ
- [ ] power/ground connectivity ผ่าน
- [ ] timing analysis ไม่ใช่ black-box โดยไม่ตั้งใจ
- [ ] setup/hold ผ่านทุก required corner
- [ ] DRC, LVS และ antenna checks ผ่านตาม signoff policy
- [ ] final GDS มี macro geometry และ seal-ring/top integration ครบ

---

## 22. คำสั่งสรุป

```bash
librelane --version
librelane --list-pdks
librelane --pdk ihp-sg13g2 --run-tag alu_macro_v1 macro/config.yaml
find macro/runs/alu_macro_v1/final -type f | sort
librelane --pdk ihp-sg13g2 --run-tag macro_top_v1 top/config.yaml
rg -n "alu_macro|u_alu|blackbox|macro" top/runs/macro_top_v1
```

## อ้างอิง

1. LibreLane Documentation, “Using Macros”: https://librelane.readthedocs.io/en/stable/usage/using_macros.html
2. LibreLane Documentation, “Power Distribution Networks”: https://librelane.readthedocs.io/en/stable/usage/pdn.html
3. LibreLane Reference, built-in flow/step configuration variables: https://librelane.readthedocs.io/en/stable/reference/

