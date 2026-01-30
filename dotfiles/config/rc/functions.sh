jdk() {
  # Function to change current java version
  # check if argument is provided
  if [ -z "$1" ]; then
    echo "Usage: jdk <version>"
    echo "Available versions:"
    archlinux-java status | grep -oP '(?<=Installed JDKs: ).*' | tr ' ' '\n'
    return 1
  fi

  # check if version is valid
  if ! archlinux-java status | grep -q "$1"; then
    __install_jdk "$1"
    if [ $? -ne 0 ]; then
      return 1
    fi

  fi

  # set java version
  sudo archlinux-java set "java-$1-openjdk"
  echo "Java version set to $1"

}

__install_jdk() {
  # Function to install a ajva version
  pacman -Ss "jdk$1-openjdk" >/dev/null
  if [ $? -ne 0 ]; then
    echo "Error: Java version '$1' is not available in the repositories."
    return 1
  fi

  # If java version exists, ask for permission to install
  echo "Java version '$1' is not installed."
  echo "Proceed with instalation (y/n)?"
  read -r response
  if [[ "$response" != "y" ]]; then
    echo "Installation cancelled."
    return 1
  fi

  sudo pacman -S "jdk$1-openjdk"
  if [ $? -eq 0 ]; then
    echo "Java version '$1' installed successfully."
    return 0
  fi

  echo "Error: Failed to install Java version '$1'."
  return 1
}

__verify_package() {
  # Verifies if all input packages are isntalled
  res=0
  for package in "$@"; do
    # Here I won't stop because I would like to see all missing packages
    if ! pacman -Qi "$package" &>/dev/null; then
      echo "Package '$package' is not installed."
      res=1
    fi
  done
  return $res
}
