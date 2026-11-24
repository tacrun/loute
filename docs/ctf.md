# CTF / Lab Arena

CTF is a first-class phase (§10.11), not a reduced mode. While an arena workspace
is active, all other phases remain fully available. 15 CTF capabilities cover web,
pwn, reversing, crypto, forensics, stego, OSINT, binary triage, scoreboard, evidence
capture and lab reset (`ctf.lab-reset`).

The `ArenaScreen` (`/arena`) presents challenge cards, flag input, hint ladder,
score clock and `ctf/flag-patterns` regex scanning of artifacts (`flag-hunt`).

`ctf_lab_reset` and `persistence_cleanup`/`exploit_cleanup` are first-class cleanup
capabilities supporting the reversibility doctrine (§5.5/§13.5).
