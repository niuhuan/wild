## 問題與解決方案

### 問題背景
在台灣環境執行 `wild`（Flutter + Rust 桌面應用）登入帳密時，驗證碼圖片（captcha）不顯示，只出現轉圈圈。  
驗證碼 API 來自 `https://www.wenku8.net/checkcode.php`，該站有 Cloudflare 防護機制（JS 挑戰），在缺少必要 Header / Cookie 或未初始化 Session 時會返回 HTML 而非圖片。

---

### 問題原因
- Rust 端 `checkcode()` 方法直接發送 GET 請求，未攜帶必要的 HTTP 標頭與 Cookie。
- 請求前沒有先建立與伺服器的 Session（未取得 PHPSESSID 與可能的 Cloudflare Token）。
- Cloudflare 攔截時會回傳 HTML 挑戰頁，導致前端無法顯示圖片。

---

### 解決方案

#### 1. 啟用 Cookie 支援
在 `Cargo.toml` 調整 `reqwest` 依賴：
```
toml
reqwest = { version = "0.12", default-features = false, features = ["cookies", "gzip", "brotli", "deflate", "rustls-tls", "http2"] }

```
#### 2. 新增統一請求標頭方法
建立 default_headers_sync()，加上：

- User-Agent
- Referer
- Accept
- Accept-Language
- Connection

#### 3. 初始化 Session
新增 init_session()，先對 /login.php 發 GET，取得初始 Cookie。


#### 4. 改寫 checkcode() 流程

1. 呼叫 init_session() 建立 Session。

2. 發送請求至 /checkcode.php，攜帶完整標頭與 Cookie。

3. 檢查回應 Content-Type：
     - image/* → 回傳圖片二進位資料。
    - text/html 且包含 Cloudflare 挑戰字樣（__cf_chl_、Just a moment 等）→ 回傳 cf_challenge 讓前端處理。

4. 修正 Rust E0505 借用衝突：先複製標頭值再讀取 bytes()。

#### 5. Cloudflare 挑戰處理（前端）
收到 cf_challenge 時，可在前端啟動 WebView2 載入 wenku8 1–3 秒，讓 JS 完成挑戰並取得 cf_clearance，再重試抓取驗證碼。



#### 關鍵點
在請求驗證碼前，必須先初始化 Session，攜帶完整 HTTP 標頭與 Cookie，並針對 Cloudflare 挑戰頁進行檢測與處理。