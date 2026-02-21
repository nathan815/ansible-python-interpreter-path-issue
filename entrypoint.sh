#!/bin/bash
set -e

echo "============================================"
echo "ansible-core 2.17 Shebang Quoting Repro"
echo "============================================"
echo ""
echo "Environment:"
ansible --version | head -3
echo "Remote shell: $(readlink -f /bin/sh)"
echo ""

# Start SSH server
/usr/sbin/sshd

echo "============================================"
echo "Running playbook with -vvvv"
echo "============================================"
echo ""

# Run the playbook, capture output
set +e
OUTPUT=$(ansible-playbook -i inventory playbook.yml -vvvv 2>&1)
RC=$?
set -e

# Print full output
echo "$OUTPUT"

echo ""
echo "============================================"
echo "KEY LINES - How the interpreter is invoked:"
echo "============================================"
echo ""

# Show the critical SSH execution lines
echo "$OUTPUT" | grep -E "'/usr/bin/env python'|/usr/bin/env python |'/usr/bin/python'|/usr/bin/python " | head -4

echo ""
echo "============================================"
echo "RESULT SUMMARY"
echo "============================================"
echo ""

if echo "$OUTPUT" | grep -q "/usr/bin/env python: not found"; then
    echo "BUG REPRODUCED: /usr/bin/env python gets single-quoted in the SSH"
    echo "command, causing dash to treat it as a single filename."
    echo ""
    echo "Module with #!/usr/bin/python  -> PASS (quoting harmless, no space)"
    echo "Module with #!/usr/bin/env python -> FAIL (quoting breaks env lookup)"
else
    echo "Bug NOT reproduced on this ansible-core version."
fi

echo ""
exit $RC
