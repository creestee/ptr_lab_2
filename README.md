# Project 1: Stream Processing with Actors

## Docker Container
The SSE streams for this lab are available from :

```
docker run --rm -it -p 4000:4000 alexburlacu/rtp-server:faf18x
```

## Supervision Tree

```mermaid
graph TB
    Main_Supervisor-->Load_Balancer
    Main_Supervisor-->SSE_Client_1
    Main_Supervisor-->SSE_Client_2
    Main_Supervisor-->Printer_Supervisor
    Printer_Supervisor-->Printer_1
    Printer_Supervisor-->Printer_2
    Printer_Supervisor-->Printer_3
    Printer_Supervisor-->Tweet_Analyzer
```

## Message Flow Diagram

```mermaid
sequenceDiagram
    Server-->SSE_Client: SSE Streams
    SSE_Client-->Load_Balancer: SSE Json ncoded data
    Load_Balancer-->Printer: SSE Json encoded data
    Printer-->Tweet_Analyzer: Parsed Json
```