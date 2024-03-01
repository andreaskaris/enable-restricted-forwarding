## How to run

Run script `apply-machine-config.sh` for each role. The script accepts parameters
in the following order:
```
./apply-machine-config.sh <role name> <if1> <if2> <if3> <...>
```

For example:
```
./apply-machine-config.sh master eno12409.123 eno12409.124
```

The script will also save a backup of the applied MachineConfiguration to directory `_output`.
