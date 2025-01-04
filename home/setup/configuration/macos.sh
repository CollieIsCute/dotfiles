# if fish is not in /etc/shells, add it
if ! grep -q "fish" /etc/shells; then
	echo "Adding fish to /etc/shells..."
	echo "/opt/homebrew/bin/fish" | sudo tee -a /etc/shells
end
# if $SHELL is not fish, then change default shell to fish
if test "$SHELL" != "/opt/homebrew/bin/fish"
    echo "Changing default shell to fish..."
    chsh -s /opt/homebrew/bin/fish
end
echo -e "$GREEN""Please log out and log in again to make fish shell work""$NC"
