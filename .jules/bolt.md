## 2024-05-14 - Bash String Manipulation vs External Commands
**Learning:** Using `echo | cut` and `echo | grep` inside a loop in bash is significantly slower due to the overhead of spawning subshells and external processes for every iteration.
**Action:** Use native bash parameter expansion (e.g., `${var#prefix}`, `${var%%suffix}`) and bash regular expression matching (`[[ $var =~ $regex ]]`) to avoid subshells in loops. This reduced processing time from ~5.5s to ~0.01s for 600 items.
## 2024-05-15 - Python Native Directory Traversal vs External Subprocesses
**Learning:** Shelling out to external utilities like `find` via `os.system` or `subprocess` within Python scripts introduces significant overhead due to subshell spawning and external process execution. This is especially true when performing multiple independent `find` calls on the same directory tree.
**Action:** Use native Python libraries like `os.walk` or `os.scandir` combined with `os.chmod`, `os.chown`, etc., to traverse directories in a single pass and eliminate subprocess overhead. This reduces execution time and improves cross-platform compatibility.

## 2024-06-28 - Secure Native File Traversal Optimization
**Learning:** Shelling out to `chown -R` via `os.system` incurs significant process spawning overhead and forces redundant directory traversals when modifying multiple permissions. However, directly replacing it with Python's native `os.chown` inside an `os.walk` loop introduces a critical Local Privilege Escalation (LPE) vulnerability, as `os.chown` follows symlinks by default whereas GNU `chown -R` does not.
**Action:** When replacing `os.system("chown -R ...")` with native `os.walk` in Python scripts, always use `os.lchown` on files and directories to ensure symlinks are not maliciously followed, preserving the security guarantees of the original subprocess call while eliminating overhead.
