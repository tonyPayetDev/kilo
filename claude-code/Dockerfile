FROM codercom/code-server:latest

USER coder
WORKDIR /home/coder/project

# Claude Code native installation, as the unprivileged coder user.
RUN curl -fsSL https://claude.ai/install.sh -o /tmp/claude-install.sh \
    && bash /tmp/claude-install.sh \
    && rm /tmp/claude-install.sh

ENV PATH="/home/coder/.local/bin:${PATH}"
EXPOSE 8080

# Refuse to start without an explicit password configured in Coolify.
CMD ["sh", "-c", "test -n \"$PASSWORD\" || { echo 'ERROR: Configure PASSWORD in Coolify first.' >&2; exit 1; }; exec code-server --auth password --bind-addr 0.0.0.0:8080 /home/coder/project"]
