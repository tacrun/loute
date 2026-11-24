# CTF Mode

CTF is one of the eleven catalog phases. It means using LOUTE to analyze and
solve capture-the-flag challenges with the same argv-only engine used for every
other phase. It does not build labs, generate challenges, or host a competition.

The catalog ships 15 CTF capabilities across web, pwn, reversing, crypto,
forensics, stego, OSINT, binary triage and flag hunting. Select `CTF` in the
sidebar, choose a capability, pick an action and sub-action, supply the
challenge artifact or target, and press Execute.

Flag hunting uses the `ctf/flag-patterns` wordlist to scan artifacts for
candidate flags. The `ctf_flag_format` input accepts a custom pattern when a
challenge uses a nonstandard flag format.

All CTF sub-actions preserve provenance and catalog identity exactly like
engagement work. Every command runs through the runtime and its output is
parsed and normalized into the same finding and asset model.
