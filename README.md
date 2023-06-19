# rosbot-xl-manipulation

In this project you can find an example integration of ROSbot XL with [OpenManipulatorX](https://emanual.robotis.com/docs/en/platform/openmanipulator_x/overview/) based on [MoveIt2](https://moveit.picknik.ai/humble/index.html). It includes [servo mode](https://moveit.picknik.ai/humble/doc/examples/realtime_servo/realtime_servo_tutorial.html) configuration, which allows controlling manipulator with a gamepad.

## Quick Start (real robot)

### PC

Clone this repository:

```
git clone https://github.com/husarion/rosbot-xl-manipulation.git
```

**Connect a gamepad to the USB port of your PC/laptop**

Check your configs in the `.env` file:

```
MANIPULATOR_SERIAL=/dev/ttyMANIPULATOR
MANIPULATOR_BAUDRATE=1000000

DDS_CONFIG=DEFAULT
# DDS_CONFIG=HUSARNET_SIMPLE_AUTO

# RMW_IMPLEMENTATION=rmw_fastrtps_cpp
RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

MECANUM=False
```

**Notes:**
- Make sure to add the following line: `ACTION=="add", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6014", SYMLINK+="ttyMANIPULATOR"` to your robot's udev rules, so that manipulator will be available under `/dev/ttyMANIPULATOR`
- Set `MANIPULATOR_BAUDRATE` according to the baud rate that is set in servos (by default this value should be set to 1000000, you can check/change this value in the [Dynamixel Wizard 2.0](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/))
- With `DDS_CONFIG=DEFAULT` your robot and laptop need to be in the same LAN network. If you want to use this demo over the Internet, set `DDS_CONFIG=HUSARNET_SIMPLE_AUTO` and [enable Husarnet on ROSbot XL and your PC](https://husarion.com/manuals/rosbot/remote-access/).

Sync a workspace with ROSbot XL:

```bash
./sync_with_rosbot.sh <ROSbot_XL_IP>
```

Open a new terminal on the PC and run Rviz and gamepad: 

```bash
xhost +local:docker && \
docker compose -f compose.pc.yaml up
```

## ROSbot

> **Firmware version**
>
> Before running the project, make sure you have the correct version of firmware flashed on your robot.
>
> Firmware flashing command (run in the ROSbot's terminal)
>
> ```
> docker run --rm -it --privileged \
> --mount type=bind,source=/dev/ttyUSBDB,target=/dev/ttyUSBDB \
> husarion/rosbot-xl:humble \
> flash-firmware.py -p /dev/ttyUSBDB
> ```

> **Warning**
> 
> After running the following command servos' torque will be turned on, so first lift the manipulator, so it won't be in collision with your robot.


In the ROSbot's terminal execute (in `/home/husarion/rosbot-xl-manipulation` directory):

```bash
docker compose -f compose.rosbot.yaml up
```

## Manipulator control

> Please note that manipulator controls can be changed by editing `joy_servo.yaml` in the config directory. It is also possible to configure ROSbot XL control (`joy2twist.yaml` config).

First make sure that gamepad is in the *Direct Input Mode* (switch in front with letters *D* and *X*, select *D*).

Controls:
 * `RB` - manipulator's dead man's switch
 * `LB` - ROSbot control dead man's switch (with this button pressed you can control ROSbot XL, for specific commands please refer to the documentation of the [joy2twist node](https://github.com/husarion/joy2twist))
 * `Start` - return the manipulator to the Home position
 * `Left Joy` - moving end effector in X/Y directions
 * `Right Joy` - moving end effector in the Z direction (Up/Down) and changing Pitch angle (Left/Right)
 * `Left/Right arrow` - moving joint1 of the manipulator
 * `Up/Down arrow` - moving joint2 of the manipulator
 * `X/B button` - moving joint3 of the manipulator
 * `Y/A` - moving joint4 of the manipulator 
 * `RT` - close gripper
 * `LT` - open gripper

If the manipulator stops moving it could be near collision (may not appear so, because collision bounds are larger than the robot) or singularity. If that happens the easiest option is to press `Start` so that the manipulator will return to the Home position.

Apart from a gamepad, it is also possible to control the manipulator using MoveIt's *MotionPlanning* plugin in the RViz. 

The torque of the manipulator can be turned off by executing the following service call in one of the containers:
```
ros2 service call /controller_manager/set_hardware_component_state \
  controller_manager_msgs/srv/SetHardwareComponentState \
  "{name: 'manipulator', target_state: {id: 0, label: 'inactive'}}"
```

It is not recommended to later turn it on using service, as the last commanded position is remembered and the manipulator will attempt to return to it upon enabling torque. Instead you should restart the container.

## Quick Start (Gazebo simulation)

> **Prerequisites**
>
> The `compose.sim.nvidia.yaml` file uses NVIDIA Container Runtime. Make sure you have NVIDIA GPU and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) installed.
>
> It is also possible to run the simulation without NVIDIA GPU - use the `compose.sim.yaml` file instead, but please note that performance won't be too good, that's why Nvidia configuration is recommended.

Start the containers in a new terminal:

```bash
xhost +local:docker && \
docker compose -f compose.sim.nvidia.yaml up
```

> Collision for the manipulator is disabled in Gazebo Ignition - there aren't any collision models available for OpenManipulatorX, in the official configuration visual meshes are used also for collision, which causes a large drop in the real-time factor of the simulation.

> In simulation servo position control is used instead of velocity (due to a bug, which causes the manipulator to fall just after start). As a result homing manipulator from joy_servo isn't supported.