```mermaid
sequenceDiagram
    Server-->SSE_Client: SSE Streams
    SSE_Client-->Printer: SSE Json encoded data
    Printer-->Tweet_Analyzer: Parsed Json
```