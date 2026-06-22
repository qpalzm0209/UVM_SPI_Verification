# UVM SPI Verification

## 프로젝트 개요

SPI Master/Slave와 128 x 8-bit 메모리를 구현하고, 주소 기반 read/write 통신을 UVM testbench로 검증한 프로젝트입니다.
Master는 `SCLK`, `MOSI`, `MISO`, `SS` 신호로 Slave에 command와 데이터를 전송하며, CPOL/CPHA 파라미터로 SPI timing mode를 설정할 수 있습니다.
[발표자료 PDF](https://drive.google.com/file/d/15UOciy35ZHzkBzh2YRFDWcRITzPA8Ij-/view?usp=drive_link)

## 목표 동작

- Master는 `SS`를 활성화한 뒤 `주소[6:0] + mode[0]` 형식의 8-bit command를 전송합니다.
- Write 모드(`mode=1`)에서는 MOSI로 전송한 8-bit 데이터를 선택한 메모리 주소에 저장합니다.
- Read 모드(`mode=0`)에서는 선택한 메모리 주소의 8-bit 데이터를 Slave가 MISO로 반환하고, Master가 수신합니다.
- Slave 메모리는 128개의 8-bit word로 구성되며 reset 시 모든 위치를 `0x00`으로 초기화합니다.
- 한 transaction은 `SS` assertion, command 전송, read/write data 전송, `SS` deassertion 순서로 처리합니다.

검증 환경에서는 위 동작을 transaction 단위로 확인합니다.

- SPI transaction을 sequence item으로 정의합니다.
- Driver가 SPI 입력 조건과 전송 데이터를 생성합니다.
- Monitor가 MOSI/MISO/SCLK/SS 흐름을 관찰하고 transaction으로 복원합니다.
- Scoreboard에서 기대값과 실제 수신값을 비교합니다.
- Full sweep test로 128개 전 주소에 `0x00`, `0x0F`, `0xF0`, `0xFF`를 write/read하여 총 512개 write와 512개 read를 확인합니다.

## 기술 스택

| 구분 | 내용 |
| --- | --- |
| 핵심 개념 | UVM, SPI, sequence, driver, monitor, scoreboard, full sweep test |
| 검증 대상 | SPI Master/Slave 기반 128 x 8-bit memory read/write transaction |
| 사용 언어 | SystemVerilog |
| 사용 도구 | UVM 1.2 기반 simulator, Verdi/파형 디버깅 환경 |

## 시스템 구조

```text
spi_tb_top
├─ spi_master_slave_top
├─ spi_if
└─ spi_env
   ├─ spi_agent
   │  ├─ spi_sequencer
   │  ├─ spi_driver
   │  └─ spi_monitor
   └─ spi_scoreboard

spi_base_test
└─ spi_full_sweep_test
```

- `spi_seq_item`: SPI command/data transaction을 정의합니다.
- `spi_base_sequence`: 기본 SPI 전송 stimulus를 생성합니다.
- `spi_driver`: transaction을 SPI 신호로 구동합니다.
- `spi_monitor`: SPI line을 관찰해 전송 결과를 수집합니다.
- `spi_scoreboard`: 송신/수신 데이터 정합성을 확인합니다.
- `spi_env`: agent와 scoreboard를 연결한 검증 환경입니다.

## 검증 방식

- SPI line의 bit-level timing과 transaction-level 결과를 함께 확인합니다.
- Full sweep sequence로 단일 케이스가 아닌 반복 패턴 검증을 수행합니다.
