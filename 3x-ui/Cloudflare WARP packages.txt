Cloudflare WARP packages
Cloudflare's client-side software can be installed on Linux with package managers APT or YUM by following these instructions. However, keep in mind that not all packages may support all operating systems or architectures and that you can check a specific package's page (linked from the homepage) to see what's available. We generally support modern versions of the following distributions:
•	Ubuntu
•	Debian
•	Red Hat Enterprise Linux & CentOS
Ubuntu
The supported releases are:
•	Noble (24.04)
•	Jammy (22.04)
•	Focal (20.04)
Older builds exist for:
•	Bionic (18.04)
•	Xenial (16.04)

# Add cloudflare gpg key
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg


# Add this repo to your apt repositories
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list


# Install
sudo apt-get update && sudo apt-get install cloudflare-warp


---------------------------------
Debian
The supported releases are:
•	Bookworm (12)
•	Bullseye (11)
•	Buster (10)
Older builds exist for:
•	Stretch (9)
# Add cloudflare gpg key
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg


# Add this repo to your apt repositories
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list


# Install
sudo apt-get update && sudo apt-get install cloudflare-warp


-------------------------------------
		
warp-cli registration new
warp-cli mode proxy
warp-cli connect

проверка запуска прокси warp
netstat -tulnp

curl --proxy socks5h://127.0.0.1:40000 https://ifconfig.me
