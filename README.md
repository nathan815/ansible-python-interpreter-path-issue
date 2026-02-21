# Ansible Module Shebang Issue: `#!/usr/bin/env python` Breaks on SSH

## How to Run This Repro

```bash
docker build -t ansible-module-issue-repro .
docker run --rm ansible-module-issue-repro
```

## Summary

Custom Ansible modules that use `#!/usr/bin/env python` as their shebang violate [Ansible's module development requirements](https://docs.ansible.com/projects/ansible-core/devel/dev_guide/developing_modules_documenting.html#python-shebang-utf-8-coding) and will fail when executed over SSH on hosts where `/bin/sh` is `dash` (Ubuntu/Debian default).

The failure manifests as:

```
/bin/sh: 1: /usr/bin/env python: not found
```

This was previously masked on older ansible-core versions (2.15/2.16) but is exposed starting with ansible-core 2.17 due to a change in how the shell plugin quotes interpreter paths.

## Root Cause

**This is not an ansible-core bug — it is a module authoring issue.**

Per [Ansible's official documentation](https://docs.ansible.com/projects/ansible-core/devel/dev_guide/developing_modules_documenting.html#python-shebang-utf-8-coding):

> - Begin your Ansible module with `#!/usr/bin/python` so that `ansible_python_interpreter` works.
> - **Do NOT use `#!/usr/bin/env`** because it makes `env` the interpreter and bypasses `ansible_<interpreter>_interpreter` logic.
> - Passing arguments to the interpreter in the shebang does not work; for example, `#!/usr/bin/env python`.

The [shebang sanity test](https://docs.ansible.com/ansible/latest/dev_guide/testing/sanity/shebang.html) also states:

> This does not apply to Ansible modules, which should not be executable and **must always use `#!/usr/bin/python`**.

### Why it breaks

When a module uses `#!/usr/bin/env python`:

1. Ansible sees `/usr/bin/env` as the interpreter (not `/usr/bin/python`), so it does **not** substitute `ansible_python_interpreter` — see [issue #82737](https://github.com/ansible/ansible/issues/82737), confirmed as by-design behavior.
2. The literal string `/usr/bin/env python` (with a space) is used as the interpreter command in the SSH execution.
3. ansible-core 2.17's shell plugin quotes this value, producing `'/usr/bin/env python'` in the SSH command.
4. The remote shell (`dash`) treats the quoted string as a **single filename**, looks for a file literally named `env python` in `/usr/bin/`, and fails with exit code 127.

Modules with the correct `#!/usr/bin/python` shebang are unaffected because:
- Ansible properly substitutes `ansible_python_interpreter`
- Even when quoted, `'/usr/bin/python'` is equivalent to `/usr/bin/python` (no space)

### Why it worked before

On ansible-core 2.15/2.16, the interpreter path was passed **unquoted** through the SSH command, so `/usr/bin/env python` happened to work as two separate tokens. This was a lucky accident — the modules were always non-compliant.

## Reproduction

This repo provides a self-contained Docker-based reproduction.

### Using Docker (recommended)

```bash
docker build -t ansible-module-issue-repro .
docker run --rm ansible-module-issue-repro
```

### Manual

Prerequisites:
- ansible-core 2.17.x on the control node
- A remote host accessible via SSH where `/bin/sh` is `dash` (e.g., Ubuntu/Debian)

```bash
pip install ansible-core==2.17.7
# Edit inventory with your target host
ansible-playbook -i inventory playbook.yml -vvvv
```

### Expected vs Actual

| Module | Shebang | Result |
|---|---|---|
| `test_noshebang` | `#!/usr/bin/python` | **Passes** on all versions |
| `test_shebang` | `#!/usr/bin/env python` | **Fails** on 2.17.x |

In `-vvvv` output you'll see the difference:
```
# Correct shebang — quoting is harmless (no space):
'/usr/bin/python' /root/.ansible/tmp/.../AnsiballZ_test_noshebang.py

# Wrong shebang — quoting breaks it (space inside quotes):
'/usr/bin/env python' /root/.ansible/tmp/.../AnsiballZ_test_shebang.py
```

## Fix

**Change module shebangs from `#!/usr/bin/env python` to `#!/usr/bin/python`** per Ansible's module development requirements.

### Workarounds (if you can't fix modules immediately)

1. Set `interpreter_python = /usr/bin/python3` in `ansible.cfg` under `[defaults]`
2. Downgrade to ansible-core 2.16.x (ansible 9.x)

## References

- [Ansible module shebang requirements](https://docs.ansible.com/projects/ansible-core/devel/dev_guide/developing_modules_documenting.html#python-shebang-utf-8-coding)
- [Ansible sanity test: shebang](https://docs.ansible.com/ansible/latest/dev_guide/testing/sanity/shebang.html)
- [Issue #82737: ansible_python_interpreter not honored with #!/usr/bin/env shebang](https://github.com/ansible/ansible/issues/82737) (confirmed by-design)
