
Quick Summary
Component	Purpose	Example Port
Listener Port	Port on which ALB listens for traffic	80 or 443
Target Group Port	Port on which your EC2/containers/app listens	3000, 8080, etc.

# 4-tier-project

 Setup Should Be:
🔹 Backend Application
Listens on: port 3000

🔹 Target Group (for backend)
Port: 3000 (because the app listens on this)

🔹 Load Balancer Listener
Port: 80 (for HTTP) or 443 (for HTTPS)

🔹 Nginx Frontend Proxy Configuration
If your frontend uses Nginx to proxy requests to the backend:

location /api {
    proxy_pass http://<BACKEND-ALB-DNS>:80;  # Use 80, not 3000

request flow 

Frontend → NGINX → Backend ALB:80 → Target Group → EC2:3000
