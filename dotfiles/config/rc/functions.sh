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

copy() {

  cat $1 | wl-copy
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

new-java() {
  if [[ $# -ne 2 ]]; then
    echo "Usage: new-java <group_id> <project_name>"
    return 1
  fi

  local group_id="$1"
  local project_name="$2"

  mvn archetype:generate \
    -DgroupId="$group_id" \
    -DartifactId="$project_name" \
    -DarchetypeArtifactId=maven-archetype-quickstart \
    -DarchetypeVersion=1.4 \
    -DinteractiveMode=false
}

open() {

  # iterate over arguments
  for arg in "$@"; do
    zathura "$arg" &
    disown
  done
}
qrcode() {
  qrencode -s 10 -m 2 -o - "$1" | wl-copy --type image/png
}
virtmic() {
  # Create/remove null-sink to route PC output into discord (or other) mic input
  if [[ $# -ne 1 || ("$1" != "start" && "$1" != "stop") ]]; then
    echo "Usage: virtmic start|stop"
    return 1
  fi

  if [[ "$1" == "start" ]]; then
    pactl load-module module-null-sink sink_name=virtmic sink_properties=device.description=VirtMic
    pactl load-module module-remap-source master=virtmic.monitor source_name=virtmic_mic source_properties=device.description=VirtMic-Input
    echo "virtmic up. Move app output -> VirtMic. Discord input -> VirtMic-Input"
    return 0
  fi

  local ids
  ids="$(pactl list short modules | awk '($2=="module-null-sink" && /virtmic/) || ($2=="module-remap-source" && /virtmic_mic/){print $1}')"
  if [[ -z "$ids" ]]; then
    echo "virtmic not running."
    return 1
  fi
  echo "$ids" | while read -r id; do pactl unload-module "$id"; done
  echo "virtmic down"
}

econfig() {
  if [[ $# -ne 1 ]]; then
    echo "Usage: econfig <config_folder>"
    return 1
  fi
  local config_folder="$HOME/installation/dotfiles/config/$1"

  if [[ ! -d "$config_folder" ]]; then
    echo "Error: Config folder '$config_folder' does not exist."
    return 1
  fi

  $EDITOR "$config_folder"
}

poutput() {
  local monitor="$1"

  if ! xrandr --query | grep -q "^${monitor} connected"; then
    echo "poutput: monitor '${monitor}' not connected" >&2
    return 1
  fi

  xrandr --output "$monitor" --primary
  echo "Some apps (e.g steam) need restart"
}
