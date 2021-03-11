sudo apt install build-essential;
sudo apt-get install tmux htop zsh git;

#for brave-browser
sudo apt install apt-transport-https curl gnupg;
curl -s https://brave-browser-apt-beta.s3.brave.com/brave-core-nightly.asc | sudo apt-key --keyring /etc/apt/trusted.gpg.d/brave-browser-prerelease.gpg add -;
echo "deb [arch=amd64] https://brave-browser-apt-beta.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-beta.list;
sudo apt update;
sudo apt install brave-browser-beta;

chsh -s $(which zsh)