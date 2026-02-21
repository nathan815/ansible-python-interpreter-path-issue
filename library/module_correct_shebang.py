#!/usr/bin/python
# This module has the CORRECT shebang per Ansible sanity rules.
# Ansible will properly replace /usr/bin/python with the configured
# ansible_python_interpreter, and quoting '/usr/bin/python' is harmless
# since there's no space.

import sys
from ansible.module_utils.basic import AnsibleModule


def main():
    module = AnsibleModule(
        argument_spec=dict(),
        supports_check_mode=True,
    )

    module.exit_json(
        changed=False,
        msg="Module with #!/usr/bin/python shebang executed successfully",
        python_interpreter=sys.executable,
    )


if __name__ == "__main__":
    main()
