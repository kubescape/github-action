git clone https://github.com/kubescape/kubescape.git --no-checkout
cd kubescape
export LATEST=$(git describe --tags --abbrev=0)
cd ..
rm -rf kubescape
export CURRENT=$(cat Dockerfile | head -n1 | cut -d':' -f2)
if [ "$LATEST" != "$CURRENT" ]; then
    echo "New version available: $LATEST"
    sed -i "1 s/:${CURRENT}/:${LATEST}/" Dockerfile
else
    echo "No new version available"
fi
