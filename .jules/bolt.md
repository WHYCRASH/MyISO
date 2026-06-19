## 2024-05-14 - Bash String Manipulation vs External Commands
**Learning:** Using `echo | cut` and `echo | grep` inside a loop in bash is significantly slower due to the overhead of spawning subshells and external processes for every iteration.
**Action:** Use native bash parameter expansion (e.g., `${var#prefix}`, `${var%%suffix}`) and bash regular expression matching (`[[ $var =~ $regex ]]`) to avoid subshells in loops. This reduced processing time from ~5.5s to ~0.01s for 600 items.
