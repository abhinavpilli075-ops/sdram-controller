````markdown
SDRAM Controller

A **Pipelined SDRAM Controller** implemented in **Verilog HDL** for efficient read and write transactions between a host interface and SDRAM memory. This project supports SDRAM initialization, read/write operations, refresh cycles, and command sequencing using a Finite State Machine (FSM) with pipelining for improved performance.

---
Project Overview

This project implements a synchronous dynamic random-access memory (**SDRAM**) controller that acts as an interface between the host processor/system and SDRAM memory.

The controller manages:

- SDRAM Initialization Sequence
- Row Activation (ACTIVE Command)
- Read and Write Operations
- Auto Refresh Cycles
- Mode Register Configuration
- Address Mapping (Bank / Row / Column)
- Data Transfer using Pipeline Stages

The design improves memory throughput by using a pipelined approach where multiple operations are handled across different stages simultaneously.

---

Block Diagram

```text
Host Interface                    SDRAM Interface

   /-----------------------------------------------\
   |              SDRAM Controller                 |
==> host_addr                                 addr ==>
==> host_wdata                           bank_addr ==>
==> host_req                                   data <=>
==> host_we                          clock_enable -->
==> host_be                                   cs_n -->
<== host_rdata                               ras_n -->
<== host_ack                                 cas_n -->
<== host_rdata_valid                          we_n -->
   |                                        dqm[1:0] -->
   \-----------------------------------------------/
````

---

 Features

* Verilog HDL based implementation
* FSM-controlled SDRAM command generation
* SDRAM initialization support
* Read and Write transaction handling
* Auto-refresh mechanism
* CAS latency support
* Pipelined read data handling
* Byte enable (`host_be`) support
* Testbench verification using Icarus Verilog
* GTKWave waveform analysis

---

 Repository Structure

```text
sdram-controller/
│
├── sdram_controller.v         # Main SDRAM controller design
├── tb_sdram_controller.v      # Testbench for simulation
├── sdram_tb.vcd               # Generated waveform dump file
└── README.md                  # Project documentation
```

---

 Pipeline Mechanism

The SDRAM controller uses pipining to improve speed and reduce idle clock cycles.

### Pipeline Stages

### Stage 1 — Request Capture

* Captures `host_req`
* Latches address and control signals
* Stores write data if write request

### Stage 2 — Command Decode

* Determines whether operation is READ or WRITE
* Generates ACTIVE command first

### Stage 3 — SDRAM Execution

* Issues READ / WRITE command
* Handles CAS latency and timing constraints

### Stage 4 — Data Transfer

* For WRITE → sends data to SDRAM
* For READ → receives data from SDRAM through pipeline registers

This improves throughput and ensures better utilization of memory cycles.

---

 FSM States Used

The controller uses the following states:

| State         | Description           |
| ------------- | --------------------- |
| `S_INIT_WAIT` | Initial power-up wait |
| `S_INIT_PRE`  | Precharge all banks   |
| `S_INIT_REF1` | First refresh         |
| `S_INIT_REF2` | Second refresh        |
| `S_INIT_MRS`  | Load mode register    |
| `S_IDLE`      | Wait for host request |
| `S_REFRESH`   | Auto refresh          |
| `S_ACTIVE`    | Row activation        |
| `S_READ`      | Read operation        |
| `S_WRITE`     | Write operation       |

---

 Testbench Verification

The testbench verifies:

* Reset functionality
* SDRAM initialization sequence
* Write transaction
* Read transaction
* Holding `host_req` until `host_ack`
* Proper `host_rdata_valid` generation
* Correct read data verification
* FSM returning to IDLE state
* Timeout protection for simulation safety

### Verified Example

### WRITE Operation

```text
Address = 24'h000100
Write Data = 16'hABCD
```

### READ Operation

```text
Address = 24'h000100
Expected Read Data = 16'hABCD
```

### Result

```text
PASS: data matches
```

---

 Simulation Tools Used

* **Icarus Verilog**
* **GTKWave**
* **VS Code**
* **GitHub**

---
 Simulation Commands

### Compile

```bash
iverilog -o sdram_tb tb_sdram_controller.v sdram_controller.v
```

### Run Simulation

```bash
vvp sdram_tb
```

### Open Waveform

```bash
gtkwave sdram_tb.vcd
```

---

 GTKWave Simulation Output

The following waveform confirms successful:

* Reset release
* Write request
* Read request
* Host acknowledge generation
* Read data valid signal
* Correct SDRAM command sequencing

### Screenshot

![GTKWave Simulation Output](<img width="1920" height="1080" alt="simulation_output" src="https://github.com/user-attachments/assets/3ab8943e-c103-441c-abad-86e26a23ca37" />
)

```text
simulation_output.png
```



 Applications

This project is useful in:

* FPGA Memory Controllers
* Embedded Systems
* High-Speed Buffering Systems
* Processor-to-Memory Interfaces
* Communication Systems
* Digital Signal Processing
* Computer Architecture Projects

---

 Future Improvements

Possible future upgrades:

* Burst Read / Burst Write support
* Multi-bank optimization
* DDR SDRAM Controller extension
* AXI / APB interface support
* ECC (Error Correction Code)
* Advanced refresh scheduling
* Performance optimization for higher frequency designs

---

 Author

**Abhinav Pilli**

B.Tech Project
Verilog HDL Design
Pipelined SDRAM Controller

---

 License

This project is intended for academic and educational purposes.

---

```
```
