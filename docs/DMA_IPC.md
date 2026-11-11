# Project130 DMA and host-service contract

## 1. Ownership rule

The ATM host owns the physical world. NeoGS has no direct access to external ATM devices or physical ATM ports. All external-world exchange is mediated by the ATM host through DMA.

Guest x86 IN/OUT instructions operate on a software virtual I/O bus. A virtual device may enqueue a host-service request; it may not execute a physical ATM IN/OUT instruction itself.

## 2. Transport roles

- DMA carries request, response, event, debug and bulk payload bytes.
- A small control/status handshake may announce a request, signal completion or report readiness.
- The legacy byte channel is not a payload transport for service messages, debug text, keyboard events or video frames.
- ATM code must not access NeoGS-local DMA registers directly.

The Project126 reference identifies the ATM-visible NeoGS control/status interface at #BB and legacy compatibility registers at #B3/#33, with DMA payload transfer through the ZX DMA window. These register details must be verified against the target emulator/hardware and Project129's working host-side procedures before they are encoded in Project130 drivers.

## 3. DMA transaction requirements

Every transaction must define:

- direction and owner;
- buffer address and byte length;
- message type, version and sequence number;
- payload format and endianness;
- integrity check (CRC where required);
- timeout and cancellation behavior;
- completion/error status;
- buffer ownership and lifetime.

All waits are bounded. Every success and error path must leave DMA disabled or in a documented idle state. Validate lengths before accessing buffers, validate message identifiers/version, and reject malformed or stale responses.

## 4. Host-service API

Initial service families (not yet implemented):

- keyboard/input;
- block storage;
- clock/time;
- video/frame presentation;
- diagnostics;
- configuration and capabilities.

Each service has a request/response ABI. The ATM host performs physical work; NeoGS receives only the result bytes/status.

## 5. Video transport

Video frames are bulk DMA payloads, not control-channel byte streams. The frame descriptor, pixel format, stride, dimensions, slot ownership, fragmentation and CRC rules must be finalized before implementation. Project126's double-buffer/frame ABI is a proposal, not a completed or hardware-validated Project130 interface.
