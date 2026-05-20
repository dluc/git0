# git0

git0 is a native macOS graphical client for the `git` version control system.
It is a fork of [GitX](https://github.com/gitx/gitx), significantly redesigned
and extended. The git0 repository is at https://github.com/dluc/git0.

## What's different from GitX

- **Redesigned history view** — commit list, commit details, and diff are split
  into independent resizable panels. Scroll the diff independently while keeping
  the file list visible.
- **Staging area reordered** — Unstaged → Staged → Commit Message, left to right.
- **Translucency option** — solid backgrounds by default; enable translucent
  sidebar/panel backgrounds in Preferences → Appearance.
- **Settings button** — gear icon in the bottom toolbar opens Preferences
  centred over the current window.
- **Consistent scrollbars** — all scroll views use overlay-style scrollers.

## Command-line usage

The `git0` CLI binary is bundled inside the app at:

```
git0.app/Contents/Resources/git0
```

Symlink it somewhere on your PATH to use it from the terminal:

```bash
ln -s /Applications/git0.app/Contents/Resources/git0 /usr/local/bin/git0
```

### Open a repository

```bash
# Open the repository in the current directory
git0

# Open a specific directory
git0 /path/to/repo
```

### History / branch filter

```bash
# View all branches
git0 --all

# View local branches only
git0 --local

# View the selected branch only
git0 --branch

# Select a specific branch on open
git0 --branch main
```

### Commit / stage view

```bash
git0 --commit
git0 -c
```

### Diff

```bash
# Show a diff in git0
git0 --diff HEAD~3

# Pipe a diff from stdin
git diff | git0
```

### Search

```bash
# Search subject, author or SHA
git0 --search=<string>
git0 -s<string>

# Pickaxe search (commits that add/remove string)
git0 --Search=<string>
git0 -S<string>

# Regex search
git0 --regex=<regex>
git0 -r<regex>

# Commits that touch a path
git0 --path=<file>
git0 -p<file>
git0 -- <file>
```

### Repository operations

```bash
# Initialise a new repository and open it
git0 --init

# Clone a repository and open it
git0 --clone <url>
git0 --clone <url> <destination>
```

### Target a specific repository

```bash
# --git-dir must be the first argument
git0 --git-dir=/path/to/repo [command]
```

### Other

```bash
git0 --version    # print version info
git0 --help       # print usage
```

## How to Build in Xcode

Create a `Dev.xcconfig` file at the project root:

```
DEVELOPMENT_TEAM = YOUR_TEAM_ID
CODE_SIGN_IDENTITY = Apple Development
ENABLE_HARDENED_RUNTIME = YES
```

Replace `YOUR_TEAM_ID` with your Apple development team ID (found in
Keychain Access → My Certificates → certificate details → Organizational Unit).

Then open `GitX.xcodeproj` in Xcode and run.

## License

git0 is licensed under GPL version 2, the same as the upstream GitX project.
See the `COPYING` file.
