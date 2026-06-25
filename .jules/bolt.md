## 2024-05-14 - Bash String Manipulation vs External Commands
**Learning:** Using `echo | cut` and `echo | grep` inside a loop in bash is significantly slower due to the overhead of spawning subshells and external processes for every iteration.
**Action:** Use native bash parameter expansion (e.g., `${var#prefix}`, `${var%%suffix}`) and bash regular expression matching (`[[ $var =~ $regex ]]`) to avoid subshells in loops. This reduced processing time from ~5.5s to ~0.01s for 600 items.
## 2024-05-15 - Python Native Directory Traversal vs External Subprocesses
**Learning:** Shelling out to external utilities like `find` via `os.system` or `subprocess` within Python scripts introduces significant overhead due to subshell spawning and external process execution. This is especially true when performing multiple independent `find` calls on the same directory tree.
**Action:** Use native Python libraries like `os.walk` or `os.scandir` combined with `os.chmod`, `os.chown`, etc., to traverse directories in a single pass and eliminate subprocess overhead. This reduces execution time and improves cross-platform compatibility.
## 2026-06-25 - Consolidating os.walk for Permissions and Ownership
**Learning:** Performing multiple independent file tree operations (e.g. `os.system('chown -R')` followed by a native `os.walk` for `chmod`) causes redundant I/O and unnecessary subshell spawns.
**Action:** Combine `os.chown` and `os.chmod` operations into a single native Python `os.walk` loop to perform all file metadata modifications in a single pass.
