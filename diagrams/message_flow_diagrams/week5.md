```mermaid
sequenceDiagram
    Server-->SSE_Client: SSE Streams
    SSE_Client-->Load_Balancer: SSE Json ncoded data
    Load_Balancer-->Worker: SSE Json encoded data
    Worker-->Tweet_Analyzer: Tweets
    Worker-->Batcher: Redacted Tweets
    PoolManager-->PoolManager: Checking Workers status
```