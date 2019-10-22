# Zwave2MQTT
[![Build Status](https://cloud.drone.io/api/badges/LANsible/docker-zwave2mqtt/status.svg)](https://cloud.drone.io/LANsible/docker-zwave2mqtt)
[![Docker Pulls](https://img.shields.io/docker/pulls/lansible/zwave2mqtt.svg)](https://hub.docker.com/r/lansible/zwave2mqtt)
[![Docker Version](https://images.microbadger.com/badges/version/lansible/zwave2mqtt:latest.svg)](https://microbadger.com/images/lansible/zwave2mqtt:latest)
[![Docker Size/Layers](https://images.microbadger.com/badges/image/lansible/zwave2mqtt:latest.svg)](https://microbadger.com/images/lansible/zwave2mqtt:latest)

## Why not use the official container?

It has no arm64 support, this project might make it back upstream :)
This container allows this setup to work flawlessly!

## Test container with docker-compose

```
cd examples/compose
docker-compose up
```

### Building the container locally

You could build the container locally to add plugins. It works like this:

```bash
docker build . \
      --tag lansible/zwave2mqtt:latest
```

## Credits

* [OpenZWave/Zwave2Mqtt](https://github.com/OpenZWave/Zwave2Mqtt)