sudo apt-get install build-essential tmux htop zsh git make g++;

#for brave-browser
sudo apt install apt-transport-https curl gnupg;
curl -s https://brave-browser-apt-beta.s3.brave.com/brave-core-nightly.asc | sudo apt-key --keyring /etc/apt/trusted.gpg.d/brave-browser-prerelease.gpg add -;
echo "deb [arch=amd64] https://brave-browser-apt-beta.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-beta.list;
sudo apt update;
sudo apt install brave-browser-beta;

chsh -s $(which zsh)
sudo apt update
sudo apt upgrade