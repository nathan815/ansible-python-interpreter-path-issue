#!/usr/bin/env python
# This module has the WRONG shebang per Ansible sanity rules.
# It should be #!/usr/bin/python but uses #!/usr/bin/env python.
# On ansible-core 2.17.x, this causes the interpreter to be quoted
# as '/usr/bin/env python' (single string) in the SSH command,
# which breaks on dash/sh.

import sys
from ansible.module_utils.basic import AnsibleModule


def main():
    module = AnsibleModule(
        argument_spec=dict(),
        supports_check_mode=True,
    )

    module.exit_json(
        changed=False,
        msg="Module with #!/usr/bin/env python shebang executed successfully",
        python_interpreter=sys.executable,
    )


if __name__ == "__main__":
    main()
