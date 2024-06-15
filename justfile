set dotenv-load

[private]
default:
    @just --list --unsorted

[private]
alias flash := flash-firmware
[private]
alias rosbot := start-rosbot
[private]
alias pc := start-pc
[private]
alias simulation := start-simulation
[private]
alias teleop := run-teleop

[private]
pre-commit:
    #!/bin/bash
    if ! command -v pre-commit &> /dev/null; then
        pip install pre-commit
        pre-commit install
    fi
    pre-commit run -a


# Copy repo content to remote host with 'rsync' and watch for changes
sync hostname="${ROBOT_NAMESPACE}" password="husarion": _install-rsync _run-as-user
    #!/bin/bash
    mkdir -m 775 -p maps
    sshpass -p "{{password}}" rsync -vRr --exclude='.git/' --exclude='maps/' --delete ./ husarion@{{hostname}}:/home/husarion/${PWD##*/}
    while inotifywait -r -e modify,create,delete,move ./ --exclude='.git/' --exclude='maps/' ; do
        sshpass -p "{{password}}" rsync -vRr --exclude='.git/' --exclude='maps/' --delete ./ husarion@{{hostname}}:/home/husarion/${PWD##*/}
    done

# flash the proper firmware for STM32 microcontroller in ROSbot XL
flash-firmware: _install-yq _run-as-user
    #!/bin/bash
    echo "Stopping all running containers"
    docker ps -q | xargs -r docker stop

    echo "Flashing the firmware for STM32 microcontroller in ROSbot"
    docker run \
        --rm -it \
        --device /dev/ttyUSBDB \
        --device /dev/bus/usb/ \
        $(yq .services.rosbot.image compose.yaml) \
        flash-firmware.py -p /dev/ttyUSBDB
        # ros2 run rosbot_xl_utils flash_firmware --port /dev/ttyUSBDB

# start containers on a physical ROSbot XL
start-rosbot: _run-as-user
    #!/bin/bash
    docker compose down
    docker compose pull
    docker compose up

# start containers on PC
start-pc: _run-as-user
    #!/bin/bash
    xhost +local:docker
    docker compose -f compose.pc.yaml up

# start containers on a physical ROSbot XL
start-simulation: _run-as-user
    #!/bin/bash
    xhost +local:docker
    docker compose -f compose.sim.gazebo.yaml down
    docker compose -f compose.sim.gazebo.yaml pull
    docker compose -f compose.sim.gazebo.yaml up

# run teleop_twist_keybaord (host)
run-teleop:
    #!/bin/bash
    . .env.local
    ros2 run teleop_twist_keyboard teleop_twist_keyboard # --ros-args -r __ns:=/${ROBOT_NAMESPACE}

_run-as-root:
    #!/bin/bash
    if [ "$EUID" -ne 0 ]; then
        echo -e "\e[1;33mPlease re-run as root user to install dependencies\e[0m"
        exit 1
    fi

_run-as-user:
    #!/bin/bash
    if [ "$EUID" -eq 0 ]; then
        echo -e "\e[1;33mPlease re-run as non-root user\e[0m"
        exit 1
    fi

_install-rsync:
    #!/bin/bash
    if ! command -v rsync &> /dev/null || ! command -v sshpass &> /dev/null || ! command -v inotifywait &> /dev/null; then
        if [ "$EUID" -ne 0 ]; then
            echo -e "\e[1;33mPlease run as root to install dependencies\e[0m"
            exit 1
        fi
        apt install -y rsync sshpass inotify-tools
    fi

_install-yq:
    #!/bin/bash
    if ! command -v /usr/bin/yq &> /dev/null; then
        if [ "$EUID" -ne 0 ]; then
            echo -e "\e[1;33mPlease run as root to install dependencies\e[0m"
            exit 1
        fi

        YQ_VERSION=v4.35.1
        ARCH=$(arch)

        if [ "$ARCH" = "x86_64" ]; then
            YQ_ARCH="amd64"
        elif [ "$ARCH" = "aarch64" ]; then
            YQ_ARCH="arm64"
        else
            YQ_ARCH="$ARCH"
        fi

        curl -L https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${YQ_ARCH} -o /usr/bin/yq
        chmod +x /usr/bin/yq
        echo "yq installed successfully!"
    fi


# source ROS 2 workspace
config:
    #!/bin/bash
    RULE='ACTION=="add", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6014", SYMLINK+="ttyMANIPULATOR"'

    # Define the udev rules directory and the file to store the rule
    UDEV_RULES_DIR="/etc/udev/rules.d"
    UDEV_RULES_FILE="99-local.rules"

    # Check if the rule already exists
    if grep -q "$RULE" "$UDEV_RULES_DIR/$UDEV_RULES_FILE"; then
        echo "Rule already exists, no action taken."
    else
        echo "Adding udev rule."
        echo "$RULE" | sudo tee -a "$UDEV_RULES_DIR/$UDEV_RULES_FILE"
        # Reload udev rules
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        echo "udev rule added and reloaded."
    fi
