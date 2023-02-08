# rosbot-xl-manipulation

Example integration of ROSbot XL with [OpenManipulatorX](https://emanual.robotis.com/docs/en/platform/openmanipulator_x/overview/), with a [MoveIt2](https://moveit.picknik.ai/humble/index.html) along servo mode configuration, which allows to control manipulator with a joystick.

## Quick Start (real robot)

### PC

Clone this repository:

```
git clone https://github.com/husarion/rosbot-xl-manipulation.git
```

**Connect a gamepad to USB port of your PC/laptop**

Check your configs in `.env` file:

```
MANIPULATOR_SERIAL=/dev/ttyUSB0
MANIPULATOR_BAUDRATE=1000000

DDS_CONFIG=DEFAULT
# DDS_CONFIG=HUSARNET_SIMPLE_AUTO

# RMW_IMPLEMENTATION=rmw_fastrtps_cpp
RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

MECANUM=False
```

**Notes:**
- Usually MANIPULATOR is listed under `/dev/ttyUSB0`, but verify it with `ls -la /dev/ttyUSB*` command.
- Set `MANIPULATOR_BAUDRATE` according to baudrate that is set in servos (by default this value should be set to 1000000, you can check/change this value in the [Dynamixel Wizard 2.0](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/))
- With `DDS_CONFIG=DEFAULT` your robot and laptop need to be in the same LAN network. If you want to use this demo over the Internet, set `DDS_CONFIG=HUSARNET_SIMPLE_AUTO` and [enable Husarnet on ROSbot XL and you PC](https://husarion.com/manuals/rosbot/remote-access/).

Sync a workspace with ROSbot XL:

```bash
./sync_with_rosbot.sh <ROSbot_XL_IP>
```

Open new terminal on PC and run Rviz and gamepad: 

```bash
xhost +local:docker && \
docker compose -f compose.pc.yaml up
```

## ROSbot

> **Firmware version**
>
> Before running the project, make sure you have the correct version of a firmware flashed on your robot.
>
> Firmware flashing command (run in the ROSbot's terminal)
>
> ```
> docker run --rm -it --privileged \
> husarion/rosbot-xl-manipulation:humble \
> flash-firmware.py -p /dev/ttyUSB0
> ```

In the ROSbot's terminal execute (in `/home/husarion/rosbot-xl-manipulation` directory):

```bash
docker compose -f compose.rosbot.yaml up
```

## Manipulator control

> Please note that manipulator controls can be changed by editing `joy_servo.yaml` in the config directory. It is also possible to configure ROSbot XL control (`joy2twist.yaml` config).

First make sure that joystick is in the DirectInput Mode (switch in front with letters D and X, select D).

Controls:
 * `RB` - manipulator dead man's switch \
 * `LB` - ROSbot control dead man's switch (with this button pressed you can control ROSbot XL, for specific command please refer to documentation of [joy2twist node](https://github.com/husarion/joy2twist)) \
 * `Start` - move manipulator to Home position \
 * `Left Joy` - moving end effector in X/Y directions \
 * `Right Joy` - moving end effector in Z direction (Up/Down) and changing Pitch angle (Left/Right) \
 * `Left/Right arrow` - moving joint1 of manipulator \
 * `Up/Down arrow` - moving joint2 of manipulator \
 * `X/B button` - moving joint3 of manipulator \
 * `Y/A` - moving joint4 of manipulator \
 * `RT` - close gripper \
 * `LT` - open gripper

If manipulator stops moving it could be that it is near collision (may not appear so, because collision bounds are larger than robot) or singularity. If that happens the easiest option is to press `Start` so that manipulator will return to Home position.

Apart from joystick, it is also possible to control manipulator using MoveIt MotionPlanning plugin in the RViz. 

Torque of the manipulator can be turned off by executing following service call in one of the containers:
```
ros2 service call /controller_manager/set_hardware_component_state controller_manager_msgs/srv/SetHardwareComponentState "{name: 'manipulator', target_state: {id: 0, label: 'inactive'}}"
```
Later it can be turned on likewise, only labal should be changed to `active`.

## Quick Start (Gazebo simulation)

> **Prerequisites**
>
> The `compose.sim.nvidia.yaml` file uses NVIDIA Container Runtime. Make sure you have NVIDIA GPU and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) installed.
>
> It is also possible to run simulation without NVIDIA GPU - use `compose.sim.yaml` file instead, but please note that performance won't be too good, that's why nvidia configuration is recomended.

Start the containers in a new terminal:

```bash
xhost +local:docker && \
docker compose -f compose.sim.nvidia.yaml up
```

> Collision for manipulator is disabled in Gazebo Ignition - there aren't any collision models available for OpenManipulatorX, in the official configuration visual meshes are used also for collision, which causes large drop in real time factor of the simulation.
> In simulation servo position control is used instead of velocity (due to bug, which causes manipulator to fall down just after start). As a result homing manipulator from joy_servo isn't supported.