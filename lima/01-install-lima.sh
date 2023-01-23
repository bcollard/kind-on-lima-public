arch=$(uname -m)

read -p "enter Lima version to install: " VERSION

curl -L -O https://github.com/lima-vm/lima/releases/download/v${VERSION}/lima-${VERSION}-Darwin-${arch}.tar.gz
tar xvfz lima-${VERSION}-Darwin-${arch}.tar.gz
echo "version ${VERSION} installed under ./bin"

./bin/limactl --version