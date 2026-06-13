# corechunk/cplay

dont update or touch the cplay file which is the compiled version of src/ folder and the compilation process is 

## compilation
```bash  
# from repo root
./scripts/deploy
```

## output
```text
┌─    zsh   kamui/netchunk    ✔ 
└─[ / run 󰁔 media 󰁔 part1 󰁔 inv 󰁔 codx 󰁔 remote 󰁔 bash 󰁔 cplay ]
❯ ./scripts/deploy                                                                                                 󱎫 230ms [13/06 03:48] CPU:27 Mem:6.3
[Sourcing Remote] dev|compile.sh -> https://raw.githubusercontent.com/corechunk/bash-lib/main/lib/dev/compile.sh ✅
📦 Compiling scripts...
  📁 [Source Dir]  src
  📂 [Output Dir]  .
  📄 [Output Name] cplay
  🎯 [Main Entry]  src/main.sh
  🔄 [Recursive]   true
  📝 [Shebang]     #!/usr/bin/env bash
  ⚙️ [Strip Mode]  all
  ➜ [Main Entry] src/main.sh
✅ Success: Compiled to ./cplay
```