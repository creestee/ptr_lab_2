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