```mermaid
sequenceDiagram
    Server-->SSE_Client: SSE Streams
    SSE_Client-->Load_Balancer: SSE Json ncoded data
    Load_Balancer-->Printer: SSE Json encoded data
    Printer-->Tweet_Analyzer: Parsed Json
    PoolManager-->PoolManager: Checking Workers status
```