if hyprctl getoption debug:overlay | grep -q 1; then
  hyprctl keyword debug:overlay false
else
  hyprctl keyword debug:overlay true
fi
