# re-toolkit

Headless reverse-engineering helpers built on the Ghidra in this repository.

```sh
re-toolkit/setup.sh                 # build Ghidra from source, install to /opt/ghidra-dev (~15 min, once)
re-toolkit/re.sh <binary> [out_dir] # analyze + decompile, write a report
```

The report directory contains:

| File | Contents |
|---|---|
| `summary.txt` | format, language, SHA-256, function counts, entry points |
| `decompiled.c` | every non-library function, decompiled |
| `imports.txt` | external functions the binary calls |
| `strings.txt` | defined strings (4+ chars) with addresses |
| `ghidra.log` | full headless analyzer log |

`scripts/Report.java` also creates functions at labeled code that auto-analysis left outside any
function, such as `main` when it is only referenced as the pointer passed to `__libc_start_main`.

`setup.sh` targets the Claude Code cloud container; see the comments at its top for the network
workarounds it applies.
