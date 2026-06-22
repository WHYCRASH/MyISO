## 2024-05-14 - Bash String Manipulation vs External Commands
**Learning:** Using `echo | cut` and `echo | grep` inside a loop in bash is significantly slower due to the overhead of spawning subshells and external processes for every iteration.
**Action:** Use native bash parameter expansion (e.g., `${var#prefix}`, `${var%%suffix}`) and bash regular expression matching (`[[ $var =~ $regex ]]`) to avoid subshells in loops. This reduced processing time from ~5.5s to ~0.01s for 600 items.

## 2024-06-22 - Python Subshells vs Native Libraries
**Learning:** Using `os.system` with external shell commands (like `find` and `chown`) for directory traversal and file manipulation is significantly slower due to the overhead of spawning subshells and external processes. A quick benchmark showed a time reduction from ~0.027s to ~0.007s when replacing three `os.system` calls with native Python `os.walk`, `os.chown`, and `os.chmod` for 1000 files.
**Action:** For directory traversal and file manipulation in Python scripts, prefer using native Python libraries (e.g., `os.walk`, `os.chmod`, `os.chown`) instead of shelling out to external utilities via system calls to eliminate subshell spawn overhead and improve performance.
