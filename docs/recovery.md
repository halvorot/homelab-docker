# Recovery

1. Reinstall Proxmox and Ubuntu VM.
2. Install Docker, Docker Compose, Restic, GitHub runner.
3. Clone this repo to `/srv/stacks/homelab-docker`.
4. Restore data:

    ```bash
    ./scripts/backup/restic-restore.sh latest /srv
    ```

5. Re-deploy via Github
