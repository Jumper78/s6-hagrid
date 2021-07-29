hagrid_version := '90356ddb282874d5be5f7406e49e203f3caf437c'

build v=hagrid_version:
  #!/bin/bash
  ver=$(echo {{v}} | cut -c 1-8)

  docker build . \
    -t "andrewzah/hagrid:${ver}"
