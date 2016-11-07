#!/usr/bin/python
# -*- coding: utf-8 -*-
# Title: win_wait_for.ps1
# Author: Paul Northrop (GitHub: @sukpan), SAS Institute, Inc. (GitHub: @sassoftware)
#
# Purpose: To mimic the core ansible module "wait_for" on Windows platforms
#
#
# Copyright (c) 2016 SAS Institute, Inc.
#
# This module is licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ------------------------------------------------------
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.



DOCUMENTATION = '''
---
module: win_wait_for
version_added: "2.3"
description:
  - You can wait for a set amount of time C(timeout), this is the default if nothing is specified.
  - Waiting for a port to become available is useful for when services are not immediately available after their init scripts return which is true of certain Java application servers. 
  - This module can also be used to wait for a regex match a string to be present in a file.
  - This module can also be used to wait for a file to be available or absent on the filesystem.
  - This module can also be used to wait for active connections to be closed before continuing, useful if a node is being rotated out of a load balancer pool.
options:
  host:
    description:
      - A resolvable hostname or IP address to wait for
    required: false
    default: "127.0.0.1"
  timeout:
    description:
      - maximum number of seconds to wait for
    required: false
    default: 300
  connect_timeout:
    description:
      - maximum number of seconds to wait for a connection to happen before closing and retrying
    required: false
    default: 5
  delay:
    description:
      - number of seconds to wait before starting to poll
    required: false
    default: 0
  port:
    description:
      - port number to poll
    required: false
  state:
    description:
      - either C(present), C(started), or C(stopped), C(absent), or C(drained)
      - When checking a port C(started) will ensure the port is open, C(stopped) will check that it is closed, C(drained) will check for active connections
      - When checking for a file or a search string C(present) or C(started) will ensure that the file or string is present before continuing, C(absent) will check that file is absent or removed
    choices: [ "present", "started", "stopped", "absent", "drained" ]
    default: "started"
  path:
    required: false
    description:
      - path to a file on the filesytem that must exist before continuing
  search_regex:
    required: false
    description:
      - Can be used to match a string in a file. Defaults to a multiline regex.
  exclude_hosts:
    required: false
    description:
      - comma separated list or array of hosts or IPs to ignore when looking for active TCP connections for C(drained) state
  sleep:
    required: false
    default: 1
    description:
      - Number of seconds between each poll
notes:
  - Cannot match a string in a socket connection.
  - I(delay) parameter MUST be less than I(timeout) parameter or an error will be thrown
  - When I(path) or I(name) is not provided, the I(delay) parameter is ignored so the total wait time is I(timeout).
  - I(search_regex) cannot be used when reading from a socket. This may be added in a later release.
requirements: []
author:
    - "Paul Northrop (@sukpan)"
    - "Acknowledgement: wait_for: Jeroen Hoekx (@jhoekx)"
    - "Acknowledgement: wait_for: John Jarvis (@jarv)"
    - "Acknowledgement: wait_for: Andrii Radyk (@AnderEnder)"
'''

EXAMPLES = '''

# just wait for 30 seconds
- win_wait_for: timeout=30

# just wait for 30 seconds - in this case, delay is ignored
- win_wait_for: timeout=30 delay=20

# wait for a file to exist, timeout after 10 minutes but don't perform first check for 1 minute
- win_wait_for: name='C:\Temp\somefile.txt' timeout=600 state=present delay=60

# wait for a file to be removed, wait 10 seconds between each check and timeout after 30 minutes
- win_wait_for: path='C:\Temp\somefile.txt' timeout=1800 state=absent sleep=10

# wait for a file to contain a line starting with Hello using default timeout of 5 minutes
- win_wait_for: path='C:\Temp\somefile.txt' search_regex='^Hello'

# wait up to 10 minutes for HTTP port (80) to be free
- win_wait_for: timeout=600 port=80 host=localhost state=stopped

'''

RETURN = '''
exclude_hosts:
    description: The exclude_hosts parameter expressed as a comma separated list
    returned: when exclude_hosts is defined
    type: string
    sample: "hosta, hostb"
elapsed:
    description: Time spent in module expressed as number of seconds
    returned: always
    type: int
    sample: 72
port:
    description: The port parameter supplied
    returned: when port is defined
    type: int
    sample: 80
path:
    description: The path parameter supplied
    returned: when path is defined
    type: string
    sample: "C:/SomePath/file.txt"
slept:
    description: The module slept prior to performing any checks
    returned: always
    type: boolean
    sample: True
msg:
    description: Output intrepreted into a concise message.
    returned: when failed
    type: string
    sample: timeout exceeded waiting for C:/SomePath/file.txt to be absent
state:
    description: The requested state, or default value.
    returned: always
    type: string
    sample: present
failed:
    description: Whether or not the operation failed.
    returned: always
    type: bool
    sample: False
changed:
    description: Whether or not any changes were made.
    returned: always
    type: bool
    sample: False
'''