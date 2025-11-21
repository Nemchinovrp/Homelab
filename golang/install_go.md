cd /tmp
wget https://go.dev/dl/go1.24.0.linux-amd64.tar.gz

sudo tar -C /usr/local -xzf go1.24.0.linux-amd64.tar.gz

echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc

source ~/.bashrc

go version
