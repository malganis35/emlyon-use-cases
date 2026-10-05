# Prerequisites Installation

# Windows

At each of your step, you will need to restart the terminal:

```
Start-Process powershell; exit
```

1. Install uv (Python installation)
```
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

2. Install Git (for versionning)
```
winget install -e --id Git.Git
```

3. Install Makefile support (for easy commands)
```
winget install ezwinports.make
```

4. Configure Git
```
git config --global user.name "FIRST_NAME LAST_NAME"
git config --global user.email "MY_NAME@example.com"
git config --global init.defaultBranch main
```

## MacOS

1. Install Homebrew
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

2. Add Homebrew to PATH

```
# Append Homebrew initialization to your Zsh login profile
echo >> ~/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv zsh)"' >> ~/.zprofile

# Load it immediately in your current terminal session
eval "$(/opt/homebrew/bin/brew shellenv zsh)"
```

2. Install Visual Studio
```
brew install --cask visual-studio-code
```

3. Install uv
```
brew install uv
```

4. Install Git
```
brew install git
```

5. Configure Git
```
git config --global user.name "FIRST_NAME LAST_NAME"
git config --global user.email "MY_NAME@example.com"
git config --global init.defaultBranch main
```
