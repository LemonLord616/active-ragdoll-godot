# Project notes for Codex

- After starting a Godot process for a test or render, verify that it exits when the command finishes. The workspace sandbox may not show host Godot processes, so inspect the host process list (for example, `ps aux | grep godot`) outside the sandbox. Do not treat the grep or Codex command lines as Godot processes. If one of your test processes remains, stop that specific process and verify it is gone.
