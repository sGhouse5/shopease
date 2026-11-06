# Demo script (about 8 minutes)

Rehearse twice. Record a backup screen capture of a full run before the viva.

1. **Show the architecture** (README diagram). One sentence per tool.
2. **Show the board** in Azure DevOps: a story moving to Done.
3. **Make a small visible change** (for example edit the heading in `index.html`), commit to a branch, open a PR that mentions an issue.
4. **Show Azure Pipelines** running the build and tests on the PR.
5. **Merge to main.** Show Jenkins starting automatically (webhook).
6. **Walk through the stages** in Jenkins: build, test (open the test report), package (archived jar), approval if production.
7. **Open the site** and point at the new version in the footer.
8. **Rollback:** push the deliberately broken build. Show the red Jenkins run, the Ansible rollback message and the site still working.
9. **Close:** what you would add next (Docker, SonarQube, notifications).

## Questions to prepare for

- Why Jenkins *and* Azure DevOps? (Jenkins deploys, Azure DevOps tracks work and runs a second build pipeline for comparison.)
- Why release folders and a symlink? (instant rollback, see ADR 0002)
- Why Gradle rather than Maven? (ADR 0001)
- How are secrets handled? (Jenkins credentials, no keys in the repo)
- What happens if a deployment fails? (health check, rollback, red build)
