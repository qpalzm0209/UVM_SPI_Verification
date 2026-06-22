# UVM SPI Verification

## 프로젝트 개요

SPI Master/Slave 구조를 UVM testbench로 검증한 프로젝트입니다.
SPI transaction을 모델링하고 full sweep sequence를 사용해 여러 전송 조합을 확인합니다.  
**발표자료 PDF : https://drive.google.com/file/d/15UOciy35ZHzkBzh2YRFDWcRITzPA8Ij-/view?usp=drive_link**

## 목표 동작

- SPI transaction을 sequence item으로 정의합니다.
- Driver가 SPI 입력 조건과 전송 데이터를 생성합니다.
- Monitor가 MOSI/MISO/SCLK/CS 흐름을 관찰하고 transaction으로 복원합니다.
- Scoreboard에서 기대값과 실제 수신값을 비교합니다.
- Full sweep test로 여러 데이터 패턴과 전송 조건을 확인합니다.

## 기술 스택

| 구분 | 내용 |
| --- | --- |
| 핵심 개념 | UVM, SPI, sequence, driver, monitor, scoreboard, full sweep test |
| 검증 대상 | SPI master/slave top, SPI memory/slave |
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
